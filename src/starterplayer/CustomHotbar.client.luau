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

-- Visual constants
local SLOT_SIZE = 74
local SLOT_GAP = 8
local ACCENT = Color3.fromRGB(0, 235, 255)
local IDLE_STROKE = Color3.fromRGB(70, 78, 92)
local SLOT_BG = Color3.fromRGB(20, 23, 30)
local PANEL_BG = Color3.fromRGB(14, 16, 22)
local DRAG_THRESHOLD = 6

local STRIP_CLASSES = {
	"Script", "LocalScript", "ModuleScript", "Sound", "ProximityPrompt",
	"ParticleEmitter", "PointLight", "SurfaceLight", "SpotLight", "BillboardGui", "Beam",
}

-- ---------------------------------------------------------------------------------------
-- Icon rendering (live 3D render of a tool's Handle in a ViewportFrame)
-- ---------------------------------------------------------------------------------------
local function clearViewport(viewport)
	for _, c in ipairs(viewport:GetChildren()) do
		if c:IsA("BasePart") or c:IsA("Model") then
			c:Destroy()
		end
	end
end

local function renderIcon(viewport, camera, tool)
	clearViewport(viewport)
	if not tool then
		return
	end
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end
	-- Clone the Handle (with any welded child parts) into a Model so the camera can frame the
	-- whole assembly's bounding box -- multi-part items (e.g. the water bottle) would otherwise
	-- be sized only by the Handle part and get cropped.
	local holder = Instance.new("Model")
	local model = handle:Clone()
	model.CanCollide = false
	model.CanTouch = false
	model.CanQuery = false
	model.Parent = holder
	for _, descendant in ipairs(holder:GetDescendants()) do
		for _, className in ipairs(STRIP_CLASSES) do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end
	for _, p in ipairs(holder:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	local cf, size = holder:GetBoundingBox()
	for _, p in ipairs(holder:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CFrame = CFrame.new(-cf.Position) * p.CFrame
		end
	end
	local radius = size.Magnitude / 2
	local distance = radius * 2.2 + 1
	camera.CFrame = CFrame.new(Vector3.new(distance * 0.7, distance * 0.55, distance * 0.7), Vector3.new(0, 0, 0))
	holder.Parent = viewport
end

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
	slot.BackgroundColor3 = SLOT_BG
	slot.BackgroundTransparency = 0.15
	slot.BorderSizePixel = 0
	slot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Color = IDLE_STROKE
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.Parent = slot

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 180, 190))
	gradient.Transparency = NumberSequence.new(0.85, 0.95)
	gradient.Parent = slot

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon"
	viewport.Size = UDim2.new(1, -8, 1, -8)
	viewport.Position = UDim2.new(0, 4, 0, 4)
	viewport.BackgroundTransparency = 1
	viewport.Parent = slot
	local camera = Instance.new("Camera")
	camera.FieldOfView = 28
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.new(0, 16, 0, 16)
	keyLabel.Position = UDim2.new(0, 4, 0, 2)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = area == "belt" and tostring(index) or ""
	keyLabel.TextColor3 = Color3.fromRGB(150, 156, 170)
	keyLabel.TextSize = 12
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.ZIndex = 3
	keyLabel.Parent = slot

	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(1, -6, 0, 16)
	countLabel.Position = UDim2.new(0, 0, 0, 2)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = ""
	countLabel.TextColor3 = ACCENT
	countLabel.TextSize = 13
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 3
	countLabel.Parent = slot

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -4, 0, 16)
	nameLabel.Position = UDim2.new(0, 2, 1, -16)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.TextColor3 = Color3.fromRGB(235, 238, 245)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 3
	nameLabel.Parent = slot

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
		Frame = slot, Viewport = viewport, Camera = camera, Hit = hit,
		KeyLabel = keyLabel, CountLabel = countLabel, NameLabel = nameLabel, Stroke = stroke,
		Area = area, Index = index, Tool = nil, IconTool = nil, Hovered = false, Selected = false,
	}

	hit.MouseEnter:Connect(function()
		entry.Hovered = true
		stroke.Color = ACCENT
	end)
	hit.MouseLeave:Connect(function()
		entry.Hovered = false
		if not entry.Selected then
			stroke.Color = IDLE_STROKE
		end
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

local beltFrame = Instance.new("Frame")
beltFrame.AnchorPoint = Vector2.new(0.5, 1)
beltFrame.Position = UDim2.new(0.5, 0, 1, -18)
beltFrame.Size = UDim2.new(0, BELT_SIZE * SLOT_SIZE + (BELT_SIZE - 1) * SLOT_GAP, 0, SLOT_SIZE)
beltFrame.BackgroundTransparency = 1
beltFrame.Parent = gui
local beltLayout = Instance.new("UIListLayout")
beltLayout.FillDirection = Enum.FillDirection.Horizontal
beltLayout.Padding = UDim.new(0, SLOT_GAP)
beltLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
beltLayout.VerticalAlignment = Enum.VerticalAlignment.Center
beltLayout.SortOrder = Enum.SortOrder.LayoutOrder
beltLayout.Parent = beltFrame

local BP_COLS = 5
local BP_ROWS = math.ceil(BACKPACK_SIZE / BP_COLS)
local panel = Instance.new("Frame")
panel.Name = "BackpackPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.42, 0)
panel.Size = UDim2.new(
	0, BP_COLS * SLOT_SIZE + (BP_COLS + 1) * SLOT_GAP,
	0, BP_ROWS * SLOT_SIZE + (BP_ROWS + 1) * SLOT_GAP + 38
)
panel.BackgroundColor3 = PANEL_BG
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = ACCENT
panelStroke.Thickness = 1.5
panelStroke.Transparency = 0.4
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 34)
title.BackgroundTransparency = 1
title.Text = "MOCHILA"
title.TextColor3 = ACCENT
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.Parent = panel
local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -12, 0, 34)
hint.BackgroundTransparency = 1
hint.Text = "[B]"
hint.TextColor3 = Color3.fromRGB(140, 146, 160)
hint.TextSize = 12
hint.Font = Enum.Font.GothamMedium
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.Parent = panel

local grid = Instance.new("Frame")
grid.Position = UDim2.new(0, SLOT_GAP, 0, 38)
grid.Size = UDim2.new(1, -SLOT_GAP * 2, 1, -38 - SLOT_GAP)
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
			if slot.IconTool ~= tool then
				slot.IconTool = tool
				renderIcon(slot.Viewport, slot.Camera, tool)
			end
			slot.NameLabel.Text = tool.Name
			slot.CountLabel.Text = formatCount(tool) or ""
			local equipped = isEquipped(tool)
			slot.Selected = equipped
			slot.Stroke.Color = (equipped or slot.Hovered) and ACCENT or IDLE_STROKE
			slot.Stroke.Thickness = equipped and 2.5 or 1.5
		else
			if slot.IconTool then
				slot.IconTool = nil
				clearViewport(slot.Viewport)
			end
			slot.NameLabel.Text = ""
			slot.CountLabel.Text = ""
			slot.Selected = false
			slot.Stroke.Color = slot.Hovered and ACCENT or IDLE_STROKE
			slot.Stroke.Thickness = 1.5
		end
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
	ghost.BackgroundColor3 = SLOT_BG
	ghost.BackgroundTransparency = 0.2
	ghost.ZIndex = 50
	ghost.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
	ghost.Parent = gui
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0, 10)
	gc.Parent = ghost
	local gs = Instance.new("UIStroke")
	gs.Color = ACCENT
	gs.Thickness = 2
	gs.Parent = ghost
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(1, -8, 1, -8)
	vp.Position = UDim2.new(0, 4, 0, 4)
	vp.BackgroundTransparency = 1
	vp.ZIndex = 51
	vp.Parent = ghost
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	cam.Parent = vp
	vp.CurrentCamera = cam
	renderIcon(vp, cam, slot.Tool)
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
		panel.Visible = not panel.Visible
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
