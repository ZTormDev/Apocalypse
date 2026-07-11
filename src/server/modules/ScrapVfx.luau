--!strict
-- ServerScriptService.modules.ScrapVfx
-- Particle helpers for Scrap Junk piles: small sparks on every non-lethal hit, and a bigger
-- burst on destruction. Server-side ParticleEmitter:Emit() calls replicate to all clients,
-- so no RemoteEvent plumbing is needed here.

local ScrapVfx = {}

local SPARK_COLOR = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 110, 40))

-- No custom Texture: the engine's built-in default particle (a soft round dot) is guaranteed
-- to render, whereas a guessed rbxasset:// path can silently fail to load.
local function newSparkEmitter(): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "HitSparks"
	emitter.Color = SPARK_COLOR
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(14, 28)
	emitter.SpreadAngle = Vector2.new(180, 180) -- full sphere, not a narrow cone
	emitter.Acceleration = Vector3.new(0, -40, 0) -- gravity so sparks arc down instead of floating
	emitter.Rate = 0 -- fires only via :Emit(), never continuously
	emitter.Enabled = false
	return emitter
end

-- Attaches a dormant "HitSparks" emitter to a ScrapPile's primary part at creation time.
-- Call ScrapVfx.hit(part) on every hit that doesn't destroy the pile.
function ScrapVfx.attachHitSparks(part: BasePart)
	if part:FindFirstChild("HitSparks") then
		return
	end
	local emitter = newSparkEmitter()
	-- Offset above the part's center so sparks emit from roughly the pile's surface
	-- instead of its geometric middle, which can be buried inside the mesh.
	local offset = Instance.new("Attachment")
	offset.Name = "HitSparksAttachment"
	offset.Position = Vector3.new(0, part.Size.Y * 0.3, 0)
	offset.Parent = part
	emitter.Parent = offset
end

function ScrapVfx.hit(part: BasePart?)
	local attachment = part and part:FindFirstChild("HitSparksAttachment")
	local emitter = attachment and attachment:FindFirstChild("HitSparks")
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter:Emit(20)
	end
end

-- A bigger burst that outlives the pile it came from. Earlier version created a brand new
-- Part+ParticleEmitter and emitted from it in the same tick as the pile's destruction --
-- that races against replication (the client can receive "emit" before it even knows the
-- instance exists) and silently drops the burst. Instead, a small pool of burst emitters is
-- created ONCE at server start (see below), long before any pile is ever destroyed, so by
-- the time destroyBurst() runs, every client already has them. Destroying a pile now just
-- repositions a pooled emitter and re-emits it -- the exact same "reposition/refire an
-- already-replicated instance" pattern the (working) per-hit sparks use.
local function createBurstEffect()
	local anchor = Instance.new("Part")
	anchor.Name = "ScrapDestroyBurst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(0, -500, 0) -- parked out of the way until first used
	anchor.Parent = workspace

	local sparks = newSparkEmitter()
	sparks.Speed = NumberRange.new(12, 24)
	sparks.Lifetime = NumberRange.new(0.6, 1.1)
	sparks.LightEmission = 1 -- glows so it reads clearly even at night
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	sparks.Parent = anchor

	local dust = Instance.new("ParticleEmitter")
	dust.Name = "DestroyDust"
	dust.Color = ColorSequence.new(Color3.fromRGB(160, 150, 140))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 5),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(0.8, 1.5)
	dust.Speed = NumberRange.new(3, 7)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Rate = 0
	dust.Enabled = false
	dust.Parent = anchor

	return { anchor = anchor, sparks = sparks, dust = dust }
end

local BURST_POOL_SIZE = 4 -- comfortably covers destroying several piles within ~1.5s of each other
local burstPool = {}
for _ = 1, BURST_POOL_SIZE do
	table.insert(burstPool, createBurstEffect())
end
local nextBurstIndex = 0

function ScrapVfx.destroyBurst(position: Vector3)
	nextBurstIndex = (nextBurstIndex % #burstPool) + 1
	local fx = burstPool[nextBurstIndex]
	fx.anchor.CFrame = CFrame.new(position)
	fx.sparks:Emit(60)
	fx.dust:Emit(20)
end

return ScrapVfx
