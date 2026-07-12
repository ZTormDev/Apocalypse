-- ServerScriptService.Consumables.ConsumableManager
-- Applies consumable effects. The client (ConsumableClient) enforces the hold-to-use timing
-- and fires UseConsumable once it completes; the server validates the player is holding a
-- known consumable, applies its effect (Bandage -> Health, Canned Beans -> Hunger + a little
-- Thirst, Water Bottle -> Thirst only) via SurvivalService, and consumes one unit of the tool (stackable tools
-- like Bandage lose one from their stack instead of being destroyed outright).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local SurvivalService = require(Modules:WaitForChild("SurvivalService"))
local StackableTool = require(Modules:WaitForChild("StackableTool"))

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
	if cfg.Thirst then
		SurvivalService.quench(player, cfg.Thirst)
	end

	if tool:GetAttribute("Amount") then
		StackableTool.consumeOne(player, tool.Name)
	else
		tool:Destroy()
	end
	print(player.Name .. " used a " .. tool.Name)
end)
