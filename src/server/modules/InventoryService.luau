--!strict
-- ServerScriptService.modules.InventoryService
-- Logical Belt/Backpack partition on top of Roblox's single player.Backpack. Every owned Tool
-- carries a boolean attribute "BeltItem": true = belt (hotbar, equippable), false = backpack.
-- Equipped tools live in the Character but stay BeltItem=true. Stacking tools (Scrap, Pistol
-- Ammo) count as one slot regardless of Amount.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local INV = GameConfig.Inventory

local InventoryService = {}

-- Iterates every Tool the player owns (Backpack + currently equipped in Character).
local function forEachTool(player: Player, fn: (Tool) -> ())
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") then
				fn(t)
			end
		end
	end
	local char = player.Character
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") then
				fn(t)
			end
		end
	end
end

function InventoryService.beltCount(player: Player): number
	local n = 0
	forEachTool(player, function(t)
		-- Equipped (in Character) counts as belt; in Backpack only if flagged belt.
		if t.Parent == player.Character or t:GetAttribute("BeltItem") == true then
			n += 1
		end
	end)
	return n
end

function InventoryService.backpackCount(player: Player): number
	local n = 0
	forEachTool(player, function(t)
		if t.Parent ~= player.Character and t:GetAttribute("BeltItem") == false then
			n += 1
		end
	end)
	return n
end

function InventoryService.hasTool(player: Player, toolName: string): boolean
	local found = false
	forEachTool(player, function(t)
		if t.Name == toolName then
			found = true
		end
	end)
	return found
end

-- True if the player can take a tool named `toolName`: either there's a free slot anywhere, or
-- they already own that tool (stacking items just bump Amount, no new slot needed).
function InventoryService.canAccept(player: Player, toolName: string): boolean
	if InventoryService.hasTool(player, toolName) then
		return true
	end
	return InventoryService.beltCount(player) < INV.BeltSize
		or InventoryService.backpackCount(player) < INV.BackpackSize
end

-- Assigns BeltItem for a freshly-added tool: belt if there's room, else backpack.
function InventoryService.assign(player: Player, tool: Tool)
	if tool:GetAttribute("BeltItem") ~= nil then
		return -- already partitioned
	end
	if InventoryService.beltCount(player) < INV.BeltSize then
		tool:SetAttribute("BeltItem", true)
	else
		tool:SetAttribute("BeltItem", false)
	end
end

local function areaIsBelt(player: Player, tool: Tool): boolean
	return tool.Parent == player.Character
		or tool:GetAttribute("BeltItem") == true
		or tool:GetAttribute("BeltItem") == nil
end

-- Swaps the areas of two owned tools (A takes B's area and vice versa). Only acts when they're
-- in different areas. A net-zero operation on both counts, so no capacity check is needed --
-- this is what the UI uses when dropping onto an occupied slot in the other area, where two
-- independent move() calls could each transiently violate a cap.
function InventoryService.swap(player: Player, toolA: Tool, toolB: Tool)
	if not toolA:IsA("Tool") or not toolB:IsA("Tool") then
		return
	end
	local aBelt = areaIsBelt(player, toolA)
	local bBelt = areaIsBelt(player, toolB)
	if aBelt == bBelt then
		return -- same area: purely a visual reorder, handled client-side
	end

	local function apply(tool: Tool, toBelt: boolean)
		if not toBelt and tool.Parent == player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end
		tool:SetAttribute("BeltItem", toBelt)
	end
	apply(toolA, bBelt)
	apply(toolB, aBelt)
end

-- Moves a tool to the belt (toBelt=true) or backpack, if the destination area has room.
-- Returns whether the move happened.
function InventoryService.move(player: Player, tool: Tool, toBelt: boolean): boolean
	if not tool:IsA("Tool") then
		return false
	end
	local currentlyBelt = (tool.Parent == player.Character) or (tool:GetAttribute("BeltItem") == true)
	if currentlyBelt == toBelt then
		return true -- already there
	end

	if toBelt then
		if InventoryService.beltCount(player) >= INV.BeltSize then
			return false
		end
		tool:SetAttribute("BeltItem", true)
	else
		-- Moving to backpack: if equipped, unequip it back to the Backpack first.
		if tool.Parent == player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end
		if InventoryService.backpackCount(player) >= INV.BackpackSize then
			return false
		end
		tool:SetAttribute("BeltItem", false)
	end
	return true
end

return InventoryService
