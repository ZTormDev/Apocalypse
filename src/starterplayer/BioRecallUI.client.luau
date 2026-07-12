-- StarterPlayer.StarterPlayerScripts.BioRecallUI
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local triggeredEvent = Net.event("BioRecallEvents", "BioRecallTriggered")
local completeEvent = Net.event("BioRecallEvents", "BioRecallComplete")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BioRecallUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.Visible = false
overlay.Parent = screenGui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0.8, 0, 0.2, 0)
label.Position = UDim2.new(0.1, 0, 0.4, 0)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.fromRGB(0, 255, 150)
label.TextStrokeColor3 = Color3.new(0, 0, 0)
label.TextStrokeTransparency = 1
label.TextTransparency = 1
label.TextScaled = true
label.Text = "BIO-RECALL PROTOCOL ACTIVATED"
label.Parent = overlay

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(0.8, 0, 0.08, 0)
subLabel.Position = UDim2.new(0.1, 0, 0.58, 0)
subLabel.BackgroundTransparency = 1
subLabel.Font = Enum.Font.GothamBold
subLabel.TextColor3 = Color3.fromRGB(150, 255, 220)
subLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
subLabel.TextStrokeTransparency = 1
subLabel.TextTransparency = 1
subLabel.TextScaled = true
subLabel.Text = "Restoring the base to this morning's state..."
subLabel.Parent = overlay

triggeredEvent.OnClientEvent:Connect(function()
	overlay.Visible = true
	TweenService:Create(overlay, TweenInfo.new(0.5), {BackgroundTransparency = 0.35}):Play()
	TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
	TweenService:Create(subLabel, TweenInfo.new(0.5), {TextTransparency = 0.2, TextStrokeTransparency = 0.2}):Play()
end)

completeEvent.OnClientEvent:Connect(function()
	local fadeOut = TweenService:Create(overlay, TweenInfo.new(0.8), {BackgroundTransparency = 1})
	TweenService:Create(label, TweenInfo.new(0.8), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	TweenService:Create(subLabel, TweenInfo.new(0.8), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	fadeOut:Play()
	fadeOut.Completed:Wait()
	overlay.Visible = false
end)
