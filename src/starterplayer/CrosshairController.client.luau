-- StarterPlayerScripts.CrosshairController
-- Classic minimal shooter crosshair (CS/Valorant-style): four short, thin lines with a gap in
-- the middle, no background/panel/dot -- shown while a weapon (pistol or machete) is equipped.
-- Follows the real mouse cursor -- works in every camera mode, including first person, since
-- Roblox's default camera reports the locked-to-center cursor through the same API.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WEAPON_NAMES = { ["Improvised Pistol"] = true, ["Scrap Machete"] = true }

local LINE_COLOR = Color3.fromRGB(235, 238, 245) -- neutral white, reads over any background
local LINE_LENGTH = 6
local LINE_THICKNESS = 2
local GAP = 5 -- distance from center to the start of each line

local gui = Instance.new("ScreenGui")
gui.Name = "CrosshairGui"
gui.ResetOnSpawn = false
-- IgnoreGuiInset = true: UserInputService:GetMouseLocation() already returns coordinates that
-- include the topbar inset (true screen-space pixels), so the ScreenGui must use the same space
-- or every position renders one inset-height too low.
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Crosshair"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Size = UDim2.new(0, 1, 0, 1)
root.BackgroundTransparency = 1
root.Visible = false
root.Parent = gui

local function line(sizeX, sizeY, posX, posY)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.new(0, sizeX, 0, sizeY)
	f.Position = UDim2.new(0.5, posX, 0.5, posY)
	f.BackgroundColor3 = LINE_COLOR
	f.BorderSizePixel = 0
	f.Parent = root

	-- Thin dark outline so the line stays visible over bright backgrounds too.
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1
	stroke.Transparency = 0.3
	stroke.Parent = f
end

-- Top / bottom / left / right, each offset out from center by GAP + half its own length.
local half = LINE_LENGTH / 2
line(LINE_THICKNESS, LINE_LENGTH, 0, -(GAP + half))
line(LINE_THICKNESS, LINE_LENGTH, 0, GAP + half)
line(LINE_LENGTH, LINE_THICKNESS, -(GAP + half), 0)
line(LINE_LENGTH, LINE_THICKNESS, GAP + half, 0)

local visible = false
local function setVisible(v: boolean)
	if v == visible then
		return
	end
	visible = v
	root.Visible = v
	UserInputService.MouseIconEnabled = not v
end

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local shouldShow = tool ~= nil and WEAPON_NAMES[tool.Name] == true
	setVisible(shouldShow)
	if not shouldShow then
		return
	end

	local pos = UserInputService:GetMouseLocation()
	root.Position = UDim2.new(0, pos.X, 0, pos.Y)
end)
