-- ServerScriptService.Enemies.MycomorphManager
-- Owns the night spawn loop and the AI loop. The actual Wildling construction is delegated to
-- the data-driven MycomorphFactory (stats come from GameConfig.Enemies.Variants), so this file
-- is purely behavior: when to spawn, what to target, when to attack.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local MycomorphFactory = require(Modules:WaitForChild("MycomorphFactory"))

local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")

local SPAWN = GameConfig.Enemies.Spawn
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

local function startSpawning()
	isSpawningActive = true
	print("Wildling Spawner started (Night).")
	task.spawn(function()
		while isSpawningActive do
			local purifier = getPurifier()
			if purifier and purifier:IsA("BasePart") then
				local angle = math.random() * math.pi * 2
				local dist = SPAWN.Distance
				local spawnPos = purifier.Position + Vector3.new(math.cos(angle) * dist, 2, math.sin(angle) * dist)

				local variantKey = MycomorphFactory.pickVariantKey()
				local mob = MycomorphFactory.create(variantKey, spawnPos)
				if mob then
					table.insert(activeMycomorphs, mob)
				end
			end
			task.wait(SPAWN.Interval)
		end
	end)
end

local function stopSpawning()
	isSpawningActive = false
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

		-- Prune dead/destroyed entries
		local aliveList = {}
		for _, char in ipairs(activeMycomorphs) do
			if char and char.Parent and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
				table.insert(aliveList, char)
			else
				if char and char.Parent then
					char:Destroy()
				end
			end
		end
		activeMycomorphs = aliveList

		for _, char in ipairs(activeMycomorphs) do
			local humanoid = char.Humanoid
			local root = char.PrimaryPart
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
