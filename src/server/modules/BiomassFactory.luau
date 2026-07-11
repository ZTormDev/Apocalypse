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

local BiomassFactory = {}

function BiomassFactory.spawn(pos: Vector3): BasePart
	local canister = Instance.new("Part")
	canister.Name = "BiomassCatalyst"
	canister.Size = Vector3.new(1.8, 1.8, 1.8)
	canister.Position = pos
	canister.Anchored = false
	canister.CanCollide = true
	canister.Friction = 0.8
	canister.Color = Color3.fromRGB(0, 255, 0)
	canister.Material = Enum.Material.Neon

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
	prompt.ObjectText = "Spore Biomass"
	prompt.HoldDuration = 0 -- instant press, no hold
	prompt.MaxActivationDistance = 8
	prompt.ClickablePrompt = false
	prompt.Parent = canister

	prompt.Triggered:Connect(function(player)
		local toolTemplate = ReplicatedStorage:FindFirstChild("Spore Biomass")
		if not toolTemplate then
			return
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
