-- ServerScriptService.World.LightingSetup
-- One-time apocalyptic mood pass over the static Lighting/Atmosphere/post-fx properties that
-- WorldClock doesn't touch (WorldClock only lerps ClockTime + Ambient/OutdoorAmbient for the
-- day/night cycle). Kept restrained: a dusty haze and a slight desaturated/warm color grade,
-- not a heavy fog or color shift. Does not touch the sun/moon textures or the skybox.
local Lighting = game:GetService("Lighting")

Lighting.Brightness = 2.4
Lighting.ExposureCompensation = -0.15
Lighting.ColorShift_Bottom = Color3.fromRGB(20, 14, 8) -- faint rust tint bounced off the ground

-- Distant dusty haze -- starts well past the playable dome (MaxDomeRadius 60 studs) so it never
-- obscures nearby gameplay, just softens the horizon.
Lighting.FogColor = Color3.fromRGB(150, 138, 122)
Lighting.FogStart = 150
Lighting.FogEnd = 1400

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0.4
	atmosphere.Haze = 1.4
	atmosphere.Color = Color3.fromRGB(185, 175, 160)
	atmosphere.Decay = Color3.fromRGB(150, 110, 85)
end

local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	bloom.Intensity = 0.6
	bloom.Threshold = 2.2
end

-- Subtle global color grade (separate from PlayerSporeFilter's per-player "ToxEffect", which
-- only kicks in outside the dome) -- a light desaturation and warm/ash tint everywhere.
local mood = Lighting:FindFirstChild("WorldMood")
if not mood then
	mood = Instance.new("ColorCorrectionEffect")
	mood.Name = "WorldMood"
	mood.Parent = Lighting
end
mood.Saturation = -0.15
mood.Contrast = 0.05
mood.TintColor = Color3.fromRGB(255, 244, 228)
