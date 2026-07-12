-- StarterPlayerScripts.VfxController
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local pistolFireEvent = Net.event("CombatEvents", "PistolFire")

local function createBulletTracer(firingPlayer, serverOrigin, targetPos)
	-- Try to get the actual gun barrel position for a more precise origin,
	-- falling back to the serverOrigin (humerus/neck level) if not loaded or far.
	local originPos = serverOrigin
	local char = firingPlayer and firingPlayer.Character
	if char then
		local tool = char:FindFirstChild("Improvised Pistol")
		local handle = tool and tool:FindFirstChild("Handle")
		local shotPart = handle and handle:FindFirstChild("Shot")
		if shotPart then
			originPos = shotPart.Position
		elseif handle then
			originPos = handle.Position
		end
	end

	local distance = (targetPos - originPos).Magnitude
	if distance < 0.1 then return end

	-- Draw a thin Neon cylinder/beam pointing towards target
	local tracer = Instance.new("Part")
	tracer.Name = "BulletTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 220, 80) -- Bright fiery orange/yellow
	tracer.Size = Vector3.new(0.08, 0.08, distance)

	-- Center the part between the muzzle and target, orienting towards target
	tracer.CFrame = CFrame.lookAt(originPos + (targetPos - originPos) / 2, targetPos)
	tracer.Parent = workspace

	-- Tween to fade out the tracer extremely fast (0.12s)
	local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(tracer, tweenInfo, {
		Size = Vector3.new(0, 0, distance), -- shrink width to 0
		Transparency = 1
	})

	tween.Completed:Connect(function()
		tracer:Destroy()
	end)
	tween:Play()
end

pistolFireEvent.OnClientEvent:Connect(createBulletTracer)
