-- StarterPlayerScripts.VfxController
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local AudioManager = require(Shared:WaitForChild("AudioManager"))

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

	-- Play gunshot sound locally for third-person shooters (local shooter already fired it instantly)
	if firingPlayer ~= player then
		-- Attach sound to a temporary part at originPos so it plays in 3D space
		local soundAnchor = Instance.new("Attachment")
		soundAnchor.Name = "GunshotAudioAnchor"
		soundAnchor.WorldPosition = originPos
		soundAnchor.Parent = workspace.Terrain
		
		AudioManager.play("PistolFire", soundAnchor)
		
		-- Destroy anchor after sound plays
		game:GetService("Debris"):AddItem(soundAnchor, 3.0)
	end

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

local macheteAttackEvent = Net.event("CombatEvents", "MacheteAttack")

local function replicateMacheteHit(attackerPlayer, target, isScrap)
	if attackerPlayer == player then
		return -- The attacking player already heard it instantly
	end

	local char = attackerPlayer and attackerPlayer.Character
	local machete = char and char:FindFirstChild("Scrap Machete")
	local handle = machete and machete:FindFirstChild("Handle")

	-- 1. Play swing sound on the attacker's weapon handle
	if handle then
		AudioManager.play("MacheteSwing" .. math.random(1, 3), handle)
	end

	-- 2. Play impact sound on the target
	if target and target.Parent then
		local hitSoundName = isScrap and "MacheteHitScrap" or ("MacheteHitFlesh" .. math.random(1, 2))
		AudioManager.play(hitSoundName, target.PrimaryPart or target)
	end
end

pistolFireEvent.OnClientEvent:Connect(createBulletTracer)
macheteAttackEvent.OnClientEvent:Connect(replicateMacheteHit)
