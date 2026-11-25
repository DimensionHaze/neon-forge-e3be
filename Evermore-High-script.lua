local PlayerService = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = PlayerService.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local isSpeedActive = false
local normalSpeed = 16
local boostedSpeed = 45

local function toggleSpeed()
    isSpeedActive = not isSpeedActive
    if isSpeedActive then
        humanoid.WalkSpeed = boostedSpeed
    else
        humanoid.WalkSpeed = normalSpeed
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.LeftControl then
        toggleSpeed()
        local feedbackTween = TweenService:Create(humanoid, TweenInfo.new(0.5), {JumpPower = 75})
        feedbackTween:Play()
    end
end)

print("Evermore Helper Initialized - Press Left Control to Toggle")
