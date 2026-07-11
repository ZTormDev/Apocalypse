-- ServerScriptService.Inventory.InventoryManager
-- Owns the Belt/Backpack partition and the drop input.
--  * DropItem (G): tosses the equipped tool into the world (ItemDropSystem).
--  * MoveItem: the inventory UI asks to move a tool between belt and backpack (InventoryService).
--  * Auto-assign: any tool entering a player's Backpack gets partitioned (belt if room, else
--    backpack) in one central place, covering every grant source (pickups, ScrapWallet, Ammo...).
-- Scrap and Spore Biomass keep their own richer G-bound events (DropScrap, DropBiomass).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local ItemDropSystem = require(Modules:WaitForChild("ItemDropSystem"))
local InventoryService = require(Modules:WaitForChild("InventoryService"))

local dropItemEvent = Net.event("InventoryEvents", "DropItem")
local moveItemEvent = Net.event("InventoryEvents", "MoveItem")
local swapItemEvent = Net.event("InventoryEvents", "SwapItems")

local function ownsTool(player: Player, tool: Instance): boolean
	local backpack = player:FindFirstChild("Backpack")
	return (backpack ~= nil and tool:IsDescendantOf(backpack))
		or (player.Character ~= nil and tool:IsDescendantOf(player.Character))
end

dropItemEvent.OnServerEvent:Connect(function(player: Player)
	ItemDropSystem.dropEquippedTool(player)
end)

moveItemEvent.OnServerEvent:Connect(function(player: Player, tool, toBelt)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return
	end
	if not ownsTool(player, tool) then
		return
	end
	InventoryService.move(player, tool, toBelt == true)
end)

swapItemEvent.OnServerEvent:Connect(function(player: Player, toolA, toolB)
	if typeof(toolA) ~= "Instance" or typeof(toolB) ~= "Instance" then
		return
	end
	if not toolA:IsA("Tool") or not toolB:IsA("Tool") then
		return
	end
	if ownsTool(player, toolA) and ownsTool(player, toolB) then
		InventoryService.swap(player, toolA, toolB)
	end
end)

-- Auto-partition any tool that lands in a player's Backpack.
local function watchPlayer(player: Player)
	local function onBackpack(backpack: Instance)
		backpack.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				InventoryService.assign(player, child)
			end
		end)
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				InventoryService.assign(player, child)
			end
		end
	end

	local existing = player:FindFirstChild("Backpack")
	if existing then
		onBackpack(existing)
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			onBackpack(child)
		end
	end)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
