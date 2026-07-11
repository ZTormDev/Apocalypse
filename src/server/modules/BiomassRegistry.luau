--!strict
-- ServerScriptService.modules.BiomassRegistry
-- Tracked set of live Biomass Catalyst canisters, shared between BiomassSpawner (which
-- creates and removes them) and PurifierManager (which absorbs the in-range ones into fuel),
-- so neither system has to rescan the Workspace every tick.
local BiomassRegistry = {}

local active: { [BasePart]: boolean } = {}

function BiomassRegistry.add(part: BasePart)
	active[part] = true
end

-- Removes the canister from the set and destroys it (its beam, a child, goes with it).
function BiomassRegistry.remove(part: BasePart)
	active[part] = nil
	if part and part.Parent then
		part:Destroy()
	end
end

-- Removes the canister from the tracked set WITHOUT destroying it, for when the caller wants
-- to keep the part alive a moment longer (e.g. play a pickup animation on it) while still
-- taking it out of the Purifier-absorption / beam-drawing loops immediately.
function BiomassRegistry.untrack(part: BasePart)
	active[part] = nil
end

function BiomassRegistry.getAll(): { [BasePart]: boolean }
	return active
end

function BiomassRegistry.count(): number
	local n = 0
	for _ in pairs(active) do
		n += 1
	end
	return n
end

return BiomassRegistry
