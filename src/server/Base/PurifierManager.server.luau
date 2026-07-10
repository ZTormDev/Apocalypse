-- ServerScriptService.Base.PurifierManager
-- The base's life-support subsystem: builds the Purifier (invisible anchor + decorative model)
-- and the air dome, runs the fuel/health/dome-radius simulation, absorbs in-range Biomass
-- Catalyst into fuel, and owns the server-authoritative mask-filter oxygen + toxic damage.
-- All tunables come from GameConfig; the live biomass set comes from BiomassRegistry.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local BiomassRegistry = require(Modules:WaitForChild("BiomassRegistry"))

local PC = GameConfig.Purifier
local OX = GameConfig.Oxygen

-- Shared state folder (WorldClock may create it first; find-or-create is safe either way)
local stateFolder = ReplicatedStorage:FindFirstChild("SporeTideState")
if not stateFolder then
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "SporeTideState"
	stateFolder.Parent = ReplicatedStorage
end

-- Purifier-related attributes (time attributes are owned by WorldClock)
stateFolder:SetAttribute("DomeRadius", PC.MaxDomeRadius)
stateFolder:SetAttribute("PurifierFuel", PC.StartFuel)
stateFolder:SetAttribute("PurifierMaxFuel", PC.MaxFuel)
stateFolder:SetAttribute("PurifierHealth", PC.StartHealth)
stateFolder:SetAttribute("PurifierMaxHealth", PC.MaxHealth)

-- Clean up any instances left in the Workspace by a previous run/edit session
for _, name in ipairs({ "DomeVisual", "DomeVisualTop", "DomeVisualBottom", "DomeVisualInner", "Purifier" }) do
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- Purifier: invisible collision/position anchor; the detailed "Power Core" model is the visual
local purifier = Instance.new("Part")
purifier.Name = "Purifier"
purifier.Size = PC.AnchorSize
purifier.Position = PC.Position
purifier.Anchored = true
purifier.Transparency = 1
purifier.Parent = Workspace

local powerCoreTemplate = ReplicatedStorage:FindFirstChild("PurifierModelAsset")
local purifierNeon: BasePart? = nil
if powerCoreTemplate then
	local powerCore = powerCoreTemplate["Power Core"]:Clone()
	powerCore.Name = "Power Core"
	powerCore:PivotTo(CFrame.new(purifier.Position))
	powerCore.Parent = purifier
	local neon = powerCore:FindFirstChild("Neon", true)
	if neon and neon:IsA("BasePart") then
		purifierNeon = neon
	end
end

local purifierAttachment = Instance.new("Attachment")
purifierAttachment.Name = "PurifierAttachment"
purifierAttachment.Parent = purifier

-- Air dome visual (clone the clean MeshPart template, or a fallback ball)
local domeTemplate = ReplicatedStorage:FindFirstChild("SporeDomeMesh")
local domeVisual
if domeTemplate then
	domeVisual = domeTemplate:Clone()
	domeVisual.Name = "DomeVisual"
	local radius = stateFolder:GetAttribute("DomeRadius") or PC.MaxDomeRadius
	domeVisual.Position = Vector3.new(purifier.Position.X, radius / 2, purifier.Position.Z)
	domeVisual.Parent = Workspace
else
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

-- ---------------------------------------------------------------------------------------
-- Oxygen / toxic damage (server-authoritative; the client only reads FilterOxygen for UI)
-- ---------------------------------------------------------------------------------------
local playerFilterOxygen: { [Player]: number } = {}

local function initPlayerOxygen(player: Player)
	playerFilterOxygen[player] = OX.Max
	player:SetAttribute("FilterOxygen", OX.Max)
end

for _, player in ipairs(Players:GetPlayers()) do
	initPlayerOxygen(player)
end
Players.PlayerAdded:Connect(initPlayerOxygen)
Players.PlayerRemoving:Connect(function(player)
	playerFilterOxygen[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(OX.TickInterval)
		if stateFolder:GetAttribute("TimeFrozen") then
			continue
		end
		local domeRadius = stateFolder:GetAttribute("DomeRadius") or PC.MaxDomeRadius

		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChild("Humanoid")

			if root and humanoid and humanoid.Health > 0 then
				local oxygen = playerFilterOxygen[player] or OX.Max
				local distance = (root.Position - purifier.Position).Magnitude

				if distance > domeRadius then
					oxygen = math.max(0, oxygen - OX.DrainPerTick)
					if oxygen <= 0 then
						humanoid:TakeDamage(OX.ToxicDamagePerTick)
					end
				else
					oxygen = math.min(OX.Max, oxygen + OX.RechargePerTick)
				end

				playerFilterOxygen[player] = oxygen
				player:SetAttribute("FilterOxygen", oxygen)
			end
		end
	end
end)

-- ---------------------------------------------------------------------------------------
-- Fuel decay, dome radius, dome visual, and biomass absorption (1s loop)
-- ---------------------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		if stateFolder:GetAttribute("TimeFrozen") then
			continue
		end

		-- Fuel decay
		local fuel = stateFolder:GetAttribute("PurifierFuel")
		if fuel > 0 then
			fuel = math.max(0, fuel - PC.FuelDecayPerSecond)
			stateFolder:SetAttribute("PurifierFuel", fuel)
		end

		-- Dome radius (interpolated toward target based on fuel)
		local currentRadius = stateFolder:GetAttribute("DomeRadius")
		local targetRadius = (fuel > 0) and PC.MaxDomeRadius or PC.MinDomeRadius
		currentRadius = currentRadius + (targetRadius - currentRadius) * PC.DomeLerpAlpha
		stateFolder:SetAttribute("DomeRadius", currentRadius)

		-- Dome visual
		if domeVisual then
			if domeTemplate then
				domeVisual.Size = Vector3.new(currentRadius * 2, currentRadius, currentRadius * 2)
				domeVisual.Position = Vector3.new(purifier.Position.X, currentRadius / 2, purifier.Position.Z)
			else
				domeVisual.Size = Vector3.new(currentRadius * 2, currentRadius * 2, currentRadius * 2)
				domeVisual.Position = purifier.Position
			end
		end

		-- Absorb any Biomass Catalyst inside recharge range into fuel
		for child in pairs(BiomassRegistry.getAll()) do
			local dist = (child.Position - purifier.Position).Magnitude
			if dist <= PC.RechargeRange then
				BiomassRegistry.remove(child)
				local currentFuel = stateFolder:GetAttribute("PurifierFuel")
				local maxFuel = stateFolder:GetAttribute("PurifierMaxFuel")
				stateFolder:SetAttribute("PurifierFuel", math.min(maxFuel, currentFuel + PC.RechargePerCanister))

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
