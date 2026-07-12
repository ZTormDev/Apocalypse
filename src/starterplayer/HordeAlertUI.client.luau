-- StarterPlayerScripts.HordeAlertUI
-- Shows the big cinematic "¡UNA HORDA SE ACERCA!" banner when the server announces a night horde
-- (HordeEvents.HordeWarning). Purely cosmetic: the banner scales + fades in, holds, then fades out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local hordeWarningEvent = Net.event("HordeEvents", "HordeWarning")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "HordeAlertUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Parent = playerGui

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.new(0.5, 0, 0.32, 0)
container.Size = UDim2.new(0, 700, 0, 120)
container.BackgroundTransparency = 1
container.Visible = false
container.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 74)
title.BackgroundTransparency = 1
title.Text = "A HORDE APPROACHES!"
title.TextColor3 = Color3.fromRGB(255, 60, 60)
title.TextStrokeColor3 = Color3.new(0, 0, 0)
title.TextStrokeTransparency = 0
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = container

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.new(0, 0, 0, 78)
subtitle.Size = UDim2.new(1, 0, 0, 30)
subtitle.BackgroundTransparency = 1
subtitle.Text = ""
subtitle.TextColor3 = Color3.fromRGB(235, 210, 210)
subtitle.TextStrokeColor3 = Color3.new(0, 0, 0)
subtitle.TextStrokeTransparency = 0.2
subtitle.Font = Enum.Font.GothamBold
subtitle.TextSize = 22
subtitle.Parent = container

local playing = false

local function setTransparency(t)
	title.TextTransparency = t
	title.TextStrokeTransparency = t
	subtitle.TextTransparency = math.clamp(t + 0.1, 0, 1)
	subtitle.TextStrokeTransparency = math.clamp(t + 0.2, 0, 1)
end

local function announce(message: string?, night: number?, total: number?)
	if playing then
		return
	end
	playing = true

	title.Text = message or "A HORDE APPROACHES!"
	if night then
		subtitle.Text = string.format("Night %d", night)
	else
		subtitle.Text = ""
	end

	-- Reset state: transparent + slightly oversized, then pop in.
	setTransparency(1)
	container.Visible = true
	container.Size = UDim2.new(0, 620, 0, 120)

	local popIn = TweenService:Create(container, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 720, 0, 120),
	})
	popIn:Play()

	-- Fade in
	for i = 0, 1, 0.12 do
		setTransparency(1 - i)
		task.wait(0.02)
	end
	setTransparency(0)

	task.wait(2.2) -- hold

	-- Fade out
	for i = 0, 1, 0.06 do
		setTransparency(i)
		task.wait(0.03)
	end
	setTransparency(1)
	container.Visible = false
	playing = false
end

hordeWarningEvent.OnClientEvent:Connect(function(message, night, total)
	task.spawn(announce, message, night, total)
end)
