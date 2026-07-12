-- ServerScriptService.Enemies.ZombieSpawnZones
-- Creates the 4 flat rectangular horde spawn zones (North/South/East/West of the Purifier) if
-- none exist yet -- if a developer has already hand-placed Parts tagged ZombieSpawnZone in
-- Studio, this defers to those instead of creating duplicates. MycomorphManager picks a random
-- point inside a random zone each time it spawns a zombie.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tags = require(Shared:WaitForChild("Tags"))

local HORDE = GameConfig.Enemies.Horde

-- Forces every zone (hand-placed, previously auto-created, or new below) invisible/non-solid at
-- runtime -- these are level-design placeholders only, meant to be visible in Studio while
-- positioning them, never to players in Play mode.
local function hideZone(zone: BasePart)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = false
end

if #CollectionService:GetTagged(Tags.ZombieSpawnZone) > 0 then
	-- Already hand-placed (or already created by a previous run of this script) -- don't
	-- duplicate them, but still hide them in case they were left visible for editing.
	for _, zone in ipairs(CollectionService:GetTagged(Tags.ZombieSpawnZone)) do
		if zone:IsA("BasePart") then
			hideZone(zone)
		end
	end
	return
end

local purifier = Workspace:WaitForChild("Purifier", 15)
local center = (purifier and purifier:IsA("BasePart")) and purifier.Position or GameConfig.Purifier.Position

local DIRECTIONS = {
	{ name = "North", offset = Vector3.new(0, 0, -HORDE.ZoneDistance) },
	{ name = "South", offset = Vector3.new(0, 0, HORDE.ZoneDistance) },
	{ name = "East", offset = Vector3.new(HORDE.ZoneDistance, 0, 0) },
	{ name = "West", offset = Vector3.new(-HORDE.ZoneDistance, 0, 0) },
}

-- Snaps a horizontal position down onto whatever the terrain/ground actually is beneath it
-- (rather than assuming a flat Y=0 floor), so the zone sits flush on the ground.
local function groundHeightAt(xzPos: Vector3): number
	local rayOrigin = Vector3.new(xzPos.X, xzPos.Y + 200, xzPos.Z)
	local result = Workspace:Raycast(rayOrigin, Vector3.new(0, -400, 0))
	return result and result.Position.Y or 0
end

for _, dir in ipairs(DIRECTIONS) do
	local xzPos = center + dir.offset
	local groundY = groundHeightAt(xzPos)
	local finalPos = Vector3.new(xzPos.X, groundY + HORDE.ZoneSize.Y / 2, xzPos.Z)
	local centerAtSameHeight = Vector3.new(center.X, finalPos.Y, center.Z)

	local zone = Instance.new("Part")
	zone.Name = "ZombieSpawnZone_" .. dir.name
	zone.Size = HORDE.ZoneSize
	-- Oriented to face the Purifier (its local -Z points at the center), so the zone's short
	-- edge (depth) runs toward/away from the base and its long edge runs across the perimeter.
	zone.CFrame = CFrame.lookAt(finalPos, centerAtSameHeight, Vector3.new(0, 1, 0))
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = false
	zone.Transparency = 1
	zone:SetAttribute("Direction", dir.name)
	zone.Parent = Workspace
	CollectionService:AddTag(zone, Tags.ZombieSpawnZone)
end

print("[ZombieSpawnZones] Created 4 default horde spawn zones (North/South/East/West) around the Purifier.")
