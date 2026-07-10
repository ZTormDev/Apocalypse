-- ServerScriptService.CombatManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local CombatEvents = ReplicatedStorage:WaitForChild("CombatEvents")
local macheteAttackEvent = CombatEvents:WaitForChild("MacheteAttack")
local pistolFireEvent = CombatEvents:WaitForChild("PistolFire")

local MACHETE_RANGE = 8 -- studs; a bit more generous than the client's pick range to allow for latency
local MACHETE_DAMAGE = 25
local MACHETE_COOLDOWN = 0.55

local lastAttackTime = {} -- [player] = os.clock()

macheteAttackEvent.OnServerEvent:Connect(function(player, target)
	if typeof(target) ~= "Instance" or not target:IsDescendantOf(workspace) then return end
	if not CollectionService:HasTag(target, "Mycomorph") then return end

	local char = player.Character
	local tool = char and char:FindFirstChild("Scrap Machete")
	if not tool then return end -- must have the machete equipped

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local now = os.clock()
	if now - (lastAttackTime[player] or 0) < MACHETE_COOLDOWN then return end

	local targetRoot = target.PrimaryPart
	local humanoid = target:FindFirstChild("Humanoid")
	if not targetRoot or not humanoid or humanoid.Health <= 0 then return end

	local dist = (targetRoot.Position - root.Position).Magnitude
	if dist > MACHETE_RANGE then return end

	lastAttackTime[player] = now
	humanoid:TakeDamage(MACHETE_DAMAGE)
end)

-- Improvised Pistol: server does its own raycast along the direction the client aimed;
-- the client only ever suggests a direction, never a hit result, ammo count, or damage.
local PISTOL_RANGE = 100
local PISTOL_DAMAGE = 15
local PISTOL_COOLDOWN = 0.25
local STARTING_AMMO = 12

local lastPistolFire = {} -- [player] = os.clock()

local function initAmmo(player)
	player:SetAttribute("PistolAmmo", STARTING_AMMO)
end

Players.PlayerAdded:Connect(initAmmo)
for _, player in ipairs(Players:GetPlayers()) do
	initAmmo(player)
end

pistolFireEvent.OnServerEvent:Connect(function(player, direction)
	if typeof(direction) ~= "Vector3" or direction.Magnitude == 0 then return end
	direction = direction.Unit

	local char = player.Character
	local tool = char and char:FindFirstChild("Improvised Pistol")
	if not tool then return end -- must have the pistol equipped

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local now = os.clock()
	if now - (lastPistolFire[player] or 0) < PISTOL_COOLDOWN then return end

	local ammo = player:GetAttribute("PistolAmmo") or 0
	if ammo <= 0 then return end

	lastPistolFire[player] = now
	player:SetAttribute("PistolAmmo", ammo - 1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}

	local origin = root.Position + Vector3.new(0, 1, 0)
	local result = workspace:Raycast(origin, direction * PISTOL_RANGE, params)

	if result then
		local hitPart = result.Instance
		local model = hitPart:FindFirstAncestorOfClass("Model")
		if model and CollectionService:HasTag(model, "Mycomorph") then
			local humanoid = model:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(PISTOL_DAMAGE)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttackTime[player] = nil
	lastPistolFire[player] = nil
end)
