-- ServerScriptService.MycomorphManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")

local MYCOMORPH_TAG = "Mycomorph"
local activeMycomorphs = {}

-- Utility to get purifier position
local function getPurifier()
	return Workspace:FindFirstChild("Purifier")
end

-- The Purifier Part itself is invisible (a collision/position anchor); the visible "Neon"
-- part lives inside the decorative "Power Core" model parented under it.
local function getPurifierNeon(purifier)
	return purifier and purifier:FindFirstChild("Neon", true)
end

-- 1. Dynamic Spore Monster Builder (R6-hybrid crawler, highly robust, no animations needed)
local function buildMycomorph(variantType, spawnPos)
	local char = Instance.new("Model")
	char.Name = variantType == "Fast" and "Sprout Runner" or "Spore-walker"

	-- HumanoidRootPart (PrimaryPart)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2)
	root.Position = spawnPos + Vector3.new(0, 2, 0)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = char
	char.PrimaryPart = root

	-- Torso (Fungal Body)
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.2, 2.5, 2.2)
	torso.Position = root.Position
	torso.Color = variantType == "Fast" and Color3.fromRGB(130, 0, 180) or Color3.fromRGB(45, 80, 45)
	torso.Material = Enum.Material.Mud
	torso.CanCollide = true
	torso.Parent = char

	local weldTorso = Instance.new("WeldConstraint")
	weldTorso.Part0 = root
	weldTorso.Part1 = torso
	weldTorso.Parent = root

	-- Head (Glowing Core)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Position = torso.Position + Vector3.new(0, 2, 0)
	head.Color = variantType == "Fast" and Color3.fromRGB(255, 0, 255) or Color3.fromRGB(0, 255, 100)
	head.Material = Enum.Material.Neon
	head.CanCollide = true
	head.Parent = char

	local weldHead = Instance.new("WeldConstraint")
	weldHead.Part0 = torso
	weldHead.Part1 = head
	weldHead.Parent = torso

	-- Spore Emitter VFX
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 12
	emitter.Speed = NumberRange.new(2, 5)
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Color = ColorSequence.new(head.Color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.1)
	})
	emitter.Transparency = NumberSequence.new(0.3)
	emitter.Parent = head

	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = variantType == "Fast" and 50 or 100
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = variantType == "Fast" and 22 or 13
	humanoid.Parent = char

	-- Tag for CollectionService
	CollectionService:AddTag(char, MYCOMORPH_TAG)

	char.Parent = Workspace
	table.insert(activeMycomorphs, char)

	-- Setup Billboard HealthBar
	local bgui = Instance.new("BillboardGui")
	bgui.Size = UDim2.new(4, 0, 1, 0)
	bgui.AlwaysOnTop = true
	bgui.StudsOffset = Vector3.new(0, 3, 0)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0.2, 0)
	frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	frame.BorderSizePixel = 0
	frame.Parent = bgui

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 1, 0)
	bar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	bar.BorderSizePixel = 0
	bar.Parent = frame

	humanoid.HealthChanged:Connect(function(health)
		bar.Size = UDim2.new(health / humanoid.MaxHealth, 0, 1, 0)
		if health <= 0 then
			task.wait(1.5)
			char:Destroy()
		end
	end)

	bgui.Parent = head

	return char
end

-- 2. Spawning Loop during the night
local isSpawningActive = false

local function startSpawning()
	isSpawningActive = true
	print("Wildling Spawner started (Night).")
	task.spawn(function()
		while isSpawningActive do
			local purifier = getPurifier()
			if purifier then
				-- Spawn on a circle outside the base (120 studs away)
				local angle = math.random() * math.pi * 2
				local dist = 110
				local spawnPos = purifier.Position + Vector3.new(math.cos(angle) * dist, 2, math.sin(angle) * dist)

				-- 30% chance for Sprout Runner, 70% for Spore-walker
				local isFast = math.random(1, 10) <= 3
				buildMycomorph(isFast and "Fast" or "Basic", spawnPos)
			end
			task.wait(8) -- Spawn every 8 seconds
		end
	end)
end

local function stopSpawning()
	isSpawningActive = false
	print("Stopping Wildling Spawner (Day).")
	-- Destroy all active monsters
	for _, char in ipairs(activeMycomorphs) do
		if char and char.Parent then
			char:Destroy()
		end
	end
	activeMycomorphs = {}
end

-- Watch state folder attributes
stateFolder:GetAttributeChangedSignal("IsNight"):Connect(function()
	local isNight = stateFolder:GetAttribute("IsNight")
	if isNight then
		startSpawning()
	else
		stopSpawning()
	end
end)

-- If started in night mode directly
if stateFolder:GetAttribute("IsNight") then
	startSpawning()
end

-- 3. AI Update Loop (0.5 seconds tick)
task.spawn(function()
	local attackCooldowns = {} -- [char] = lastAttackTime

	while true do
		task.wait(0.5)

		local purifier = getPurifier()
		if not purifier then continue end

		-- Clean up dead entries from our list
		local aliveList = {}
		for _, char in ipairs(activeMycomorphs) do
			if char and char.Parent and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
				table.insert(aliveList, char)
			else
				if char and char.Parent then char:Destroy() end
			end
		end
		activeMycomorphs = aliveList

		for _, char in ipairs(activeMycomorphs) do
			local humanoid = char.Humanoid
			local root = char.PrimaryPart
			if not root then continue end

			-- 1. Find Closest Target
			local targetPos = purifier.Position
			local targetInstance = purifier
			local closestPlayerDist = 99999
			local targetPlayerChar = nil

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

			-- Switch to player if they are within detection range (45 studs)
			if closestPlayerDist <= 45 and targetPlayerChar then
				targetPos = targetPlayerChar.HumanoidRootPart.Position
				targetInstance = targetPlayerChar
			end

			-- 2. Direct MoveTo
			humanoid:MoveTo(targetPos)

			-- 3. Attack Handling
			local distanceToTarget = (root.Position - targetPos).Magnitude
			local now = os.clock()
			local lastAttack = attackCooldowns[char] or 0

			if targetInstance == purifier then
				if distanceToTarget <= 9 then
					if now - lastAttack >= 1.5 then
						attackCooldowns[char] = now

						-- Damage purifier
						local hp = stateFolder:GetAttribute("PurifierHealth") or 100
						stateFolder:SetAttribute("PurifierHealth", math.max(0, hp - 5))

						-- Purifier Damage effect: flash the core's Neon part red
						local neon = getPurifierNeon(purifier)
						if neon then
							task.spawn(function()
								local original = neon.Color
								neon.Color = Color3.fromRGB(255, 0, 0)
								task.wait(0.2)
								neon.Color = original
							end)
						end

						print("The Wildling attacks the purifier! Remaining health: " .. tostring(hp - 5))
					end
				end
			else
				-- Target is Player character
				if distanceToTarget <= 5 then
					if now - lastAttack >= 1.0 then
						attackCooldowns[char] = now
						local pTitle = targetInstance.Name
						local pHumanoid = targetInstance:FindFirstChild("Humanoid")
						if pHumanoid then
							pHumanoid:TakeDamage(10)
							print("The Wildling attacks " .. pTitle .. "! Damage dealt: 10")
						end
					end
				end
			end
		end
	end
end)
