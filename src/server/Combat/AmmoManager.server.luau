-- ServerScriptService.Combat.AmmoManager
-- Keeps a visible "Pistol Ammo" inventory Tool in sync with the player's authoritative
-- PistolAmmo attribute (which the pistol reads/decrements in CombatManager). Picking up an
-- ammo box adds to PistolAmmo (ItemPickupFactory); this script reflects the running total as
-- a single stacking tool showing "Pistol Ammo (N)", and removes it when ammo hits 0.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AMMO_TOOL = "Pistol Ammo"

local function findAmmoTool(player: Player): Tool?
	local backpack = player:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild(AMMO_TOOL)
	if not tool then
		local char = player.Character
		tool = char and char:FindFirstChild(AMMO_TOOL)
	end
	return tool
end

local function sync(player: Player)
	local ammo = player:GetAttribute("PistolAmmo") or 0
	local tool = findAmmoTool(player)

	if ammo <= 0 then
		if tool then
			tool:Destroy()
		end
		return
	end

	if not tool then
		local template = ReplicatedStorage:FindFirstChild(AMMO_TOOL)
		local backpack = player:FindFirstChild("Backpack")
		if template and backpack then
			tool = template:Clone()
			tool.Parent = backpack
		end
	end

	if tool then
		tool:SetAttribute("Amount", ammo)
		tool.ToolTip = AMMO_TOOL .. " (" .. ammo .. ")"
	end
end

local function setupPlayer(player: Player)
	player:GetAttributeChangedSignal("PistolAmmo"):Connect(function()
		sync(player)
	end)
	-- Re-sync when a fresh backpack/character appears (e.g. respawn) so the tool is recreated
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		sync(player)
	end)
	task.spawn(function()
		task.wait(0.5)
		sync(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
