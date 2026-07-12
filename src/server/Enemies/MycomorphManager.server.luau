-- ServerScriptService.Enemies.MycomorphManager
-- Owns the night horde spawn loop and the AI loop. The actual Wildling construction is delegated
-- to the data-driven MycomorphFactory (stats come from GameConfig.Enemies.Variants), so this file
-- is purely behavior: when to spawn, where, what to target, when to attack.
--
-- The horde: a fixed total (GameConfig.Enemies.Horde.TotalZombies) trickled in one at a time from
-- four flat rectangular zones (ZombieSpawnZone-tagged Parts, North/South/East/West of the
-- Purifier -- see ZombieSpawnZones.server.luau) placed around the base. The "HordeActive"
-- SporeTideState attribute stays true from the first zombie's spawn until the last one (of the
-- whole night's total) dies; WorldClock watches that attribute to know when to end the night.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tags = require(Shared:WaitForChild("Tags"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local MycomorphFactory = require(Modules:WaitForChild("MycomorphFactory"))

local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")

local HORDE = GameConfig.Enemies.Horde
local AI = GameConfig.Enemies.Ai

local activeMycomorphs: { Model } = {}

local function getPurifier(): Instance?
	return Workspace:FindFirstChild("Purifier")
end

-- The Purifier Part is invisible; its visible "Neon" part lives inside the Power Core model.
local function getPurifierNeon(purifier: Instance): BasePart?
	local neon = purifier:FindFirstChild("Neon", true)
	if neon and neon:IsA("BasePart") then
		return neon
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- Spawning during the night
-- ---------------------------------------------------------------------------------------
local isSpawningActive = false
local spawnGeneration = 0 -- bumped on every start/stop so a stale in-flight loop can tell it's cancelled
local hordeSpawnedCount = 0
local hordeTargetCount = 0

-- Picks a random point inside a random ZombieSpawnZone (a flat rectangle Part). Returns nil if
-- no zones exist (ZombieSpawnZones.server.luau creates the default 4 if none were hand-placed).
local function pickSpawnPosition(): Vector3?
	local zones = CollectionService:GetTagged(Tags.ZombieSpawnZone)
	if #zones == 0 then
		warn("MycomorphManager: no ZombieSpawnZone-tagged parts found, cannot spawn the horde.")
		return nil
	end

	local zone = zones[math.random(1, #zones)]
	if not zone:IsA("BasePart") then
		return nil
	end

	local half = zone.Size / 2
	local localOffset = Vector3.new(
		(math.random() * 2 - 1) * half.X,
		half.Y + 2, -- a couple studs above the zone's top face
		(math.random() * 2 - 1) * half.Z
	)
	return (zone.CFrame * CFrame.new(localOffset)).Position
end

local function startSpawning()
	isSpawningActive = true
	spawnGeneration += 1
	local generation = spawnGeneration
	hordeSpawnedCount = 0
	hordeTargetCount = HORDE.TotalZombies
	stateFolder:SetAttribute("HordeActive", true)
	print(string.format("Wildling Spawner started (Night). Horde size: %d", hordeTargetCount))

	task.spawn(function()
		for _ = 1, hordeTargetCount do
			if generation ~= spawnGeneration then
				return -- cancelled (night ended early, e.g. a Bio-Recall reset)
			end

			local spawnPos = pickSpawnPosition()
			if spawnPos then
				local variantKey = MycomorphFactory.pickVariantKey()
				local mob = MycomorphFactory.create(variantKey, spawnPos)
				if mob then
					table.insert(activeMycomorphs, mob)
				end
			end
			hordeSpawnedCount += 1

			task.wait(HORDE.SpawnInterval)
		end
	end)
end

local function stopSpawning()
	isSpawningActive = false
	spawnGeneration += 1 -- cancels any in-flight spawn loop
	hordeSpawnedCount = 0
	hordeTargetCount = 0
	stateFolder:SetAttribute("HordeActive", false)
	print("Stopping Wildling Spawner (Day).")
	for _, char in ipairs(activeMycomorphs) do
		if char and char.Parent then
			char:Destroy()
		end
	end
	activeMycomorphs = {}
end

stateFolder:GetAttributeChangedSignal("IsNight"):Connect(function()
	if stateFolder:GetAttribute("IsNight") then
		startSpawning()
	else
		stopSpawning()
	end
end)

if stateFolder:GetAttribute("IsNight") then
	startSpawning()
end

-- ---------------------------------------------------------------------------------------
-- AI update loop
-- ---------------------------------------------------------------------------------------
task.spawn(function()
	local attackCooldowns: { [Model]: number } = {}

	while true do
		task.wait(AI.TickInterval)

		local purifier = getPurifier()
		if not purifier or not purifier:IsA("BasePart") then
			continue
		end

		-- Prune dead/destroyed entries. Looked up by class, not by name -- the rig's Humanoid
		-- instance is actually named "Zombie", so a name-based FindFirstChild("Humanoid") always
		-- missed it and pruned every zombie the very first tick after it spawned.
		local aliveList = {}
		for _, char in ipairs(activeMycomorphs) do
			local mobHumanoid = char and char.Parent and char:FindFirstChildOfClass("Humanoid")
			if mobHumanoid and mobHumanoid.Health > 0 then
				table.insert(aliveList, char)
			else
				if char and char.Parent then
					char:Destroy()
				end
				attackCooldowns[char] = nil
			end
		end
		activeMycomorphs = aliveList

		-- The night ends once the whole horde (every zombie for tonight) has been spawned and
		-- killed -- WorldClock watches HordeActive to know when to start the dawn transition.
		if stateFolder:GetAttribute("HordeActive")
			and hordeSpawnedCount >= hordeTargetCount
			and hordeTargetCount > 0
			and #activeMycomorphs == 0
		then
			stateFolder:SetAttribute("HordeActive", false)
			print("Horde cleared -- night is ending.")
		end

		for _, char in ipairs(activeMycomorphs) do
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			local root = char.PrimaryPart
			if not humanoid then
				continue
			end
			if not root then
				continue
			end

			-- Find closest target (Purifier by default, nearest player if one is in range)
			local targetPos = purifier.Position
			local targetInstance: Instance = purifier
			local closestPlayerDist = 99999
			local targetPlayerChar: Model? = nil

			for _, player in ipairs(Players:GetPlayers()) do
				local pChar = player.Character
				if pChar and pChar:FindFirstChild("HumanoidRootPart") and pChar:FindFirstChild("Humanoid") and pChar.Humanoid.Health > 0 then
					local dist = (root.Position - pChar.HumanoidRootPart.Position).Magnitude
					if dist < closestPlayerDist then
						closestPlayerDist = dist
						targetPlayerChar = pChar
					end
				end
			end

			if closestPlayerDist <= AI.DetectionRange and targetPlayerChar then
				targetPos = targetPlayerChar.HumanoidRootPart.Position
				targetInstance = targetPlayerChar
			end

			humanoid:MoveTo(targetPos)

			local distanceToTarget = (root.Position - targetPos).Magnitude
			local now = os.clock()
			local lastAttack = attackCooldowns[char] or 0

			if targetInstance == purifier then
				if distanceToTarget <= AI.PurifierAttackRange then
					if now - lastAttack >= AI.PurifierAttackCooldown then
						attackCooldowns[char] = now

						local hp = stateFolder:GetAttribute("PurifierHealth") or 100
						stateFolder:SetAttribute("PurifierHealth", math.max(0, hp - AI.PurifierDamage))

						local neon = getPurifierNeon(purifier)
						if neon then
							task.spawn(function()
								local original = neon.Color
								neon.Color = Color3.fromRGB(255, 0, 0)
								task.wait(0.2)
								neon.Color = original
							end)
						end

						print("The Wildling attacks the purifier! Remaining health: " .. tostring(hp - AI.PurifierDamage))
					end
				end
			else
				if distanceToTarget <= AI.PlayerAttackRange then
					if now - lastAttack >= AI.PlayerAttackCooldown then
						attackCooldowns[char] = now
						local pTitle = targetInstance.Name
						local pHumanoid = targetInstance:FindFirstChild("Humanoid")
						if pHumanoid then
							pHumanoid:TakeDamage(AI.PlayerDamage)
							print("The Wildling attacks " .. pTitle .. "! Damage dealt: " .. tostring(AI.PlayerDamage))
						end
					end
				end
			end
		end
	end
end)

