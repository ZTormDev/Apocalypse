-- StarterPlayerScripts.PlayerSporeFilter
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
player.CharacterAdded:Connect(function(char)
	character = char
end)

local localMask = nil

local function updateLocalGasMask(isOutside)
	if not character then
		return
	end
	if isOutside then
		-- If a gas mask (local or server) already exists in the character, do nothing
		if character:FindFirstChild("GasMask") then
			return
		end

		local maskAsset = ReplicatedStorage:FindFirstChild("GasMask")
		if maskAsset then
			localMask = maskAsset:Clone()
			localMask.Name = "GasMask"
			localMask:SetAttribute("IsLocal", true)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:AddAccessory(localMask)
			end
		end
	else
		if localMask then
			localMask:Destroy()
			localMask = nil
		end
	end
end

local function setupCharacterConnections(char)
	char.ChildAdded:Connect(function(child)
		if child.Name == "GasMask" and not child:GetAttribute("IsLocal") then
			-- The server replicated the real accessory; destroy our local predictive clone
			if localMask then
				localMask:Destroy()
				localMask = nil
			end
		end
	end)
end

if player.Character then
	setupCharacterConnections(player.Character)
end
player.CharacterAdded:Connect(function(char)
	character = char
	setupCharacterConnections(char)
end)

local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")
local purifier = workspace:WaitForChild("Purifier")

-- Visual effect setup
local colorCorrection = Lighting:FindFirstChild("ToxEffect")
if not colorCorrection then
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "ToxEffect"
	colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	colorCorrection.Saturation = 0
	colorCorrection.Contrast = 0
	colorCorrection.Parent = Lighting
end

-- GUI Setup
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:FindFirstChild("SporeTideUI")
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SporeTideUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
end

-- Frame container
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 250, 0, 185)
frame.Position = UDim2.new(0, 20, 0.5, -70)
frame.BackgroundTransparency = 0.5
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- UI Corner for modern feel
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = frame

-- Title Label
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "SPORE TIDE DAWN"
title.TextColor3 = Color3.fromRGB(0, 255, 255)
title.TextSize = 16
title.Font = Enum.Font.SourceSansBold
title.BackgroundTransparency = 1
title.Parent = frame

-- Day and Time info
local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1, 0, 0, 20)
infoText.Position = UDim2.new(0, 0, 0, 30)
infoText.Text = "Day 1 - 06:00"
infoText.TextColor3 = Color3.fromRGB(255, 255, 255)
infoText.TextSize = 14
infoText.Font = Enum.Font.SourceSans
infoText.BackgroundTransparency = 1
infoText.Parent = frame

-- Helper function to make progress bars
local function createProgressBar(name, position, barColor, labelText)
	local container = Instance.new("Frame")
	container.Name = name .. "Container"
	container.Size = UDim2.new(0.9, 0, 0, 20)
	container.Position = position
	container.BackgroundTransparency = 0.7
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	container.BorderSizePixel = 0
	container.Parent = frame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = container

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = barColor
	fill.BorderSizePixel = 0
	fill.Parent = container

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText .. ": 100%"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 11
	label.Font = Enum.Font.SourceSansBold
	label.Parent = container

	return fill, label
end

local maskFill, maskLabel = createProgressBar("Mask", UDim2.new(0.05, 0, 0, 60), Color3.fromRGB(0, 255, 120), "Mask Filter")
local fuelFill, fuelLabel = createProgressBar("Fuel", UDim2.new(0.05, 0, 0, 90), Color3.fromRGB(0, 170, 255), "Dome Fuel")
local healthFill, healthLabel = createProgressBar("Health", UDim2.new(0.05, 0, 0, 120), Color3.fromRGB(255, 60, 60), "Purifier Health")

-- Ammo readout (server-authoritative, replicated via a Player attribute)
local ammoLabel = Instance.new("TextLabel")
ammoLabel.Size = UDim2.new(0.9, 0, 0, 16)
ammoLabel.Position = UDim2.new(0.05, 0, 0, 145)
ammoLabel.BackgroundTransparency = 1
ammoLabel.Text = "Ammo: --"
ammoLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
ammoLabel.TextSize = 12
ammoLabel.Font = Enum.Font.SourceSansBold
ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
ammoLabel.Parent = frame

-- Scrap readout: the count lives on the stacking "Scrap" Tool's Amount attribute
-- (Backpack or equipped in Character), there's no leaderstat/attribute to listen to directly
local scrapLabel = Instance.new("TextLabel")
scrapLabel.Size = UDim2.new(0.9, 0, 0, 16)
scrapLabel.Position = UDim2.new(0.05, 0, 0, 163)
scrapLabel.BackgroundTransparency = 1
scrapLabel.Text = "Scrap: 0"
scrapLabel.TextColor3 = Color3.fromRGB(190, 180, 160)
scrapLabel.TextSize = 12
scrapLabel.Font = Enum.Font.SourceSansBold
scrapLabel.TextXAlignment = Enum.TextXAlignment.Left
scrapLabel.Parent = frame

local function getScrapAmount()
	local backpack = player:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild("Scrap")
	if not tool then
		local char = player.Character
		tool = char and char:FindFirstChild("Scrap")
	end
	return tool and (tool:GetAttribute("Amount") or 0) or 0
end

-- Gameplay values are computed server-side (ReplicatedStorage attribute on the Player);
-- this script predicts them locally for instant visual feedback and smooth UI bar scaling,
-- then reconciles them with incoming server updates.
local predictedOxygen = player:GetAttribute("FilterOxygen") or 100.0

player:GetAttributeChangedSignal("FilterOxygen"):Connect(function()
	local serverOxygen = player:GetAttribute("FilterOxygen") or 100.0
	-- Smoothly reconcile to avoid visible UI jumps, unless the divergence is massive (e.g. respawn/recharge)
	if math.abs(predictedOxygen - serverOxygen) > 10 then
		predictedOxygen = serverOxygen
	else
		predictedOxygen = predictedOxygen * 0.75 + serverOxygen * 0.25
	end
end)

-- Screen tint management (called during render step to align with prediction)
local currentScreenTint = "safe"
local function updateScreenTint(isOutside)
	if isOutside and currentScreenTint ~= "toxic" then
		currentScreenTint = "toxic"
		TweenService:Create(colorCorrection, TweenInfo.new(0.5), {
			TintColor = Color3.fromRGB(150, 220, 150),
			Saturation = -0.4,
			Contrast = 0.1
		}):Play()
	elseif not isOutside and currentScreenTint ~= "safe" then
		currentScreenTint = "safe"
		TweenService:Create(colorCorrection, TweenInfo.new(0.5), {
			TintColor = Color3.fromRGB(255, 255, 255),
			Saturation = 0,
			Contrast = 0
		}):Play()
	end
end

local lastUpdateTime = os.clock()

-- UI Update & Prediction loop
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = now - lastUpdateTime
	lastUpdateTime = now

	-- 1. Predict local oxygen & gas mask & screen tint
	local isOutside = false
	if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") then
		local root = character.HumanoidRootPart
		local humanoid = character.Humanoid

		if humanoid.Health > 0 then
			local distance = (root.Position - purifier.Position).Magnitude
			local domeRadius = stateFolder:GetAttribute("DomeRadius") or 50.0
			isOutside = distance > domeRadius

			-- Predict gas mask equipment
			updateLocalGasMask(isOutside)

			-- Predict screen tint
			updateScreenTint(isOutside)

			-- Predict oxygen consumption
			local drainRate = GameConfig.Oxygen.DrainPerTick / GameConfig.Oxygen.TickInterval
			local rechargeRate = GameConfig.Oxygen.RechargePerTick / GameConfig.Oxygen.TickInterval

			if isOutside then
				predictedOxygen = math.max(0, predictedOxygen - drainRate * dt)
			else
				predictedOxygen = math.min(100, predictedOxygen + rechargeRate * dt)
			end
		end
	end

	-- 2. Update time text
	local timeOfDay = stateFolder:GetAttribute("TimeOfDay") or 6.0
	local dayNum = stateFolder:GetAttribute("DayNumber") or 1
	local hours = math.floor(timeOfDay)
	local minutes = math.floor((timeOfDay - hours) * 60)
	infoText.Text = string.format("Day %d - %02d:%02d", dayNum, hours, minutes)

	-- 3. Update bars
	local fuel = stateFolder:GetAttribute("PurifierFuel") or 100.0
	local maxFuel = stateFolder:GetAttribute("PurifierMaxFuel") or 100.0
	local purifierHealth = stateFolder:GetAttribute("PurifierHealth") or 100.0
	local maxHealth = stateFolder:GetAttribute("PurifierMaxHealth") or 100.0

	local filterPct = math.clamp(predictedOxygen / 100, 0, 1)
	local fuelPct = math.clamp(fuel / maxFuel, 0, 1)
	local healthPct = math.clamp(purifierHealth / maxHealth, 0, 1)

	maskFill.Size = UDim2.new(filterPct, 0, 1, 0)
	maskLabel.Text = string.format("Mask Filter: %d%%", math.round(filterPct * 100))

	fuelFill.Size = UDim2.new(fuelPct, 0, 1, 0)
	fuelLabel.Text = string.format("Purifier Fuel: %d%%", math.round(fuelPct * 100))

	healthFill.Size = UDim2.new(healthPct, 0, 1, 0)
	healthLabel.Text = string.format("Purifier Health: %d%%", math.round(healthPct * 100))

	local ammo = player:GetAttribute("PistolAmmo")
	ammoLabel.Text = "Ammo: " .. (ammo and tostring(ammo) or "--")

	scrapLabel.Text = "Scrap: " .. getScrapAmount()
end)
