-- StarterPlayerScripts.CustomHotbar
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Replace the native backpack/hotbar entirely with our own
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local MAX_SLOTS = 5
local SLOT_SIZE = 90
local SLOT_GAP = 8

local playerGui = player:WaitForChild("PlayerGui")
local hotbarGui = Instance.new("ScreenGui")
hotbarGui.Name = "CustomHotbar"
hotbarGui.ResetOnSpawn = false
hotbarGui.Parent = playerGui

local hotbarFrame = Instance.new("Frame")
hotbarFrame.AnchorPoint = Vector2.new(0.5, 1)
hotbarFrame.Position = UDim2.new(0.5, 0, 1, -20)
hotbarFrame.Size = UDim2.new(0, MAX_SLOTS * SLOT_SIZE + (MAX_SLOTS - 1) * SLOT_GAP, 0, 70)
hotbarFrame.BackgroundTransparency = 1
hotbarFrame.Parent = hotbarGui

local equipToggle -- forward declared; assigned below, used by the slot click handlers

local slots = {} -- [i] = {Frame, KeyLabel, NameLabel, Stroke, Tool}

for i = 1, MAX_SLOTS do
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. i
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, 70)
	slot.Position = UDim2.new(0, (i - 1) * (SLOT_SIZE + SLOT_GAP), 0, 0)
	slot.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	slot.BackgroundTransparency = 0.3
	slot.BorderSizePixel = 0
	slot.Visible = false
	slot.Parent = hotbarFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Name = "SelectedStroke"
	stroke.Color = Color3.fromRGB(0, 255, 255)
	stroke.Thickness = 2
	stroke.Enabled = false
	stroke.Parent = slot

	-- Live 3D render of the equipped Tool's Handle, filling most of the slot
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon"
	viewport.Size = UDim2.new(1, 0, 1, -18) -- leave room for the name strip at the bottom
	viewport.Position = UDim2.new(0, 0, 0, 0)
	viewport.BackgroundTransparency = 1
	viewport.Parent = slot

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.new(1, 0, 0, 16)
	keyLabel.Position = UDim2.new(0, 0, 0, 2)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = tostring(i)
	keyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	keyLabel.TextSize = 12
	keyLabel.Font = Enum.Font.SourceSansBold
	keyLabel.ZIndex = 2
	keyLabel.Parent = slot

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 18)
	nameLabel.Position = UDim2.new(0, 0, 1, -18)
	nameLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.BackgroundTransparency = 0.4
	nameLabel.BorderSizePixel = 0
	nameLabel.Text = ""
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextWrapped = true
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 2
	nameLabel.Parent = slot

	local entry = {
		Frame = slot,
		KeyLabel = keyLabel,
		NameLabel = nameLabel,
		Stroke = stroke,
		Viewport = viewport,
		Camera = camera,
		IconTool = nil, -- the Tool currently rendered in Viewport, if any
		IconModel = nil, -- the cloned Handle currently parented into Viewport
		Tool = nil,
	}
	slots[i] = entry

	slot.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and entry.Tool then
			equipToggle(entry.Tool)
		end
	end)
end

-- Compact ordered list (no gaps) so the visible slots can be packed and centered as a group
-- instead of sitting left-aligned inside a fixed 5-wide container.
local slotOrder = {} -- [1..N] = tool instance, N <= MAX_SLOTS

local function getOwnedTools()
	local list = {}
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then table.insert(list, item) end
		end
	end
	local char = player.Character
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then table.insert(list, item) end
		end
	end
	return list
end

local function formatToolLabel(tool)
	local amount = tool:GetAttribute("Amount")
	if amount and amount > 1 then
		return string.format("%s (X%d)", tool.Name, amount)
	end
	return tool.Name
end

local FRAME_WIDTH = MAX_SLOTS * SLOT_SIZE + (MAX_SLOTS - 1) * SLOT_GAP

-- Instances that could try to run, play, or emit if left inside the isolated Viewport clone.
local STRIP_CLASSES = {
	"Script", "LocalScript", "ModuleScript", "Sound", "ProximityPrompt",
	"ParticleEmitter", "PointLight", "SurfaceLight", "SpotLight", "BillboardGui", "Beam",
}

local function clearSlotIcon(entry)
	if entry.IconModel then
		entry.IconModel:Destroy()
		entry.IconModel = nil
	end
end

-- Clones the Tool's Handle into the slot's ViewportFrame and frames a camera around it, so
-- the hotbar shows a live 3D render of the actual item instead of a generic placeholder.
local function setSlotIcon(entry, tool)
	clearSlotIcon(entry)
	if not tool then
		return
	end

	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	local model = handle:Clone()
	model.Anchored = true
	model.CanCollide = false
	model.CanTouch = false
	model.CanQuery = false
	model.Massless = true
	model.Transparency = 0

	for _, descendant in ipairs(model:GetDescendants()) do
		for _, className in ipairs(STRIP_CLASSES) do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end

	-- Frame the camera around the model's extents, viewed from a fixed 3/4 angle.
	local radius = model.Size.Magnitude / 2
	local distance = radius * 2.2 + 1
	local offset = Vector3.new(distance * 0.7, distance * 0.55, distance * 0.7)
	model.CFrame = CFrame.new(0, 0, 0)
	entry.Camera.CFrame = CFrame.new(offset, Vector3.new(0, 0, 0))

	model.Parent = entry.Viewport
	entry.IconModel = model
end

local function updateSlotsUI()
	local char = player.Character
	local n = #slotOrder
	local totalWidth = n > 0 and (n * SLOT_SIZE + (n - 1) * SLOT_GAP) or 0
	local startX = (FRAME_WIDTH - totalWidth) / 2

	for i = 1, MAX_SLOTS do
		local entry = slots[i]
		local tool = slotOrder[i]
		entry.Tool = tool
		if tool then
			entry.Frame.Position = UDim2.new(0, startX + (i - 1) * (SLOT_SIZE + SLOT_GAP), 0, 0)
			entry.Frame.Visible = true
			entry.KeyLabel.Text = tostring(i)
			entry.NameLabel.Text = formatToolLabel(tool)
			entry.Stroke.Enabled = (char ~= nil and tool.Parent == char)
			if entry.IconTool ~= tool then
				entry.IconTool = tool
				setSlotIcon(entry, tool)
			end
		else
			entry.Frame.Visible = false
			entry.NameLabel.Text = ""
			entry.Stroke.Enabled = false
			if entry.IconTool then
				entry.IconTool = nil
				clearSlotIcon(entry)
			end
		end
	end
end

local function refreshTools()
	local owned = getOwnedTools()
	local ownedSet = {}
	for _, tool in ipairs(owned) do
		ownedSet[tool] = true
	end

	-- Drop tools no longer owned; table.remove shifts later entries down, keeping the list packed
	for i = #slotOrder, 1, -1 do
		if not ownedSet[slotOrder[i]] then
			table.remove(slotOrder, i)
		end
	end

	-- Append newly-owned tools at the end, up to MAX_SLOTS
	for _, tool in ipairs(owned) do
		local tracked = false
		for _, t in ipairs(slotOrder) do
			if t == tool then
				tracked = true
				break
			end
		end
		if not tracked and #slotOrder < MAX_SLOTS then
			table.insert(slotOrder, tool)
		end
	end

	updateSlotsUI()
end

equipToggle = function(tool)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if tool.Parent == char then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

local function watchContainer(container)
	container.ChildAdded:Connect(refreshTools)
	container.ChildRemoved:Connect(refreshTools)
end

watchContainer(player:WaitForChild("Backpack"))

local function onCharacterAdded(char)
	watchContainer(char)
	refreshTools()
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

refreshTools()

-- Polling fallback: re-scan for new/removed tools and refresh quantity labels every tick.
-- Backpack.ChildAdded/ChildRemoved are connected above for instant response when they do
-- fire, but this catches anything they miss (and stack Amount changes, which don't fire
-- ChildAdded/Removed at all since it's the same Tool instance).
task.spawn(function()
	while true do
		task.wait(0.2)
		refreshTools()
	end
end)

-- Number keys 1-5 equip/unequip the corresponding slot, same as the native hotbar used to
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	local keyToSlot = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
	}
	local slotIndex = keyToSlot[input.KeyCode]
	if slotIndex and slotOrder[slotIndex] then
		equipToggle(slotOrder[slotIndex])
	end
end)
