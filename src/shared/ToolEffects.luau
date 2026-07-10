--!strict
-- ReplicatedStorage.Shared.ToolEffects
-- Reusable cosmetic helpers for Tools (client-side). Currently the "holster" behavior that
-- clones a weapon's Handle onto the player's back while the tool is unequipped -- extracted
-- from the Scrap Machete so the next melee weapon can reuse it instead of reimplementing it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ToolEffects = {}

local function holsterOffsetFromConfig()
	local t = GameConfig.WeaponTuning.MacheteHolster
	-- Apply Y rotation first, then X, then Z to prevent Gimbal Lock when RotY is 90
	return CFrame.new(t.PosX, t.PosY, t.PosZ)
		* CFrame.Angles(0, math.rad(t.RotY), 0)
		* CFrame.Angles(math.rad(t.RotX), 0, 0)
		* CFrame.Angles(0, 0, math.rad(t.RotZ))
end

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

	-- Use a Weld (not WeldConstraint) so the relative transform is set
	-- explicitly via C0 rather than being captured from the physics state
	-- at the moment of creation. This means GameConfig values are always
	-- applied exactly as written.
	local resolvedOffset = offset or holsterOffsetFromConfig()
	local weld = Instance.new("Weld")
	weld.Part0 = back
	weld.Part1 = holster
	weld.C0 = resolvedOffset   -- offset FROM back TO holster
	weld.C1 = CFrame.new()     -- holster's own origin (identity)
	weld.Parent = holster

	holster.Parent = character -- Weld activates here and positions holster via C0
end

return ToolEffects
