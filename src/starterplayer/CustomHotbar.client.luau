-- StarterPlayerScripts.CustomHotbar
-- Full inventory UI: a Belt (hotbar, 5 slots, always visible, the only equippable area) and a
-- Backpack (10 slots, toggled with B). Items are partitioned by the server-set "BeltItem" tool
-- attribute. Slots are POSITIONAL: dragging an item onto a slot places it at exactly that slot
-- (swapping if occupied), within an area or across belt <-> backpack. Cross-area moves ask the
-- server (MoveItem / SwapItems) which owns the BeltItem attribute. Plain click on a belt slot
-- equips/unequips; backpack items move only via drag & drop.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local moveItemEvent = Net.event("InventoryEvents", "MoveItem")
local swapItemEvent = Net.event("InventoryEvents", "SwapItems")

local BELT_SIZE = GameConfig.Inventory.BeltSize
local BACKPACK_SIZE = GameConfig.Inventory.BackpackSize

-- ---------------------------------------------------------------------------------------
-- Design tokens -- a single restrained, neutral-dark palette with one warm accent used only
-- for the equipped/hover state, so the UI reads as calm and professional rather than "gamey".
-- ---------------------------------------------------------------------------------------
local SLOT_SIZE = 68
local SLOT_GAP = 10
local SLOT_CORNER = UDim.new(0, 8)
local PANEL_CORNER = UDim.new(0, 12)

local COL_PANEL_BG = Color3.fromRGB(16, 17, 20)
local COL_SLOT_BG = Color3.fromRGB(26, 27, 32)
local COL_SLOT_BG_HOVER = Color3.fromRGB(33, 35, 41)
local COL_BORDER_IDLE = Color3.fromRGB(42, 44, 50)
local COL_BORDER_HOVER = Color3.fromRGB(96, 100, 110)
local COL_ACCENT = Color3.fromRGB(224, 158, 74) -- warm amber; equipped state + branding accents
local COL_TEXT = Color3.fromRGB(222, 224, 229)
local COL_TEXT_DIM = Color3.fromRGB(118, 122, 132)

local DRAG_THRESHOLD = 6

local TWEEN_FAST = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_PANEL = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function formatCount(tool)
	local amount = tool:GetAttribute("Amount")
	if amount and amount > 1 then
		return "x" .. amount
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- Slot construction (shared by belt + backpack)
-- ---------------------------------------------------------------------------------------
local function buildSlot(parent, area, index)
	local slot = Instance.new("Frame")
	slot.Name = area .. "Slot" .. index
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.BackgroundColor3 = COL_SLOT_BG
	slot.BorderSizePixel = 0
	slot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = SLOT_CORNER
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Color = COL_BORDER_IDLE
	stroke.Thickness = 1
	stroke.Parent = slot

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.Size = UDim2.new(0, 18, 0, 14)
	keyLabel.Position = UDim2.new(0, 5, 0, 4)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = area == "belt" and tostring(index) or ""
	keyLabel.TextColor3 = COL_TEXT_DIM
	keyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	keyLabel.TextStrokeTransparency = 0
	keyLabel.TextSize = 11
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.ZIndex = 3
	keyLabel.Parent = slot

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(1, 0, 0, 14)
	countLabel.Position = UDim2.new(0, 0, 1, -19)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = ""
	countLabel.TextColor3 = COL_ACCENT
	countLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	countLabel.TextStrokeTransparency = 0
	countLabel.TextSize = 12
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextXAlignment = Enum.TextXAlignment.Center
	countLabel.ZIndex = 3
	countLabel.Parent = slot

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -8, 1, -32)
	nameLabel.Position = UDim2.new(0, 4, 0, 16)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.TextColor3 = COL_TEXT
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextWrapped = true
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.ZIndex = 3
	nameLabel.Parent = slot

	local nameLabelConstraint = Instance.new("UITextSizeConstraint")
	nameLabelConstraint.MaxTextSize = 12
	nameLabelConstraint.Parent = nameLabel

	-- Thin accent underline, only visible while equipped -- a quieter selection indicator than a
	-- thick glowing border.
	local equippedBar = Instance.new("Frame")
	equippedBar.Name = "EquippedBar"
	equippedBar.AnchorPoint = Vector2.new(0.5, 1)
	equippedBar.Position = UDim2.new(0.5, 0, 1, -3)
	equippedBar.Size = UDim2.new(0, 0, 0, 2)
	equippedBar.BackgroundColor3 = COL_ACCENT
	equippedBar.BorderSizePixel = 0
	equippedBar.Visible = false
	equippedBar.ZIndex = 4
	equippedBar.Parent = slot
	local equippedBarCorner = Instance.new("UICorner")
	equippedBarCorner.CornerRadius = UDim.new(1, 0)
	equippedBarCorner.Parent = equippedBar

	-- Transparent button covering the whole slot, above every child, so hover + input read from
	-- one place (a Frame's MouseEnter/MouseLeave flicker as the cursor crosses child GUI objects).
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Size = UDim2.new(1, 0, 1, 0)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.ZIndex = 5
	hit.Parent = slot

	local entry = {
		Frame = slot, Hit = hit,
		KeyLabel = keyLabel, CountLabel = countLabel, NameLabel = nameLabel, Stroke = stroke,
		EquippedBar = equippedBar,
		Area = area, Index = index, Tool = nil, Hovered = false, Selected = false,
	}

	local function applyVisualState()
		if entry.Selected then
			TweenService:Create(stroke, TWEEN_FAST, { Color = COL_ACCENT, Thickness = 1.5 }):Play()
			TweenService:Create(slot, TWEEN_FAST, { BackgroundColor3 = COL_SLOT_BG_HOVER }):Play()
			equippedBar.Visible = true
			TweenService:Create(equippedBar, TWEEN_FAST, { Size = UDim2.new(0, 22, 0, 2) }):Play()
		elseif entry.Hovered then
			TweenService:Create(stroke, TWEEN_FAST, { Color = COL_BORDER_HOVER, Thickness = 1 }):Play()
			TweenService:Create(slot, TWEEN_FAST, { BackgroundColor3 = COL_SLOT_BG_HOVER }):Play()
			equippedBar.Visible = false
		else
			TweenService:Create(stroke, TWEEN_FAST, { Color = COL_BORDER_IDLE, Thickness = 1 }):Play()
			TweenService:Create(slot, TWEEN_FAST, { BackgroundColor3 = COL_SLOT_BG }):Play()
			equippedBar.Visible = false
		end
	end
	entry.ApplyVisualState = applyVisualState

	hit.MouseEnter:Connect(function()
		entry.Hovered = true
		applyVisualState()
	end)
	hit.MouseLeave:Connect(function()
		entry.Hovered = false
		applyVisualState()
	end)

	return entry
end

-- ---------------------------------------------------------------------------------------
-- Layout: belt (bottom) + backpack (center, toggled)
-- ---------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CustomHotbar"
gui.ResetOnSpawn = false
-- IgnoreGuiInset false so GUI AbsolutePosition and InputObject.Position share one coordinate
-- space; otherwise the drag ghost renders ~36px above the cursor and drops hit-test the wrong slot.
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local function addTopAccent(target, width)
	local accent = Instance.new("Frame")
	accent.Name = "TopAccent"
	accent.AnchorPoint = Vector2.new(0.5, 0)
	accent.Position = UDim2.new(0.5, 0, 0, 0)
	accent.Size = width and UDim2.new(0, width, 0, 2) or UDim2.new(1, 0, 0, 2)
	accent.BackgroundColor3 = COL_ACCENT
	accent.BackgroundTransparency = 0.35
	accent.BorderSizePixel = 0
	accent.ZIndex = 2
	accent.Parent = target
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = accent
	return accent
end

local beltPanel = Instance.new("Frame")
beltPanel.Name = "BeltPanel"
beltPanel.AnchorPoint = Vector2.new(0.5, 1)
beltPanel.Position = UDim2.new(0.5, 0, 1, -18)
beltPanel.Size = UDim2.new(
	0, BELT_SIZE * SLOT_SIZE + (BELT_SIZE - 1) * SLOT_GAP + SLOT_GAP * 2,
	0, SLOT_SIZE + SLOT_GAP * 2
)
beltPanel.BackgroundColor3 = COL_PANEL_BG
beltPanel.BackgroundTransparency = 0.08
beltPanel.BorderSizePixel = 0
beltPanel.ClipsDescendants = true
beltPanel.Parent = gui
local beltPanelCorner = Instance.new("UICorner")
beltPanelCorner.CornerRadius = PANEL_CORNER
beltPanelCorner.Parent = beltPanel
local beltPanelStroke = Instance.new("UIStroke")
beltPanelStroke.Color = COL_BORDER_IDLE
beltPanelStroke.Thickness = 1
beltPanelStroke.Parent = beltPanel
addTopAccent(beltPanel, 48)

local beltFrame = Instance.new("Frame")
beltFrame.AnchorPoint = Vector2.new(0.5, 0.5)
beltFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
beltFrame.Size = UDim2.new(0, BELT_SIZE * SLOT_SIZE + (BELT_SIZE - 1) * SLOT_GAP, 0, SLOT_SIZE)
beltFrame.BackgroundTransparency = 1
beltFrame.Parent = beltPanel
local beltLayout = Instance.new("UIListLayout")
beltLayout.FillDirection = Enum.FillDirection.Horizontal
beltLayout.Padding = UDim.new(0, SLOT_GAP)
beltLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
beltLayout.VerticalAlignment = Enum.VerticalAlignment.Center
beltLayout.SortOrder = Enum.SortOrder.LayoutOrder
beltLayout.Parent = beltFrame

local BP_COLS = 5
local BP_ROWS = math.ceil(BACKPACK_SIZE / BP_COLS)
local HEADER_HEIGHT = 32
local panel = Instance.new("Frame")
panel.Name = "BackpackPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.42, 0)
panel.Size = UDim2.new(
	0, BP_COLS * SLOT_SIZE + (BP_COLS + 1) * SLOT_GAP,
	0, BP_ROWS * SLOT_SIZE + (BP_ROWS + 1) * SLOT_GAP + HEADER_HEIGHT
)
panel.BackgroundColor3 = COL_PANEL_BG
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = PANEL_CORNER
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COL_BORDER_IDLE
panelStroke.Thickness = 1
panelStroke.Parent = panel
local panelTopAccent = addTopAccent(panel)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -24, 0, HEADER_HEIGHT)
title.Position = UDim2.new(0, 14, 0, 2)
title.BackgroundTransparency = 1
title.Text = "BACKPACK"
title.TextColor3 = COL_TEXT
title.TextStrokeColor3 = Color3.new(0, 0, 0)
title.TextStrokeTransparency = 0
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -14, 0, HEADER_HEIGHT)
hint.Position = UDim2.new(0, 0, 0, 2)
hint.BackgroundTransparency = 1
hint.Text = "B"
hint.TextColor3 = COL_TEXT_DIM
hint.TextStrokeColor3 = Color3.new(0, 0, 0)
hint.TextStrokeTransparency = 0
hint.TextSize = 12
hint.Font = Enum.Font.GothamBold
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.Parent = panel

local headerDivider = Instance.new("Frame")
headerDivider.Name = "HeaderDivider"
headerDivider.Position = UDim2.new(0, SLOT_GAP, 0, HEADER_HEIGHT)
headerDivider.Size = UDim2.new(1, -SLOT_GAP * 2, 0, 1)
headerDivider.BackgroundColor3 = COL_BORDER_IDLE
headerDivider.BorderSizePixel = 0
headerDivider.Parent = panel

local grid = Instance.new("Frame")
grid.Name = "Grid"
grid.Position = UDim2.new(0, SLOT_GAP, 0, HEADER_HEIGHT + SLOT_GAP)
grid.Size = UDim2.new(1, -SLOT_GAP * 2, 1, -HEADER_HEIGHT - SLOT_GAP * 2)
grid.BackgroundTransparency = 1
grid.Parent = panel
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
gridLayout.CellPadding = UDim2.new(0, SLOT_GAP, 0, SLOT_GAP)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local beltSlots = {}
for i = 1, BELT_SIZE do
	local e = buildSlot(beltFrame, "belt", i)
	e.Frame.LayoutOrder = i
	beltSlots[i] = e
end
local backpackSlots = {}
for i = 1, BACKPACK_SIZE do
	local e = buildSlot(grid, "backpack", i)
	e.Frame.LayoutOrder = i
	backpackSlots[i] = e
end

-- Smooth open/close for the backpack. CanvasGroup's GroupTransparency doesn't reliably cascade
-- to every descendant (grid-managed slot text stayed opaque), so instead every fadable
-- element's own transparency is tweened in lockstep -- all Tweens share the same TweenInfo and
-- are started in the same frame, so they animate together.
local fadeTargets = {} -- { {inst, prop, base}, ... } -- base = fully-open resting transparency
local function trackFade(inst, prop, base)
	table.insert(fadeTargets, { inst = inst, prop = prop, base = base })
end

trackFade(panel, "BackgroundTransparency", 0.08)
trackFade(panelStroke, "Transparency", 0)
trackFade(panelTopAccent, "BackgroundTransparency", 0.35)
trackFade(title, "TextTransparency", 0)
trackFade(title, "TextStrokeTransparency", 0)
trackFade(hint, "TextTransparency", 0)
trackFade(hint, "TextStrokeTransparency", 0)
trackFade(headerDivider, "BackgroundTransparency", 0)
for _, s in ipairs(backpackSlots) do
	trackFade(s.Frame, "BackgroundTransparency", 0)
	trackFade(s.Stroke, "Transparency", 0)
	trackFade(s.KeyLabel, "TextTransparency", 0)
	trackFade(s.KeyLabel, "TextStrokeTransparency", 0)
	trackFade(s.CountLabel, "TextTransparency", 0)
	trackFade(s.CountLabel, "TextStrokeTransparency", 0)
	trackFade(s.NameLabel, "TextTransparency", 0)
	trackFade(s.NameLabel, "TextStrokeTransparency", 0)
end

-- Start every fadable element fully transparent so the very first open plays a real fade-in
-- instead of a no-op tween (properties were built at their "open" resting values above).
for _, f in ipairs(fadeTargets) do
	f.inst[f.prop] = 1
end

local backpackOpen = false
local function setBackpackOpen(open: boolean)
	if open == backpackOpen then return end
	backpackOpen = open

	if open then
		panel.Visible = true
		panel.Position = UDim2.new(0.5, 0, 0.42, 6)
	end

	local targetPos = open and UDim2.new(0.5, 0, 0.42, 0) or UDim2.new(0.5, 0, 0.42, 6)
	TweenService:Create(panel, TWEEN_PANEL, { Position = targetPos }):Play()

	for _, f in ipairs(fadeTargets) do
		local goal = open and f.base or 1
		TweenService:Create(f.inst, TWEEN_PANEL, { [f.prop] = goal }):Play()
	end

	if not open then
		task.delay(TWEEN_PANEL.Time, function()
			if not backpackOpen then
				panel.Visible = false
			end
		end)
	end
end

-- Fade the belt in once on load rather than popping in instantly.
beltPanel.BackgroundTransparency = 1
beltPanelStroke.Transparency = 1
for _, s in ipairs(beltSlots) do
	s.Frame.BackgroundTransparency = 1
	s.Stroke.Transparency = 1
	s.KeyLabel.TextTransparency = 1
	s.KeyLabel.TextStrokeTransparency = 1
end
TweenService:Create(beltPanel, TWEEN_PANEL, { BackgroundTransparency = 0.08 }):Play()
TweenService:Create(beltPanelStroke, TWEEN_PANEL, { Transparency = 0 }):Play()
for _, s in ipairs(beltSlots) do
	TweenService:Create(s.Frame, TWEEN_PANEL, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(s.Stroke, TWEEN_PANEL, { Transparency = 0 }):Play()
	TweenService:Create(s.KeyLabel, TWEEN_PANEL, { TextTransparency = 0, TextStrokeTransparency = 0 }):Play()
end

-- ---------------------------------------------------------------------------------------
-- Positional inventory state: fixed arrays, one entry per slot (nil = empty).
-- ---------------------------------------------------------------------------------------
local beltItems = {} -- [1..BELT_SIZE]
local backpackItems = {} -- [1..BACKPACK_SIZE]

local function isEquipped(tool)
	local char = player.Character
	return char ~= nil and tool.Parent == char
end

local function isBelt(tool)
	return isEquipped(tool) or tool:GetAttribute("BeltItem") == true or tool:GetAttribute("BeltItem") == nil
end

local function ownedTools()
	local list = {}
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") then table.insert(list, t) end
		end
	end
	local char = player.Character
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") then table.insert(list, t) end
		end
	end
	return list
end

local function firstFree(arr, cap)
	for i = 1, cap do
		if arr[i] == nil then return i end
	end
	return nil
end

-- Keeps every tracked tool in the exact slot the player left it; drops gone tools; places any
-- newly-owned tool (a pickup) into the first free slot of its attribute-decided area.
local function reconcile()
	local owned = ownedTools()
	local ownedSet = {}
	for _, t in ipairs(owned) do ownedSet[t] = true end

	for i = 1, BELT_SIZE do
		if beltItems[i] and not ownedSet[beltItems[i]] then beltItems[i] = nil end
	end
	for i = 1, BACKPACK_SIZE do
		if backpackItems[i] and not ownedSet[backpackItems[i]] then backpackItems[i] = nil end
	end

	local placed = {}
	for i = 1, BELT_SIZE do if beltItems[i] then placed[beltItems[i]] = true end end
	for i = 1, BACKPACK_SIZE do if backpackItems[i] then placed[backpackItems[i]] = true end end

	for _, t in ipairs(owned) do
		if not placed[t] then
			local wantsBelt = isBelt(t)
			local arr = wantsBelt and beltItems or backpackItems
			local cap = wantsBelt and BELT_SIZE or BACKPACK_SIZE
			local slot = firstFree(arr, cap)
			if not slot then -- area full: fall back to the other area
				arr = wantsBelt and backpackItems or beltItems
				cap = wantsBelt and BACKPACK_SIZE or BELT_SIZE
				slot = firstFree(arr, cap)
			end
			if slot then
				arr[slot] = t
				placed[t] = true
			end
		end
	end
end

local function renderArea(slotList, itemsArr)
	for i, slot in ipairs(slotList) do
		local tool = itemsArr[i]
		slot.Tool = tool
		if tool then
			slot.NameLabel.Text = tool.Name
			slot.CountLabel.Text = formatCount(tool) or ""
			slot.Selected = isEquipped(tool)
		else
			slot.NameLabel.Text = ""
			slot.CountLabel.Text = ""
			slot.Selected = false
		end
		slot.ApplyVisualState()
	end
end

local function refresh()
	reconcile()
	renderArea(beltSlots, beltItems)
	renderArea(backpackSlots, backpackItems)
end

local function equipToggle(tool)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if tool.Parent == char then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

-- Optimistically set the attribute (server reconciles) so a cross-area move/swap doesn't flicker.
local function serverMove(tool, toBelt)
	tool:SetAttribute("BeltItem", toBelt)
	moveItemEvent:FireServer(tool, toBelt)
end
local function serverSwap(toolA, toolB, aToBelt, bToBelt)
	toolA:SetAttribute("BeltItem", aToBelt)
	toolB:SetAttribute("BeltItem", bToBelt)
	swapItemEvent:FireServer(toolA, toolB)
end

-- ---------------------------------------------------------------------------------------
-- Drag & drop (positional: place at the exact target slot, swapping if occupied)
-- ---------------------------------------------------------------------------------------
local dragCandidate = nil
local dragging = false
local ghost = nil

local function areaArray(area)
	return area == "belt" and beltItems or backpackItems
end

local function allSlots()
	local list = {}
	for _, s in ipairs(beltSlots) do table.insert(list, s) end
	if panel.Visible then
		for _, s in ipairs(backpackSlots) do table.insert(list, s) end
	end
	return list
end

local function slotUnder(pos)
	for _, s in ipairs(allSlots()) do
		local ap, asz = s.Frame.AbsolutePosition, s.Frame.AbsoluteSize
		if pos.X >= ap.X and pos.X <= ap.X + asz.X and pos.Y >= ap.Y and pos.Y <= ap.Y + asz.Y then
			return s
		end
	end
	return nil
end

local function destroyGhost()
	if ghost then ghost:Destroy() ghost = nil end
end

local function startDrag(slot, mousePos)
	dragging = true
	ghost = Instance.new("Frame")
	ghost.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.BackgroundColor3 = COL_SLOT_BG_HOVER
	ghost.BackgroundTransparency = 0.05
	ghost.ZIndex = 50
	ghost.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
	ghost.Parent = gui
	local gc = Instance.new("UICorner")
	gc.CornerRadius = SLOT_CORNER
	gc.Parent = ghost
	local gs = Instance.new("UIStroke")
	gs.Color = COL_ACCENT
	gs.Thickness = 1.5
	gs.Parent = ghost
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -8, 1, -8)
	nameLabel.Position = UDim2.new(0, 4, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = slot.Tool and slot.Tool.Name or ""
	nameLabel.TextColor3 = COL_TEXT
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextWrapped = true
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.ZIndex = 51
	nameLabel.Parent = ghost

	local nameLabelConstraint = Instance.new("UITextSizeConstraint")
	nameLabelConstraint.MaxTextSize = 12
	nameLabelConstraint.Parent = nameLabel
end

local function handleDrop(sourceSlot, target)
	if not target then return end
	local sTool = sourceSlot.Tool
	if not sTool then return end
	if target.Area == sourceSlot.Area and target.Index == sourceSlot.Index then
		return
	end

	local sArr = areaArray(sourceSlot.Area)
	local tArr = areaArray(target.Area)
	local tTool = tArr[target.Index]

	if target.Area == sourceSlot.Area then
		-- Same area: place at target slot, swap if occupied. No server needed.
		sArr[sourceSlot.Index] = tTool
		tArr[target.Index] = sTool
	else
		-- Cross-area: target empty -> a move; occupied -> a swap (counts stay balanced).
		if tTool == nil then
			sArr[sourceSlot.Index] = nil
			tArr[target.Index] = sTool
			serverMove(sTool, target.Area == "belt")
		else
			sArr[sourceSlot.Index] = tTool
			tArr[target.Index] = sTool
			serverSwap(sTool, tTool, target.Area == "belt", sourceSlot.Area == "belt")
		end
	end
	refresh()
end

for _, slotList in ipairs({ beltSlots, backpackSlots }) do
	for _, slot in ipairs(slotList) do
		slot.Hit.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			if not slot.Tool then return end
			dragCandidate = { Slot = slot, StartPos = input.Position }
		end)
	end
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local pos = input.Position
	if dragging and ghost then
		ghost.Position = UDim2.new(0, pos.X, 0, pos.Y)
	elseif dragCandidate then
		local d = (Vector2.new(pos.X, pos.Y) - Vector2.new(dragCandidate.StartPos.X, dragCandidate.StartPos.Y)).Magnitude
		if d > DRAG_THRESHOLD then
			startDrag(dragCandidate.Slot, pos)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if dragging then
		handleDrop(dragCandidate.Slot, slotUnder(input.Position))
		destroyGhost()
		dragging = false
		dragCandidate = nil
	elseif dragCandidate then
		-- Plain click. Belt: equip/unequip. Backpack: nothing (drag & drop only).
		local slot = dragCandidate.Slot
		dragCandidate = nil
		if slot.Tool and slot.Area == "belt" then
			equipToggle(slot.Tool)
		end
	end
end)

-- ---------------------------------------------------------------------------------------
-- Wiring: refresh on inventory changes, B toggle, number keys
-- ---------------------------------------------------------------------------------------
local function watchContainer(container)
	container.ChildAdded:Connect(refresh)
	container.ChildRemoved:Connect(refresh)
end

watchContainer(player:WaitForChild("Backpack"))
local function onCharacterAdded(char)
	watchContainer(char)
	refresh()
end
if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)
refresh()

task.spawn(function()
	while true do
		task.wait(0.25)
		refresh()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.B then
		setBackpackOpen(not backpackOpen)
		return
	end

	local keyToSlot = {
		[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5,
	}
	local slotIndex = keyToSlot[input.KeyCode]
	if slotIndex and beltItems[slotIndex] then
		equipToggle(beltItems[slotIndex])
	end
end)
