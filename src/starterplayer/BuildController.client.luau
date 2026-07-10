-- StarterPlayerScripts.BuildController
-- The console is now a shop: it only crafts blueprint items for Scrap. Actually building
-- happens by equipping the crafted blueprint Tool (see ReplicatedStorage.Wall/Electric Fence
-- .BlueprintClient) and clicking to place it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local craftItemEvent = Net.event("BuildEvents", "CraftStructureItem")

-- Costs come straight from GameConfig.Structures -- the same table the server charges from,
-- so the displayed price can never drift from the actual cost.
local STRUCTURES = GameConfig.Structures

-- Build menu GUI, opened from the Assembly Console
local playerGui = player:WaitForChild("PlayerGui")
local menuGui = Instance.new("ScreenGui")
menuGui.Name = "BuildMenu"
menuGui.ResetOnSpawn = false
menuGui.Enabled = false
menuGui.Parent = playerGui

local menuFrame = Instance.new("Frame")
menuFrame.Size = UDim2.new(0, 240, 0, 170)
menuFrame.Position = UDim2.new(0.5, -120, 0.5, -85)
menuFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
menuFrame.BackgroundTransparency = 0.1
menuFrame.BorderSizePixel = 0
menuFrame.Parent = menuGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 10)
menuCorner.Parent = menuFrame

local menuTitle = Instance.new("TextLabel")
menuTitle.Size = UDim2.new(1, 0, 0, 30)
menuTitle.Text = "ASSEMBLY CONSOLE"
menuTitle.TextColor3 = Color3.fromRGB(0, 255, 255)
menuTitle.TextSize = 16
menuTitle.Font = Enum.Font.SourceSansBold
menuTitle.BackgroundTransparency = 1
menuTitle.Parent = menuFrame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 16)
subtitle.Position = UDim2.new(0, 0, 0, 28)
subtitle.Text = "Craft blueprints, then equip & place them"
subtitle.TextColor3 = Color3.fromRGB(170, 170, 170)
subtitle.TextSize = 11
subtitle.Font = Enum.Font.SourceSans
subtitle.BackgroundTransparency = 1
subtitle.Parent = menuFrame

local function closeMenu()
	menuGui.Enabled = false
end

local function craftItem(structureType)
	craftItemEvent:FireServer(structureType)
end

local function createCraftButton(structureType, position)
	local cost = STRUCTURES[structureType].Cost
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.9, 0, 0, 40)
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(50, 55, 60)
	button.Text = string.format("Craft %s (%d Scrap)", structureType, cost)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Font = Enum.Font.SourceSansBold
	button.Parent = menuFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

	button.MouseButton1Click:Connect(function()
		craftItem(structureType)
	end)
end

createCraftButton("Wall", UDim2.new(0.05, 0, 0, 48))
createCraftButton("Electric Fence", UDim2.new(0.05, 0, 0, 98))

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0.9, 0, 0, 30)
closeButton.Position = UDim2.new(0.05, 0, 0, 138)
closeButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
closeButton.Text = "Close"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 14
closeButton.Font = Enum.Font.SourceSansBold
closeButton.Parent = menuFrame

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0, 6)
closeButtonCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(closeMenu)

-- Hook the menu up to the Assembly Console's ProximityPrompt (ProximityPrompt.Triggered
-- fires locally for the client that triggered it, so no extra remote plumbing is needed)
local function hookConsole(console)
	local prompt = console:WaitForChild("ProximityPrompt")
	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer == player then
			menuGui.Enabled = not menuGui.Enabled
		end
	end)
end

local existingConsole = Workspace:FindFirstChild("AssemblyConsole")
if existingConsole then
	hookConsole(existingConsole)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "AssemblyConsole" then
		hookConsole(child)
	end
end)
