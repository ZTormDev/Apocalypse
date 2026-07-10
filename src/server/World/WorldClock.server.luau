-- ServerScriptService.World.WorldClock
-- Owns only the day/night clock: advancing time-of-day, flagging night, incrementing the day
-- counter at dawn, and driving the lighting. Fuel, dome, and biomass (previously bundled into
-- the same monolith) live in Base/PurifierManager now.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local stateFolder = ReplicatedStorage:FindFirstChild("SporeTideState")
if not stateFolder then
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "SporeTideState"
	stateFolder.Parent = ReplicatedStorage
end

-- Time-of-day state (purifier-related attributes are owned by PurifierManager)
stateFolder:SetAttribute("TimeOfDay", GameConfig.World.DayStartHour)
stateFolder:SetAttribute("IsNight", false)
stateFolder:SetAttribute("DayNumber", 1)
stateFolder:SetAttribute("TimeFrozen", false) -- true while the Bio-Recall Protocol is restoring

local TIME_STEP = GameConfig.World.TimeStep
local DAY_START = GameConfig.World.DayStartHour
local NIGHT_START = GameConfig.World.NightStartHour

task.spawn(function()
	while true do
		task.wait(1)
		if stateFolder:GetAttribute("TimeFrozen") then
			continue
		end

		-- Advance time
		local timeOfDay = stateFolder:GetAttribute("TimeOfDay")
		timeOfDay = (timeOfDay + TIME_STEP) % 24
		stateFolder:SetAttribute("TimeOfDay", timeOfDay)

		-- Night flag
		local isNight = (timeOfDay >= NIGHT_START or timeOfDay < DAY_START)
		stateFolder:SetAttribute("IsNight", isNight)

		-- Day increment at dawn
		local prevTime = timeOfDay - TIME_STEP
		if prevTime < DAY_START and timeOfDay >= DAY_START then
			local dayNum = stateFolder:GetAttribute("DayNumber")
			stateFolder:SetAttribute("DayNumber", dayNum + 1)
			print("Day " .. tostring(dayNum + 1) .. " has begun!")
		end

		-- Lighting
		Lighting.ClockTime = timeOfDay
		if isNight then
			Lighting.Ambient = GameConfig.World.NightAmbient
			Lighting.OutdoorAmbient = GameConfig.World.NightOutdoorAmbient
		else
			Lighting.Ambient = GameConfig.World.DayAmbient
			Lighting.OutdoorAmbient = GameConfig.World.DayOutdoorAmbient
		end
	end
end)
