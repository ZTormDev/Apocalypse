--!strict
-- ServerScriptService.modules.BiomassFactory
-- Builds a single Biomass Catalyst canister (green fuel cell) at a given position. Extracted
-- from BiomassSpawner so the central SpawnManager can create canisters without owning a spawn
-- loop. BiomassSpawner still owns the drop-back (G) and the Purifier-link beam; PurifierManager
-- still absorbs in-range canisters into fuel via the shared BiomassRegistry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = script.Parent
local BiomassRegistry = require(Modules:WaitForChild("BiomassRegistry"))
local PickupVfx = require(Modules:WaitForChild("PickupVfx"))
local InventoryService = require(Modules:WaitForChild("InventoryService"))

local BiomassFactory = {}

function BiomassFactory.spawn(pos: Vector3): BasePart
	-- The world canister uses the SAME visual as the held Biomass Fuel tool (clone its Handle),
	-- so a dropped/spawned canister and the equipped tool look identical. Falls back to a plain
	-- green cube if the tool/Handle is missing.
	local canister: BasePart
	local template = ReplicatedStorage:FindFirstChild("Biomass Fuel")
	local handleTemplate = template and template:FindFirstChild("Handle")
	if handleTemplate and handleTemplate:IsA("BasePart") then
		canister = handleTemplate:Clone()
	else
		canister = Instance.new("Part")
		canister.Size = Vector3.new(1.8, 1.8, 1.8)
		canister.Color = Color3.fromRGB(0, 255, 0)
		canister.Material = Enum.Material.Neon
	end
	canister.Name = "BiomassCatalyst"
	canister.Anchored = false
	canister.CanCollide = true
	canister.Massless = false
	canister.Friction = 0.8
	canister.CFrame = CFrame.new(pos)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(0, 255, 0)
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = canister

	local biomassAttachment = Instance.new("Attachment")
	biomassAttachment.Name = "BiomassAttachment"
	biomassAttachment.Parent = canister

	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Store in Inventory"
	prompt.ObjectText = "Biomass Fuel"
	prompt.HoldDuration = 0 -- instant press, no hold
	prompt.MaxActivationDistance = 8
	prompt.ClickablePrompt = false
	prompt.Parent = canister

	prompt.Triggered:Connect(function(player)
		local toolTemplate = ReplicatedStorage:FindFirstChild("Biomass Fuel")
		if not toolTemplate then
			return
		end
		if not InventoryService.canAccept(player, "Biomass Fuel") then
			return -- belt + backpack full: can't pick up
		end

		-- Untrack (NOT remove -> remove() destroys the part, orphaning it out of Workspace so
		-- the pickup animation would play on an invisible object). Keep it alive to animate.
		BiomassRegistry.untrack(canister)
		local existingBeam = canister:FindFirstChild("SporeLinkBeam")
		if existingBeam then
			existingBeam:Destroy()
		end

		PickupVfx.absorb(canister, prompt, player, function()
			canister:Destroy()
			local clone = toolTemplate:Clone()
			clone.Parent = player:WaitForChild("Backpack")
			print(player.Name .. " stored biomass in their inventory.")
		end)
	end)

	canister.Parent = Workspace
	BiomassRegistry.add(canister)
	return canister
end

return BiomassFactory
