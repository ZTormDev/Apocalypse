-- ReplicatedStorage.Improvised Pistol.PistolClient
-- Sends only the aim direction; the server (CombatManager) does its own raycast and is the
-- sole authority on ammo and damage. Everything here is cosmetic (muzzle flash + SFX).
local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local pistolFireEvent = Net.event("CombatEvents", "PistolFire")

local COOLDOWN = GameConfig.Pistol.ClientCooldown
local lastFire = 0

-- Cosmetic muzzle flash / shell-eject / sound (from the mesh asset's own effect parts). Tied
-- to that specific mesh's named children, so it stays here rather than in a generic helper.
local handle = Tool:FindFirstChild("Handle")
local shot = handle and handle:FindFirstChild("Shot")
local dispenser = handle and handle:FindFirstChild("Dispenser")
local shell = handle and handle:FindFirstChild("Shell")
local sounds = handle and handle:FindFirstChild("Sounds")

local function playMuzzleFlash()
	if shot then
		shot.GunShotLight.Enabled = true
		shot.Transparency = 0
		shot.Smoke1.Enabled = true
		shot.Smoke2.Enabled = true
	end
	if dispenser then
		dispenser.s1.Enabled = true
		dispenser.s2.Enabled = true
		dispenser.s3.Enabled = true
		dispenser.s4.Enabled = true
		dispenser.s5.Enabled = true
		dispenser.Decal1.Transparency = 0
		dispenser.Decal2.Transparency = 0
	end
	if shell then
		shell.shel.Enabled = true
	end

	task.wait(0.05)

	if shot then
		shot.GunShotLight.Enabled = false
		shot.Transparency = 1
		shot.Smoke1.Enabled = false
		shot.Smoke2.Enabled = false
	end
	if dispenser then
		dispenser.s1.Enabled = false
		dispenser.s2.Enabled = false
		dispenser.s3.Enabled = false
		dispenser.s4.Enabled = false
		dispenser.s5.Enabled = false
		dispenser.Decal1.Transparency = 1
		dispenser.Decal2.Transparency = 1
	end
	task.wait(0.4)
	if shell then
		shell.shel.Enabled = false
	end
end

if sounds then
	Tool.Equipped:Connect(function()
		sounds.Equip:Play()
	end)
	Tool.Unequipped:Connect(function()
		sounds.Unequipped:Play()
	end)
end

Tool.Activated:Connect(function()
	local now = os.clock()
	if now - lastFire < COOLDOWN then
		return
	end
	lastFire = now

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local aimPoint = mouse.Hit and mouse.Hit.Position or (root.Position + root.CFrame.LookVector * 100)
	local direction = aimPoint - root.Position
	if direction.Magnitude > 0 then
		direction = direction.Unit
	else
		direction = root.CFrame.LookVector
	end

	pistolFireEvent:FireServer(direction)
	if sounds then
		sounds.Activated:Play()
	end
	task.spawn(playMuzzleFlash)
end)
