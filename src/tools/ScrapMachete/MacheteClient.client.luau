-- ReplicatedStorage.Scrap Machete.MacheteClient
-- Client target selection + back holster. The server (CombatManager)
-- independently re-validates range/cooldown before applying damage; this only picks a target.
local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tags = require(Shared:WaitForChild("Tags"))
local ToolEffects = require(Shared:WaitForChild("ToolEffects"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local macheteAttackEvent = Net.event("CombatEvents", "MacheteAttack")

local MACHETE = GameConfig.Machete
local TUNING = GameConfig.WeaponTuning.MacheteGrip

local function applyGrip()
	local g = TUNING
	Tool.Grip = CFrame.new(g.PosX, g.PosY, g.PosZ)
		* CFrame.Angles(0, math.rad(g.RotY), 0)
		* CFrame.Angles(math.rad(g.RotX), 0, 0)
		* CFrame.Angles(0, 0, math.rad(g.RotZ))
end
local RANGE = MACHETE.ClientRange
local CONE_DOT = MACHETE.ClientConeDot
local COOLDOWN = MACHETE.ClientCooldown
local HOLSTER_NAME = "MacheteHolster"
local SWING_ANIM_ID = MACHETE.SwingAnimationId
local SWING_ANIM_SPEEDS = MACHETE.SwingAnimationSpeeds

local lastAttack = 0

-- Swing animation: one AnimationTrack loaded fresh onto the current character's Animator
-- each Equip, replayed at alternating speeds per swing (see GameConfig) for variety.
local swingTracks: { AnimationTrack } = {}
local swingIndex = 0

local function loadSwingAnimations(character: Model?)
	swingTracks = {}
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local anim = Instance.new("Animation")
	anim.AnimationId = SWING_ANIM_ID
	for _ in ipairs(SWING_ANIM_SPEEDS) do
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			table.insert(swingTracks, track)
		end
	end
end

local function playSwingAnimation()
	if #swingTracks == 0 then
		return
	end
	swingIndex = (swingIndex % #swingTracks) + 1
	local track = swingTracks[swingIndex]
	track:Play(0.05, 1, SWING_ANIM_SPEEDS[swingIndex])
end

local function stopSwingAnimations()
	for _, track in ipairs(swingTracks) do
		track:Stop()
	end
end

-- Picks the closest Mycomorph or ScrapPile roughly in front of the player.
local function findClosestTarget()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local closest, closestDist = nil, MACHETE.ClientRange

	-- 1. Search tagged Mycomorph enemies
	local CollectionService = game:GetService("CollectionService")
	for _, model in ipairs(CollectionService:GetTagged(Tags.Mycomorph)) do
		local mRoot = model.PrimaryPart
		-- The Wildling rig's Humanoid is named "Zombie", not "Humanoid" -- look up by class.
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if mRoot and humanoid and humanoid.Health > 0 then
			local toTarget = mRoot.Position - root.Position
			local dist = toTarget.Magnitude
			if dist <= closestDist and dist > 0 then
				if root.CFrame.LookVector:Dot(toTarget.Unit) > MACHETE.ClientConeDot then
					closest = model
					closestDist = dist
				end
			end
		end
	end

	-- 2. Search ScrapPiles (minable models)
	for _, model in ipairs(workspace:GetChildren()) do
		if model.Name == "ScrapPile" then
			local mRoot = model.PrimaryPart
			if mRoot then
				local toTarget = mRoot.Position - root.Position
				local dist = toTarget.Magnitude
				if dist <= closestDist and dist > 0 then
					if root.CFrame.LookVector:Dot(toTarget.Unit) > MACHETE.ClientConeDot then
						closest = model
						closestDist = dist
					end
				end
			end
		end
	end

	return closest
end

Tool.Activated:Connect(function()
	local now = os.clock()
	if now - lastAttack < COOLDOWN then
		return
	end
	lastAttack = now

	playSwingAnimation()

	local target = findClosestTarget()
	if target then
		-- Send hit command to server
		macheteAttackEvent:FireServer(target)
	end
end)

-- Holster connections
Tool.Equipped:Connect(function()
	applyGrip()
	ToolEffects.removeHolster(player.Character, HOLSTER_NAME)
	loadSwingAnimations(player.Character)
end)

Tool.Unequipped:Connect(function()
	ToolEffects.showHolster(Tool, player.Character, HOLSTER_NAME)
	stopSwingAnimations()
	comboStep = 1 -- reset combo on holster
end)

if player.Character then
	ToolEffects.showHolster(Tool, player.Character, HOLSTER_NAME)
end

player.CharacterAdded:Connect(function(char)
	ToolEffects.showHolster(Tool, char, HOLSTER_NAME)
end)
