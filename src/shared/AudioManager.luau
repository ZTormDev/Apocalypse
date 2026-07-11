--!strict
-- Shared.AudioManager
-- Centralized audio player that pre-creates sound instances to prevent network lag/cuts when
-- playing sound effects. Works on both Client and Server.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local AudioManager = {}

-- Centralized registry of all SFX asset IDs in the game
local SOUND_REGISTRY = {
	-- Machete
	MacheteEquip = { id = "rbxassetid://18148611279", volume = 0.8, duration = 1.0 },
	MacheteUnequip = { id = "rbxassetid://97568182472477", volume = 0.8, duration = 1.0 },
	MacheteSwing1 = { id = "rbxassetid://101905567133955", volume = 0.8, duration = 0.5 },
	MacheteSwing2 = { id = "rbxassetid://124552528285855", volume = 0.8, duration = 0.5 },
	MacheteSwing3 = { id = "rbxassetid://88839800795591", volume = 0.8, duration = 0.5 },
	MacheteHitFlesh1 = { id = "rbxassetid://120707490368093", volume = 0.8, duration = 0.5 },
	MacheteHitFlesh2 = { id = "rbxassetid://123554252851848", volume = 0.8, duration = 0.5 },
	MacheteHitScrap = { id = "rbxassetid://108848349044700", volume = 0.9, pitchRange = {0.85, 1.15}, duration = 0.5 },

	-- Pistol
	PistolEquip = { id = "rbxassetid://3120031857", volume = 0.8, duration = 1.0 },
	PistolUnequip = { id = "rbxassetid://7405483764", volume = 0.8, duration = 1.0 },
	PistolFire = { id = "rbxassetid://680140087", volume = 0.8, duration = 1.2 },
	PistolEmpty = { id = "rbxassetid://93840917543863", volume = 0.8, duration = 0.8 },

	-- Consumables
	DrinkLoop = { id = "rbxassetid://133347729618467", volume = 0.8, looped = true },
	FoodLoop = { id = "rbxassetid://6830313781", volume = 1.5, looped = true }, -- elevated volume as requested
	BandageUse = { id = "rbxassetid://18100163169", volume = 0.8, duration = 5.0 },

	-- Pickup
	ItemPickup = { id = "rbxassetid://76809333017046", volume = 0.4, pitchRange = {0.9, 1.1}, duration = 0.5 }
}

-- Pre-created template sounds stored in memory to prevent loading delay on play
local templates: { [string]: Sound } = {}

for name, cfg in pairs(SOUND_REGISTRY) do
	local sound = Instance.new("Sound")
	sound.Name = name .. "_Template"
	sound.SoundId = cfg.id
	sound.Volume = cfg.volume
	if cfg.looped then
		sound.Looped = true
	end
	templates[name] = sound
end

-- Plays a sound at a parent instance (e.g. character head, part, or local player).
-- Returns the playing Sound instance so it can be manually stopped if needed (e.g., loops).
function AudioManager.play(soundName: string, parent: Instance?, volumeOverride: number?, pitchOverride: number?, forceLooped: boolean?): Sound?
	local template = templates[soundName]
	if not template then
		warn("AudioManager: Sound name not registered: " .. tostring(soundName))
		return nil
	end

	local targetParent = parent or SoundService
	local cfg = SOUND_REGISTRY[soundName]

	local sound = template:Clone()
	sound.Name = soundName
	sound.Parent = targetParent

	-- Configure volume
	if volumeOverride then
		sound.Volume = volumeOverride
	end

	-- Configure pitch/playback speed
	if pitchOverride then
		sound.PlaybackSpeed = pitchOverride
	elseif cfg.pitchRange then
		local min, max = cfg.pitchRange[1], cfg.pitchRange[2]
		sound.PlaybackSpeed = math.random(min * 100, max * 100) / 100
	end

	-- Force loop property override if specified
	if forceLooped ~= nil then
		sound.Looped = forceLooped
	end

	sound:Play()

	-- Only schedule destruction for non-looped sounds
	if not sound.Looped then
		-- Use real length if loaded, otherwise fallback immediately to registered duration (usually 0.5s - 1.2s)
		local duration = (sound.TimeLength > 0 and sound.TimeLength) or cfg.duration or 1.5
		Debris:AddItem(sound, duration + 0.1)
	end

	return sound
end

return AudioManager
