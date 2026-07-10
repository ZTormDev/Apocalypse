-- ReplicatedStorage.Electric Fence.BlueprintClient (identical script also lives in the Wall blueprint)
-- Equip the blueprint to enter build mode: a ghost tracks the cursor (grid + magnet snapping),
-- R rotates it (hinged around the connection point when snapped), and clicking places it,
-- consuming one charge. Unequipping cancels without spending anything.
local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local BuildEvents = ReplicatedStorage:WaitForChild("BuildEvents")
local placeStructureEvent = BuildEvents:WaitForChild("PlaceStructure")
local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")

local structureType = Tool.Name -- "Wall" or "Electric Fence"

local SIZES = {
	["Wall"] = Vector3.new(6, 8, 1),
	["Electric Fence"] = Vector3.new(6, 6, 0.4),
}
local size = SIZES[structureType]

local GRID_SIZE = 1 -- fine free-placement grid; used as a fallback when not snapping to a neighbor
local SNAP_RADIUS = 8 -- studs; how close you need to place to an existing structure to magnet onto it
local MAX_REACH = 30 -- studs; how far from the player the cursor can be

local VALID_COLOR = Color3.fromRGB(0, 200, 90)
local INVALID_COLOR = Color3.fromRGB(220, 40, 40)
local VALID_TRANSPARENCY = 0.25
local INVALID_TRANSPARENCY = 0.45

local ghost = nil
local rotationY = 0
local lastRawPos = nil
local renderConn = nil

local function getPurifier()
	return Workspace:FindFirstChild("Purifier")
end

-- Snaps to either (a) flush against the nearest existing structure within SNAP_RADIUS, or
-- (b) the fine grid if nothing is nearby. Mirrors the server's authoritative recompute
-- exactly, so the preview matches what actually gets built.
--
-- When snapped, rotationY hinges around the shared connection point (the touching face's
-- center) instead of the new piece's own center, so e.g. two flush pieces ("__") rotate into
-- a corner ("_|") instead of spinning the second piece in place.
local function computeSnappedCFrame(rawPos, rotY)
	local closest, closestDist = nil, SNAP_RADIUS
	for _, structure in ipairs(CollectionService:GetTagged("Structure")) do
		if structure.Parent then
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

		return CFrame.new(pivotPos) * CFrame.Angles(0, rotY, 0) * CFrame.new(-pivotPos) * dockedCFrame
	end

	local x = math.floor(rawPos.X / GRID_SIZE + 0.5) * GRID_SIZE
	local z = math.floor(rawPos.Z / GRID_SIZE + 0.5) * GRID_SIZE
	local y = rawPos.Y + size.Y / 2 -- rest on top of whatever the cursor is pointing at, not embedded in it
	return CFrame.new(x, y, z) * CFrame.Angles(0, rotY, 0)
end

local function isWithinBuildZone(pos)
	local purifier = getPurifier()
	if not purifier then return false end
	local domeRadius = stateFolder:GetAttribute("DomeRadius") or 0
	return (pos - purifier.Position).Magnitude <= domeRadius
end

-- Shrunk slightly so a flush magnet-snapped neighbor (touching, zero gap) doesn't
-- register as an obstruction against itself
local function isObstructed(cframe)
	local char = player.Character
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char, ghost}

	local checkSize = size - Vector3.new(0.1, 0.1, 0.1)
	local parts = Workspace:GetPartBoundsInBox(cframe, checkSize, params)
	for _, part in ipairs(parts) do
		if part.CanCollide then
			return true
		end
	end
	return false
end

local function stopGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

local function startGhost()
	stopGhost()
	rotationY = 0

	ghost = Instance.new("Part")
	ghost.Name = "PlacementGhost"
	ghost.Size = size
	ghost.Material = Enum.Material.ForceField
	ghost.Color = VALID_COLOR
	ghost.Transparency = VALID_TRANSPARENCY
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.CastShadow = false
	-- Parented to the Tool itself (not Workspace) so if the server destroys the tool
	-- (last charge consumed), the ghost is torn down automatically as its child -- no
	-- reliance on Destroying/Unequipped firing in time, which isn't guaranteed once the
	-- tool's own script threads are being cut. A Part's own CFrame still renders correctly
	-- in world space regardless of its parent.
	ghost.Parent = Tool

	renderConn = RunService.RenderStepped:Connect(function()
		if not ghost then return end

		if not mouse.Target then return end

		lastRawPos = mouse.Hit.Position
		local cf = computeSnappedCFrame(lastRawPos, rotationY)
		ghost.CFrame = cf

		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local inReach = root and (lastRawPos - root.Position).Magnitude <= MAX_REACH
		local valid = inReach and isWithinBuildZone(cf.Position) and not isObstructed(cf)

		if valid then
			ghost.Color = VALID_COLOR
			ghost.Transparency = VALID_TRANSPARENCY
		else
			ghost.Color = INVALID_COLOR
			ghost.Transparency = INVALID_TRANSPARENCY
		end
	end)
end

Tool.Equipped:Connect(startGhost)
Tool.Unequipped:Connect(stopGhost)

UserInputService.InputBegan:Connect(function(input, processed)
	if not ghost then return end
	if input.KeyCode == Enum.KeyCode.R then
		rotationY += math.rad(90)
	end
end)

Tool.Activated:Connect(function()
	if not ghost or not lastRawPos then return end
	placeStructureEvent:FireServer(structureType, lastRawPos, rotationY)
end)
