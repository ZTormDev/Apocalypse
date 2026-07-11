-- ServerScriptService.World.WorldClock
-- Phase-based day/night cycle. Instead of a continuously ticking clock, time is divided into
-- four phases with fixed REAL-second durations (GameConfig.World):
--   Day (steady) -> Dusk (transition) -> Night (steady, enemies) -> Dawn (transition) -> Day...
-- Within each phase the sun (ClockTime) and ambient light are interpolated from the phase's
-- start keyframe to its end keyframe, so Day/Night look stable and Dusk/Dawn smoothly cross-fade.
-- IsNight is true only during the Night phase; DayNumber increments each time a new Day begins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local W = GameConfig.World

local stateFolder = ReplicatedStorage:FindFirstChild("SporeTideState")
if not stateFolder then
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "SporeTideState"
	stateFolder.Parent = ReplicatedStorage
end

-- Phase table. ClockTime keyframes are continuous across phases (mod 24): 6->18->20->28(=4)->30(=6).
local PHASES = {
	{ name = "Day",   duration = W.DayDuration,   clockFrom = 6,  clockTo = 18, nightFrom = 0, nightTo = 0, isNight = false },
	{ name = "Dusk",  duration = W.DuskDuration,  clockFrom = 18, clockTo = 20, nightFrom = 0, nightTo = 1, isNight = false },
	{ name = "Night", duration = W.NightDuration, clockFrom = 20, clockTo = 28, nightFrom = 1, nightTo = 1, isNight = true },
	{ name = "Dawn",  duration = W.DawnDuration,  clockFrom = 28, clockTo = 30, nightFrom = 1, nightTo = 0, isNight = false },
}

stateFolder:SetAttribute("TimeOfDay", W.DayStartHour)
stateFolder:SetAttribute("IsNight", false)
stateFolder:SetAttribute("DayNumber", 1)
stateFolder:SetAttribute("TimeFrozen", false) -- true while the Bio-Recall Protocol is restoring
stateFolder:SetAttribute("Phase", "Day")

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function applyPhase(phase, p: number)
	local clock = lerp(phase.clockFrom, phase.clockTo, p) % 24
	local nf = lerp(phase.nightFrom, phase.nightTo, p)

	stateFolder:SetAttribute("TimeOfDay", clock)
	Lighting.ClockTime = clock
	Lighting.Ambient = W.DayAmbient:Lerp(W.NightAmbient, nf)
	Lighting.OutdoorAmbient = W.DayOutdoorAmbient:Lerp(W.NightOutdoorAmbient, nf)
end

local phaseIndex = 1
local phaseElapsed = 0

local function enterPhase(index: number)
	phaseIndex = index
	local phase = PHASES[index]
	stateFolder:SetAttribute("Phase", phase.name)
	stateFolder:SetAttribute("IsNight", phase.isNight)
end

task.spawn(function()
	local last = os.clock()
	local wasFrozen = false

	while true do
		task.wait(0.1)
		local now = os.clock()
		local dt = now - last
		last = now

		if stateFolder:GetAttribute("TimeFrozen") then
			wasFrozen = true
			continue
		end
		if wasFrozen then
			-- Bio-Recall just finished (it resets the world to 6:00 AM of the same day) -- realign
			-- the phase machine to the start of Day without bumping DayNumber.
			wasFrozen = false
			enterPhase(1)
			phaseElapsed = 0
		end

		phaseElapsed += dt
		local phase = PHASES[phaseIndex]
		while phaseElapsed >= phase.duration do
			phaseElapsed -= phase.duration
			local nextIndex = (phaseIndex % #PHASES) + 1
			enterPhase(nextIndex)
			phase = PHASES[phaseIndex]
			if phase.name == "Day" then
				local dayNum = stateFolder:GetAttribute("DayNumber")
				stateFolder:SetAttribute("DayNumber", dayNum + 1)
				print("Day " .. tostring(dayNum + 1) .. " has begun!")
			end
		end

		applyPhase(phase, phaseElapsed / phase.duration)
	end
end)
