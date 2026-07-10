-- StarterPlayerScripts.ProximityPromptScaler
-- Roblox's default ProximityPrompt UI renders very large; this shrinks it globally
-- (affects every prompt in the game: scrap pickup, build console, biomass, etc.)
-- without needing to touch each individual ProximityPrompt instance.
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local SCALE = 0.55

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function applyScale()
	local promptsGui = playerGui:FindFirstChild("ProximityPrompts")
	local billboard = promptsGui and promptsGui:FindFirstChild("Prompt")
	local frame = billboard and billboard:FindFirstChild("Frame")
	if not frame then
		return
	end

	local uiScale = frame:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = frame
	end
	uiScale.Scale = SCALE
end

ProximityPromptService.PromptShown:Connect(applyScale)
