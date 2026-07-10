-- ServerScriptService.Base.BiomassSpawner
-- Spawns Biomass Catalyst canisters out in the danger zone, lets players store them (E) or
-- throw them back (F), and draws the energy beam from an in-range canister to the Purifier.
-- The live canister set is shared with PurifierManager (which absorbs them into fuel) through
-- BiomassRegistry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local BiomassRegistry = require(Modules:WaitForChild("BiomassRegistry"))

local BM = GameConfig.Biomass
local RECHARGE_RANGE = GameConfig.Purifier.RechargeRange

local dropBiomassEvent = Net.event("SporeEvents", "DropBiomass")

local purifier = Workspace:WaitForChild("Purifier", 15)

-- Clean up any biomass left over from a previous run
for _, child in ipairs(Workspace:GetChildren()) do
	if child.Name == "BiomassCatalyst" then
		child:Destroy()
	end
end

local function spawnBiomass(pos: Vector3?): BasePart
	local canister = Instance.new("Part")
	canister.Name = "BiomassCatalyst"
	canister.Size = Vector3.new(1.8, 1.8, 1.8)

	if pos then
		canister.Position = pos
	else
		local angle = math.random() * math.pi * 2
		local dist = math.random(BM.SpawnMinDist, BM.SpawnMaxDist)
		canister.Position = purifier.Position + Vector3.new(math.cos(angle) * dist, 5, math.sin(angle) * dist)
	end

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
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 8
	prompt.ClickablePrompt = false
	prompt.Parent = canister

	prompt.Triggered:Connect(function(player)
		local toolTemplate = ReplicatedStorage:FindFirstChild("Spore Biomass")
		if toolTemplate then
			local clone = toolTemplate:Clone()
			clone.Parent = player:WaitForChild("Backpack")
			BiomassRegistry.remove(canister)
			print(player.Name .. " stored biomass in their inventory.")
		end
	end)

	canister.Parent = Workspace
	BiomassRegistry.add(canister)
	return canister
end

-- Initial canisters
for _ = 1, BM.InitialCount do
	spawnBiomass()
end

-- Periodic top-up
task.spawn(function()
	while true do
		task.wait(BM.RespawnCheckInterval)
		if BiomassRegistry.count() < BM.MaxCount then
			spawnBiomass()
		end
	end
end)

-- Drop (F): throw one canister forward out of the held Spore Biomass tool
dropBiomassEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end

	local tool = char:FindFirstChild("Spore Biomass")
	if tool then
		tool:Destroy()
		local root = char.HumanoidRootPart
		local spawnPos = root.Position + root.CFrame.LookVector * 4
		local spawned = spawnBiomass(spawnPos)
		spawned.AssemblyLinearVelocity = root.CFrame.LookVector * BM.ThrowVelocity + Vector3.new(0, 10, 0)
		print(player.Name .. " dropped and threw biomass with F.")
	end
end)

-- Dynamic connection beam (fast 0.1s tick for responsiveness)
task.spawn(function()
	while true do
		task.wait(0.1)
		local purifAtt = purifier:FindFirstChild("PurifierAttachment")
		if not purifAtt then
			purifAtt = Instance.new("Attachment")
			purifAtt.Name = "PurifierAttachment"
			purifAtt.Parent = purifier
		end

		for child in pairs(BiomassRegistry.getAll()) do
			local dist = (child.Position - purifier.Position).Magnitude
			local biomassAttachment = child:FindFirstChild("BiomassAttachment")
			if not biomassAttachment then
				biomassAttachment = Instance.new("Attachment")
				biomassAttachment.Name = "BiomassAttachment"
				biomassAttachment.Parent = child
			end

			local existingBeam = child:FindFirstChild("SporeLinkBeam")

			if dist <= RECHARGE_RANGE then
				if not existingBeam then
					existingBeam = Instance.new("Beam")
					existingBeam.Name = "SporeLinkBeam"
					existingBeam.Texture = "rbxassetid://450715307"
					existingBeam.TextureMode = Enum.TextureMode.Wrap
					existingBeam.TextureSpeed = -3

					local c1 = Color3.fromRGB(0, 255, 120)
					local c2 = Color3.fromRGB(0, 200, 255)
					existingBeam.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, c1),
						ColorSequenceKeypoint.new(1, c2),
					})

					existingBeam.Width0 = 0.8
					existingBeam.Width1 = 0.3
					existingBeam.FaceCamera = true
					existingBeam.Attachment0 = biomassAttachment
					existingBeam.Attachment1 = purifAtt
					existingBeam.Parent = child
				end
			else
				if existingBeam then
					existingBeam:Destroy()
				end
			end
		end
	end
end)
