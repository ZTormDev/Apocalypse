-- ServerScriptService.Inventory.InventoryManager
-- Wires the generic "drop whatever tool is currently equipped" input (see
-- StarterPlayerScripts.ItemDropController, G key) to ItemDropSystem. Scrap and Spore Biomass
-- keep their own existing G-bound events (DropScrap, DropBiomass) since dropping those means
-- something richer than "toss the tool" -- everything else funnels through here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local ItemDropSystem = require(Modules:WaitForChild("ItemDropSystem"))

local dropItemEvent = Net.event("InventoryEvents", "DropItem")

dropItemEvent.OnServerEvent:Connect(function(player: Player)
	ItemDropSystem.dropEquippedTool(player)
end)
