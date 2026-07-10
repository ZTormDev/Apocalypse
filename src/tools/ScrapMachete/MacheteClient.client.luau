-- ReplicatedStorage.Scrap Machete.MacheteClient
local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local CombatEvents = ReplicatedStorage:WaitForChild("CombatEvents")
local macheteAttackEvent = CombatEvents:WaitForChild("MacheteAttack")

local RANGE = 7
local CONE_DOT = 0.3 -- roughly a 70-degree forward cone
local COOLDOWN = 0.6
local lastAttack = 0

-- Picks the closest Mycomorph roughly in front of the player; the server independently
-- re-validates range/cooldown before applying any damage, this is just target selection.
local function findClosestMycomorph()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local closest, closestDist = nil, RANGE
	for _, model in ipairs(CollectionService:GetTagged("Mycomorph")) do
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
	if now - lastAttack < COOLDOWN then return end
	lastAttack = now

	if swingSound then swingSound:Play() end

	local target = findClosestMycomorph()
	if target then
		macheteAttackEvent:FireServer(target)
		if hitSound then hitSound:Play() end
	end
end)

-- Holster: show a copy of the blade on the player's back whenever the tool isn't equipped
local HOLSTER_NAME = "MacheteHolster"

local function removeHolster(char)
	local existing = char and char:FindFirstChild(HOLSTER_NAME)
	if existing then
		existing:Destroy()
	end
end

local function addHolster(char)
	if not char then return end
	removeHolster(char) -- avoid duplicates

	local back = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local handle = Tool:FindFirstChild("Handle")
	if not back or not handle then return end

	local holster = handle:Clone()
	holster.Name = HOLSTER_NAME
	holster.Anchored = false
	holster.CanCollide = false
	holster.CanTouch = false
	holster.CanQuery = false
	holster.Massless = true
	holster.CFrame = back.CFrame * CFrame.new(0, 0.2, 0.5) * CFrame.Angles(math.rad(100), 0, 0)
	holster.Parent = char

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = back
	weld.Part1 = holster
	weld.Parent = holster
end

Tool.Equipped:Connect(function()
	removeHolster(player.Character)
end)

Tool.Unequipped:Connect(function()
	addHolster(player.Character)
end)

-- Show the holster immediately once the tool lands in the backpack (it starts unequipped).
-- Note: don't use `player.CharacterAdded:Wait()` here -- if the character already loaded before
-- this script started, that event already fired and Wait() would hang forever.
if player.Character then
	addHolster(player.Character)
end

player.CharacterAdded:Connect(function(char)
	addHolster(char)
end)
