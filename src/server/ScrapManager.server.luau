-- ServerScriptService.ScrapManager
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MAX_PILES = 12
local SPAWN_MIN_DIST = 90 -- far outside the dome, like fuel, so players have to venture out for it
local SPAWN_MAX_DIST = 160
local SCRAP_PER_PILE = 5
local RESPAWN_CHECK_INTERVAL = 12

local ScrapEvents = ReplicatedStorage:WaitForChild("ScrapEvents")
local dropScrapEvent = ScrapEvents:WaitForChild("DropScrap")
local ScrapWallet = require(script.Parent:WaitForChild("ScrapWallet"))

local activePiles = {} -- [part] = true

-- Clean up any leftover piles from previous runs/edit mode
for _, child in ipairs(Workspace:GetChildren()) do
	if child.Name == "ScrapPile" then
		child:Destroy()
	end
end

local purifier = Workspace:WaitForChild("Purifier", 15)

local function removeScrapPile(pile)
	activePiles[pile] = nil
	if pile and pile.Parent then
		pile:Destroy()
	end
end

-- Physical scrap pile -- same interaction model as Biomass: walk up, store it in your
-- inventory (E) as a Tool, or throw it back out into the world (F).
local function spawnScrapPile(pos)
	if not purifier then
		purifier = Workspace:FindFirstChild("Purifier")
		if not purifier then return nil end
	end

	local pile = Instance.new("Part")
	pile.Name = "ScrapPile"
	pile.Size = Vector3.new(1.6, 1.2, 2)

	if pos then
		pile.Position = pos
	else
		local angle = math.random() * math.pi * 2
		local dist = math.random(SPAWN_MIN_DIST, SPAWN_MAX_DIST)
		pile.Position = purifier.Position + Vector3.new(math.cos(angle) * dist, 2, math.sin(angle) * dist)
	end

	pile.Anchored = false
	pile.CanCollide = true
	pile.Friction = 0.8
	pile.Material = Enum.Material.Metal
	pile.Color = Color3.fromRGB(120, 110, 90)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Store in Inventory [E]"
	prompt.ObjectText = "Scrap"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 8
	prompt.ClickablePrompt = false
	prompt.Parent = pile

	prompt.Triggered:Connect(function(player)
		removeScrapPile(pile)
		ScrapWallet.Add(player, SCRAP_PER_PILE)
		print(player.Name .. " stored scrap in their inventory.")
	end)

	pile.Parent = Workspace
	activePiles[pile] = true
	return pile
end

-- Drop Tool (F): throws exactly one pile's worth back into the world, out of the stack
dropScrapEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end

	if not ScrapWallet.TrySpend(player, SCRAP_PER_PILE) then return end

	local spawnPos = char.HumanoidRootPart.Position + char.HumanoidRootPart.CFrame.LookVector * 4
	local spawned = spawnScrapPile(spawnPos)
	if spawned then
		spawned.AssemblyLinearVelocity = char.HumanoidRootPart.CFrame.LookVector * 25 + Vector3.new(0, 10, 0)
	end

	print(player.Name .. " dropped and threw scrap with F.")
end)

-- Initial piles
for i = 1, MAX_PILES do
	spawnScrapPile()
end

-- Periodic top-up
task.spawn(function()
	while true do
		task.wait(RESPAWN_CHECK_INTERVAL)
		local count = 0
		for _ in pairs(activePiles) do
			count = count + 1
		end
		if count < MAX_PILES then
			spawnScrapPile()
		end
	end
end)
