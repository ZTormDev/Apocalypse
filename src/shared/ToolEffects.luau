--!strict
-- ReplicatedStorage.Shared.ToolEffects
-- Reusable cosmetic helpers for Tools (client-side). Currently the "holster" behavior that
-- clones a weapon's Handle onto the player's back while the tool is unequipped -- extracted
-- from the Scrap Machete so the next melee weapon can reuse it instead of reimplementing it.
local ToolEffects = {}

local DEFAULT_OFFSET = CFrame.new(0, 0.2, 0.5) * CFrame.Angles(math.rad(100), 0, 0)

function ToolEffects.removeHolster(character: Model?, holsterName: string)
	if not character then
		return
	end
	local existing = character:FindFirstChild(holsterName)
	if existing then
		existing:Destroy()
	end
end

-- Clones `tool.Handle` onto the character's back (UpperTorso/Torso) as a welded, non-colliding
-- cosmetic part named `holsterName`. Safe to call repeatedly (replaces any existing holster).
function ToolEffects.showHolster(tool: Tool, character: Model?, holsterName: string, offset: CFrame?)
	if not character then
		return
	end
	ToolEffects.removeHolster(character, holsterName)

	local back = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local handle = tool:FindFirstChild("Handle")
	if not back or not handle or not back:IsA("BasePart") or not handle:IsA("BasePart") then
		return
	end

	local holster = handle:Clone()
	holster.Name = holsterName
	holster.Anchored = false
	holster.CanCollide = false
	holster.CanTouch = false
	holster.CanQuery = false
	holster.Massless = true
	holster.CFrame = back.CFrame * (offset or DEFAULT_OFFSET)
	holster.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = back
	weld.Part1 = holster
	weld.Parent = holster
end

return ToolEffects
