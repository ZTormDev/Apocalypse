-- StarterPlayerScripts.FootstepController
-- Roblox's built-in footstep sound is engine-managed and doesn't differentiate walking from
-- sprinting enough to be noticeable, so this mutes the default "Running" sound and drives our
-- own footstep audio with a clearly distinct cadence/pitch/volume per state.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local PLAYER_MOVEMENT = GameConfig.Player

local FOOTSTEP_SOUND_ID = "rbxassetid://139218459028027"

local WALK_INTERVAL = 0.35
local WALK_PITCH = 0.9
local WALK_VOLUME = 0.8

local SPRINT_INTERVAL = 0.25
local SPRINT_PITCH = 1.1
local SPRINT_VOLUME = 1

local player = Players.LocalPlayer
local stepConn: RBXScriptConnection? = nil

local function muteDefaultRunningSound(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 5)
	local defaultRunning = root and root:WaitForChild("Running", 5)
	if defaultRunning and defaultRunning:IsA("Sound") then
		defaultRunning.Volume = 0
	end
end

local function onCharacterAdded(char: Model)
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	local root = char:WaitForChild("HumanoidRootPart") :: BasePart

	local footstepSound = Instance.new("Sound")
	footstepSound.Name = "Footstep"
	footstepSound.SoundId = FOOTSTEP_SOUND_ID
	footstepSound.Parent = root

	task.spawn(muteDefaultRunningSound, char)

	if stepConn then
		stepConn:Disconnect()
	end

	local stepTimer = 0
	stepConn = RunService.Heartbeat:Connect(function(dt)
		-- Do not play footstep sounds if dead, not moving, or in the air (FloorMaterial is Air)
		if humanoid.Health <= 0 or humanoid.MoveDirection.Magnitude == 0 or humanoid.FloorMaterial == Enum.Material.Air then
			stepTimer = 0
			return
		end

		local sprinting = humanoid.WalkSpeed >= PLAYER_MOVEMENT.SprintSpeed - 0.5
		local interval = sprinting and SPRINT_INTERVAL or WALK_INTERVAL

		stepTimer += dt
		if stepTimer >= interval then
			stepTimer = 0
			footstepSound.PlaybackSpeed = sprinting and SPRINT_PITCH or WALK_PITCH
			footstepSound.Volume = sprinting and SPRINT_VOLUME or WALK_VOLUME
			footstepSound:Play()
		end
	end)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
