-- ReplicatedStorage.Improvised Pistol.PistolClient
local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local CombatEvents = ReplicatedStorage:WaitForChild("CombatEvents")
local pistolFireEvent = CombatEvents:WaitForChild("PistolFire")

local COOLDOWN = 0.3
local lastFire = 0

-- Purely cosmetic muzzle flash/shell-eject/sound feedback (from the mesh asset's own
-- effect parts) -- this never touches damage or ammo, the server remains sole authority.
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
	Tool.Equipped:Connect(function() sounds.Equip:Play() end)
	Tool.Unequipped:Connect(function() sounds.Unequipped:Play() end)
end

-- Sends the aim direction only; the server does its own raycast and decides what (if
-- anything) got hit, and is the sole authority on ammo count and damage.
Tool.Activated:Connect(function()
	local now = os.clock()
	if now - lastFire < COOLDOWN then return end
	lastFire = now

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local aimPoint = mouse.Hit and mouse.Hit.Position or (root.Position + root.CFrame.LookVector * 100)
	local direction = aimPoint - root.Position
	if direction.Magnitude > 0 then
		direction = direction.Unit
	else
		direction = root.CFrame.LookVector
	end

	pistolFireEvent:FireServer(direction)
	if sounds then sounds.Activated:Play() end
	task.spawn(playMuzzleFlash)
end)
