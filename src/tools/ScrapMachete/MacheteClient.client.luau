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

-- Picks the closest Mycomorph or ScrapPile roughly in front of the player.
local function findClosestTarget()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local closest, closestDist = nil, RANGE

	-- 1. Search tagged Mycomorph enemies
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

	-- 2. Search ScrapPiles (minable models)
	for _, model in ipairs(workspace:GetChildren()) do
		if model.Name == "ScrapPile" then
			local mRoot = model.PrimaryPart
			if mRoot then
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
	end

	return closest
end

-- Sound Management
local handle = Tool:WaitForChild("Handle")
local sounds = handle:WaitForChild("Sounds")

local function playRandomSwing()
	if not sounds then return end
	local swingSounds = {}
	for _, child in ipairs(sounds:GetChildren()) do
		if string.find(child.Name, "Swing") then
			table.insert(swingSounds, child)
		end
	end
	if #swingSounds > 0 then
		local s = swingSounds[math.random(1, #swingSounds)]
		s:Play()
	end
end

local function playRandomHit(isScrapHit: boolean)
	if not sounds then return end
	if isScrapHit then
		local scrapHit = sounds:FindFirstChild("ScrapHit")
		if scrapHit then
			-- Random pitch variation between 0.85 and 1.15
			scrapHit.PlaybackSpeed = math.random(85, 115) / 100
			scrapHit:Play()
		end
	else
		-- Flesh hits for enemies (Hit1, Hit2)
		local hitSounds = {}
		for _, child in ipairs(sounds:GetChildren()) do
			-- Exclude ScrapHit from flesh hits list
			if string.find(child.Name, "Hit") and child.Name ~= "ScrapHit" then
				table.insert(hitSounds, child)
			end
		end
		if #hitSounds > 0 then
			local s = hitSounds[math.random(1, #hitSounds)]
			s:Play()
		end
	end
end

Tool.Activated:Connect(function()
	local now = os.clock()
	if now - lastAttack < COOLDOWN then
		return
	end
	lastAttack = now

	-- Play swing sound
	playRandomSwing()

	local target = findClosestTarget()
	if target then
		macheteAttackEvent:FireServer(target)
		local isScrap = (target.Name == "ScrapPile")
		playRandomHit(isScrap)
	end
end)

-- Show the blade on the player's back whenever the tool isn't equipped
Tool.Equipped:Connect(function()
	applyGrip()
	ToolEffects.removeHolster(player.Character, HOLSTER_NAME)

	-- Play equip sound
	local equipSound = sounds and sounds:FindFirstChild("Equip")
	if equipSound then
		equipSound:Play()
	end
end)

Tool.Unequipped:Connect(function()
	ToolEffects.showHolster(Tool, player.Character, HOLSTER_NAME)

	-- Play unequip sound
	local unequipSound = sounds and sounds:FindFirstChild("Unequip")
	if unequipSound then
		unequipSound:Play()
	end
end)

-- Show the holster immediately once the tool lands in the backpack (starts unequipped).
if player.Character then
	ToolEffects.showHolster(Tool, player.Character, HOLSTER_NAME)
end

player.CharacterAdded:Connect(function(char)
	ToolEffects.showHolster(Tool, char, HOLSTER_NAME)
end)
