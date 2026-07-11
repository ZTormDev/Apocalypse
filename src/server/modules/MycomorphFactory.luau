-- ServerScriptService.modules.MycomorphFactory
-- Data-driven Wildling builder. Clones a real R15 rig template from ReplicatedStorage.EnemyModels
-- (one per variant key: "Basic", "Fast"), then applies the variant's stats (health, speed,
-- display name) from GameConfig.Enemies.Variants and adds a billboard health bar. The rig keeps
-- its own appearance and Animate script; the game (MycomorphManager) drives it via Humanoid:MoveTo.
-- The caller owns tracking the returned model in the active list.
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
	return (next(variants))
end

local function getTemplate(variantKey: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("EnemyModels")
	local template = folder and folder:FindFirstChild(variantKey)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local function addHealthBar(char: Model, humanoid: Humanoid)
	local adornee = char:FindFirstChild("Head") or char.PrimaryPart
	if not adornee then
		return
	end

	local bgui = Instance.new("BillboardGui")
	bgui.Size = UDim2.new(4, 0, 0.6, 0)
	bgui.AlwaysOnTop = true
	bgui.StudsOffset = Vector3.new(0, 2.5, 0)
	bgui.MaxDistance = 60

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.BorderSizePixel = 0
	frame.Parent = bgui
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 3)
	fc.Parent = frame

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 1, 0)
	bar.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
	bar.BorderSizePixel = 0
	bar.Parent = frame
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 3)
	bc.Parent = bar

	bgui.Parent = adornee

	local despawnDelay = GameConfig.Enemies.DespawnDelay
	humanoid.HealthChanged:Connect(function(health)
		bar.Size = UDim2.new(math.clamp(health / humanoid.MaxHealth, 0, 1), 0, 1, 0)
		if health <= 0 then
			task.wait(despawnDelay)
			char:Destroy()
		end
	end)
end

function MycomorphFactory.create(variantKey: string, spawnPos: Vector3): Model?
	local def = GameConfig.Enemies.Variants[variantKey]
	if not def then
		return nil
	end
	local template = getTemplate(variantKey)
	if not template then
		warn("MycomorphFactory: no EnemyModels template for variant " .. tostring(variantKey))
		return nil
	end

	local char = template:Clone()
	char.Name = def.DisplayName

	-- Make sure nothing is anchored so the Humanoid can walk it.
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
		end
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		char:Destroy()
		return nil
	end
	humanoid.MaxHealth = def.MaxHealth
	humanoid.Health = def.MaxHealth
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	if not char.PrimaryPart then
		char.PrimaryPart = char:FindFirstChild("HumanoidRootPart")
	end

	char:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 3, 0)))
	CollectionService:AddTag(char, Tags.Mycomorph)
	char.Parent = Workspace

	addHealthBar(char, humanoid)

	return char
end

return MycomorphFactory
