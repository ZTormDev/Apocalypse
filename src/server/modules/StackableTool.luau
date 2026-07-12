--!strict
-- ServerScriptService.modules.StackableTool
-- Generic helper for tools that stack via an "Amount" attribute on a single Tool instance
-- instead of spawning one Tool instance per pickup (generalizes the pattern ScrapWallet
-- pioneered for Scrap, so other stackable items -- e.g. Bandage -- don't reimplement it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StackableTool = {}

local function findTool(player: Player, toolName: string): Tool?
	local backpack = player:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild(toolName)
	if tool and tool:IsA("Tool") then
		return tool
	end

	local char = player.Character
	tool = char and char:FindFirstChild(toolName)
	if tool and tool:IsA("Tool") then
		return tool
	end

	return nil
end

function StackableTool.getAmount(player: Player, toolName: string): number
	local tool = findTool(player, toolName)
	return tool and (tool:GetAttribute("Amount") or 0) or 0
end

-- Adds `amount` of `toolName`, merging into the player's existing stack if they have one, or
-- cloning a fresh stack (from a ReplicatedStorage template of the same name) if they don't.
-- Returns the new stack size, or 0 if no template/backpack was available.
function StackableTool.add(player: Player, toolName: string, amount: number): number
	local tool = findTool(player, toolName)
	if tool then
		local newAmount = (tool:GetAttribute("Amount") or 0) + amount
		tool:SetAttribute("Amount", newAmount)
		return newAmount
	end

	local template = ReplicatedStorage:FindFirstChild(toolName)
	if not template or not template:IsA("Tool") then
		return 0
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return 0
	end

	local clone = template:Clone()
	clone:SetAttribute("Amount", amount)
	clone.Parent = backpack
	return amount
end

-- Removes one unit from the player's stack of `toolName`, destroying the Tool once it reaches
-- zero. Returns true if a unit was removed (false if the player had none).
function StackableTool.consumeOne(player: Player, toolName: string): boolean
	local tool = findTool(player, toolName)
	if not tool then
		return false
	end
	local current = tool:GetAttribute("Amount") or 1
	if current <= 1 then
		tool:Destroy()
	else
		tool:SetAttribute("Amount", current - 1)
	end
	return true
end

return StackableTool
