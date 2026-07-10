-- ReplicatedStorage.Scrap Machete.MacheteClient
-- Client target selection + swing/hit SFX + back holster. The server (CombatManager)
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

local lastAttack = 0

-- Picks the closest Mycomorph roughly in front of the player.
local function findClosestMycomorph()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local closest, closestDist = nil, RANGE
	for _, model in ipairs(CollectionService:GetTagged(Tags.Mycomorph)) do
		local mRoot = model.PrimaryPart
		local humanoid = model:FindFirstChild("Humanoid")
		if mRoot and humanoid and humanoid.Health > 0 then
			local toTarget = mRoot.Position - root.Position
			local dist = toTarget.Magnitude
			if dist <= closestDist and dist > 0 then
				if root.CFrame.LookVector:Dot(toTarget.Unit) > CONE_DOT then
					closest = model
					closestDist = dist
				end
			end
		end
	end
	return closest
end

local handle = Tool:FindFirstChild("Handle")
local swingSound = handle and handle:FindFirstChild("Swing")
local hitSound = handle and handle:FindFirstChild("Hit")

Tool.Activated:Connect(function()
	local now = os.clock()
	if now - lastAttack < COOLDOWN then
		return
	end
	lastAttack = now

	if swingSound then
		swingSound:Play()
	end

	local target = findClosestMycomorph()
	if target then
		macheteAttackEvent:FireServer(target)
		if hitSound then
			hitSound:Play()
		end
	end
end)

-- Show the blade on the player's back whenever the tool isn't equipped
Tool.Equipped:Connect(function()
	applyGrip()
	ToolEffects.removeHolster(player.Character, HOLSTER_NAME)
end)

Tool.Unequipped:Connect(function()
	ToolEffects.showHolster(Tool, player.Character, HOLSTER_NAME)
end)

-- Show the holster immediately once the tool lands in the backpack (starts unequipped).
-- Don't use player.CharacterAdded:Wait() here -- if the character already loaded, that event
-- already fired and Wait() would hang forever.
if player.Character then
	ToolEffects.showHolster(Tool, player.Character, HOLSTER_NAME)
end

player.CharacterAdded:Connect(function(char)
	ToolEffects.showHolster(Tool, char, HOLSTER_NAME)
end)
