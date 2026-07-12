-- ServerScriptService.Enemies.MycomorphManager
-- Owns the night horde spawn loop and the AI loop. The actual Wildling construction is delegated
-- to the data-driven MycomorphFactory (stats come from GameConfig.Enemies.Variants), so this file
-- is purely behavior: when to spawn, where, what to target, when to attack.
--
-- The horde scales night after night (HordeDirector decides the size + how many zones): more
-- zombies and more simultaneously-active zones as DayNumber climbs. Zombies trickle in one at a
-- time from flat rectangular ZombieSpawnZone-tagged Parts; a chosen zone spawns its share, and
-- the next chosen zone only joins in once the current one passes Horde.ZoneAdvanceThreshold. Each
-- active zone shows a red "HORDA" alert (billboard + light pillar), and a big on-screen banner is
-- pushed to clients (HordeEvents.HordeWarning). The "HordeActive" SporeTideState attribute stays
-- true from the first spawn until the whole night's total is spawned AND killed; WorldClock
-- watches it to know when to end the night.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tags = require(Shared:WaitForChild("Tags"))
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local MycomorphFactory = require(Modules:WaitForChild("MycomorphFactory"))
local HordeDirector = require(Modules:WaitForChild("HordeDirector"))

local hordeWarningEvent = Net.event("HordeEvents", "HordeWarning")

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

-- A random point just above the top face of a specific spawn zone.
local function randomPointInZone(zone: BasePart): Vector3
	local half = zone.Size / 2
	local localOffset = Vector3.new(
		(math.random() * 2 - 1) * half.X,
		half.Y + 2,
		(math.random() * 2 - 1) * half.Z
	)
	return (zone.CFrame * CFrame.new(localOffset)).Position
end

-- ---------------------------------------------------------------------------------------
-- Zone alert marker: a pulsing red "HORDA" billboard + a translucent light pillar over a zone,
-- so players can see from across the map exactly where a wave is coming from.
-- ---------------------------------------------------------------------------------------
local function showZoneAlert(zone: BasePart)
	if zone:FindFirstChild("HordeAlert") then
		return
	end
	local alert = Instance.new("Model")
	alert.Name = "HordeAlert"

	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(60, math.min(zone.Size.X, zone.Size.Z) * 0.6, math.min(zone.Size.X, zone.Size.Z) * 0.6)
	pillar.CFrame = CFrame.new(zone.Position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = Color3.fromRGB(255, 40, 40)
	pillar.Transparency = 0.75
	pillar.Parent = alert

	local bb = Instance.new("BillboardGui")
	bb.Name = "Warning"
	bb.Size = UDim2.new(0, 240, 0, 60)
	bb.StudsOffset = Vector3.new(0, 14, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 1000
	bb.Adornee = zone

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "⚠ HORDE ⚠"
	label.TextColor3 = Color3.fromRGB(255, 60, 60)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = bb
	bb.Parent = alert

	alert.Parent = zone

	-- Pulse the pillar + label (TweenService stops automatically when the model is destroyed).
	local TweenService = game:GetService("TweenService")
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(pillar, info, { Transparency = 0.5 }):Play()
	TweenService:Create(label, info, { TextTransparency = 0.35 }):Play()
end

local function hideZoneAlert(zone: BasePart)
	local alert = zone:FindFirstChild("HordeAlert")
	if alert then
		alert:Destroy()
	end
end

local function clearAllZoneAlerts()
	for _, zone in ipairs(CollectionService:GetTagged(Tags.ZombieSpawnZone)) do
		if zone:IsA("BasePart") then
			hideZoneAlert(zone)
		end
	end
end

local function startSpawning()
	isSpawningActive = true
	spawnGeneration += 1
	local generation = spawnGeneration
	hordeSpawnedCount = 0

	-- Gather the available zones (BaseParts only) and shuffle so the chosen set/order varies.
	local zones = {}
	for _, z in ipairs(CollectionService:GetTagged(Tags.ZombieSpawnZone)) do
		if z:IsA("BasePart") then
			table.insert(zones, z)
		end
	end
	if #zones == 0 then
		warn("MycomorphManager: no ZombieSpawnZone-tagged parts found, cannot spawn the horde.")
		return
	end
	for i = #zones, 2, -1 do
		local j = math.random(1, i)
		zones[i], zones[j] = zones[j], zones[i]
	end

	local night = stateFolder:GetAttribute("DayNumber") or 1
	local plan = HordeDirector.planNight(night, #zones)

	local chosen = {}
	for i = 1, plan.zoneCount do
		chosen[i] = zones[i]
	end

	hordeTargetCount = plan.total
	stateFolder:SetAttribute("HordeActive", true)
	print(string.format("Night %d horde: %d zombies across %d zone(s).", night, plan.total, plan.zoneCount))

	-- Epic on-screen warning for every client.
	hordeWarningEvent:FireAllClients("A HORDE APPROACHES!", night, plan.total)

	-- Staggered spawn: each zone spawns its share one at a time; the next chosen zone only joins
	-- in once the current one has spawned ZoneAdvanceThreshold of its zombies.
	local function spawnZone(index: number)
		if index > #chosen then
			return
		end
		local zone = chosen[index]
		local count = plan.perZone[index]
		local advanceAt = math.max(1, math.ceil(count * HORDE.ZoneAdvanceThreshold))
		showZoneAlert(zone)

		task.spawn(function()
			for i = 1, count do
				if generation ~= spawnGeneration then
					hideZoneAlert(zone)
					return
				end
				local variantKey = MycomorphFactory.pickVariantKey()
				local mob = MycomorphFactory.create(variantKey, randomPointInZone(zone))
				if mob then
					table.insert(activeMycomorphs, mob)
				end
				hordeSpawnedCount += 1

				if i == advanceAt then
					spawnZone(index + 1) -- next zone joins the assault
				end
				task.wait(HORDE.SpawnInterval)
			end
			hideZoneAlert(zone)
		end)
	end
	spawnZone(1)
end

local function stopSpawning()
	isSpawningActive = false
	spawnGeneration += 1 -- cancels any in-flight spawn loop
	hordeSpawnedCount = 0
	hordeTargetCount = 0
	stateFolder:SetAttribute("HordeActive", false)
	clearAllZoneAlerts()
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

		-- Prune dead entries from tracking/targeting -- but don't destroy the corpse: it just
		-- died (or ragdolled and is still on the ground), and MycomorphFactory's own
		-- humanoid.Died handler ragdolls it and despawns it later (GameConfig.Enemies.DespawnDelay).
		-- Destroying it here would cut that ragdoll short the instant a zombie dies. Looked up by
		-- class, not by name -- the rig's Humanoid instance is actually named "Zombie", so a
		-- name-based FindFirstChild("Humanoid") always missed it and pruned every zombie the very
		-- first tick after it spawned.
		local aliveList = {}
		for _, char in ipairs(activeMycomorphs) do
			local mobHumanoid = char and char.Parent and char:FindFirstChildOfClass("Humanoid")
			if mobHumanoid and mobHumanoid.Health > 0 then
				table.insert(aliveList, char)
			else
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

