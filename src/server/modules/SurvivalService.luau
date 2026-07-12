--!strict
-- ServerScriptService.modules.SurvivalService
-- Server-authoritative Health + Hunger + Thirst. Health is the character's Humanoid.Health
-- (MaxHealth set from config); Hunger/Thirst are Player attributes (0-100) the HUD reads. Both
-- drain over time (faster while sprinting), and hitting 0 on either damages health. Being
-- well-fed slowly regenerates health. ConsumableManager calls heal()/feed()/quench() to apply
-- bandage/food/drink effects.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local Ragdoll = require(Modules:WaitForChild("Ragdoll"))

local SV = GameConfig.Survival
local SPRINT_SPEED = GameConfig.Player.SprintSpeed

local SurvivalService = {}
local started = false

local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = SV.MaxHealth
	humanoid.Health = SV.MaxHealth
	-- Hide Roblox's built-in floating health bar; the custom HUD (PlayerSporeFilter) is the only
	-- health display.
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	-- Ragdoll on death instead of Roblox's default BreakJointsOnDeath (which disassembles the rig
	-- into disconnected floating parts) -- the character should flop over and stay in one piece.
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Connect(function()
		Ragdoll.apply(character)
	end)
	-- Reset hunger/thirst on every (re)spawn -- otherwise a player who died starving/dehydrated
	-- respawns with it still at 0 and immediately starts dying again, an endless death loop
	-- (which also made Bio-Recall fire on repeat and wipe every zombie the moment it spawned).
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		player:SetAttribute("Hunger", SV.MaxHunger)
		player:SetAttribute("Thirst", SV.MaxThirst)
	end
end

local function setupPlayer(player: Player)
	player:SetAttribute("Hunger", SV.MaxHunger)
	player:SetAttribute("Thirst", SV.MaxThirst)
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

	local sprinting = isSprinting(character, humanoid)

	-- Drain hunger (faster while sprinting)
	local hunger = player:GetAttribute("Hunger") or SV.MaxHunger
	local hungerDrain = SV.HungerDrainPerTick
	if sprinting then
		hungerDrain *= SV.SprintHungerMultiplier
	end
	hunger = math.max(0, hunger - hungerDrain)
	player:SetAttribute("Hunger", hunger)

	-- Drain thirst (faster while sprinting)
	local thirst = player:GetAttribute("Thirst") or SV.MaxThirst
	local thirstDrain = SV.ThirstDrainPerTick
	if sprinting then
		thirstDrain *= SV.SprintThirstMultiplier
	end
	thirst = math.max(0, thirst - thirstDrain)
	player:SetAttribute("Thirst", thirst)

	-- Starving/dehydration damages health; being well-fed slowly regenerates it
	if hunger <= 0 then
		humanoid:TakeDamage(SV.StarveDamagePerTick)
	end
	if thirst <= 0 then
		humanoid:TakeDamage(SV.DehydrateDamagePerTick)
	end
	if hunger >= SV.HungerRegenThreshold and thirst > 0 and humanoid.Health < humanoid.MaxHealth then
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

-- Restores player Thirst by `amount`, clamped to MaxThirst.
function SurvivalService.quench(player: Player, amount: number)
	local thirst = player:GetAttribute("Thirst") or 0
	player:SetAttribute("Thirst", math.min(SV.MaxThirst, thirst + amount))
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
