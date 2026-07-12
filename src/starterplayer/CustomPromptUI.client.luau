-- StarterPlayerScripts.CustomPromptUI
-- Renders our own compact interaction prompt (key badge + action/object text + hold progress)
-- for every ProximityPrompt with Style = Custom, replacing Roblox's oversized default UI.
-- Detection/range/hold/trigger logic still lives entirely on the ProximityPrompt instances
-- themselves (server-created); this script only draws the visuals. Same design language as the
-- inventory UI (CustomHotbar): neutral dark panel, thin borders, one warm amber accent.
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COL_BG = Color3.fromRGB(26, 27, 32)
local COL_BORDER = Color3.fromRGB(42, 44, 50)
local COL_ACCENT = Color3.fromRGB(224, 158, 74)
local COL_TEXT = Color3.fromRGB(222, 224, 229)
local COL_TEXT_DIM = Color3.fromRGB(118, 122, 132)

local TWEEN_IN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CustomPromptUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local activeEntries = {} -- [ProximityPrompt] = { billboard, fill, holdConn }

local function buildBillboard(prompt: ProximityPrompt)
	local adornee = prompt.Parent
	if not adornee or not adornee:IsA("BasePart") then
		return nil
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CustomPrompt"
	billboard.Size = UDim2.new(0, 150, 0, 44)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = adornee
	billboard.Parent = screenGui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = COL_BG
	card.BackgroundTransparency = 1 -- fades in below
	card.BorderSizePixel = 0
	card.Parent = billboard

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "Stroke"
	cardStroke.Color = COL_BORDER
	cardStroke.Thickness = 1
	cardStroke.Transparency = 1 -- fades in below
	cardStroke.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 7)
	padding.PaddingRight = UDim.new(0, 7)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = card

	-- Key badge -- same visual language as an inventory slot: flat bg, thin border, small radius.
	local keyBadge = Instance.new("Frame")
	keyBadge.Name = "KeyBadge"
	keyBadge.Size = UDim2.new(0, 26, 0, 26)
	keyBadge.BackgroundColor3 = Color3.fromRGB(20, 21, 25)
	keyBadge.BorderSizePixel = 0
	keyBadge.ClipsDescendants = true
	keyBadge.Parent = card

	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 6)
	keyCorner.Parent = keyBadge

	local keyStroke = Instance.new("UIStroke")
	keyStroke.Color = COL_BORDER
	keyStroke.Thickness = 1
	keyStroke.Parent = keyBadge

	-- Hold-progress fill, rises from the bottom of the badge in the accent color.
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.new(0, 0, 1, 0)
	fill.Size = UDim2.new(1, 0, 0, 0)
	fill.BackgroundColor3 = COL_ACCENT
	fill.BackgroundTransparency = 0.25
	fill.BorderSizePixel = 0
	fill.Parent = keyBadge

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.Size = UDim2.new(1, 0, 1, 0)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = prompt.KeyboardKeyCode and prompt.KeyboardKeyCode.Name or "E"
	keyLabel.TextColor3 = COL_TEXT
	keyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	keyLabel.TextStrokeTransparency = 0
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextScaled = true
	keyLabel.ZIndex = 2
	keyLabel.Parent = keyBadge

	-- Text column (ActionText on top, ObjectText smaller below)
	local textColumn = Instance.new("Frame")
	textColumn.Name = "TextColumn"
	textColumn.Size = UDim2.new(1, -42, 1, 0)
	textColumn.BackgroundTransparency = 1
	textColumn.Parent = card

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "ActionLabel"
	actionLabel.Size = UDim2.new(1, 0, 0.6, 0)
	actionLabel.BackgroundTransparency = 1
	actionLabel.Text = prompt.ActionText
	actionLabel.TextColor3 = COL_TEXT
	actionLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	actionLabel.TextStrokeTransparency = 0
	actionLabel.Font = Enum.Font.GothamBold
	actionLabel.TextScaled = true
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.Parent = textColumn

	local objectLabel = Instance.new("TextLabel")
	objectLabel.Name = "ObjectLabel"
	objectLabel.Position = UDim2.new(0, 0, 0.6, 0)
	objectLabel.Size = UDim2.new(1, 0, 0.4, 0)
	objectLabel.BackgroundTransparency = 1
	objectLabel.Text = prompt.ObjectText
	objectLabel.TextColor3 = COL_TEXT_DIM
	objectLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	objectLabel.TextStrokeTransparency = 0
	objectLabel.Font = Enum.Font.GothamBold
	objectLabel.TextScaled = true
	objectLabel.TextXAlignment = Enum.TextXAlignment.Left
	objectLabel.Visible = prompt.ObjectText ~= ""
	objectLabel.Parent = textColumn

	-- Fade in rather than popping onscreen instantly.
	TweenService:Create(card, TWEEN_IN, { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(cardStroke, TWEEN_IN, { Transparency = 0 }):Play()

	return billboard, fill
end

local function onPromptShown(prompt: ProximityPrompt)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end

	local billboard, fill = buildBillboard(prompt)
	if not billboard then
		return
	end

	activeEntries[prompt] = { billboard = billboard, fill = fill, holdConn = nil }
end

local function onPromptHidden(prompt: ProximityPrompt)
	local entry = activeEntries[prompt]
	if not entry then
		return
	end
	if entry.holdConn then
		entry.holdConn:Disconnect()
	end
	entry.billboard:Destroy()
	activeEntries[prompt] = nil
end

local function onHoldBegan(prompt: ProximityPrompt)
	local entry = activeEntries[prompt]
	if not entry or prompt.HoldDuration <= 0 then
		return
	end

	local startTime = os.clock()
	entry.holdConn = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - startTime) / prompt.HoldDuration, 0, 1)
		entry.fill.Size = UDim2.new(1, 0, alpha, 0)
	end)
end

local function onHoldEnded(prompt: ProximityPrompt)
	local entry = activeEntries[prompt]
	if not entry then
		return
	end
	if entry.holdConn then
		entry.holdConn:Disconnect()
		entry.holdConn = nil
	end
	entry.fill.Size = UDim2.new(1, 0, 0, 0)
end

ProximityPromptService.PromptShown:Connect(onPromptShown)
ProximityPromptService.PromptHidden:Connect(onPromptHidden)
ProximityPromptService.PromptButtonHoldBegan:Connect(onHoldBegan)
ProximityPromptService.PromptButtonHoldEnded:Connect(onHoldEnded)
ProximityPromptService.PromptTriggered:Connect(onPromptHidden)
