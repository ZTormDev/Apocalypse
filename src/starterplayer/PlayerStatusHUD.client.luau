-- StarterPlayerScripts.PlayerStatusHUD
-- Minimal health + hunger + thirst bars, bottom-left of the screen. Same design language as the
-- rest of the HUD (CustomHotbar/CustomPromptUI): neutral dark panel, thin border, one warm
-- accent. Health reads Humanoid.Health directly (already server-authoritative/replicated);
-- hunger/thirst read the player's "Hunger"/"Thirst" attributes (set by SurvivalService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COL_PANEL_BG = Color3.fromRGB(16, 17, 20)
local COL_BAR_BG = Color3.fromRGB(26, 27, 32)
local COL_BORDER = Color3.fromRGB(42, 44, 50)
local COL_ACCENT = Color3.fromRGB(224, 158, 74)
local COL_HEALTH = Color3.fromRGB(196, 84, 84)
local COL_HUNGER = Color3.fromRGB(224, 158, 74)
local COL_THIRST = Color3.fromRGB(80, 160, 230)
local COL_FILTER = Color3.fromRGB(120, 220, 200)
local COL_TEXT = Color3.fromRGB(222, 224, 229)
local COL_TEXT_DIM = Color3.fromRGB(118, 122, 132)

local PANEL_WIDTH = 250
local BAR_HEIGHT = 20
local BAR_GAP = 10
local PADDING = 14

local TWEEN_FILL = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerStatusHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "StatusPanel"
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 16, 1, -18)
panel.Size = UDim2.new(0, PANEL_WIDTH, 0, PADDING * 2 + BAR_HEIGHT * 3 + BAR_GAP * 2)
panel.BackgroundColor3 = COL_PANEL_BG
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COL_BORDER
panelStroke.Thickness = 1
panelStroke.Parent = panel

local topAccent = Instance.new("Frame")
topAccent.Name = "TopAccent"
topAccent.AnchorPoint = Vector2.new(0.5, 0)
topAccent.Position = UDim2.new(0.5, 0, 0, 0)
topAccent.Size = UDim2.new(0, 56, 0, 2)
topAccent.BackgroundColor3 = COL_ACCENT
topAccent.BackgroundTransparency = 0.35
topAccent.BorderSizePixel = 0
topAccent.ZIndex = 2
topAccent.Parent = panel
local topAccentCorner = Instance.new("UICorner")
topAccentCorner.CornerRadius = UDim.new(1, 0)
topAccentCorner.Parent = topAccent

local function buildBar(parent: Frame, labelText: string, barColor: Color3, order: number)
	local row = Instance.new("Frame")
	row.Name = labelText .. "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -PADDING * 2, 0, BAR_HEIGHT)
	row.Position = UDim2.new(0, PADDING, 0, PADDING + (order - 1) * (BAR_HEIGHT + BAR_GAP))
	row.Parent = parent

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = COL_BAR_BG
	bg.BorderSizePixel = 0
	bg.Parent = row

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 5)
	bgCorner.Parent = bg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = COL_BORDER
	bgStroke.Thickness = 1
	bgStroke.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = barColor
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -10, 1, 0)
	label.Position = UDim2.new(0, 5, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = COL_TEXT
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextSize = 13
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 3
	label.Parent = bg

	local pctLabel = Instance.new("TextLabel")
	pctLabel.Name = "Pct"
	pctLabel.Size = UDim2.new(1, -10, 1, 0)
	pctLabel.BackgroundTransparency = 1
	pctLabel.Text = "100%"
	pctLabel.TextColor3 = COL_TEXT
	pctLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	pctLabel.TextStrokeTransparency = 0.3
	pctLabel.TextSize = 13
	pctLabel.Font = Enum.Font.GothamBold
	pctLabel.TextXAlignment = Enum.TextXAlignment.Right
	pctLabel.ZIndex = 3
	pctLabel.Parent = bg

	return fill, pctLabel
end

local healthFill, healthPct = buildBar(panel, "HEALTH", COL_HEALTH, 1)
local hungerFill, hungerPct = buildBar(panel, "HUNGER", COL_HUNGER, 2)
local thirstFill, thirstPct = buildBar(panel, "THIRST", COL_THIRST, 3)

-- Mask filter: a separate small panel above the main stats, only shown while outside the dome
-- (IsOutsideDome attribute, set by PurifierManager) -- irrelevant/noise while safe inside.
local filterPanel = Instance.new("Frame")
filterPanel.Name = "FilterPanel"
filterPanel.AnchorPoint = Vector2.new(0, 1)
filterPanel.Position = UDim2.new(0, 16, 1, -18 - (PADDING * 2 + BAR_HEIGHT * 3 + BAR_GAP * 2) - 10)
filterPanel.Size = UDim2.new(0, PANEL_WIDTH, 0, PADDING * 2 + BAR_HEIGHT)
filterPanel.BackgroundColor3 = COL_PANEL_BG
filterPanel.BackgroundTransparency = 0.08
filterPanel.BorderSizePixel = 0
filterPanel.Visible = false
filterPanel.Parent = screenGui

local filterPanelCorner = Instance.new("UICorner")
filterPanelCorner.CornerRadius = UDim.new(0, 12)
filterPanelCorner.Parent = filterPanel

local filterPanelStroke = Instance.new("UIStroke")
filterPanelStroke.Color = COL_BORDER
filterPanelStroke.Thickness = 1
filterPanelStroke.Parent = filterPanel

local filterTopAccent = Instance.new("Frame")
filterTopAccent.Name = "TopAccent"
filterTopAccent.AnchorPoint = Vector2.new(0.5, 0)
filterTopAccent.Position = UDim2.new(0.5, 0, 0, 0)
filterTopAccent.Size = UDim2.new(0, 56, 0, 2)
filterTopAccent.BackgroundColor3 = COL_FILTER
filterTopAccent.BackgroundTransparency = 0.35
filterTopAccent.BorderSizePixel = 0
filterTopAccent.ZIndex = 2
filterTopAccent.Parent = filterPanel
local filterTopAccentCorner = Instance.new("UICorner")
filterTopAccentCorner.CornerRadius = UDim.new(1, 0)
filterTopAccentCorner.Parent = filterTopAccent

local filterFill, filterPct = buildBar(filterPanel, "FILTER", COL_FILTER, 1)

local SV = GameConfig.Survival

local function setBar(fill: Frame, pctLabel: TextLabel, pct: number)
	pct = math.clamp(pct, 0, 1)
	TweenService:Create(fill, TWEEN_FILL, { Size = UDim2.new(pct, 0, 1, 0) }):Play()
	pctLabel.Text = math.round(pct * 100) .. "%"
end

local function updateHunger()
	local hunger = player:GetAttribute("Hunger") or SV.MaxHunger
	setBar(hungerFill, hungerPct, hunger / SV.MaxHunger)
end
player:GetAttributeChangedSignal("Hunger"):Connect(updateHunger)
updateHunger()

local function updateThirst()
	local thirst = player:GetAttribute("Thirst") or SV.MaxThirst
	setBar(thirstFill, thirstPct, thirst / SV.MaxThirst)
end
player:GetAttributeChangedSignal("Thirst"):Connect(updateThirst)
updateThirst()

local OX = GameConfig.Oxygen

local function updateFilter()
	filterPanel.Visible = player:GetAttribute("IsOutsideDome") == true
	local oxygen = player:GetAttribute("FilterOxygen") or OX.Max
	setBar(filterFill, filterPct, oxygen / OX.Max)
end
player:GetAttributeChangedSignal("FilterOxygen"):Connect(updateFilter)
player:GetAttributeChangedSignal("IsOutsideDome"):Connect(updateFilter)
updateFilter()

local function hookHumanoid(char: Model)
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid

	local function updateHealth()
		setBar(healthFill, healthPct, humanoid.Health / humanoid.MaxHealth)
	end

	humanoid.HealthChanged:Connect(updateHealth)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)
	updateHealth()
end

if player.Character then
	hookHumanoid(player.Character)
end
player.CharacterAdded:Connect(hookHumanoid)
