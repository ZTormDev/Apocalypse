-- ServerScriptService.World.SpawnManager
-- Central, Points-based loot spawning. Replaces the old hardcoded spawn loops in ScrapManager
-- and BiomassSpawner. Designers place tagged marker Parts in the Workspace:
--   * ItemSpawnPoint -> spawns weighted loot (ammo, machete, bandage, drink, food, biomass)
--   * ScrapSpawnPoint -> spawns a mineable Scrap Junk pile
-- Each point keeps at most MaxPerPoint live items and, each tick, rolls SpawnChance to try
-- topping up. All tunables live in GameConfig.Spawning / GameConfig.LootTable.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tags = require(Shared:WaitForChild("Tags"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local ItemPickupFactory = require(Modules:WaitForChild("ItemPickupFactory"))
local BiomassFactory = require(Modules:WaitForChild("BiomassFactory"))
local ScrapPileFactory = require(Modules:WaitForChild("ScrapPileFactory"))

local SPAWN = GameConfig.Spawning
local LOOT = GameConfig.LootTable

-- point (Instance) -> array of spawned instances still tied to it
local tracked: { [Instance]: { Instance } } = {}

local function jitteredPos(point: BasePart): Vector3
	local j = SPAWN.PositionJitter
	return point.Position + Vector3.new(math.random(-j, j), 0, math.random(-j, j))
end

-- Removes destroyed entries and returns how many are still alive.
local function liveCount(point: Instance): number
	local list = tracked[point]
	if not list then
		list = {}
		tracked[point] = list
	end
	for i = #list, 1, -1 do
		local inst = list[i]
		if not inst or not inst.Parent then
			table.remove(list, i)
		end
	end
	return #list
end

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

local function spawnAtItemPoint(point: BasePart): Instance?
	local entry = pickLoot()
	local pos = jitteredPos(point)
	if entry.kind == "biomass" then
		return BiomassFactory.spawn(pos)
	else
		return ItemPickupFactory.spawn(entry.name, pos)
	end
end

local function spawnAtScrapPoint(point: BasePart): Instance?
	return ScrapPileFactory.spawn(jitteredPos(point))
end

local function tickPoints(tag: string, cfg, spawnFn)
	for _, point in ipairs(CollectionService:GetTagged(tag)) do
		if point:IsA("BasePart") then
			if liveCount(point) < cfg.MaxPerPoint and math.random() < cfg.SpawnChance then
				local spawned = spawnFn(point)
				if spawned then
					table.insert(tracked[point], spawned)
				end
			end
		end
	end
end

-- Points are left visible (neon markers) in Studio so designers can see/move them; hide them
-- at runtime so players never see the markers.
local function hidePoints(tag: string)
	for _, point in ipairs(CollectionService:GetTagged(tag)) do
		if point:IsA("BasePart") then
			point.Transparency = 1
			point.CanCollide = false
			point.CanQuery = false
		end
	end
end

task.spawn(function()
	-- small delay so tagged points placed in the Workspace are all present
	task.wait(2)
	hidePoints(Tags.ItemSpawnPoint)
	hidePoints(Tags.ScrapSpawnPoint)
	while true do
		tickPoints(Tags.ItemSpawnPoint, SPAWN.ItemPoint, spawnAtItemPoint)
		tickPoints(Tags.ScrapSpawnPoint, SPAWN.ScrapPoint, spawnAtScrapPoint)
		task.wait(SPAWN.TickInterval)
	end
end)
