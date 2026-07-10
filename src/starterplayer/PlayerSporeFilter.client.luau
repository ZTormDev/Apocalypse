-- StarterPlayerScripts.PlayerSporeFilter
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
player.CharacterAdded:Connect(function(char)
	character = char
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
-- this script only reads them for the UI and cosmetic effects, it never deals damage itself.
local filterOxygen = player:GetAttribute("FilterOxygen") or 100.0

player:GetAttributeChangedSignal("FilterOxygen"):Connect(function()
	filterOxygen = player:GetAttribute("FilterOxygen") or 100.0
end)

-- Cosmetic-only loop: toggles the toxic screen tint based on dome distance
task.spawn(function()
	while true do
		task.wait(0.5)

		if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") then
			local root = character.HumanoidRootPart
			local humanoid = character.Humanoid

			if humanoid.Health > 0 then
				local distance = (root.Position - purifier.Position).Magnitude
				local domeRadius = stateFolder:GetAttribute("DomeRadius") or 50.0

				if distance > domeRadius then
					TweenService:Create(colorCorrection, TweenInfo.new(0.5), {
						TintColor = Color3.fromRGB(150, 220, 150),
						Saturation = -0.4,
						Contrast = 0.1
					}):Play()
				else
					TweenService:Create(colorCorrection, TweenInfo.new(0.5), {
						TintColor = Color3.fromRGB(255, 255, 255),
						Saturation = 0,
						Contrast = 0
					}):Play()
				end
			end
		end
	end
end)

-- UI Update loop
RunService.RenderStepped:Connect(function()
	-- Update time text
	local timeOfDay = stateFolder:GetAttribute("TimeOfDay") or 6.0
	local dayNum = stateFolder:GetAttribute("DayNumber") or 1
	local hours = math.floor(timeOfDay)
	local minutes = math.floor((timeOfDay - hours) * 60)
	infoText.Text = string.format("Day %d - %02d:%02d", dayNum, hours, minutes)

	-- Update bars
	local fuel = stateFolder:GetAttribute("PurifierFuel") or 100.0
	local maxFuel = stateFolder:GetAttribute("PurifierMaxFuel") or 100.0
	local purifierHealth = stateFolder:GetAttribute("PurifierHealth") or 100.0
	local maxHealth = stateFolder:GetAttribute("PurifierMaxHealth") or 100.0

	local filterPct = math.clamp(filterOxygen / 100, 0, 1)
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
