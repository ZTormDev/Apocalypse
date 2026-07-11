--!strict
-- ServerScriptService.modules.ItemPickupFactory
-- Spawns a world pickup for a named ReplicatedStorage Tool. The pickup is a clone of the
-- tool's Handle sitting in the world with a "Pick Up" ProximityPrompt (E). On pickup it plays
-- the shared absorb animation and grants the item: normal tools are cloned into the player's
-- Backpack; "Pistol Ammo" instead adds PerBox to the player's PistolAmmo attribute (AmmoManager
-- reflects that as the visible stacking tool), so ammo never accumulates as many dead boxes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local Modules = script.Parent
local PickupVfx = require(Modules:WaitForChild("PickupVfx"))
local InventoryService = require(Modules:WaitForChild("InventoryService"))

local ItemPickupFactory = {}

local AMMO_TOOL = "Pistol Ammo"

function ItemPickupFactory.spawn(toolName: string, pos: Vector3): BasePart?
	local template = ReplicatedStorage:FindFirstChild(toolName)
	if not template or not template:IsA("Tool") then
		warn("ItemPickupFactory: tool template not found: " .. tostring(toolName))
		return nil
	end
	local handleTemplate = template:FindFirstChild("Handle")
	if not handleTemplate or not handleTemplate:IsA("BasePart") then
		warn("ItemPickupFactory: tool has no Handle: " .. tostring(toolName))
		return nil
	end

	local worldItem = handleTemplate:Clone()
	worldItem.Name = toolName .. "Pickup"
	worldItem.Anchored = false
	worldItem.CanCollide = true
	worldItem.Massless = false
	worldItem.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = toolName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.ClickablePrompt = false
	prompt.Parent = worldItem

	prompt.Triggered:Connect(function(player)
		if worldItem.Parent ~= Workspace then
			return -- already claimed
		end
		-- Ammo stacks into PistolAmmo (no slot); other tools need inventory room.
		if toolName ~= AMMO_TOOL and not InventoryService.canAccept(player, toolName) then
			return -- belt + backpack full: can't pick up
		end
		PickupVfx.absorb(worldItem, prompt, player, function()
			worldItem:Destroy()
			if toolName == AMMO_TOOL then
				local current = player:GetAttribute("PistolAmmo") or 0
				player:SetAttribute("PistolAmmo", current + GameConfig.Ammo.PerBox)
			else
				local backpack = player:FindFirstChild("Backpack")
				if backpack then
					template:Clone().Parent = backpack
				end
			end
		end)
	end)

	worldItem.Parent = Workspace
	return worldItem
end

return ItemPickupFactory
