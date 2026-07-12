--!strict
-- ServerScriptService.modules.Ragdoll
-- Converts a character's animated Motor6D rig into physics-simulated BallSocketConstraints on
-- death, so it flops naturally in place (a real ragdoll) instead of Roblox's default
-- BreakJointsOnDeath behavior (which disassembles the rig into disconnected floating parts).
--
-- Two things make a naive version of this look broken, both fixed here:
--   1. Self-collision: without disabling it, every limb collides with its neighbors and the
--      whole rig vibrates/explodes instead of settling. Fixed by moving every part of the
--      ragdolled character into a dedicated CollisionGroup that doesn't collide with itself.
--   2. Uniform joint limits: giving every joint the same generic cone (e.g. the engine's
--      45-degree default) makes shoulders/hips look locked up and wrists/neck look loose.
--      Fixed with per-joint-name limits approximating real human range of motion.
local PhysicsService = game:GetService("PhysicsService")

local Ragdoll = {}

local COLLISION_GROUP = "RagdollNoSelfCollide"
local collisionGroupReady = false

local function ensureCollisionGroup()
	if collisionGroupReady then
		return
	end
	collisionGroupReady = true
	pcall(function()
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end

-- Cone half-angle (degrees) and twist range per R15 joint name. Anything not listed falls back
-- to DEFAULT_LIMITS. Roughly modeled on real human joint mobility -- tight wrists/ankles/neck,
-- loose shoulders/hips.
local JOINT_LIMITS: { [string]: { upperAngle: number, twist: number } } = {
	Neck = { upperAngle = 35, twist = 40 },
	Waist = { upperAngle = 25, twist = 30 },
	Root = { upperAngle = 20, twist = 20 },
	RootJoint = { upperAngle = 20, twist = 20 },

	LeftShoulder = { upperAngle = 80, twist = 60 },
	RightShoulder = { upperAngle = 80, twist = 60 },
	LeftHip = { upperAngle = 60, twist = 45 },
	RightHip = { upperAngle = 60, twist = 45 },

	LeftElbow = { upperAngle = 70, twist = 15 },
	RightElbow = { upperAngle = 70, twist = 15 },
	LeftKnee = { upperAngle = 70, twist = 5 },
	RightKnee = { upperAngle = 70, twist = 5 },

	LeftWrist = { upperAngle = 30, twist = 20 },
	RightWrist = { upperAngle = 30, twist = 20 },
	LeftAnkle = { upperAngle = 30, twist = 15 },
	RightAnkle = { upperAngle = 30, twist = 15 },
}
local DEFAULT_LIMITS = { upperAngle = 45, twist = 30 }

function Ragdoll.apply(character: Model)
	ensureCollisionGroup()

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Hands full control of the rig to physics instead of the Humanoid's animation/movement
		-- state machine, which would otherwise keep fighting the ragdoll to hold its last pose.
		humanoid.PlatformStand = true
	end

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = COLLISION_GROUP
		end
	end

	for _, joint in ipairs(character:GetDescendants()) do
		if joint:IsA("Motor6D") then
			local part0, part1 = joint.Part0, joint.Part1
			if part0 and part1 then
				local a0 = Instance.new("Attachment")
				a0.Name = "RagdollAttachment0"
				a0.CFrame = joint.C0
				a0.Parent = part0

				local a1 = Instance.new("Attachment")
				a1.Name = "RagdollAttachment1"
				a1.CFrame = joint.C1
				a1.Parent = part1

				local limits = JOINT_LIMITS[joint.Name] or DEFAULT_LIMITS

				local socket = Instance.new("BallSocketConstraint")
				socket.Name = "RagdollSocket"
				socket.Attachment0 = a0
				socket.Attachment1 = a1
				socket.LimitsEnabled = true
				socket.UpperAngle = limits.upperAngle
				socket.TwistLimitsEnabled = true
				socket.TwistLowerAngle = -limits.twist
				socket.TwistUpperAngle = limits.twist
				socket.Parent = part0

				joint:Destroy()
			end
		end
	end
end

return Ragdoll
