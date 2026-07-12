-- ServerScriptService.Building.BuildManager
-- Server-authoritative building: the Assembly Console shop (craft a blueprint Tool for Scrap),
-- the placement handler (consume a held blueprint to build a structure), and the Electric Fence
-- damage tick. The placement math is the shared PlacementGeometry module -- the exact same code
-- the client ghost preview uses -- so the preview can never disagree with what the server builds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))
local PlacementGeometry = require(Shared:WaitForChild("PlacementGeometry"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local ScrapWallet = require(Modules:WaitForChild("ScrapWallet"))

local STRUCTURES = GameConfig.Structures
local BUILD = GameConfig.Building
local FENCE = GameConfig.ElectricFence

local placeStructureEvent = Net.event("BuildEvents", "PlaceStructure")
local craftItemEvent = Net.event("BuildEvents", "CraftStructureItem")

local purifier = Workspace:WaitForChild("Purifier", 15)

-- Physical Assembly Console station near the base
local function createConsole()
	local existing = Workspace:FindFirstChild("AssemblyConsole")
	if existing then
		existing:Destroy()
	end

	local console = Instance.new("Part")
	console.Name = "AssemblyConsole"
	console.Size = Vector3.new(3, 4, 2)
	console.Anchored = true
	console.Material = Enum.Material.Metal
	console.Color = Color3.fromRGB(60, 70, 80)
	console.Position = (purifier and purifier.Position or Vector3.new(0, 4, 0)) + Vector3.new(10, 2, 0)
	console.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Open Assembly Console"
	prompt.ObjectText = "Assembly Console"
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 10
	prompt.Parent = console
end

createConsole()

-- ---------------------------------------------------------------------------------------
-- Shop: spend Scrap for a stacking blueprint Tool (same stacking pattern as ScrapWallet)
-- ---------------------------------------------------------------------------------------
local function findBlueprintTool(player: Player, structureType: string): Instance?
	local backpack = player:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild(structureType)
	if tool then
		return tool
	end
	local char = player.Character
	return char and char:FindFirstChild(structureType)
end

craftItemEvent.OnServerEvent:Connect(function(player, structureType)
	local def = STRUCTURES[structureType]
	if not def then
		return
	end

	local console = Workspace:FindFirstChild("AssemblyConsole")
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not console or not root then
		return
	end
	if (console.Position - root.Position).Magnitude > BUILD.ConsoleInteractRange then
		return
	end

	if not ScrapWallet.TrySpend(player, def.Cost) then
		return
	end

	local tool = findBlueprintTool(player, structureType)
	if tool then
		tool:SetAttribute("Amount", (tool:GetAttribute("Amount") or 0) + 1)
	else
		local template = ReplicatedStorage:FindFirstChild(structureType)
		if not template then
			ScrapWallet.Add(player, def.Cost) -- refund; couldn't give the item
			return
		end
		local clone = template:Clone()
		clone:SetAttribute("Amount", 1)
		clone.Parent = player:WaitForChild("Backpack")
	end

	print(player.Name .. " crafted a " .. structureType .. " blueprint")
end)

-- ---------------------------------------------------------------------------------------
-- Placement: consume one charge of a held blueprint to build a structure
-- ---------------------------------------------------------------------------------------
placeStructureEvent.OnServerEvent:Connect(function(player, structureType, rawPos, rotationY)
	local def = STRUCTURES[structureType]
	if not def then
		return
	end
	if typeof(rawPos) ~= "Vector3" or typeof(rotationY) ~= "number" then
		return
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local dist = (rawPos - root.Position).Magnitude
	if dist > BUILD.MaxReach then
		return
	end

	-- Must actually be holding a charged blueprint of this type
	local tool = char:FindFirstChild(structureType)
	local amount = tool and (tool:GetAttribute("Amount") or 0) or 0
	if amount <= 0 then
		return
	end

	-- Recompute placement entirely server-side; snap rotation to 90 degrees so a modified
	-- client can't send an arbitrary angle
	local snappedRotationY = math.floor(rotationY / (math.pi / 2) + 0.5) * (math.pi / 2)
	local finalCFrame = PlacementGeometry.computeSnappedCFrame(rawPos, snappedRotationY, def.Size)

	if not PlacementGeometry.isWithinBuildZone(finalCFrame.Position) then
		return
	end
	if PlacementGeometry.isObstructed(finalCFrame, def.Size, { char }) then
		return
	end

	-- Consume one charge; destroy the tool (and exit build mode with it) at zero
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

	CollectionService:AddTag(structure, Tags.Structure)
	if def.Electric then
		CollectionService:AddTag(structure, Tags.ElectricFence)
	end

	print(player.Name .. " built a " .. structureType)
end)

-- ---------------------------------------------------------------------------------------
-- Electric Fence damage tick (only while the Purifier has fuel)
-- ---------------------------------------------------------------------------------------
local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")

task.spawn(function()
	while true do
		task.wait(FENCE.TickInterval)
		local fuel = stateFolder:GetAttribute("PurifierFuel") or 0
		if fuel > 0 then
			for _, fence in ipairs(CollectionService:GetTagged(Tags.ElectricFence)) do
				if fence.Parent then
					local overlapParams = OverlapParams.new()
					overlapParams.FilterType = Enum.RaycastFilterType.Exclude
					overlapParams.FilterDescendantsInstances = { fence }

					local checkSize = fence.Size + FENCE.Padding
					local parts = Workspace:GetPartBoundsInBox(fence.CFrame, checkSize, overlapParams)

					local zapped = {}
					for _, part in ipairs(parts) do
						local model = part:FindFirstAncestorOfClass("Model")
						if model and not zapped[model] and CollectionService:HasTag(model, Tags.Mycomorph) then
							-- The Wildling rig's Humanoid is named "Zombie", not "Humanoid".
							local humanoid = model:FindFirstChildOfClass("Humanoid")
							if humanoid and humanoid.Health > 0 then
								zapped[model] = true
								humanoid:TakeDamage(FENCE.Damage)
							end
						end
					end

					if next(zapped) then
						task.spawn(function()
							local original = fence.Color
							fence.Color = Color3.fromRGB(255, 255, 255)
							task.wait(0.1)
							if fence.Parent then
								fence.Color = original
							end
						end)
					end
				end
			end
		end
	end
end)
