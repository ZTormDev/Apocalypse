-- Consumable use client. ONE script shared by every consumable Tool (Bandage, Water Bottle, Canned Beans)
-- via a common $path in the Rojo project -- it reads its hold time from GameConfig.Consumables
-- keyed by Tool.Name. Hold left-click for that many seconds to use it; releasing early cancels.
-- A small on-screen progress bar shows the hold; the server (ConsumableManager) applies the
-- actual effect and consumes the tool.
local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local useConsumableEvent = Net.event("SurvivalEvents", "UseConsumable")

local cfg = GameConfig.Consumables[Tool.Name]
local HOLD_TIME = (cfg and cfg.HoldTime) or 3

-- Progress UI (built lazily, reused across uses)
local screenGui, barFill, barLabel
local function ensureUI()
	if screenGui then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ConsumableProgress"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.new(0.5, 0, 0.62, 0)
	container.Size = UDim2.new(0, 220, 0, 24)
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	container.BackgroundTransparency = 0.4
	container.BorderSizePixel = 0
	container.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = container

	barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
	barFill.BorderSizePixel = 0
	barFill.Parent = container
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = barFill

	barLabel = Instance.new("TextLabel")
	barLabel.Size = UDim2.new(1, 0, 1, 0)
	barLabel.BackgroundTransparency = 1
	barLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	barLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	barLabel.TextStrokeTransparency = 0
	barLabel.TextSize = 13
	barLabel.Font = Enum.Font.GothamBold
	barLabel.ZIndex = 2
	barLabel.Parent = container
end

local equipped = false
local holding = false
local holdStart = 0
local fired = false
local renderConn

local function stopHold(completed: boolean?)
	holding = false
	fired = false
	if screenGui then
		screenGui.Enabled = false
	end
	if barFill then
		barFill.Size = UDim2.new(0, 0, 1, 0)
	end
end

local function startHold()
	if holding then
		return
	end
	ensureUI()
	holding = true
	fired = false
	holdStart = os.clock()
	screenGui.Enabled = true
	barLabel.Text = "Using " .. Tool.Name .. "..."
end

local function onRender()
	if not holding or fired then
		return
	end
	local elapsed = os.clock() - holdStart
	local pct = math.clamp(elapsed / HOLD_TIME, 0, 1)
	barFill.Size = UDim2.new(pct, 0, 1, 0)
	if pct >= 1 then
		fired = true
		stopHold(true) -- Pass true since it successfully completed
		useConsumableEvent:FireServer()
	end
end

Tool.Equipped:Connect(function()
	equipped = true
	renderConn = RunService.RenderStepped:Connect(onRender)
end)

Tool.Unequipped:Connect(function()
	equipped = false
	stopHold()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not equipped then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startHold()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		stopHold()
	end
end)
