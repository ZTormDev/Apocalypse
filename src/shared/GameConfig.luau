--!strict
-- ReplicatedStorage.Shared.GameConfig
-- Single source of truth for every tunable gameplay number. Both client and server require
-- this module, so a value defined here can never drift between the two (which was the case
-- before, e.g. structure costs were hand-copied into the client build menu).
--
-- Where the client and server intentionally use *different* values (e.g. a slightly more
-- generous melee range on the server to absorb latency), both are named explicitly rather
-- than hidden as two separate magic numbers in two files.

local GameConfig = {}

-- ---------------------------------------------------------------------------------------
-- Day / night clock and Purifier simulation
-- ---------------------------------------------------------------------------------------
GameConfig.World = {
	-- Phase-based day/night cycle: each phase lasts a fixed number of REAL seconds. Day and
	-- Night are steady; Dusk/Dawn are the short lighting transitions between them.
	--   Day -> Dusk -> Night -> Dawn -> Day ...
	DayDuration = 300, -- 5 min of daytime
	DuskDuration = 30, -- 30s transition day -> night
	NightDuration = 180, -- 3 min of night (enemies spawn)
	DawnDuration = 30, -- 30s transition night -> day

	DayStartHour = 6.0, -- ClockTime the day begins at (also used by Bio-Recall's reset)

	-- Lighting tint per phase (lerped across Dusk/Dawn)
	NightAmbient = Color3.fromRGB(15, 15, 30),
	NightOutdoorAmbient = Color3.fromRGB(10, 10, 25),
	DayAmbient = Color3.fromRGB(120, 120, 120),
	DayOutdoorAmbient = Color3.fromRGB(120, 120, 120),
}

GameConfig.Purifier = {
	Position = Vector3.new(0, 6, 0),
	AnchorSize = Vector3.new(7.3, 12, 7.3), -- invisible collision/position anchor

	StartFuel = 100.0,
	MaxFuel = 100.0,
	StartHealth = 100.0,
	MaxHealth = 100.0,
	FuelDecayPerSecond = 0.3,

	MaxDomeRadius = 60.0,
	MinDomeRadius = 12.0, -- emergency radius when fuel hits zero
	DomeLerpAlpha = 0.1, -- per-second interpolation toward the target radius

	RechargeRange = 20, -- studs within which a Biomass Catalyst is absorbed
	RechargePerCanister = 25,
}

-- Server-authoritative mask filter / toxic damage (client only reads these for UI)
GameConfig.Oxygen = {
	Max = 100.0,
	DrainPerTick = 2.5, -- per 0.5s tick outside the dome
	RechargePerTick = 5.0, -- per 0.5s tick inside the dome
	ToxicDamagePerTick = 5, -- once the filter is empty
	TickInterval = 0.5,
}

-- ---------------------------------------------------------------------------------------
-- Economy: Biomass Catalyst (fuel) and Scrap (currency) pickups
-- ---------------------------------------------------------------------------------------
GameConfig.Biomass = {
	InitialCount = 8,
	MaxCount = 15,
	RespawnCheckInterval = 15,
	SpawnMinDist = 90,
	SpawnMaxDist = 160,
	ThrowVelocity = 25,
}

GameConfig.Scrap = {
	MaxPiles = 12,
	SpawnMinDist = 90,
	SpawnMaxDist = 160,
	PerPile = 5,
	RespawnCheckInterval = 12,
	ThrowVelocity = 25,
	MaxHealth = 100,
}

-- ---------------------------------------------------------------------------------------
-- Survival: player Health (Humanoid.Health) + Hunger (Player "Hunger" attribute, 0-100).
-- Both are server-authoritative; the client HUD only reads them.
-- ---------------------------------------------------------------------------------------
GameConfig.Survival = {
	MaxHealth = 100,
	MaxHunger = 100,
	TickInterval = 1.0, -- seconds per survival tick

	HungerDrainPerTick = 0.6, -- baseline hunger lost per tick while alive
	SprintHungerMultiplier = 2.5, -- hunger drains this much faster while sprinting

	StarveDamagePerTick = 3, -- health lost per tick once hunger hits 0
	HealthRegenPerTick = 0, -- health regained per tick while well-fed (disabled)
	HungerRegenThreshold = 50, -- hunger must be above this for health to regen
}

-- Consumable tools: hold left-click for HoldTime seconds, then apply the effect.
-- Bandage restores Health; Drink/Food restore Hunger.
GameConfig.Consumables = {
	["Bandage"] = { HoldTime = 5, Heal = 25 },
	["Drink"] = { HoldTime = 2, Hunger = 20 },
	["Food"] = { HoldTime = 2, Hunger = 40 },
}

-- One "Pistol Ammo" box grants this much to the player's PistolAmmo attribute.
GameConfig.Ammo = {
	PerBox = 30,
}

-- Inventory partition: the Belt (hotbar, always visible, the only equippable area) and the
-- Backpack (opened with B). Stacking tools (Scrap, Pistol Ammo) occupy 1 slot regardless of Amount.
GameConfig.Inventory = {
	BeltSize = 5,
	BackpackSize = 10,
}

-- ---------------------------------------------------------------------------------------
-- Central spawn system (SpawnManager). Loot spawns at tagged Points in the Workspace,
-- not in a hardcoded ring. Two point kinds: ItemSpawnPoint and ScrapSpawnPoint.
-- ---------------------------------------------------------------------------------------
GameConfig.Spawning = {
	TickInterval = 5, -- seconds between spawn rolls across all points
	PositionJitter = 3, -- studs of random horizontal offset from the point's center

	ItemPoint = {
		MaxPerPoint = 2, -- max live items a single item point keeps around
		SpawnChance = 0.5, -- probability, per tick, to try spawning at a point below max
	},
	ScrapPoint = {
		MaxPerPoint = 1, -- one scrap pile per point at a time
		SpawnChance = 0.6,
	},
}

-- Weighted loot table for ItemSpawnPoints. `kind` selects the spawn factory:
--   "tool"    -> ItemPickupFactory (clones the named ReplicatedStorage Tool as a world pickup)
--   "biomass" -> BiomassFactory (the green fuel canister)
GameConfig.LootTable = {
	{ name = "Pistol Ammo", kind = "tool", weight = 3 },
	{ name = "Scrap Machete", kind = "tool", weight = 1 },
	{ name = "Bandage", kind = "tool", weight = 3 },
	{ name = "Drink", kind = "tool", weight = 3 },
	{ name = "Food", kind = "tool", weight = 3 },
	{ name = "Biomass", kind = "biomass", weight = 2 },
}

-- ---------------------------------------------------------------------------------------
-- Player movement
-- ---------------------------------------------------------------------------------------
GameConfig.Player = {
	WalkSpeed = 12,
	SprintSpeed = 20,
}

-- ---------------------------------------------------------------------------------------
-- Weapons
-- ---------------------------------------------------------------------------------------
GameConfig.Machete = {
	Damage = 25,
	ServerRange = 10, -- authoritative hit range (a touch more generous for latency)
	ServerCooldown = 0.55,
	ClientRange = 9, -- client target-selection range
	ClientCooldown = 0.6,
	ClientConeDot = -0.5, -- ~120 degree forward cone for target selection
	-- Default Roblox slash animation (from the official "Sword Fighting" sample kit).
	-- The kit's only other built-in swing ("Lunge") raises a leg mid-attack, which reads
	-- oddly for a quick melee swing, so instead we alternate the same Slash clip between
	-- a normal-speed and a faster playback for swing variety.
	SwingAnimationId = "rbxassetid://522635514",
	SwingAnimationSpeeds = { 1, 1.35 },
}

GameConfig.Pistol = {
	Damage = 15,
	Range = 100,
	ServerCooldown = 0.25,
	ClientCooldown = 0.3,
	StartingAmmo = 12,
}

-- ---------------------------------------------------------------------------------------
-- Structures (shop + placement). One table read by the client cost display, the server
-- crafting handler, and the server placement handler alike.
-- ---------------------------------------------------------------------------------------
GameConfig.Structures = {
	["Wall"] = {
		Cost = 20,
		Health = 150,
		Size = Vector3.new(6, 8, 1),
		Color = Color3.fromRGB(95, 85, 75),
		Material = Enum.Material.Concrete,
		Electric = false,
	},
	["Electric Fence"] = {
		Cost = 40,
		Health = 80,
		Size = Vector3.new(6, 6, 0.4),
		Color = Color3.fromRGB(210, 210, 70),
		Material = Enum.Material.Metal,
		Electric = true,
	},
}

GameConfig.Building = {
	GridSize = 1, -- fine free-placement grid, fallback when not snapping to a neighbor
	SnapRadius = 8, -- studs; magnet range onto an existing structure
	MaxReach = 30, -- studs; how far from the player the cursor can place
	ConsoleInteractRange = 15,

	-- Placement ghost appearance
	GhostValidColor = Color3.fromRGB(0, 200, 90),
	GhostInvalidColor = Color3.fromRGB(220, 40, 40),
	GhostValidTransparency = 0.25,
	GhostInvalidTransparency = 0.45,
}

GameConfig.ElectricFence = {
	Damage = 8,
	TickInterval = 1.0,
	Padding = Vector3.new(3, 3, 3), -- box padding, since CanCollide keeps enemies from overlapping
}

-- ---------------------------------------------------------------------------------------
-- Enemies (Mycomorph variants). Data-driven: adding a variant is a new row here, no code.
-- ---------------------------------------------------------------------------------------
GameConfig.Enemies = {
	Variants = {
		["Basic"] = {
			DisplayName = "Spore-walker",
			MaxHealth = 100,
			WalkSpeed = 13,
			TorsoColor = Color3.fromRGB(45, 80, 45),
			HeadColor = Color3.fromRGB(0, 255, 100),
			SpawnWeight = 7, -- out of 10
		},
		["Fast"] = {
			DisplayName = "Sprout Runner",
			MaxHealth = 50,
			WalkSpeed = 22,
			TorsoColor = Color3.fromRGB(130, 0, 180),
			HeadColor = Color3.fromRGB(255, 0, 255),
			SpawnWeight = 3,
		},
	},

	Spawn = {
		Distance = 110, -- studs from the Purifier
		Interval = 8, -- seconds between spawns during the night
	},

	Ai = {
		TickInterval = 0.5,
		DetectionRange = 45, -- switch target from Purifier to a player within this range
		PurifierAttackRange = 9,
		PurifierAttackCooldown = 1.5,
		PurifierDamage = 5,
		PlayerAttackRange = 5,
		PlayerAttackCooldown = 1.0,
		PlayerDamage = 10,
	},

	DespawnDelay = 1.5, -- seconds a corpse lingers after death
}

-- ---------------------------------------------------------------------------------------
-- Bio-Recall protocol (team-wipe rewind)
-- ---------------------------------------------------------------------------------------
GameConfig.BioRecall = {
	DeathCheckInterval = 1, -- seconds between team-wipe checks
	DramaticPause = 3, -- seconds the overlay shows before the world is restored
	-- Items gathered/crafted during a failed day are discarded on recall (persistent Scrap
	-- is restored from the snapshot separately, so it is not listed here).
	DiscardedOnRecall = {
		["Wall"] = true,
		["Electric Fence"] = true,
		["Spore Biomass"] = true,
	},
}

-- ---------------------------------------------------------------------------------------
-- Tuning: weapon grip & holster offsets
-- All angles are in DEGREES for readability; the scripts convert to radians.
-- ---------------------------------------------------------------------------------------
GameConfig.WeaponTuning = {

	-- Scrap Machete -- grip in the player's hand
	-- Pos   = where the handle centre sits relative to the hand attachment
	-- Rot   = X/Y/Z Euler rotation of the handle (degrees)
	MacheteGrip = {
		PosX = 0, PosY = -1.3, PosZ = 0,
		RotX = 15, RotY = 0, RotZ = 0,
	},

	-- Improvised Pistol -- grip in the player's hand
	PistolGrip = {
		PosX = -0.5, PosY = -0.25, PosZ = 0,
		RotX = 0, RotY = -90, RotZ = 0,
	},

	-- Scrap Machete -- holster on the player's back (while unequipped)
	-- Pos is relative to the UpperTorso/Torso centre
	MacheteHolster = {
		PosX = 0.25, PosY = 0, PosZ = 0.6,
		RotX = 225, RotY = 90, RotZ = 0,
	},
}

return GameConfig
