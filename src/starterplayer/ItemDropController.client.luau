-- StarterPlayerScripts.ItemDropController
-- G drops whatever tool is currently equipped, as a physical object other players can pick
-- back up with E. Scrap and Biomass Fuel already have their own G behavior wired to their
-- own tools (throwing a plaque from your wallet / respawning the full canister with its
-- light + Purifier beam) so this defers to their existing events instead of double-dropping.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local dropItemEvent = Net.event("InventoryEvents", "DropItem")
local dropBiomassEvent = Net.event("SporeEvents", "DropBiomass")

-- Tools with their own dedicated G-drop behavior, and which event to fire instead.
local SPECIAL_DROP_EVENTS: { [string]: RemoteEvent } = {
	["Biomass Fuel"] = dropBiomassEvent,
}
local HANDLES_OWN_DROP = { ["Scrap"] = true } -- see ScrapDropScript.client.luau

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.G then
		return
	end

	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not tool then
		return
	end

	if HANDLES_OWN_DROP[tool.Name] then
		return
	end

	local specialEvent = SPECIAL_DROP_EVENTS[tool.Name]
	if specialEvent then
		specialEvent:FireServer()
	else
		dropItemEvent:FireServer()
	end
end)
