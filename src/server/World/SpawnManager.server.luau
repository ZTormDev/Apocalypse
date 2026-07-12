-- ServerScriptService.World.SpawnManager
-- Central, Points-based daily spawning cycle. Resets every dawn (DayNumber change)
-- based on random percentages between 50% and 100% of the total workspace spawn points.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tags = require(Shared:WaitForChild("Tags"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local ItemPickupFactory = require(Modules:WaitForChild("ItemPickupFactory"))
local BiomassFactory = require(Modules:WaitForChild("BiomassFactory"))
local ScrapPileFactory = require(Modules:WaitForChild("ScrapPileFactory"))
local BiomassRegistry = require(Modules:WaitForChild("BiomassRegistry"))

local SPAWN = GameConfig.Spawning
local LOOT = GameConfig.LootTable

-- Track instances spawned today to clean them up next morning
local activeSpawns: { Instance } = {}

-- Jitter position
local function jitteredPos(point: BasePart): Vector3
	local j = SPAWN.PositionJitter
	return point.Position + Vector3.new(math.random(-j, j), 0, math.random(-j, j))
end

-- Loot picker
local totalLootWeight = 0
for _, entry in ipairs(LOOT) do
	totalLootWeight += entry.weight
end

local function pickLoot()
	local roll = math.random() * totalLootWeight
	local acc = 0
	for _, entry in ipairs(LOOT) do
		acc += entry.weight
		if roll <= acc then
			return entry
		end
	end
	return LOOT[#LOOT]
end

-- Clear all remaining spawned items/piles on the map
local function clearRemainingSpawns()
	-- 1. Destroy tracked spawns
	for _, inst in ipairs(activeSpawns) do
		if inst and inst.Parent then
			if inst.Name == "BiomassCatalyst" then
				BiomassRegistry.untrack(inst)
			end
			inst:Destroy()
		end
	end
	activeSpawns = {}

	-- 2. Scan Workspace for leftovers (just in case)
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "ScrapPile" or child.Name == "BiomassCatalyst" or string.match(child.Name, "Pickup$") or child.Name == "ScrapItemDropped" then
			if child.Name == "BiomassCatalyst" then
				BiomassRegistry.untrack(child)
			end
			child:Destroy()
		end
	end
end

-- Shuffle array in place
local function shuffleArray(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
end

-- Main Spawning Cycle
local function runDailySpawnCycle()
	clearRemainingSpawns()

	-- A) ITEMS
	local itemPoints = CollectionService:GetTagged(Tags.ItemSpawnPoint)
	local validItemPoints = {}
	for _, p in ipairs(itemPoints) do
		if p:IsA("BasePart") then
			table.insert(validItemPoints, p)
		end
	end

	-- Percentage of points to spawn, per GameConfig.Spawning.Min/MaxDailyPercent
	local itemPct = math.random(SPAWN.MinDailyPercent, SPAWN.MaxDailyPercent) / 100
	local numItemSpawns = math.round(#validItemPoints * itemPct)

	shuffleArray(validItemPoints)

	for i = 1, math.min(numItemSpawns, #validItemPoints) do
		local point = validItemPoints[i]
		local entry = pickLoot()
		local pos = jitteredPos(point)
		local spawnedObj = nil

		if entry.kind == "biomass" then
			spawnedObj = BiomassFactory.spawn(pos)
		else
			spawnedObj = ItemPickupFactory.spawn(entry.name, pos)
		end

		if spawnedObj then
			table.insert(activeSpawns, spawnedObj)
		end
	end

	print(string.format("[SpawnManager] Spawned items on %d/%d points (%.0f%%)", numItemSpawns, #validItemPoints, itemPct * 100))

	-- B) SCRAP JUNKS
	local scrapPoints = CollectionService:GetTagged(Tags.ScrapSpawnPoint)
	local validScrapPoints = {}
	for _, p in ipairs(scrapPoints) do
		if p:IsA("BasePart") then
			table.insert(validScrapPoints, p)
		end
	end

	-- Percentage of points to spawn, per GameConfig.Spawning.Min/MaxDailyPercent
	local scrapPct = math.random(SPAWN.MinDailyPercent, SPAWN.MaxDailyPercent) / 100
	local numScrapSpawns = math.round(#validScrapPoints * scrapPct)

	shuffleArray(validScrapPoints)

	for i = 1, math.min(numScrapSpawns, #validScrapPoints) do
		local point = validScrapPoints[i]
		local spawnedObj = ScrapPileFactory.spawn(jitteredPos(point))
		if spawnedObj then
			table.insert(activeSpawns, spawnedObj)
		end
	end

	print(string.format("[SpawnManager] Spawned scrap piles on %d/%d points (%.0f%%)", numScrapSpawns, #validScrapPoints, scrapPct * 100))
end

-- Hide marker parts
local function hidePoints(tag: string)
	for _, point in ipairs(CollectionService:GetTagged(tag)) do
		if point:IsA("BasePart") then
			point.Transparency = 1
			point.CanCollide = false
			point.CanQuery = false
		end
	end
end

-- Initial execution & DayNumber listener setup
task.spawn(function()
	task.wait(2) -- Wait for Workspace loading
	hidePoints(Tags.ItemSpawnPoint)
	hidePoints(Tags.ScrapSpawnPoint)

	-- SporeTideState configuration folder
	local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")

	-- Initial spawn cycle for Day 1
	runDailySpawnCycle()

	-- Connect to DayNumber attribute to run the cycle every time a new day begins
	stateFolder:GetAttributeChangedSignal("DayNumber"):Connect(function()
		runDailySpawnCycle()
	end)
end)
