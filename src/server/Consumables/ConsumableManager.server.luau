-- ServerScriptService.Consumables.ConsumableManager
-- Applies consumable effects. The client (ConsumableClient) enforces the hold-to-use timing
-- and fires UseConsumable once it completes; the server validates the player is holding a
-- known consumable, applies its effect (Bandage -> Health, Drink/Food -> Hunger) via
-- SurvivalService, and consumes the tool.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local SurvivalService = require(Modules:WaitForChild("SurvivalService"))

local useConsumableEvent = Net.event("SurvivalEvents", "UseConsumable")

useConsumableEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not tool then
		return
	end

	local cfg = GameConfig.Consumables[tool.Name]
	if not cfg then
		return
	end

	if cfg.Heal then
		SurvivalService.heal(player, cfg.Heal)
	end
	if cfg.Hunger then
		SurvivalService.feed(player, cfg.Hunger)
	end

	tool:Destroy()
	print(player.Name .. " used a " .. tool.Name)
end)
