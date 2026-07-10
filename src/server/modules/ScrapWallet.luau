-- ServerScriptService.ScrapWallet
-- Scrap lives on a single stacking Tool in the player's inventory (Backpack or equipped in
-- Character) instead of a leaderstat, so this module is the one place that reads/writes it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScrapWallet = {}

local function findScrapTool(player)
	local backpack = player:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild("Scrap")
	if tool then return tool end

	local char = player.Character
	tool = char and char:FindFirstChild("Scrap")
	if tool then return tool end

	return nil
end

function ScrapWallet.GetAmount(player)
	local tool = findScrapTool(player)
	return tool and (tool:GetAttribute("Amount") or 0) or 0
end

-- Adds `amount` scrap, merging into the player's existing stack if they have one
function ScrapWallet.Add(player, amount)
	local tool = findScrapTool(player)
	if tool then
		local newAmount = (tool:GetAttribute("Amount") or 0) + amount
		tool:SetAttribute("Amount", newAmount)
		tool.ToolTip = "Scrap Bundle (" .. newAmount .. ")"
		return newAmount
	end

	local template = ReplicatedStorage:FindFirstChild("Scrap")
	if not template then return 0 end

	local clone = template:Clone()
	clone:SetAttribute("Amount", amount)
	clone.ToolTip = "Scrap Bundle (" .. amount .. ")"
	clone.Parent = player:WaitForChild("Backpack")
	return amount
end

-- Forces the stack to an exact value (used by the Bio-Recall snapshot restore).
-- Destroys the tool entirely if set to 0.
function ScrapWallet.SetAmount(player, amount)
	local tool = findScrapTool(player)
	if amount <= 0 then
		if tool then tool:Destroy() end
		return 0
	end

	if tool then
		tool:SetAttribute("Amount", amount)
		tool.ToolTip = "Scrap Bundle (" .. amount .. ")"
		return amount
	end

	return ScrapWallet.Add(player, amount)
end

-- Removes `amount` scrap if the player has enough; returns true on success.
-- Destroys the stack entirely once it reaches zero.
function ScrapWallet.TrySpend(player, amount)
	local tool = findScrapTool(player)
	local current = tool and (tool:GetAttribute("Amount") or 0) or 0
	if current < amount then return false end

	local remaining = current - amount
	if remaining <= 0 then
		tool:Destroy()
	else
		tool:SetAttribute("Amount", remaining)
		tool.ToolTip = "Scrap Bundle (" .. remaining .. ")"
	end
	return true
end

return ScrapWallet
