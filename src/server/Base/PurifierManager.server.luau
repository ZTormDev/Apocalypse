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
local ModelBounds = require(Shared:WaitForChild("ModelBounds"))

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
stateFolder:SetAttribute("PurifierLevel", 1)
stateFolder:SetAttribute("PurifierMaxDomeRadius", PC.MaxDomeRadius)

local function maxFuelForLevel(level: number): number
	return PC.MaxFuel + (level - 1) * PC.FuelCapacityPerLevel
end

local function maxDomeRadiusForLevel(level: number): number
	return PC.MaxDomeRadius + (level - 1) * PC.DomeRadiusPerLevel
end

-- Deposits `amount` fuel into the Purifier. If it overflows the current level's capacity, the
-- Purifier levels up -- raising both fuel capacity and the max dome radius -- and the leftover
-- fuel carries over into the new capacity (looping if one big deposit spans multiple levels).
-- Shared by every fueling path (the interaction prompt below, and passive in-range absorption)
-- so leveling behaves consistently no matter how the fuel was delivered.
local function addFuel(amount: number)
	if amount <= 0 then
		return
	end

	local level = stateFolder:GetAttribute("PurifierLevel") or 1
	local maxFuel = maxFuelForLevel(level)
	local fuel = (stateFolder:GetAttribute("PurifierFuel") or 0) + amount

	while fuel > maxFuel and level < PC.MaxLevel do
		fuel -= maxFuel
		level += 1
		maxFuel = maxFuelForLevel(level)
		print("Purifier leveled up to level " .. level .. "!")
	end
	fuel = math.min(fuel, maxFuel)

	stateFolder:SetAttribute("PurifierLevel", level)
	stateFolder:SetAttribute("PurifierMaxFuel", maxFuel)
	stateFolder:SetAttribute("PurifierFuel", fuel)
	stateFolder:SetAttribute("PurifierMaxDomeRadius", maxDomeRadiusForLevel(level))
end

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
local promptCenterY = PC.Position.Y -- overwritten below once the model's real AABB is known
if powerCoreTemplate then
	local powerCore = powerCoreTemplate["Power Core"]:Clone()
	powerCore.Name = "Power Core"
	powerCore:ScaleTo(0.7)
	powerCore:PivotTo(CFrame.new(purifier.Position))
	powerCore.Parent = purifier

	-- ScaleTo shrinks the model around its own pivot (its vertical center), not its visual base,
	-- so after scaling down the model floats above the floor. Re-anchor it using its true AABB so
	-- the bottom lands exactly on the floor (the bottom of the invisible anchor part).
	local aabbCenter, aabbSize = ModelBounds.getAABB(powerCore)
	local floorY = purifier.Position.Y - PC.AnchorSize.Y / 2
	local modelBottomY = aabbCenter.Y - aabbSize.Y / 2
	local correction = floorY - modelBottomY
	if math.abs(correction) > 0.001 then
		powerCore:PivotTo(powerCore:GetPivot() + Vector3.new(0, correction, 0))
	end

	-- Shrink the invisible collision box to match the model's real (post-scale) footprint instead
	-- of the old fixed AnchorSize, which was sized for the original, larger model and now reads
	-- as an oversized invisible wall around it. Keep its bottom pinned to the same floor level.
	local finalCenter, finalSize = ModelBounds.getAABB(powerCore)
	purifier.Size = finalSize
	purifier.Position = Vector3.new(PC.Position.X, floorY + finalSize.Y / 2, PC.Position.Z)
	promptCenterY = finalCenter.Y

	local neon = powerCore:FindFirstChild("Neon", true)
	if neon and neon:IsA("BasePart") then
		purifierNeon = neon
	end
end

local purifierAttachment = Instance.new("Attachment")
purifierAttachment.Name = "PurifierAttachment"
purifierAttachment.Parent = purifier

local function flashNeon()
	if not purifierNeon then
		return
	end
	task.spawn(function()
		local original = purifierNeon.Color
		purifierNeon.Color = Color3.fromRGB(0, 255, 150)
		task.wait(0.5)
		purifierNeon.Color = original
	end)
end

-- Interaction-based fueling: approach the Purifier carrying "Biomass Fuel" tools and press E to
-- deposit ALL of them at once. This is the primary way fuel gets loaded now that biomass is
-- collected into inventory first (see BiomassFactory's own pickup prompt).
-- Parented to a small dedicated anchor (not the tall collision box) positioned at the model's
-- real vertical center, minus the CustomPromptUI script's fixed +2 stud badge offset, so the
-- prompt visually lands centered on the model instead of floating near its top.
local promptAnchor = Instance.new("Part")
promptAnchor.Name = "LoadFuelPromptAnchor"
promptAnchor.Size = Vector3.new(1, 1, 1)
promptAnchor.Position = Vector3.new(PC.Position.X, promptCenterY - 2, PC.Position.Z)
promptAnchor.Anchored = true
promptAnchor.CanCollide = false
promptAnchor.CanTouch = false
promptAnchor.CanQuery = false
promptAnchor.Transparency = 1
promptAnchor.Parent = purifier

local function getBiomassTools(player: Player): { Tool }
	local canisters = {}
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == "Biomass Fuel" then
				table.insert(canisters, tool)
			end
		end
	end
	local char = player.Character
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == "Biomass Fuel" then
				table.insert(canisters, tool)
			end
		end
	end
	return canisters
end

local loadFuelPrompt = Instance.new("ProximityPrompt")
loadFuelPrompt.Name = "LoadFuelPrompt"
loadFuelPrompt.Style = Enum.ProximityPromptStyle.Custom
loadFuelPrompt.ActionText = "Load Fuel"
loadFuelPrompt.ObjectText = "Purifier"
loadFuelPrompt.HoldDuration = PC.LoadFuelHoldDuration
loadFuelPrompt.MaxActivationDistance = PC.LoadFuelActivationDistance
-- The anchor sits inside the Purifier's own collision box (for centering), so the default
-- line-of-sight raycast would hit that box's near wall and hide the prompt. Not needed for a
-- fixed, always-visible base structure.
loadFuelPrompt.RequiresLineOfSight = false
loadFuelPrompt.Enabled = false -- only enabled while a nearby player is actually carrying fuel
loadFuelPrompt.Parent = promptAnchor

loadFuelPrompt.Triggered:Connect(function(triggeringPlayer: Player)
	local canisters = getBiomassTools(triggeringPlayer)
	if #canisters == 0 then
		return
	end

	for _, tool in ipairs(canisters) do
		tool:Destroy()
	end

	addFuel(#canisters * PC.RechargePerCanister)
	flashNeon()
	print(triggeringPlayer.Name .. " loaded " .. #canisters .. " biomass canister(s) into the Purifier.")
end)

-- The prompt is only useful if the player actually has fuel to deposit, so only enable it while
-- a player within activation range is carrying at least one Biomass Fuel canister.
task.spawn(function()
	while true do
		task.wait(0.5)
		local shouldShow = false
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local dist = (root.Position - promptAnchor.Position).Magnitude
				if dist <= PC.LoadFuelActivationDistance and #getBiomassTools(plr) > 0 then
					shouldShow = true
					break
				end
			end
		end
		loadFuelPrompt.Enabled = shouldShow
	end
end)

-- Fuel level indicator: a billboard progress bar centered above the Purifier's true visual AABB
-- (the "Power Core" model, not the invisible anchor part), same minimalist HUD style as the
-- inventory/prompt UI. Rises/falls as the base is fed fuel (Biomass Catalyst) or it decays.
-- Shows the current level and the fuel amount (current/max) so leveling progress is legible.
do
	local fuelBillboard = Instance.new("BillboardGui")
	fuelBillboard.Name = "FuelGui"
	fuelBillboard.Size = UDim2.new(0, 260, 0, 50)
	fuelBillboard.StudsOffsetWorldSpace = ModelBounds.getTopCenter(purifier, 1.4) - purifier.Position
	fuelBillboard.MaxDistance = 45
	fuelBillboard.AlwaysOnTop = true
	fuelBillboard.Adornee = purifier
	fuelBillboard.Parent = purifier

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, 0, 0, 21)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "LEVEL 1"
	levelLabel.TextColor3 = Color3.fromRGB(222, 224, 229)
	levelLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	levelLabel.TextStrokeTransparency = 0
	levelLabel.TextSize = 20
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Parent = fuelBillboard

	local fuelBg = Instance.new("Frame")
	fuelBg.Name = "Bg"
	fuelBg.AnchorPoint = Vector2.new(0.5, 0)
	fuelBg.Position = UDim2.new(0.5, 0, 0, 27)
	fuelBg.Size = UDim2.new(0.7, 0, 0, 16)
	fuelBg.BackgroundColor3 = Color3.fromRGB(26, 27, 32)
	fuelBg.BackgroundTransparency = 0.1
	fuelBg.BorderSizePixel = 0
	fuelBg.Parent = fuelBillboard

	local fuelBgCorner = Instance.new("UICorner")
	fuelBgCorner.CornerRadius = UDim.new(0, 5)
	fuelBgCorner.Parent = fuelBg

	local fuelBgStroke = Instance.new("UIStroke")
	fuelBgStroke.Color = Color3.fromRGB(42, 44, 50)
	fuelBgStroke.Thickness = 1
	fuelBgStroke.Parent = fuelBg

	local fuelFill = Instance.new("Frame")
	fuelFill.Name = "Fill"
	fuelFill.Size = UDim2.new(0, 0, 1, 0)
	fuelFill.BackgroundColor3 = Color3.fromRGB(160, 90, 230) -- purple
	fuelFill.BorderSizePixel = 0
	fuelFill.Parent = fuelBg

	local fuelFillCorner = Instance.new("UICorner")
	fuelFillCorner.CornerRadius = UDim.new(0, 5)
	fuelFillCorner.Parent = fuelFill

	local fuelAmountLabel = Instance.new("TextLabel")
	fuelAmountLabel.Name = "AmountLabel"
	fuelAmountLabel.Size = UDim2.new(1, -6, 1, 0)
	fuelAmountLabel.BackgroundTransparency = 1
	fuelAmountLabel.Text = ""
	fuelAmountLabel.TextColor3 = Color3.fromRGB(222, 224, 229)
	fuelAmountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	fuelAmountLabel.TextStrokeTransparency = 0
	fuelAmountLabel.TextSize = 13
	fuelAmountLabel.Font = Enum.Font.GothamBold
	fuelAmountLabel.TextXAlignment = Enum.TextXAlignment.Right
	fuelAmountLabel.ZIndex = 2
	fuelAmountLabel.Parent = fuelBg

	local function updateFuelBar()
		local fuel = stateFolder:GetAttribute("PurifierFuel") or 0
		local maxFuel = stateFolder:GetAttribute("PurifierMaxFuel") or 1
		local level = stateFolder:GetAttribute("PurifierLevel") or 1
		fuelFill.Size = UDim2.new(math.clamp(fuel / maxFuel, 0, 1), 0, 1, 0)
		fuelAmountLabel.Text = math.floor(fuel) .. " / " .. math.floor(maxFuel)
		levelLabel.Text = "LEVEL " .. level
	end
	stateFolder:GetAttributeChangedSignal("PurifierFuel"):Connect(updateFuelBar)
	stateFolder:GetAttributeChangedSignal("PurifierMaxFuel"):Connect(updateFuelBar)
	stateFolder:GetAttributeChangedSignal("PurifierLevel"):Connect(updateFuelBar)
	updateFuelBar()
end

-- Constant ambient energy particles so the Purifier reads as "alive" at all times, not
-- just when actively recharging. Emitted from the CENTER of the anchor and pushed outward
-- in every direction (full sphere, not a narrow upward cone) so it reads as an energy field
-- expanding from the core rather than motes rising from one spot.
-- No custom Texture: the engine's built-in default particle renders reliably everywhere.
local ambientAttachment = Instance.new("Attachment")
ambientAttachment.Name = "PurifierAmbientAttachment"
ambientAttachment.Parent = purifier

local ambientEmitter = Instance.new("ParticleEmitter")
ambientEmitter.Name = "PurifierAmbient"
ambientEmitter.Color = ColorSequence.new(Color3.fromRGB(0, 255, 200))
ambientEmitter.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.9),
	NumberSequenceKeypoint.new(1, 0.1),
})
ambientEmitter.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.1),
	NumberSequenceKeypoint.new(1, 1),
})
ambientEmitter.Lifetime = NumberRange.new(1.5, 2.5)
ambientEmitter.Speed = NumberRange.new(4, 9)
ambientEmitter.SpreadAngle = Vector2.new(180, 180) -- full sphere outward, not just up
ambientEmitter.Rate = 20
ambientEmitter.Enabled = true
ambientEmitter.Parent = ambientAttachment

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
local playerWasOutside: { [Player]: boolean } = {} -- tracks the dome-boundary crossing, not just current state

local function initPlayerOxygen(player: Player)
	playerFilterOxygen[player] = OX.Max
	playerWasOutside[player] = false
	player:SetAttribute("FilterOxygen", OX.Max)
	player:SetAttribute("IsOutsideDome", false)
end

for _, player in ipairs(Players:GetPlayers()) do
	initPlayerOxygen(player)
end
Players.PlayerAdded:Connect(initPlayerOxygen)
Players.PlayerRemoving:Connect(function(player)
	playerFilterOxygen[player] = nil
	playerWasOutside[player] = nil
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
				local isOutside = distance > domeRadius

				if isOutside then
					-- Every fresh exit gets a full tank, rather than continuing from wherever the
					-- filter was left off (e.g. topped up mid-drain by briefly stepping back in).
					if not playerWasOutside[player] then
						oxygen = OX.Max
					end

					oxygen = math.max(0, oxygen - OX.DrainPerTick)
					if oxygen <= 0 then
						humanoid:TakeDamage(OX.ToxicDamagePerTick)
					end

					-- Equip gas mask if not already wearing it
					if not char:FindFirstChild("GasMask") then
						local maskAsset = ReplicatedStorage:FindFirstChild("GasMask")
						if maskAsset then
							local maskClone = maskAsset:Clone()
							maskClone.Name = "GasMask"
							humanoid:AddAccessory(maskClone)
						end
					end
				else
					oxygen = math.min(OX.Max, oxygen + OX.RechargePerTick)

					-- Remove gas mask if wearing it
					local mask = char:FindFirstChild("GasMask")
					if mask then
						mask:Destroy()
					end
				end

				playerWasOutside[player] = isOutside
				playerFilterOxygen[player] = oxygen
				player:SetAttribute("FilterOxygen", oxygen)
				player:SetAttribute("IsOutsideDome", isOutside)
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

		-- Dome radius (interpolated toward target based on fuel, capped by the current level)
		local currentRadius = stateFolder:GetAttribute("DomeRadius")
		local maxDomeRadius = stateFolder:GetAttribute("PurifierMaxDomeRadius") or PC.MaxDomeRadius
		local targetRadius = (fuel > 0) and maxDomeRadius or PC.MinDomeRadius
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

		-- Absorb any dropped Biomass Catalyst inside recharge range into fuel (e.g. a canister
		-- thrown with G that lands near the base) -- same addFuel/leveling path as the prompt.
		for child in pairs(BiomassRegistry.getAll()) do
			local dist = (child.Position - purifier.Position).Magnitude
			if dist <= PC.RechargeRange then
				BiomassRegistry.remove(child)
				addFuel(PC.RechargePerCanister)
				flashNeon()
				print("Purifier recharged with biomass absorbed in range.")
			end
		end
	end
end)
