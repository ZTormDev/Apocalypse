-- ServerScriptService.Base.BiomassSpawner
-- Owns Biomass drop-back (G) and the energy beam from an in-range canister to the Purifier.
-- Canisters themselves are now created by the central Points-based SpawnManager (via
-- BiomassFactory); this script no longer runs a spawn loop. The live canister set is shared
-- with PurifierManager (which absorbs them into fuel) through BiomassRegistry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local BiomassRegistry = require(Modules:WaitForChild("BiomassRegistry"))
local BiomassFactory = require(Modules:WaitForChild("BiomassFactory"))

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

-- Drop (G): throw one canister forward out of the held Spore Biomass tool
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
		local spawned = BiomassFactory.spawn(spawnPos)
		spawned.AssemblyLinearVelocity = root.CFrame.LookVector * BM.ThrowVelocity + Vector3.new(0, 10, 0)
		print(player.Name .. " dropped and threw biomass with G.")
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
