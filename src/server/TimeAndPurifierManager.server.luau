-- ServerScriptService.TimeAndPurifierManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

-- 1. Create SporeTideState Folder in ReplicatedStorage
local stateFolder = ReplicatedStorage:FindFirstChild("SporeTideState")
if not stateFolder then
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "SporeTideState"
	stateFolder.Parent = ReplicatedStorage
end

-- Initialize attributes
stateFolder:SetAttribute("TimeOfDay", 6.0)
stateFolder:SetAttribute("IsNight", false)
stateFolder:SetAttribute("DomeRadius", 60.0)
stateFolder:SetAttribute("PurifierFuel", 100.0)
stateFolder:SetAttribute("PurifierMaxFuel", 100.0)
stateFolder:SetAttribute("PurifierHealth", 100.0)
stateFolder:SetAttribute("PurifierMaxHealth", 100.0)
stateFolder:SetAttribute("DayNumber", 1)
stateFolder:SetAttribute("TimeFrozen", false) -- true while the Bio-Recall Protocol is restoring state

-- Clean up any existing instances in workspace from previous runs/edit mode first!
local oldDome = Workspace:FindFirstChild("DomeVisual")
if oldDome then oldDome:Destroy() end
local oldDomeTop = Workspace:FindFirstChild("DomeVisualTop")
if oldDomeTop then oldDomeTop:Destroy() end
local oldDomeBottom = Workspace:FindFirstChild("DomeVisualBottom")
if oldDomeBottom then oldDomeBottom:Destroy() end
local oldDomeInner = Workspace:FindFirstChild("DomeVisualInner")
if oldDomeInner then oldDomeInner:Destroy() end
local oldPurifier = Workspace:FindFirstChild("Purifier")
if oldPurifier then oldPurifier:Destroy() end

-- 2. Create the Purifier and Dome in Workspace
-- The Purifier Part is an invisible collision/position anchor (game logic reads
-- purifier.Position everywhere); the detailed "Power Core" model is purely the visual,
-- parented underneath so it moves/gets cleaned up together with the anchor.
local purifier = Instance.new("Part")
purifier.Name = "Purifier"
purifier.Size = Vector3.new(7.3, 12, 7.3)
purifier.Position = Vector3.new(0, 6, 0)
purifier.Anchored = true
purifier.Transparency = 1
purifier.Parent = Workspace

local powerCoreTemplate = ReplicatedStorage:FindFirstChild("PurifierModelAsset")
local purifierNeon = nil
if powerCoreTemplate then
	local powerCore = powerCoreTemplate["Power Core"]:Clone()
	powerCore.Name = "Power Core"
	powerCore:PivotTo(CFrame.new(purifier.Position))
	powerCore.Parent = purifier
	purifierNeon = powerCore:FindFirstChild("Neon", true)
end

local purifierAttachment = Instance.new("Attachment")
purifierAttachment.Name = "PurifierAttachment"
purifierAttachment.Parent = purifier

-- Create the Dome using the clean MeshPart template from ReplicatedStorage
local domeTemplate = ReplicatedStorage:FindFirstChild("SporeDomeMesh")
local domeVisual
if domeTemplate then
	domeVisual = domeTemplate:Clone()
	domeVisual.Name = "DomeVisual"
	-- Initial position centered on ground (Y = radius / 2)
	local radius = stateFolder:GetAttribute("DomeRadius") or 60.0
	domeVisual.Position = Vector3.new(purifier.Position.X, radius / 2, purifier.Position.Z)
	domeVisual.Parent = Workspace
else
	-- Fallback if the template is somehow missing (uses a basic Sphere part)
	domeVisual = Instance.new("Part")
	domeVisual.Name = "DomeVisual"
	domeVisual.Shape = Enum.PartType.Ball
	domeVisual.Position = purifier.Position
	domeVisual.Anchored = true
	domeVisual.CanCollide = false
	domeVisual.CanTouch = false
	domeVisual.CanQuery = false
	domeVisual.CastShadow = false
	domeVisual.Transparency = 0.85
	domeVisual.Color = Color3.fromRGB(0, 255, 255)
	domeVisual.Material = Enum.Material.ForceField
	domeVisual.Parent = Workspace
end

-- 3. Inventory Pickup State
local SporeEvents = ReplicatedStorage:WaitForChild("SporeEvents")
local dropBiomassEvent = SporeEvents:WaitForChild("DropBiomass")

local activeBiomass = {} -- [part] = true (tracked set, avoids rescanning Workspace every tick)

local function removeBiomass(part)
	activeBiomass[part] = nil
	if part and part.Parent then
		part:Destroy()
	end
end

-- Spawning Biomass Catalyst fuel canisters (unanchored physics cubes!)
local function spawnBiomass(pos)
	local canister = Instance.new("Part")
	canister.Name = "BiomassCatalyst"
	canister.Size = Vector3.new(1.8, 1.8, 1.8)

	if pos then
		canister.Position = pos
	else
		-- Random spawn far outside the dome, so players have to venture into danger to fetch fuel
		local angle = math.random() * math.pi * 2
		local dist = math.random(90, 160)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		canister.Position = purifier.Position + Vector3.new(x, 5, z)
	end

	canister.Anchored = false
	canister.CanCollide = true
	canister.Friction = 0.8
	canister.Color = Color3.fromRGB(0, 255, 0)
	canister.Material = Enum.Material.Neon

	-- Add point light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(0, 255, 0)
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = canister

	-- Attachment for dynamic beam connection
	local biomassAttachment = Instance.new("Attachment")
	biomassAttachment.Name = "BiomassAttachment"
	biomassAttachment.Parent = canister

	-- ProximityPrompt for Inventory collection (E)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Store in Inventory [E]"
	prompt.ObjectText = "Spore Biomass"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 8
	prompt.ClickablePrompt = false
	prompt.Parent = canister

	prompt.Triggered:Connect(function(player)
		-- Add tool to inventory
		local toolTemplate = ReplicatedStorage:FindFirstChild("Spore Biomass")
		if toolTemplate then
			local clone = toolTemplate:Clone()
			clone.Parent = player:WaitForChild("Backpack")
			removeBiomass(canister)
			print(player.Name .. " stored biomass in their inventory.")
		end
	end)

	canister.Parent = Workspace
	activeBiomass[canister] = true
	return canister
end

-- Clean up any old biomass from previous plays
for _, child in ipairs(Workspace:GetChildren()) do
	if child.Name == "BiomassCatalyst" then
		child:Destroy()
	end
end

-- Spawn initial canisters
for i = 1, 8 do
	spawnBiomass()
end

-- Periodic spawner for biomass
task.spawn(function()
	while true do
		task.wait(15)
		local count = 0
		for _ in pairs(activeBiomass) do
			count = count + 1
		end
		if count < 15 then
			spawnBiomass()
		end
	end
end)

-- 4. Drop Tool (F)
dropBiomassEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end

	local tool = char:FindFirstChild("Spore Biomass")
	if tool then
		tool:Destroy()
		-- Spawn physical canister and throw it forward
		local spawnPos = char.HumanoidRootPart.Position + char.HumanoidRootPart.CFrame.LookVector * 4
		local spawned = spawnBiomass(spawnPos)

		spawned.AssemblyLinearVelocity = char.HumanoidRootPart.CFrame.LookVector * 25 + Vector3.new(0, 10, 0)
		print(player.Name .. " dropped and threw biomass with F.")
	end
end)

-- 5. Main Time, Fuel, and Purifier Recharge Loop
local TIME_STEP = 0.1 -- Hour increment per second (240 seconds per day)
local FUEL_DECAY = 0.3 -- Fuel lost per second
local RECHARGE_RANGE = 20 -- Distance within which biomass is absorbed

-- Server-authoritative mask filter / toxic damage state (never trust the client with damage)
local FILTER_DRAIN = 2.5 -- per 0.5s tick outside the dome
local FILTER_RECHARGE = 5.0 -- per 0.5s tick inside the dome
local TOXIC_DAMAGE = 5 -- per 0.5s tick once filter is empty
local playerFilterOxygen = {} -- [player] = value

local function initPlayerOxygen(player)
	playerFilterOxygen[player] = 100.0
	player:SetAttribute("FilterOxygen", 100.0)
end

for _, player in ipairs(Players:GetPlayers()) do
	initPlayerOxygen(player)
end
Players.PlayerAdded:Connect(initPlayerOxygen)
Players.PlayerRemoving:Connect(function(player)
	playerFilterOxygen[player] = nil
end)

-- Toxic zone damage tick (0.5s, server-side only)
task.spawn(function()
	while true do
		task.wait(0.5)
		if stateFolder:GetAttribute("TimeFrozen") then continue end
		local domeRadius = stateFolder:GetAttribute("DomeRadius") or 60.0

		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChild("Humanoid")

			if root and humanoid and humanoid.Health > 0 then
				local oxygen = playerFilterOxygen[player] or 100.0
				local distance = (root.Position - purifier.Position).Magnitude

				if distance > domeRadius then
					oxygen = math.max(0, oxygen - FILTER_DRAIN)
					if oxygen <= 0 then
						humanoid:TakeDamage(TOXIC_DAMAGE)
					end
				else
					oxygen = math.min(100, oxygen + FILTER_RECHARGE)
				end

				playerFilterOxygen[player] = oxygen
				player:SetAttribute("FilterOxygen", oxygen)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		if stateFolder:GetAttribute("TimeFrozen") then continue end

		-- Update Time
		local timeOfDay = stateFolder:GetAttribute("TimeOfDay")
		timeOfDay = (timeOfDay + TIME_STEP) % 24
		stateFolder:SetAttribute("TimeOfDay", timeOfDay)

		-- Set IsNight
		local isNight = (timeOfDay >= 18.0 or timeOfDay < 6.0)
		stateFolder:SetAttribute("IsNight", isNight)

		-- Check Day increment
		local prevTime = timeOfDay - TIME_STEP
		if prevTime < 6.0 and timeOfDay >= 6.0 then
			local dayNum = stateFolder:GetAttribute("DayNumber")
			stateFolder:SetAttribute("DayNumber", dayNum + 1)
			print("Day " .. tostring(dayNum + 1) .. " has begun!")
		end

		-- Update lighting
		Lighting.ClockTime = timeOfDay
		if isNight then
			Lighting.Ambient = Color3.fromRGB(15, 15, 30)
			Lighting.OutdoorAmbient = Color3.fromRGB(10, 10, 25)
		else
			Lighting.Ambient = Color3.fromRGB(120, 120, 120)
			Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 120)
		end

		-- Fuel Decay
		local fuel = stateFolder:GetAttribute("PurifierFuel")
		if fuel > 0 then
			fuel = math.max(0, fuel - FUEL_DECAY)
			stateFolder:SetAttribute("PurifierFuel", fuel)
		end

		-- Calculate Dome Radius based on Fuel
		local maxRadius = 60.0
		local minRadius = 12.0
		local currentRadius = stateFolder:GetAttribute("DomeRadius")
		local targetRadius = (fuel > 0) and maxRadius or minRadius

		-- Interpolate radius for smooth transition
		currentRadius = currentRadius + (targetRadius - currentRadius) * 0.1
		stateFolder:SetAttribute("DomeRadius", currentRadius)

		-- Update visual dome scale and position
		if domeVisual then
			if domeTemplate then
				domeVisual.Size = Vector3.new(currentRadius * 2, currentRadius, currentRadius * 2)
				domeVisual.Position = Vector3.new(purifier.Position.X, currentRadius / 2, purifier.Position.Z)
			else
				domeVisual.Size = Vector3.new(currentRadius * 2, currentRadius * 2, currentRadius * 2)
				domeVisual.Position = purifier.Position
			end
		end

		-- Check if any Biomass is inside the Purifier range and absorb it
		for child in pairs(activeBiomass) do
			local dist = (child.Position - purifier.Position).Magnitude
			if dist <= RECHARGE_RANGE then
				removeBiomass(child)
				local currentFuel = stateFolder:GetAttribute("PurifierFuel")
				local maxFuel = stateFolder:GetAttribute("PurifierMaxFuel")
				stateFolder:SetAttribute("PurifierFuel", math.min(maxFuel, currentFuel + 25))

				-- Visual feedback: brief color flash on the core's Neon part
				if purifierNeon then
					task.spawn(function()
						local original = purifierNeon.Color
						purifierNeon.Color = Color3.fromRGB(0, 255, 150)
						task.wait(0.5)
						purifierNeon.Color = original
					end)
				end

				print("Purifier recharged with biomass absorbed in range.")
			end
		end
	end
end)

-- 6. Dynamic Connection Beam Task (Runs fast at 0.1s ticks for high responsiveness)
task.spawn(function()
	while true do
		task.wait(0.1)
		local purifAtt = purifier:FindFirstChild("PurifierAttachment")
		if not purifAtt then
			purifAtt = Instance.new("Attachment")
			purifAtt.Name = "PurifierAttachment"
			purifAtt.Parent = purifier
		end

		for child in pairs(activeBiomass) do
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
					existingBeam.Texture = "rbxassetid://450715307" -- Glowing beam texture
					existingBeam.TextureMode = Enum.TextureMode.Wrap
					existingBeam.TextureSpeed = -3 -- Flowing into the purifier

					-- Beautiful Cyan-Green energy gradient
					local c1 = Color3.fromRGB(0, 255, 120) -- Spore Green
					local c2 = Color3.fromRGB(0, 200, 255) -- Cyan
					existingBeam.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, c1),
						ColorSequenceKeypoint.new(1, c2)
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
