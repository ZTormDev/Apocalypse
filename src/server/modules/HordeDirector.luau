--!strict
-- ServerScriptService.modules.HordeDirector
-- Pure difficulty math for the night horde. Given the night number and how many spawn zones
-- exist, it decides how many zones to use and how many zombies each gets. Kept separate from
-- MycomorphManager (which owns the actual spawning/AI) so the curve is easy to read and tune.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local HORDE = GameConfig.Enemies.Horde

local HordeDirector = {}

-- Number of zones active this night, from the ZoneProgression tiers, clamped to what exists.
function HordeDirector.zonesForNight(night: number, availableZones: number): number
	local minZones, maxZones = 1, 1
	for _, tier in ipairs(HORDE.ZoneProgression) do
		if night <= tier.untilNight then
			minZones, maxZones = tier.min, tier.max
			break
		end
	end
	local count = math.random(minZones, maxZones)
	return math.clamp(count, 1, math.max(1, availableZones))
end

function HordeDirector.totalZombies(night: number): number
	return HORDE.BaseZombies + HORDE.ZombiesGrowthPerNight * (night - 1)
end

-- Splits `total` as evenly as possible across `zoneCount` zones (earlier zones take the remainder).
function HordeDirector.distribute(total: number, zoneCount: number): { number }
	local per = {}
	local base = math.floor(total / zoneCount)
	local remainder = total % zoneCount
	for i = 1, zoneCount do
		per[i] = base + (i <= remainder and 1 or 0)
	end
	return per
end

-- Full plan for the night: how many zones, and the per-zone zombie counts.
function HordeDirector.planNight(night: number, availableZones: number): { zoneCount: number, perZone: { number }, total: number }
	local zoneCount = HordeDirector.zonesForNight(night, availableZones)
	local total = math.max(zoneCount, HordeDirector.totalZombies(night)) -- at least 1 per zone
	local perZone = HordeDirector.distribute(total, zoneCount)
	return { zoneCount = zoneCount, perZone = perZone, total = total }
end

return HordeDirector
