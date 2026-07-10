-- StarterPlayerScripts.ArmAimController
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local MAX_ANGLE = math.rad(45) -- 45 degrees limit

local function getShoulderJoint(character)
	local rightUpperArm = character:FindFirstChild("RightUpperArm")
	if not rightUpperArm then return nil end
	return rightUpperArm:FindFirstChild("RightShoulder")
end

-- Connect to Stepped (runs after animations but before physics/rendering)
RunService.Stepped:Connect(function()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Arm aiming only applies to guns/pistols (Improvised Pistol)
	local tool = character:FindFirstChildOfClass("Tool")
	local isGun = tool and (tool.Name == "Improvised Pistol")
	local shoulder = getShoulderJoint(character)
	local upperTorso = character:FindFirstChild("UpperTorso")

	if isGun and shoulder and upperTorso then
		local shoulderWorldPos = upperTorso.CFrame:PointToWorldSpace(shoulder.C0.Position)
		local mousePos = mouse.Hit.Position
		local toMouse = mousePos - shoulderWorldPos

		if toMouse.Magnitude > 0 then
			toMouse = toMouse.Unit
			-- Convert the direction vector into upperTorso local space
			local localDir = upperTorso.CFrame:VectorToObjectSpace(toMouse)

			-- Calculate yaw (horizontal angle) and pitch (vertical angle) relative to the front (0, 0, -1)
			local yaw = math.atan2(localDir.X, -localDir.Z)
			local pitch = math.atan2(localDir.Y, math.sqrt(localDir.X^2 + localDir.Z^2))

			-- Clamp to the 45-degree cone
			yaw = math.clamp(yaw, -MAX_ANGLE, MAX_ANGLE)
			pitch = math.clamp(pitch, -MAX_ANGLE, MAX_ANGLE)

			-- Apply aiming directly to the joint Transform (R15 default arm points down, offset by 90 on X)
			shoulder.Transform = CFrame.Angles(math.rad(90) + pitch, 0, yaw)
		end
	end
	-- No else branch: for melee/no tool, never touch the shoulder so Roblox's
	-- default animations (idle, walk, run, tool hold) drive it untouched.
end)
