--!strict
-- ReplicatedStorage.Shared.PlacementGeometry
-- The build-placement math, shared verbatim between the server's authoritative placement
-- handler (BuildManager) and the client's ghost preview (BlueprintClient). Previously these
-- were two hand-copied implementations that had to be kept in sync by discipline alone -- a
-- mismatch here is a real bug (the preview would show a placement the server then rejects, or
-- vice versa), so making it literally one module is the single most valuable change in the
-- refactor.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(script.Parent.GameConfig)
local Tags = require(script.Parent.Tags)

local GRID_SIZE = GameConfig.Building.GridSize
local SNAP_RADIUS = GameConfig.Building.SnapRadius

local PlacementGeometry = {}

-- Snaps a raw world position to either (a) flush against the nearest existing structure
-- within SNAP_RADIUS, or (b) the fine grid if nothing is nearby.
--
-- When snapped, rotationY is applied as a hinge around the shared connection point (the
-- touching face's center) rather than around the new piece's own center, so e.g. two flush
-- pieces ("__") rotate into a corner ("_|") instead of spinning the second piece in place.
function PlacementGeometry.computeSnappedCFrame(rawPos: Vector3, rotationY: number, size: Vector3): CFrame
	local closest: BasePart? = nil
	local closestDist = SNAP_RADIUS
	for _, structure in ipairs(CollectionService:GetTagged(Tags.Structure)) do
		if structure:IsA("BasePart") and structure.Parent then
			local dist = (structure.Position - rawPos).Magnitude
			if dist < closestDist then
				closest = structure
				closestDist = dist
			end
		end
	end

	if closest then
		local existingCFrame = closest.CFrame
		local localCursor = existingCFrame:PointToObjectSpace(rawPos)
		local halfExisting = closest.Size / 2
		local halfNew = size / 2

		local axis, sign
		if math.abs(localCursor.X) / halfExisting.X >= math.abs(localCursor.Z) / halfExisting.Z then
			axis, sign = "X", (localCursor.X >= 0 and 1 or -1)
		else
			axis, sign = "Z", (localCursor.Z >= 0 and 1 or -1)
		end

		local faceOffset, dockOffset
		if axis == "X" then
			faceOffset = Vector3.new(sign * halfExisting.X, 0, 0)
			dockOffset = Vector3.new(sign * (halfExisting.X + halfNew.X), 0, 0)
		else
			faceOffset = Vector3.new(0, 0, sign * halfExisting.Z)
			dockOffset = Vector3.new(0, 0, sign * (halfExisting.Z + halfNew.Z))
		end

		local pivotPos = (existingCFrame * CFrame.new(faceOffset)).Position
		local dockedCFrame = existingCFrame * CFrame.new(dockOffset) -- flush, 0 extra rotation

		return CFrame.new(pivotPos) * CFrame.Angles(0, rotationY, 0) * CFrame.new(-pivotPos) * dockedCFrame
	end

	local x = math.floor(rawPos.X / GRID_SIZE + 0.5) * GRID_SIZE
	local z = math.floor(rawPos.Z / GRID_SIZE + 0.5) * GRID_SIZE
	local y = rawPos.Y + size.Y / 2 -- rest on top of whatever the cursor points at, not embedded
	return CFrame.new(x, y, z) * CFrame.Angles(0, rotationY, 0)
end

-- True only if `pos` is inside the Purifier's current dome radius.
function PlacementGeometry.isWithinBuildZone(pos: Vector3): boolean
	local purifier = Workspace:FindFirstChild("Purifier")
	if not purifier or not purifier:IsA("BasePart") then
		return false
	end
	local stateFolder = ReplicatedStorage:FindFirstChild("SporeTideState")
	local domeRadius = (stateFolder and stateFolder:GetAttribute("DomeRadius")) or 0
	return (pos - purifier.Position).Magnitude <= (domeRadius :: number)
end

-- True if any CanCollide part (other than those ignored) overlaps the placement box. The
-- box is shrunk slightly so a flush magnet-snapped neighbor (touching, zero gap) doesn't
-- register as an obstruction against itself.
function PlacementGeometry.isObstructed(cframe: CFrame, size: Vector3, ignoreInstances: { Instance }): boolean
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = ignoreInstances

	local checkSize = size - Vector3.new(0.1, 0.1, 0.1)
	local parts = Workspace:GetPartBoundsInBox(cframe, checkSize, overlapParams)
	for _, part in ipairs(parts) do
		if part.CanCollide then
			return true
		end
	end
	return false
end

return PlacementGeometry
