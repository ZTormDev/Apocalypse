--!strict
-- ServerScriptService.modules.SurvivalService
-- Server-authoritative Health + Hunger. Health is the character's Humanoid.Health (MaxHealth
-- set from config); Hunger is a Player attribute "Hunger" (0-100) the HUD reads. Hunger drains
-- over time (faster while sprinting), starving damages health, and being well-fed slowly
-- regenerates health. ConsumableManager calls heal()/feed() to apply bandage/food/drink effects.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local SV = GameConfig.Survival
local SPRINT_SPEED = GameConfig.Player.SprintSpeed

local SurvivalService = {}
local started = false

local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = SV.MaxHealth
	humanoid.Health = SV.MaxHealth
	-- Reset hunger on every (re)spawn -- otherwise a player who died starving respawns with
	-- Hunger still at 0 and immediately starves again, an endless death loop (which also made
	-- Bio-Recall fire on repeat and wipe every zombie the moment it spawned).
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		player:SetAttribute("Hunger", SV.MaxHunger)
	end
end

local function setupPlayer(player: Player)
	player:SetAttribute("Hunger", SV.MaxHunger)
	if player.Character then
		setupCharacter(player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)
end

local function isSprinting(character: Model, humanoid: Humanoid): boolean
	return humanoid.WalkSpeed >= SPRINT_SPEED and humanoid.MoveDirection.Magnitude > 0.1
end

local function tickPlayer(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	local hunger = player:GetAttribute("Hunger") or SV.MaxHunger

	-- Drain hunger (faster while sprinting)
	local drain = SV.HungerDrainPerTick
	if isSprinting(character, humanoid) then
		drain *= SV.SprintHungerMultiplier
	end
	hunger = math.max(0, hunger - drain)
	player:SetAttribute("Hunger", hunger)

	-- Starving damages health; being well-fed slowly regenerates it
	if hunger <= 0 then
		humanoid:TakeDamage(SV.StarveDamagePerTick)
	elseif hunger >= SV.HungerRegenThreshold and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + SV.HealthRegenPerTick)
	end
end

-- Restores player Health by `amount`, clamped to MaxHealth.
function SurvivalService.heal(player: Player, amount: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

-- Restores player Hunger by `amount`, clamped to MaxHunger.
function SurvivalService.feed(player: Player, amount: number)
	local hunger = player:GetAttribute("Hunger") or 0
	player:SetAttribute("Hunger", math.min(SV.MaxHunger, hunger + amount))
end

-- Idempotent boot: wires player/character setup and the survival tick loop.
function SurvivalService.start()
	if started then
		return
	end
	started = true

	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end
	Players.PlayerAdded:Connect(setupPlayer)

	task.spawn(function()
		while true do
			task.wait(SV.TickInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				tickPlayer(player)
			end
		end
	end)
end

return SurvivalService
