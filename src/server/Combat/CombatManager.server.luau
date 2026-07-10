-- ServerScriptService.Combat.CombatManager
-- Server-authoritative validation for both starter weapons. The client only ever suggests a
-- target (machete) or a direction (pistol); the server independently re-checks range/cooldown/
-- ammo and applies all damage. Also owns the player's PistolAmmo attribute.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))

local MACHETE = GameConfig.Machete
local PISTOL = GameConfig.Pistol

local macheteAttackEvent = Net.event("CombatEvents", "MacheteAttack")
local pistolFireEvent = Net.event("CombatEvents", "PistolFire")

-- ---------------------------------------------------------------------------------------
-- Scrap Machete (melee)
-- ---------------------------------------------------------------------------------------
local lastAttackTime: { [Player]: number } = {}

macheteAttackEvent.OnServerEvent:Connect(function(player, target)
	if typeof(target) ~= "Instance" or not target:IsDescendantOf(workspace) then
		return
	end
	if not CollectionService:HasTag(target, Tags.Mycomorph) then
		return
	end

	local char = player.Character
	local tool = char and char:FindFirstChild("Scrap Machete")
	if not tool then
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local now = os.clock()
	if now - (lastAttackTime[player] or 0) < MACHETE.ServerCooldown then
		return
	end

	local targetRoot = target.PrimaryPart
	local humanoid = target:FindFirstChild("Humanoid")
	if not targetRoot or not humanoid or humanoid.Health <= 0 then
		return
	end

	local dist = (targetRoot.Position - root.Position).Magnitude
	if dist > MACHETE.ServerRange then
		return
	end

	lastAttackTime[player] = now
	humanoid:TakeDamage(MACHETE.Damage)
end)

-- ---------------------------------------------------------------------------------------
-- Improvised Pistol (ranged): server does its own raycast along the aimed direction
-- ---------------------------------------------------------------------------------------
local lastPistolFire: { [Player]: number } = {}

local function initAmmo(player: Player)
	player:SetAttribute("PistolAmmo", PISTOL.StartingAmmo)
end

Players.PlayerAdded:Connect(initAmmo)
for _, player in ipairs(Players:GetPlayers()) do
	initAmmo(player)
end

pistolFireEvent.OnServerEvent:Connect(function(player, direction)
	if typeof(direction) ~= "Vector3" or direction.Magnitude == 0 then
		return
	end
	direction = direction.Unit

	local char = player.Character
	local tool = char and char:FindFirstChild("Improvised Pistol")
	if not tool then
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local now = os.clock()
	if now - (lastPistolFire[player] or 0) < PISTOL.ServerCooldown then
		return
	end

	local ammo = player:GetAttribute("PistolAmmo") or 0
	if ammo <= 0 then
		return
	end

	lastPistolFire[player] = now
	player:SetAttribute("PistolAmmo", ammo - 1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local origin = root.Position + Vector3.new(0, 1, 0)
	local targetPosition = origin + direction * PISTOL.Range
	local result = workspace:Raycast(origin, direction * PISTOL.Range, params)

	if result then
		targetPosition = result.Position
		local hitPart = result.Instance
		local model = hitPart:FindFirstAncestorOfClass("Model")
		if model and CollectionService:HasTag(model, Tags.Mycomorph) then
			local humanoid = model:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(PISTOL.Damage)
			end
		end
	end

	-- Replicate the shot to all clients for visual tracers
	pistolFireEvent:FireAllClients(player, origin, targetPosition)
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttackTime[player] = nil
	lastPistolFire[player] = nil
end)
