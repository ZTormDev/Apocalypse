-- ServerScriptService.BioRecallManager
-- "Dome Reset": if every player dies, the Purifier's emergency life-support module
-- (Bio-Recall Protocol) rewinds the base to its state at 6:00 AM that morning, per the
-- lore in Game_Design_Document.md section 4. Prevents permanent softlocks on a team wipe.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")
local ScrapWallet = require(script.Parent:WaitForChild("ScrapWallet"))

local BioRecallEvents = ReplicatedStorage:FindFirstChild("BioRecallEvents")
if not BioRecallEvents then
	BioRecallEvents = Instance.new("Folder")
	BioRecallEvents.Name = "BioRecallEvents"
	BioRecallEvents.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name)
	local remote = BioRecallEvents:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = BioRecallEvents
	end
	return remote
end

local triggeredEvent = getOrCreateRemote("BioRecallTriggered")
local completeEvent = getOrCreateRemote("BioRecallComplete")

local purifier = Workspace:WaitForChild("Purifier", 15)

local STARTING_AMMO = 12
-- Items gathered/crafted during the failed day are lost on recall, same as the lore's
-- "you lose materials gathered during that failed day" rule. Scrap itself is restored
-- separately from the snapshot since it's the persistent currency, not a raw pickup.
local DISCARDED_ON_RECALL = {["Wall"] = true, ["Electric Fence"] = true, ["Spore Biomass"] = true}

local snapshot = nil
local isRecalling = false
local hasEverSpawned = {} -- [player] = true; a player who hasn't spawned yet doesn't count toward a "wipe"

local function onCharacterAdded(player)
	hasEverSpawned[player] = true
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then hasEverSpawned[player] = true end
	player.CharacterAdded:Connect(function() onCharacterAdded(player) end)
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function() onCharacterAdded(player) end)
end)
Players.PlayerRemoving:Connect(function(player)
	hasEverSpawned[player] = nil
end)

local function takeSnapshot()
	local structures = {}
	for _, structure in ipairs(CollectionService:GetTagged("Structure")) do
		if structure.Parent then
			table.insert(structures, {
				Name = structure.Name,
				CFrame = structure.CFrame,
				Size = structure.Size,
				Material = structure.Material,
				Color = structure.Color,
				Health = structure:GetAttribute("Health"),
				MaxHealth = structure:GetAttribute("MaxHealth"),
				Electric = CollectionService:HasTag(structure, "ElectricFence"),
			})
		end
	end

	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		players[player.UserId] = {
			Scrap = ScrapWallet.GetAmount(player),
			PistolAmmo = player:GetAttribute("PistolAmmo") or STARTING_AMMO,
		}
	end

	snapshot = {
		Structures = structures,
		PurifierFuel = stateFolder:GetAttribute("PurifierFuel"),
		PurifierHealth = stateFolder:GetAttribute("PurifierHealth"),
		Players = players,
	}

	print("Bio-Recall snapshot saved at dawn (Day " .. tostring(stateFolder:GetAttribute("DayNumber")) .. ").")
end

-- Initial snapshot as soon as the world is ready (covers Day 1 before the first dawn signal)
if purifier then
	takeSnapshot()
end

-- Re-snapshot every time a new day dawns (TimeAndPurifierManager increments DayNumber at 6:00 AM)
stateFolder:GetAttributeChangedSignal("DayNumber"):Connect(function()
	if not isRecalling then
		takeSnapshot()
	end
end)

local function clearDiscardedItems(player)
	local backpack = player:FindFirstChild("Backpack")
	local char = player.Character
	for itemName in pairs(DISCARDED_ON_RECALL) do
		local fromBackpack = backpack and backpack:FindFirstChild(itemName)
		if fromBackpack then fromBackpack:Destroy() end
		local fromChar = char and char:FindFirstChild(itemName)
		if fromChar then fromChar:Destroy() end
	end
end

local function respawnPlayer(player, playerSnapshot)
	clearDiscardedItems(player)

	local connection
	connection = player.CharacterAdded:Connect(function()
		connection:Disconnect()

		player:SetAttribute("FilterOxygen", 100)
		player:SetAttribute("PistolAmmo", playerSnapshot and playerSnapshot.PistolAmmo or STARTING_AMMO)
		ScrapWallet.SetAmount(player, playerSnapshot and playerSnapshot.Scrap or 0)
	end)
	player:LoadCharacter()
end

local function triggerBioRecall()
	if isRecalling or not snapshot then return end
	isRecalling = true

	print("Team wipe detected -- Bio-Recall Protocol activated.")
	stateFolder:SetAttribute("TimeFrozen", true)
	triggeredEvent:FireAllClients()

	task.wait(3) -- dramatic pause so players can read the overlay

	-- Remove every Wildling on the map
	for _, mycomorph in ipairs(CollectionService:GetTagged("Mycomorph")) do
		if mycomorph.Parent then mycomorph:Destroy() end
	end

	-- Destroy everything built during the failed day, then rebuild the 6:00 AM snapshot
	for _, structure in ipairs(CollectionService:GetTagged("Structure")) do
		if structure.Parent then structure:Destroy() end
	end
	for _, data in ipairs(snapshot.Structures) do
		local part = Instance.new("Part")
		part.Name = data.Name
		part.Size = data.Size
		part.CFrame = data.CFrame
		part.Anchored = true
		part.CanCollide = true
		part.Material = data.Material
		part.Color = data.Color
		part:SetAttribute("Health", data.Health)
		part:SetAttribute("MaxHealth", data.MaxHealth)
		part.Parent = Workspace
		CollectionService:AddTag(part, "Structure")
		if data.Electric then
			CollectionService:AddTag(part, "ElectricFence")
		end
	end

	-- Restore Purifier fuel/health; the dome radius converges back to it automatically
	stateFolder:SetAttribute("PurifierFuel", snapshot.PurifierFuel)
	stateFolder:SetAttribute("PurifierHealth", snapshot.PurifierHealth)

	-- Restore each player's inventory and respawn them at the base
	for _, player in ipairs(Players:GetPlayers()) do
		respawnPlayer(player, snapshot.Players[player.UserId])
	end

	-- Reset the clock to 6:00 AM of the same day
	stateFolder:SetAttribute("TimeOfDay", 6.0)
	stateFolder:SetAttribute("IsNight", false)
	stateFolder:SetAttribute("TimeFrozen", false)

	completeEvent:FireAllClients()
	isRecalling = false

	print("Bio-Recall Protocol complete -- base restored to 6:00 AM state.")
end

-- Team death detection (1s tick)
task.spawn(function()
	while true do
		task.wait(1)
		if isRecalling then continue end

		local players = Players:GetPlayers()
		if #players == 0 then continue end

		local allDead = true
		for _, player in ipairs(players) do
			if not hasEverSpawned[player] then
				-- still loading in for the first time; doesn't count toward a wipe
				allDead = false
				break
			end
			local char = player.Character
			local humanoid = char and char:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				allDead = false
				break
			end
		end

		if allDead then
			triggerBioRecall()
		end
	end
end)
