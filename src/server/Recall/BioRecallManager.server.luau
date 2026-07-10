-- ServerScriptService.Recall.BioRecallManager
-- "Dome Reset": if every player dies, the Purifier's emergency module rewinds the base to its
-- state at 6:00 AM that morning (GDD section 4), preventing a permanent softlock on a team wipe.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local ScrapWallet = require(Modules:WaitForChild("ScrapWallet"))

local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")

local RECALL = GameConfig.BioRecall
local STARTING_AMMO = GameConfig.Pistol.StartingAmmo
local DISCARDED_ON_RECALL = RECALL.DiscardedOnRecall

local triggeredEvent = Net.event("BioRecallEvents", "BioRecallTriggered")
local completeEvent = Net.event("BioRecallEvents", "BioRecallComplete")

local purifier = Workspace:WaitForChild("Purifier", 15)

local snapshot: any = nil
local isRecalling = false
local hasEverSpawned: { [Player]: boolean } = {} -- a player still loading in doesn't count as a "wipe"

local function onCharacterAdded(player: Player)
	hasEverSpawned[player] = true
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		hasEverSpawned[player] = true
	end
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
end)
Players.PlayerRemoving:Connect(function(player)
	hasEverSpawned[player] = nil
end)

local function takeSnapshot()
	local structures = {}
	for _, structure in ipairs(CollectionService:GetTagged(Tags.Structure)) do
		if structure.Parent then
			table.insert(structures, {
				Name = structure.Name,
				CFrame = structure.CFrame,
				Size = structure.Size,
				Material = structure.Material,
				Color = structure.Color,
				Health = structure:GetAttribute("Health"),
				MaxHealth = structure:GetAttribute("MaxHealth"),
				Electric = CollectionService:HasTag(structure, Tags.ElectricFence),
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

-- Initial snapshot once the world is ready (covers Day 1 before the first dawn)
if purifier then
	takeSnapshot()
end

-- Re-snapshot each dawn (WorldClock increments DayNumber at 6:00 AM)
stateFolder:GetAttributeChangedSignal("DayNumber"):Connect(function()
	if not isRecalling then
		takeSnapshot()
	end
end)

local function clearDiscardedItems(player: Player)
	local backpack = player:FindFirstChild("Backpack")
	local char = player.Character
	for itemName in pairs(DISCARDED_ON_RECALL) do
		local fromBackpack = backpack and backpack:FindFirstChild(itemName)
		if fromBackpack then
			fromBackpack:Destroy()
		end
		local fromChar = char and char:FindFirstChild(itemName)
		if fromChar then
			fromChar:Destroy()
		end
	end
end

local function respawnPlayer(player: Player, playerSnapshot: any)
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
	if isRecalling or not snapshot then
		return
	end
	isRecalling = true

	print("Team wipe detected -- Bio-Recall Protocol activated.")
	stateFolder:SetAttribute("TimeFrozen", true)
	triggeredEvent:FireAllClients()

	task.wait(RECALL.DramaticPause)

	-- Remove every Wildling
	for _, mycomorph in ipairs(CollectionService:GetTagged(Tags.Mycomorph)) do
		if mycomorph.Parent then
			mycomorph:Destroy()
		end
	end

	-- Destroy everything built during the failed day, then rebuild the 6:00 AM snapshot
	for _, structure in ipairs(CollectionService:GetTagged(Tags.Structure)) do
		if structure.Parent then
			structure:Destroy()
		end
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
		CollectionService:AddTag(part, Tags.Structure)
		if data.Electric then
			CollectionService:AddTag(part, Tags.ElectricFence)
		end
	end

	-- Restore Purifier fuel/health; the dome radius converges back automatically
	stateFolder:SetAttribute("PurifierFuel", snapshot.PurifierFuel)
	stateFolder:SetAttribute("PurifierHealth", snapshot.PurifierHealth)

	-- Restore each player's inventory and respawn them at the base
	for _, player in ipairs(Players:GetPlayers()) do
		respawnPlayer(player, snapshot.Players[player.UserId])
	end

	-- Reset the clock to 6:00 AM of the same day
	stateFolder:SetAttribute("TimeOfDay", GameConfig.World.DayStartHour)
	stateFolder:SetAttribute("IsNight", false)
	stateFolder:SetAttribute("TimeFrozen", false)

	completeEvent:FireAllClients()
	isRecalling = false

	print("Bio-Recall Protocol complete -- base restored to 6:00 AM state.")
end

-- Team death detection
task.spawn(function()
	while true do
		task.wait(RECALL.DeathCheckInterval)
		if isRecalling then
			continue
		end

		local players = Players:GetPlayers()
		if #players == 0 then
			continue
		end

		local allDead = true
		for _, player in ipairs(players) do
			if not hasEverSpawned[player] then
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
