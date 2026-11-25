-- ===============================================================
--  [LA] LETHAL APE ESP + AUTO FARM (FINAL VERSION)
--  Author: DevXelw
--  Version: 2.4
--  
--  Features:
--  [OK] Monsters: purple outline + names on top
--  [OK] Resources: colored outlines (Gold, Meat, Emerald, Diamond, Copper)
--  [OK] Auto-hide resources when collected (transparency check)
--  [OK] Mobile auto-farm button (finger-draggable)
--  [OK] Auto-teleport to resources and automatic collection
--  [OK] Return to original position on disable
--  [OK] Anti-fall during farming
--  [OK] Fast farming
--  [OK] Auto-disable when no resources remain
--  [OK] Compact button
--  [OK] Works in folders: Sandman/Ashy, KusMonster, DusMonster, GusMonster, LostMonster, Scraps
-- ===============================================================

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local activeESP = {}
local autoFarmEnabled = false
local currentTarget = nil
local farmConnection = nil
local antiFallConnection = nil
local originalPosition = nil
local isTeleporting = false
local noResourcesCount = 0
local maxNoResourcesAttempts = 5 -- Search attempts before auto-disable

-- --------------------------------------------------------------
--  FOLDERS TO SEARCH
-- --------------------------------------------------------------
local MONSTER_FOLDERS = {
    "Sandman/Ashy",
    "KusMonster",
    "DusMonster",
    "GusMonster",
    "LostMonster"
}

local SCRAP_FOLDERS = {
    "Scraps"
}

-- --------------------------------------------------------------
--  RESOURCE COLORS
-- --------------------------------------------------------------
local RESOURCE_COLORS = {
    Gold = Color3.new(1, 0.8, 0),      -- Yellow
    Meat = Color3.new(1, 0, 0),        -- Red
    Emerald = Color3.new(0, 1, 0),     -- Green
    Diamond = Color3.new(0, 0.6, 1),   -- Blue
    Copper = Color3.new(0.8, 0.4, 0),  -- Orange
}

-- --------------------------------------------------------------
--  CHECK: IS IT A MONSTER?
-- --------------------------------------------------------------
local function isMonster(obj)
    if not obj:IsA("Model") then return false end
    if not obj:FindFirstChildOfClass("Humanoid") then return false end
    if obj == LocalPlayer.Character then return false end
    return true
end

-- --------------------------------------------------------------
--  CHECK: IS RESOURCE VISIBLE?
-- --------------------------------------------------------------
local function isResourceVisible(resource)
    local parts = {}
    
    if resource:IsA("Model") then
        for _, part in ipairs(resource:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(parts, part)
            end
        end
    elseif resource:IsA("BasePart") then
        table.insert(parts, resource)
    end
    
    if #parts == 0 then return true end
    
    for _, part in ipairs(parts) do
        if part.Transparency < 0.9 then
            if part.Position.Y > -100 and part.Position.Y < 1000 then
                return true
            end
        end
    end
    
    return false
end

-- --------------------------------------------------------------
--  GET RESOURCE COLOR
-- --------------------------------------------------------------
local function getResourceColor(obj)
    local name = obj.Name
    for resourceName, color in pairs(RESOURCE_COLORS) do
        if name:find(resourceName) then
            return color
        end
    end
    return Color3.new(1, 1, 1)
end

-- --------------------------------------------------------------
--  CREATE MONSTER HIGHLIGHT
-- --------------------------------------------------------------
local function createMonsterESP(monster)
    if activeESP[monster] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.new(0.6, 0, 1)
    highlight.FillTransparency = 0.35
    highlight.OutlineTransparency = 0.1
    highlight.Parent = monster
    
    local head = monster:FindFirstChild("Head") or monster:FindFirstChild("HumanoidRootPart")
    if head then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "MonsterESP"
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 120, 0, 25)
        billboard.StudsOffset = Vector3.new(0, 4, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = monster
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = monster.Name
        label.TextSize = 13
        label.TextColor3 = Color3.new(0.6, 0, 1)
        label.Font = Enum.Font.SourceSansBold
        label.TextStrokeTransparency = 0.2
        label.Parent = billboard
        
        activeESP[monster] = {
            Highlight = highlight,
            Billboard = billboard,
            Type = "Monster"
        }
    else
        activeESP[monster] = {
            Highlight = highlight,
            Type = "Monster"
        }
    end
end

-- --------------------------------------------------------------
--  CREATE RESOURCE HIGHLIGHT
-- --------------------------------------------------------------
local function createResourceESP(resource)
    if activeESP[resource] then return end
    
    local color = getResourceColor(resource)
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = color
    highlight.FillTransparency = 0.3
    highlight.OutlineTransparency = 0.1
    highlight.Parent = resource
    
    activeESP[resource] = {
        Highlight = highlight,
        Type = "Resource"
    }
end

-- --------------------------------------------------------------
--  REMOVE HIGHLIGHT
-- --------------------------------------------------------------
local function removeESP(obj)
    local esp = activeESP[obj]
    if esp then
        if esp.Highlight then esp.Highlight:Destroy() end
        if esp.Billboard then esp.Billboard:Destroy() end
        activeESP[obj] = nil
    end
end

-- --------------------------------------------------------------
--  REFRESH LIST
-- --------------------------------------------------------------
local function updateESP()
    local current = {}
    
    -- Monsters
    for _, folderName in ipairs(MONSTER_FOLDERS) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if isMonster(obj) then
                    current[obj] = true
                    if not activeESP[obj] then
                        createMonsterESP(obj)
                    end
                end
            end
        end
    end
    
    -- Resources (Scraps)
    for _, folderName in ipairs(SCRAP_FOLDERS) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                current[obj] = true
                if isResourceVisible(obj) then
                    if not activeESP[obj] then
                        createResourceESP(obj)
                    end
                else
                    if activeESP[obj] then
                        removeESP(obj)
                    end
                end
            end
        end
    end
    
    for obj, _ in pairs(activeESP) do
        if not current[obj] or not obj.Parent then
            removeESP(obj)
        end
    end
end

-- --------------------------------------------------------------
--  AUTO-FARM FUNCTIONS
-- --------------------------------------------------------------
-- Check if resources exist on map
local function hasAnyResources()
    for _, folderName in ipairs(SCRAP_FOLDERS) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if isResourceVisible(obj) then
                    return true
                end
            end
        end
    end
    return false
end

local function findNearestResource()
    local nearest = nil
    local shortestDistance = math.huge
    local character = LocalPlayer.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not humanoidRootPart then return nil end
    
    for _, folderName in ipairs(SCRAP_FOLDERS) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if isResourceVisible(obj) and obj ~= currentTarget then
                    local mainPart = nil
                    
                    -- Find main part of resource
                    if obj:IsA("Model") then
                        mainPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Base") or obj:FindFirstChild("Part")
                        if not mainPart then
                            for _, child in ipairs(obj:GetDescendants()) do
                                if child:IsA("BasePart") then
                                    mainPart = child
                                    break
                                end
                            end
                        end
                    elseif obj:IsA("BasePart") then
                        mainPart = obj
                    end
                    
                    if mainPart and mainPart:IsA("BasePart") then
                        local distance = (mainPart.Position - humanoidRootPart.Position).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            nearest = obj
                        end
                    end
                end
            end
        end
    end
    
    return nearest
end

-- Find ProximityPrompt in resource
local function findProximityPrompt(resource)
    if not resource then return nil end
    
    -- Check the object itself
    local prompt = resource:FindFirstChildOfClass("ProximityPrompt")
    if prompt then return prompt end
    
    -- Check all descendants
    for _, child in ipairs(resource:GetDescendants()) do
        if child:IsA("ProximityPrompt") then
            return child
        end
    end
    
    return nil
end

-- Force-activate ProximityPrompt
local function forceActivatePrompt(prompt)
    if not prompt then return false end
    
    -- Multiple activation attempts
    for i = 1, 3 do
        pcall(function()
            fireproximityprompt(prompt)
        end)
        
        pcall(function()
            prompt:InputHoldBegin()
        end)
        
        task.wait(0.1)
        
        pcall(function()
            prompt:InputHoldEnd()
        end)
        
        task.wait(0.05)
    end
    
    return true
end

-- Teleport and face the resource
local function teleportAndFaceResource(resource)
    local character = LocalPlayer.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not humanoidRootPart or not resource then return false end
    
    local mainPart = nil
    
    -- Find the main part
    if resource:IsA("Model") then
        mainPart = resource:FindFirstChild("HumanoidRootPart") or resource:FindFirstChild("Base") or resource:FindFirstChild("Part")
        if not mainPart then
            for _, child in ipairs(resource:GetDescendants()) do
                if child:IsA("BasePart") then
                    mainPart = child
                    break
                end
            end
        end
    elseif resource:IsA("BasePart") then
        mainPart = resource
    end
    
    if not mainPart or not mainPart:IsA("BasePart") then return false end
    
    -- Teleport right to the resource (slightly above)
    local targetPosition = mainPart.Position + Vector3.new(0, 3, 0)
    
    -- Create CFrame looking at the resource
    local lookAt = CFrame.lookAt(targetPosition, mainPart.Position)
    
    -- Smooth teleport
    isTeleporting = true
    humanoidRootPart.CFrame = lookAt
    humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
    humanoidRootPart.RotVelocity = Vector3.new(0, 0, 0)
    
    task.wait(0.05)
    isTeleporting = false
    
    return true
end

-- Anti-fall system
local function startAntiFall()
    if antiFallConnection then
        antiFallConnection:Disconnect()
    end
    
    antiFallConnection = RunService.Heartbeat:Connect(function()
        if autoFarmEnabled and not isTeleporting then
            local character = LocalPlayer.Character
            local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChild("Humanoid")
            
            if humanoidRootPart and humanoid then
                -- Check if character is falling
                if humanoidRootPart.Velocity.Y < -50 then
                    -- Stop the fall
                    humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
                    humanoidRootPart.RotVelocity = Vector3.new(0, 0, 0)
                    
                    -- Lift slightly up
                    local newPos = humanoidRootPart.Position + Vector3.new(0, 5, 0)
                    humanoidRootPart.CFrame = CFrame.new(newPos)
                end
                
                -- Hold character in place (anti-gravity)
                if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
                    humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
                    
                    -- Find ground below character
                    local rayOrigin = humanoidRootPart.Position
                    local rayDirection = Vector3.new(0, -10, 0)
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterDescendantsInstances = {character}
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    
                    local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                    
                    if raycastResult then
                        -- Place character on ground
                        humanoidRootPart.CFrame = CFrame.new(raycastResult.Position + Vector3.new(0, 3, 0))
                    end
                end
            end
        end
    end)
end

local function stopAntiFall()
    if antiFallConnection then
        antiFallConnection:Disconnect()
        antiFallConnection = nil
    end
end

-- Save position
local function savePosition()
    local character = LocalPlayer.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if humanoidRootPart then
        originalPosition = humanoidRootPart.CFrame
        print("[Auto Farm] Position saved")
    end
end

-- Return to original position
local function returnToOriginalPosition()
    if originalPosition then
        local character = LocalPlayer.Character
        local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
        
        if humanoidRootPart then
            isTeleporting = true
            humanoidRootPart.CFrame = originalPosition
            humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
            humanoidRootPart.RotVelocity = Vector3.new(0, 0, 0)
            
            task.wait(0.1)
            isTeleporting = false
            
            print("[Auto Farm] Return to original position")
            originalPosition = nil
        end
    end
end

-- Stop farming function
local function stopFarm(button)
    autoFarmEnabled = false
    
    if button then
        button.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
        button.Text = "[AF]"
    end
    
    -- Stop farming
    if farmConnection then
        task.cancel(farmConnection)
        farmConnection = nil
    end
    
    -- Stop anti-fall
    stopAntiFall()
    
    -- Return to original position
    returnToOriginalPosition()
    
    -- Reset counter
    noResourcesCount = 0
end

-- Main farm loop
local function farmLoop(button)
    while autoFarmEnabled do
        if not autoFarmEnabled then break end
        
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        
        if character and humanoid and humanoid.Health > 0 then
            -- Check for resources
            if not hasAnyResources() then
                noResourcesCount += 1
                print("[Auto Farm] No resources found (attempt " .. noResourcesCount .. " of " .. maxNoResourcesAttempts .. ")")
                
                if noResourcesCount >= maxNoResourcesAttempts then
                    print("[Auto Farm] No resources left! Auto-disabling...")
                    stopFarm(button)
                    break
                end
                
                task.wait(1)
                continue
            else
                -- Reset counter when resources found
                noResourcesCount = 0
            end
            
            -- Find nearest resource
            local target = findNearestResource()
            
            if target then
                currentTarget = target
                
                -- Teleport and face resource
                if teleportAndFaceResource(target) then
                    -- Look for ProximityPrompt
                    local prompt = findProximityPrompt(target)
                    
                    if prompt then
                        -- Fast activation
                        for i = 1, 5 do
                            if not autoFarmEnabled then break end
                            
                            forceActivatePrompt(prompt)
                            
                            task.wait(0.15)
                            
                            -- Check if resource disappeared
                            if not isResourceVisible(target) or not target.Parent then
                                break
                            end
                        end
                    else
                        -- Try ProximityPrompt in radius
                        local radius = 10
                        local character = LocalPlayer.Character
                        
                        if character and character:FindFirstChild("HumanoidRootPart") then
                            for _, obj in ipairs(Workspace:GetDescendants()) do
                                if obj:IsA("ProximityPrompt") and obj.Parent then
                                    local promptPart = obj.Parent
                                    if promptPart:IsA("BasePart") then
                                        local distance = (promptPart.Position - character.HumanoidRootPart.Position).Magnitude
                                        if distance < radius then
                                            forceActivatePrompt(obj)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                currentTarget = nil
                
                -- Minimal delay for speed
                task.wait(0.2)
            else
                -- If target not found but resources exist
                noResourcesCount += 1
                
                if noResourcesCount >= maxNoResourcesAttempts then
                    print("[Auto Farm] Cannot find resources! Auto-disabling...")
                    stopFarm(button)
                    break
                end
                
                task.wait(1)
            end
        else
            task.wait(0.5)
        end
        
        task.wait(0.1)
    end
end

-- --------------------------------------------------------------
--  CREATE MOBILE BUTTON (COMPACT VERSION)
-- --------------------------------------------------------------
local function createMobileButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoFarmGUI"
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    
    -- Small button
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 45, 0, 45) -- Reduced size (was 80x80)
    button.Position = UDim2.new(0.85, 0, 0.75, 0)
    button.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    button.BackgroundTransparency = 0.3
    button.BorderSizePixel = 0
    button.Text = "[AF]"
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 20 -- Reduced text size (was 16)
    button.AutoButtonColor = false
    button.ZIndex = 10
    button.Parent = screenGui
    
    -- Button styling
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 22) -- Half of size for round shape
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 1.5 -- Thinner stroke
    stroke.Transparency = 0.5
    stroke.Parent = button
    
    -- Button dragging
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local clickTime = 0
    
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
            clickTime = tick()
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    button.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            local newX = startPos.X.Scale + (delta.X / Workspace.CurrentCamera.ViewportSize.X)
            local newY = startPos.Y.Scale + (delta.Y / Workspace.CurrentCamera.ViewportSize.Y)
            
            newX = math.clamp(newX, 0, 1 - (button.Size.X.Offset / Workspace.CurrentCamera.ViewportSize.X))
            newY = math.clamp(newY, 0, 1 - (button.Size.Y.Offset / Workspace.CurrentCamera.ViewportSize.Y))
            
            button.Position = UDim2.new(newX, 0, newY, 0)
        end
    end)
    
    -- Toggle auto-farm
    button.MouseButton1Click:Connect(function()
        -- Check if it was a drag or a click
        if tick() - clickTime < 0.3 then
            autoFarmEnabled = not autoFarmEnabled
            
            if autoFarmEnabled then
                button.BackgroundColor3 = Color3.new(0, 0.8, 0)
                button.Text = "[OK]"
                print("[Auto Farm] ON")
                
                -- Save position
                savePosition()
                
                -- Start anti-fall
                startAntiFall()
                
                -- Reset counter
                noResourcesCount = 0
                
                -- Start farming
                farmConnection = task.spawn(function()
                    farmLoop(button)
                end)
            else
                print("[Auto Farm] Manually disabled")
                stopFarm(button)
            end
        end
    end)
    
    return button
end

-- --------------------------------------------------------------
--  STARTUP
-- --------------------------------------------------------------
print("[Lethal Ape ESP + Auto Farm] Loaded!")
print("[ESP] Monsters: purple + names")
print("[ESP] Resources: colored outlines (Gold, Meat, Emerald, Diamond, Copper)")
print("[Auto Farm] Mobile button created (compact)")
print("[Auto Farm] Position saving: ON")
print("[Auto Farm] Anti-fall: ON")
print("[Auto Farm] Speed: Fast")
print("[Auto Farm] Auto-disable when no resources: ON")

task.wait(0.5)
updateESP()

-- Create mobile button
createMobileButton()

-- ESP update loop
task.spawn(function()
    while task.wait(0.5) do
        updateESP()
    end
end)

-- Watch for new objects
for _, folderName in ipairs(MONSTER_FOLDERS) do
    local folder = Workspace:FindFirstChild(folderName)
    if folder then
        folder.ChildAdded:Connect(function(obj)
            task.wait(0.1)
            if isMonster(obj) then
                createMonsterESP(obj)
            end
        end)
    end
end

for _, folderName in ipairs(SCRAP_FOLDERS) do
    local folder = Workspace:FindFirstChild(folderName)
    if folder then
        folder.ChildAdded:Connect(function(obj)
            task.wait(0.1)
            createResourceESP(obj)
        end)
    end
end