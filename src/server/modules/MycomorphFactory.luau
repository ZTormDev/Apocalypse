-- ServerScriptService.modules.MycomorphFactory
-- Data-driven Wildling builder. Reads its stats (health, speed, colors, display name) from
-- GameConfig.Enemies.Variants, so adding a new enemy variant is a new config row -- no code
-- change here. Builds a robust R6-hybrid crawler with a Humanoid, spore VFX, and a billboard
-- health bar, parents it to the Workspace, tags it, and returns the model. The caller owns
-- tracking it in the active list.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tags = require(Shared:WaitForChild("Tags"))

local MycomorphFactory = {}

-- Weighted pick of a variant key from GameConfig.Enemies.Variants (order-independent).
function MycomorphFactory.pickVariantKey(): string
	local variants = GameConfig.Enemies.Variants
	local totalWeight = 0
	for _, def in pairs(variants) do
		totalWeight += def.SpawnWeight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for key, def in pairs(variants) do
		cumulative += def.SpawnWeight
		if roll <= cumulative then
			return key
		end
	end
	-- Fallback (floating-point edge): return any key
	return (next(variants))
end

function MycomorphFactory.create(variantKey: string, spawnPos: Vector3): Model?
	local def = GameConfig.Enemies.Variants[variantKey]
	if not def then
		return nil
	end

	local char = Instance.new("Model")
	char.Name = def.DisplayName

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
	torso.Color = def.TorsoColor
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
	head.Color = def.HeadColor
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
		NumberSequenceKeypoint.new(1, 0.1),
	})
	emitter.Transparency = NumberSequence.new(0.3)
	emitter.Parent = head

	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = def.MaxHealth
	humanoid.Health = def.MaxHealth
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.Parent = char

	-- Tag for CollectionService
	CollectionService:AddTag(char, Tags.Mycomorph)

	char.Parent = Workspace

	-- Billboard health bar
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

	local despawnDelay = GameConfig.Enemies.DespawnDelay
	humanoid.HealthChanged:Connect(function(health)
		bar.Size = UDim2.new(health / humanoid.MaxHealth, 0, 1, 0)
		if health <= 0 then
			task.wait(despawnDelay)
			char:Destroy()
		end
	end)

	bgui.Parent = head

	return char
end

return MycomorphFactory
