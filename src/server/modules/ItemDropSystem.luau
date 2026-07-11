--!strict
-- ServerScriptService.modules.ItemDropSystem
-- Generic drop/pickup for any equipped Tool: dropping tosses the Tool instance itself (not a
-- clone) into the world as a physical object, so any attributes/state already on it survive
-- the round trip; picking it back up (E, via ProximityPrompt) reparents that same instance
-- into the collecting player's Backpack.
local Modules = script.Parent
local PickupVfx = require(Modules:WaitForChild("PickupVfx"))

local ItemDropSystem = {}

local THROW_VELOCITY = 20

-- Tools whose Equipped/Unequipped scripts manage their own cosmetic side effects (e.g. a
-- "holster" clone shown on the back while unequipped-but-still-owned). Those clones assume
-- the tool is still in the Backpack, which is no longer true once fully dropped in the world,
-- so we explicitly clean them up here rather than teach every tool script about full drops.
local HOLSTER_NAMES_BY_TOOL = {
	["Scrap Machete"] = "MacheteHolster",
}

function ItemDropSystem.dropEquippedTool(player: Player)
	local char = player.Character
	if not char then
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return
	end

	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then
		return
	end

	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return -- no physical Handle to represent in the world
	end

	local originalSize = handle.Size
	local originalCanCollide = handle.CanCollide
	local originalAnchored = handle.Anchored

	humanoid:UnequipTools()

	local holsterName = HOLSTER_NAMES_BY_TOOL[tool.Name]
	if holsterName then
		local holster = char:FindFirstChild(holsterName)
		if holster then
			holster:Destroy()
		end
	end

	tool.Parent = workspace
	handle.Anchored = false
	handle.CanCollide = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = tool.Name
	prompt.MaxActivationDistance = 8
	prompt.ClickablePrompt = false
	prompt.Parent = handle

	tool:PivotTo(CFrame.new(root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)))
	handle.AssemblyLinearVelocity = root.CFrame.LookVector * THROW_VELOCITY * 0.5 + Vector3.new(0, 8, 0)

	prompt.Triggered:Connect(function(collectingPlayer: Player)
		if tool.Parent ~= workspace then
			return -- already picked up by someone else
		end
		PickupVfx.absorb(handle, prompt, collectingPlayer, function()
			if not prompt or not prompt.Parent then
				return
			end
			prompt:Destroy()
			handle.Size = originalSize
			handle.Anchored = originalAnchored
			handle.CanCollide = originalCanCollide
			local backpack = collectingPlayer:FindFirstChild("Backpack")
			if backpack then
				tool.Parent = backpack
			else
				tool.Parent = nil
			end
		end)
	end)
end

return ItemDropSystem
