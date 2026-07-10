-- StarterPlayerScripts.SprintController
-- Hold Shift to sprint. Speed values come from GameConfig so tuning stays in one place.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local PLAYER_MOVEMENT = GameConfig.Player

local player = Players.LocalPlayer

local function getHumanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function setSprinting(sprinting: boolean)
	local humanoid = getHumanoid()
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = sprinting and PLAYER_MOVEMENT.SprintSpeed or PLAYER_MOVEMENT.WalkSpeed
end

local function onCharacterAdded(char: Model)
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = PLAYER_MOVEMENT.WalkSpeed
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprinting(true)
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprinting(false)
	end
end)
