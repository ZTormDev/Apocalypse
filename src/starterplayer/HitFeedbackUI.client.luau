-- StarterPlayerScripts.HitFeedbackUI
-- Draws the "hitmarker" wherever a weapon actually lands a hit on a zombie: a burst of blood
-- particles at the hit position, plus a floating number showing the damage dealt. Headshots
-- (pistol only) get a bigger blood burst and a yellow number instead of white. Purely cosmetic
-- and purely client-local -- no pooling/race-condition concerns since each client creates and
-- emits its own instances after receiving the event, nothing is replicated further.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local hitFeedbackEvent = Net.event("CombatEvents", "HitFeedback")

local function spawnBlood(position: Vector3, isHeadshot: boolean)
	local anchor = Instance.new("Part")
	anchor.Name = "BloodHit"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 15, 15), Color3.fromRGB(90, 5, 5))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, isHeadshot and 0.55 or 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Transparency = NumberSequence.new(0, 0.4)
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Speed = NumberRange.new(6, isHeadshot and 20 or 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(isHeadshot and 30 or 12)

	Debris:AddItem(anchor, 2)
end

local function spawnDamageNumber(position: Vector3, damage: number, isHeadshot: boolean)
	local jitter = Vector3.new((math.random() - 0.5) * 1.5, math.random() * 0.5, (math.random() - 0.5) * 1.5)

	local bb = Instance.new("BillboardGui")
	bb.Name = "DamageNumber"
	bb.Size = UDim2.new(0, 100, 0, 40)
	bb.StudsOffset = Vector3.new(0, 1.5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 150
	bb.Adornee = nil
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.CFrame = CFrame.new(position + jitter)
	holder.Parent = Workspace
	bb.Adornee = holder
	bb.Parent = holder

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = tostring(math.floor(damage))
	label.Font = isHeadshot and Enum.Font.GothamBlack or Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = isHeadshot and Color3.fromRGB(255, 225, 60) or Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Parent = bb

	-- Float up and fade out.
	local riseGoal = { StudsOffset = bb.StudsOffset + Vector3.new(0, 2.2, 0) }
	TweenService:Create(bb, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), riseGoal):Play()
	task.delay(0.35, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)

	Debris:AddItem(holder, 1)
end

hitFeedbackEvent.OnClientEvent:Connect(function(position, damage, isHeadshot)
	if typeof(position) ~= "Vector3" or typeof(damage) ~= "number" then
		return
	end
	isHeadshot = isHeadshot == true
	spawnBlood(position, isHeadshot)
	spawnDamageNumber(position, damage, isHeadshot)
end)
