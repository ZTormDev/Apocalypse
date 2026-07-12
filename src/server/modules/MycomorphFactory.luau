-- ServerScriptService.modules.MycomorphFactory
-- Data-driven Wildling builder. Clones a real R15 rig template from ReplicatedStorage.EnemyModels
-- (one per variant key: "Basic", "Fast"), then applies the variant's stats (health, speed,
-- display name) from GameConfig.Enemies.Variants and adds a billboard health bar. The rig keeps
-- its own appearance and Animate script; the game (MycomorphManager) drives it via Humanoid:MoveTo.
-- The caller owns tracking the returned model in the active list.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tags = require(Shared:WaitForChild("Tags"))

local MycomorphFactory = {}

-- Wildlings physically collide with each other (a normal collision group, so a crowd pushes/
-- jostles like real bodies) -- but AutoJumpEnabled is off on their Humanoid (set below) so being
-- blocked by another Wildling's body never makes one hop up and appear to climb on top of it.
local WILDLING_COLLISION_GROUP = "Wildling"
local wildlingCollisionGroupReady = false
local function ensureWildlingCollisionGroup()
	if wildlingCollisionGroupReady then
		return
	end
	wildlingCollisionGroupReady = true
	pcall(function()
		PhysicsService:RegisterCollisionGroup(WILDLING_COLLISION_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(WILDLING_COLLISION_GROUP, WILDLING_COLLISION_GROUP, true)
end

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

-- Same minimalist HUD language as the rest of the game (dark panel, thin border, bold outlined
-- text): name label on top, health bar below it.
local function addHealthBar(char: Model, humanoid: Humanoid, displayName: string)
	local adornee = char:FindFirstChild("Head") or char.PrimaryPart
	if not adornee then
		return
	end

	local bgui = Instance.new("BillboardGui")
	bgui.Name = "HealthGui"
	bgui.Size = UDim2.new(0, 110, 0, 30)
	bgui.AlwaysOnTop = true
	bgui.StudsOffset = Vector3.new(0, 2.6, 0)
	bgui.MaxDistance = 60
	bgui.Parent = adornee

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 15)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = displayName
	nameLabel.TextColor3 = Color3.fromRGB(222, 224, 229)
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = bgui

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Position = UDim2.new(0, 0, 0, 17)
	bg.Size = UDim2.new(1, 0, 0, 9)
	bg.BackgroundColor3 = Color3.fromRGB(26, 27, 32)
	bg.BackgroundTransparency = 0.1
	bg.BorderSizePixel = 0
	bg.Parent = bgui

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = bg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(42, 44, 50)
	bgStroke.Thickness = 1
	bgStroke.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(196, 84, 84) -- matches the player HUD's health color
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local despawnDelay = GameConfig.Enemies.DespawnDelay
	humanoid.HealthChanged:Connect(function(health)
		fill.Size = UDim2.new(math.clamp(health / humanoid.MaxHealth, 0, 1), 0, 1, 0)
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

	ensureWildlingCollisionGroup()

	local char = template:Clone()
	char.Name = def.DisplayName

	-- Make sure nothing is anchored so the Humanoid can walk it, put every part in the
	-- no-self-collide group so a crowd doesn't shove/pile on top of each other, and strip any
	-- leftover contact-damage Scripts baked into the source rig asset (toolbox zombie rigs
	-- commonly ship with an uncooled-down Touched->Health handler on the torso, which stacks
	-- with -- and wildly outpaces -- the controlled cooldown-based damage in MycomorphManager).
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CollisionGroup = WILDLING_COLLISION_GROUP
		elseif p:IsA("Script") and p.Name ~= "Animate" then
			p:Destroy()
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
	-- Fully neutralize jumping (not just AutoJumpEnabled) so a Humanoid blocked by another
	-- Wildling's body can never hop up and appear to climb/stand on top of it -- with JumpPower/
	-- JumpHeight zeroed, even a Jump state transition physically can't lift it off the ground.
	humanoid.AutoJumpEnabled = false
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	-- Roblox's own engine-level toggle for the Climbing HumanoidStateType (used for
	-- TrussPart/ladder climbing) -- disabled outright so a Wildling can never enter that state.
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	-- This is the actual cause of "climbing"/step-up: MaxSlopeAngle (default 89) lets a Humanoid
	-- walk straight up anything short of a sheer wall, including another Wildling's rounded
	-- body -- it reads as a steep-but-climbable slope. Capping it low makes any body-height
	-- obstacle (including another zombie) act like an unclimbable wall instead.
	humanoid.MaxSlopeAngle = 5

	if not char.PrimaryPart then
		char.PrimaryPart = char:FindFirstChild("HumanoidRootPart")
	end

	char:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 3, 0)))
	CollectionService:AddTag(char, Tags.Mycomorph)
	char.Parent = Workspace

	addHealthBar(char, humanoid, def.DisplayName)

	return char
end

return MycomorphFactory
