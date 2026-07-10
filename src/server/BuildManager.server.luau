-- ServerScriptService.BuildManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")

local BuildEvents = ReplicatedStorage:FindFirstChild("BuildEvents")
if not BuildEvents then
	BuildEvents = Instance.new("Folder")
	BuildEvents.Name = "BuildEvents"
	BuildEvents.Parent = ReplicatedStorage
end

local placeStructureEvent = BuildEvents:FindFirstChild("PlaceStructure")
if not placeStructureEvent then
	placeStructureEvent = Instance.new("RemoteEvent")
	placeStructureEvent.Name = "PlaceStructure"
	placeStructureEvent.Parent = BuildEvents
end

local craftItemEvent = BuildEvents:FindFirstChild("CraftStructureItem")
if not craftItemEvent then
	craftItemEvent = Instance.new("RemoteEvent")
	craftItemEvent.Name = "CraftStructureItem"
	craftItemEvent.Parent = BuildEvents
end

local GRID_SIZE = 1 -- fine free-placement grid; used as a fallback when not snapping to a neighbor
local SNAP_RADIUS = 8 -- studs; how close you need to place to an existing structure to magnet onto it
local MAX_REACH = 30 -- studs; how far from the player the cursor can be
local CONSOLE_INTERACT_RANGE = 15

local ScrapWallet = require(script.Parent:WaitForChild("ScrapWallet"))

local STRUCTURES = {
	["Wall"] = {
		Cost = 20,
		Health = 150,
		Size = Vector3.new(6, 8, 1),
		Color = Color3.fromRGB(95, 85, 75),
		Material = Enum.Material.Concrete,
	},
	["Electric Fence"] = {
		Cost = 40,
		Health = 80,
		Size = Vector3.new(6, 6, 0.4),
		Color = Color3.fromRGB(210, 210, 70),
		Material = Enum.Material.Metal,
		Electric = true,
	},
}

local purifier = Workspace:WaitForChild("Purifier", 15)

-- Physical Assembly Console station near the base
local function createConsole()
	local existing = Workspace:FindFirstChild("AssemblyConsole")
	if existing then existing:Destroy() end

	local console = Instance.new("Part")
	console.Name = "AssemblyConsole"
	console.Size = Vector3.new(3, 4, 2)
	console.Anchored = true
	console.Material = Enum.Material.Metal
	console.Color = Color3.fromRGB(60, 70, 80)
	console.Position = (purifier and purifier.Position or Vector3.new(0, 4, 0)) + Vector3.new(10, 2, 0)
	console.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Assembly Console [E]"
	prompt.ObjectText = "Assembly Console"
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 10
	prompt.Parent = console
end

createConsole()

-- Crafting: spend Scrap for a blueprint item (a Tool that stacks, same pattern as ScrapWallet)
local function findBlueprintTool(player, structureType)
	local backpack = player:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild(structureType)
	if tool then return tool end

	local char = player.Character
	tool = char and char:FindFirstChild(structureType)
	return tool
end

craftItemEvent.OnServerEvent:Connect(function(player, structureType)
	local def = STRUCTURES[structureType]
	if not def then return end

	local console = Workspace:FindFirstChild("AssemblyConsole")
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not console or not root then return end
	if (console.Position - root.Position).Magnitude > CONSOLE_INTERACT_RANGE then return end

	if not ScrapWallet.TrySpend(player, def.Cost) then return end

	local tool = findBlueprintTool(player, structureType)
	if tool then
		tool:SetAttribute("Amount", (tool:GetAttribute("Amount") or 0) + 1)
	else
		local template = ReplicatedStorage:FindFirstChild(structureType)
		if not template then
			ScrapWallet.Add(player, def.Cost) -- refund, we couldn't actually give the item
			return
		end
		local clone = template:Clone()
		clone:SetAttribute("Amount", 1)
		clone.Parent = player:WaitForChild("Backpack")
	end

	print(player.Name .. " crafted a " .. structureType .. " blueprint")
end)

-- Snaps a raw world position to either (a) flush against the nearest existing structure
-- within SNAP_RADIUS, or (b) the fine grid if nothing is nearby. Shared by client preview
-- and this server-side authoritative recompute -- the server never trusts a client-sent
-- CFrame directly, only the raw cursor position and the raw (unclamped) rotation request.
--
-- When snapped, rotationY is applied as a hinge around the shared connection point (the
-- touching face's center) rather than around the new piece's own center, so e.g. two flush
-- pieces ("__") rotate into a corner ("_|") instead of spinning the second piece in place.
local function computeSnappedCFrame(rawPos, rotationY, size)
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

		return CFrame.new(pivotPos) * CFrame.Angles(0, rotationY, 0) * CFrame.new(-pivotPos) * dockedCFrame
	end

	local x = math.floor(rawPos.X / GRID_SIZE + 0.5) * GRID_SIZE
	local z = math.floor(rawPos.Z / GRID_SIZE + 0.5) * GRID_SIZE
	local y = rawPos.Y + size.Y / 2 -- rest on top of whatever the cursor is pointing at, not embedded in it
	return CFrame.new(x, y, z) * CFrame.Angles(0, rotationY, 0)
end

-- True only if `pos` is inside the Purifier's current dome radius
local function isWithinBuildZone(pos)
	if not purifier then return false end
	local domeRadius = stateFolder:GetAttribute("DomeRadius") or 0
	return (pos - purifier.Position).Magnitude <= domeRadius
end

-- Shrunk slightly so a flush magnet-snapped neighbor (touching, zero gap) doesn't
-- register as an obstruction against itself
local function isObstructed(cframe, size, ignoreInstances)
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

placeStructureEvent.OnServerEvent:Connect(function(player, structureType, rawPos, rotationY)
	local def = STRUCTURES[structureType]
	if not def then return end
	if typeof(rawPos) ~= "Vector3" or typeof(rotationY) ~= "number" then return end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local dist = (rawPos - root.Position).Magnitude
	if dist > MAX_REACH then return end

	-- Must actually be holding a charged blueprint of this type
	local tool = char:FindFirstChild(structureType)
	local amount = tool and (tool:GetAttribute("Amount") or 0) or 0
	if amount <= 0 then return end

	-- Recompute the final placement entirely server-side (grid + magnet + pivot rotation);
	-- snap rotationY to the nearest 90 degrees so a modified client can't send arbitrary angles
	local snappedRotationY = math.floor(rotationY / (math.pi / 2) + 0.5) * (math.pi / 2)
	local finalCFrame = computeSnappedCFrame(rawPos, snappedRotationY, def.Size)

	if not isWithinBuildZone(finalCFrame.Position) then return end
	if isObstructed(finalCFrame, def.Size, {char}) then return end

	-- Consume one charge; remove the tool entirely (and exit build mode with it) at zero
	if amount <= 1 then
		tool:Destroy()
	else
		tool:SetAttribute("Amount", amount - 1)
	end

	local structure = Instance.new("Part")
	structure.Name = structureType
	structure.Size = def.Size
	structure.CFrame = finalCFrame
	structure.Anchored = true
	structure.CanCollide = true
	structure.Material = def.Material
	structure.Color = def.Color
	structure:SetAttribute("Health", def.Health)
	structure:SetAttribute("MaxHealth", def.Health)
	structure.Parent = Workspace

	CollectionService:AddTag(structure, "Structure")
	if def.Electric then
		CollectionService:AddTag(structure, "ElectricFence")
	end

	print(player.Name .. " built a " .. structureType)
end)

-- Electric Fence damage tick: zaps any Mycomorph pressed against it, only while the
-- purifier has fuel. Uses a padded box query instead of true overlap, since CanCollide
-- stops the Mycomorph from ever actually penetrating the fence part.
local ELECTRIC_DAMAGE = 8
local ELECTRIC_TICK = 1.0
local ELECTRIC_PADDING = Vector3.new(3, 3, 3)

task.spawn(function()
	while true do
		task.wait(ELECTRIC_TICK)
		local fuel = stateFolder:GetAttribute("PurifierFuel") or 0
		if fuel > 0 then
			for _, fence in ipairs(CollectionService:GetTagged("ElectricFence")) do
				if fence.Parent then
					local overlapParams = OverlapParams.new()
					overlapParams.FilterType = Enum.RaycastFilterType.Exclude
					overlapParams.FilterDescendantsInstances = {fence}

					local checkSize = fence.Size + ELECTRIC_PADDING
					local parts = Workspace:GetPartBoundsInBox(fence.CFrame, checkSize, overlapParams)

					local zapped = {}
					for _, part in ipairs(parts) do
						local model = part:FindFirstAncestorOfClass("Model")
						if model and not zapped[model] and CollectionService:HasTag(model, "Mycomorph") then
							local humanoid = model:FindFirstChild("Humanoid")
							if humanoid and humanoid.Health > 0 then
								zapped[model] = true
								humanoid:TakeDamage(ELECTRIC_DAMAGE)
							end
						end
					end

					if next(zapped) then
						task.spawn(function()
							local original = fence.Color
							fence.Color = Color3.fromRGB(255, 255, 255)
							task.wait(0.1)
							if fence.Parent then fence.Color = original end
						end)
					end
				end
			end
		end
	end
end)
