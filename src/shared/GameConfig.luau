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
	-- Night has no fixed duration -- it lasts exactly as long as the zombie horde does (see
	-- GameConfig.Enemies.Horde), ending the moment the last zombie dies. This is a safety cap
	-- only, in case the horde system stalls for any reason, so the game can't soft-lock at night.
	NightMaxDuration = 900,
	DawnDuration = 30, -- 30s transition night -> day

	DayStartHour = 6.0, -- ClockTime the day begins at (also used by Bio-Recall's reset)

	-- Lighting tint per phase (lerped across Dusk/Dawn). Slightly dust/rust-shifted off neutral
	-- grey for a subdued apocalyptic mood -- kept close to the original brightness so it reads
	-- as "dusty" rather than a heavy color grade. Night is kept bright enough to actually see
	-- (and fight the horde) by, with a cool blue-purple tint instead of near-black.
	NightAmbient = Color3.fromRGB(70, 65, 85),
	NightOutdoorAmbient = Color3.fromRGB(55, 52, 72),
	DayAmbient = Color3.fromRGB(118, 108, 96),
	DayOutdoorAmbient = Color3.fromRGB(122, 112, 98),
}

GameConfig.Purifier = {
	Position = Vector3.new(0, 6, 0),
	AnchorSize = Vector3.new(7.3, 12, 7.3), -- invisible collision/position anchor

	StartFuel = 100.0,
	MaxFuel = 100.0,
	StartHealth = 100.0,
	MaxHealth = 100.0,
	FuelDecayPerSecond = 0.3,

	MaxDomeRadius = 60.0, -- level 1 dome radius cap; each level adds DomeRadiusPerLevel on top
	MinDomeRadius = 12.0, -- emergency radius when fuel hits zero
	DomeLerpAlpha = 0.1, -- per-second interpolation toward the target radius

	RechargeRange = 20, -- studs within which a dropped Biomass Catalyst is absorbed
	RechargePerCanister = 25,

	-- Leveling: loading more fuel than the current capacity levels the Purifier up, carrying the
	-- leftover fuel into the new (larger) capacity and expanding the dome.
	MaxLevel = 5,
	FuelCapacityPerLevel = 40.0, -- added to MaxFuel per level above 1
	DomeRadiusPerLevel = 12.0, -- added to MaxDomeRadius per level above 1

	-- Interaction-based fueling (LoadFuelPrompt on the Purifier itself)
	LoadFuelHoldDuration = 0.5,
	LoadFuelActivationDistance = 10,
}

-- Server-authoritative mask filter / toxic damage (client only reads these for UI).
-- A full tank lasts ~4 min outside the dome (the new map spans ~500 studs from the Purifier, so
-- reaching the far spawn points and back needs real headroom) and refills from empty in ~1 min
-- inside it. Running the filter fully dry gives a ~25s grace window before it starts costing
-- health, instead of an instant death sentence.
GameConfig.Oxygen = {
	Max = 100.0,
	DrainPerTick = 0.2, -- per 0.5s tick outside the dome (~240s / 4 min for a full tank)
	RechargePerTick = 0.8, -- per 0.5s tick inside the dome (~60s to refill from empty)
	ToxicDamagePerTick = 2, -- once the filter is empty (~25s to kill from full health)
	TickInterval = 0.5,
}

-- ---------------------------------------------------------------------------------------
-- Economy: Biomass Catalyst (fuel) and Scrap (currency) pickups
-- ---------------------------------------------------------------------------------------
-- NOTE: spawning itself (counts/locations/frequency) is owned by the Points-based SpawnManager
-- (GameConfig.Spawning below) since the old ring-around-the-Purifier spawner was replaced. Only
-- the fields actually still read by BiomassSpawner/ScrapManager/ScrapPileFactory remain here.
GameConfig.Biomass = {
	ThrowVelocity = 25,
}

GameConfig.Scrap = {
	PerPile = 5,
	ThrowVelocity = 25,
	MaxHealth = 100,
}

-- ---------------------------------------------------------------------------------------
-- Survival: player Health (Humanoid.Health) + Hunger + Thirst (Player attributes, 0-100 each).
-- All three are server-authoritative; the client HUD only reads them.
-- ---------------------------------------------------------------------------------------
-- Baseline hunger lasts ~15 min and thirst ~10 min before hitting 0 while just walking around --
-- long enough to actually explore/fight/build between meals in a real session, instead of the
-- previous ~2-3 min drain that made sprinting for even a few seconds a death sentence. Sprinting
-- still costs noticeably more (2.5x), so pacing yourself still matters.
GameConfig.Survival = {
	MaxHealth = 100,
	MaxHunger = 100,
	MaxThirst = 100,
	TickInterval = 1.0, -- seconds per survival tick

	HungerDrainPerTick = 0.11, -- baseline hunger lost per tick while alive (~900s / 15 min to empty)
	SprintHungerMultiplier = 2.5, -- hunger drains this much faster while sprinting

	ThirstDrainPerTick = 0.17, -- baseline thirst lost per tick while alive (~600s / 10 min to empty)
	SprintThirstMultiplier = 2.5, -- thirst drains this much faster while sprinting

	StarveDamagePerTick = 2, -- health lost per tick once hunger hits 0 (~50s to kill from full health)
	DehydrateDamagePerTick = 2, -- health lost per tick once thirst hits 0 (~50s to kill from full health)
	HealthRegenPerTick = 0, -- health regained per tick while well-fed (disabled)
	HungerRegenThreshold = 50, -- hunger must be above this for health to regen
}

-- Consumable tools: hold left-click for HoldTime seconds, then apply the effect.
-- Bandage restores Health. Canned Beans mainly restores Hunger with a small Thirst bump;
-- Water Bottle restores Thirst only, no Hunger.
GameConfig.Consumables = {
	["Bandage"] = { HoldTime = 5, Heal = 25 },
	["Water Bottle"] = { HoldTime = 2, Hunger = 0, Thirst = 60 },
	["Canned Beans"] = { HoldTime = 2, Hunger = 40, Thirst = 10 },
}

-- One "Pistol Ammo" box grants this much to the player's PistolAmmo attribute. Kept below
-- StartingAmmo so a single lucky pickup doesn't trivialize ammo management for the rest of a
-- session -- multiple boxes are still needed to keep the pistol topped up over several nights.
GameConfig.Ammo = {
	PerBox = 20,
}

-- Inventory partition: the Belt (hotbar, always visible, the only equippable area) and the
-- Backpack (opened with B). Stacking tools (Scrap, Pistol Ammo) occupy 1 slot regardless of Amount.
GameConfig.Inventory = {
	BeltSize = 5,
	BackpackSize = 10,
}

-- ---------------------------------------------------------------------------------------
-- Central spawn system (SpawnManager). Loot spawns at tagged Points in the Workspace (not a
-- hardcoded ring) once per day: each dawn, a random percentage of ItemSpawnPoints and of
-- ScrapSpawnPoints (independently rolled) get an item/pile, and everything left over from the
-- previous day is cleared first.
-- ---------------------------------------------------------------------------------------
GameConfig.Spawning = {
	PositionJitter = 3, -- studs of random horizontal offset from the point's center
	MinDailyPercent = 50, -- lower bound of the per-day roll (% of points that get filled)
	MaxDailyPercent = 100, -- upper bound of the per-day roll
}

-- Weighted loot table for ItemSpawnPoints. `kind` selects the spawn factory:
--   "tool"    -> ItemPickupFactory (clones the named ReplicatedStorage Tool as a world pickup)
--   "biomass" -> BiomassFactory (the green fuel canister)
GameConfig.LootTable = {
	{ name = "Pistol Ammo", kind = "tool", weight = 3 },
	{ name = "Scrap Machete", kind = "tool", weight = 1 },
	{ name = "Bandage", kind = "tool", weight = 3 },
	{ name = "Water Bottle", kind = "tool", weight = 3 },
	{ name = "Canned Beans", kind = "tool", weight = 3 },
	{ name = "Biomass Fuel", kind = "biomass", weight = 2 },
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
	-- 20 dmg: kills a Basic zombie (100 HP) in 5 hits, a Fast zombie (50 HP) in 3 hits.
	Damage = 20,
	ServerRange = 10, -- authoritative hit range (a touch more generous for latency)
	ServerCooldown = 0.3,
	ClientRange = 9, -- client target-selection range
	ClientCooldown = 0.35, -- fast, snappy swings
	ClientConeDot = -0.5, -- ~120 degree forward cone for target selection
	-- Default Roblox slash animation (from the official "Sword Fighting" sample kit).
	-- The kit's only other built-in swing ("Lunge") raises a leg mid-attack, which reads
	-- oddly for a quick melee swing, so instead we alternate the same Slash clip between
	-- two fast playback speeds for swing variety. Speeds are high so each swing finishes
	-- within the short cooldown (the clip is ~0.5s at speed 1).
	SwingAnimationId = "rbxassetid://522635514",
	SwingAnimationSpeeds = { 1.6, 1.9 },
}

GameConfig.Pistol = {
	-- 25 dmg: kills a Basic zombie (100 HP) in 4 shots, a Fast zombie (50 HP) in 2 shots.
	Damage = 25,
	-- A headshot (raycast hits the "Head" part) multiplies damage -- 4x means a headshot alone
	-- (100 dmg) one-shots a Basic zombie and easily one-shots a Fast zombie.
	HeadshotMultiplier = 4,
	Range = 100,
	ServerCooldown = 0.25,
	ClientCooldown = 0.3,
	-- 16 = 4 basic kills' worth of pure body shots (or ~7-8 kills mixing in headshots); enough to
	-- lean on the pistol early without making the machete pointless as a backup.
	StartingAmmo = 16,
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
			WalkSpeed = GameConfig.Player.WalkSpeed, -- matches the player's normal walk speed
			TorsoColor = Color3.fromRGB(45, 80, 45),
			HeadColor = Color3.fromRGB(0, 255, 100),
			SpawnWeight = 7, -- out of 10
		},
		["Fast"] = {
			DisplayName = "Sprout Runner",
			MaxHealth = 50,
			WalkSpeed = (GameConfig.Player.WalkSpeed + GameConfig.Player.SprintSpeed) / 2, -- between the player's walk and sprint speed
			TorsoColor = Color3.fromRGB(130, 0, 180),
			HeadColor = Color3.fromRGB(255, 0, 255),
			SpawnWeight = 3,
		},
	},

	-- The night horde. Difficulty scales night after night: more total zombies and more
	-- simultaneously-active spawn zones. Zombies trickle in one at a time; a zone doesn't all
	-- spawn at once, and the next chosen zone only joins in once the current one has spawned
	-- ZoneAdvanceThreshold of its share. Night ends once every zombie is spawned AND killed.
	Horde = {
		SpawnInterval = 4, -- seconds between each individual zombie spawn
		ZoneAdvanceThreshold = 0.65, -- fraction of a zone's zombies spawned before the next zone starts

		-- Total zombies for a night = BaseZombies + ZombiesGrowthPerNight * (night - 1)
		BaseZombies = 6, -- night 1 (a small horde)
		ZombiesGrowthPerNight = 2,

		-- How many zones spawn at once, by night. First tier whose untilNight >= the night wins;
		-- a random count in [min, max] is picked (capped by how many zones actually exist).
		ZoneProgression = {
			{ untilNight = 1, min = 1, max = 1 }, -- night 1: one zone
			{ untilNight = 10, min = 2, max = 2 }, -- nights 2-10: two zones
			{ untilNight = 30, min = 2, max = 3 }, -- nights 11-30: two or three zones
			{ untilNight = math.huge, min = 3, max = 4 }, -- night 31+: three or four zones
		},

		ZoneSize = Vector3.new(40, 1, 16), -- flat rectangle footprint (X width, Y thickness, Z depth)
		ZoneDistance = 100, -- studs from the Purifier to each zone's center
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

	DespawnDelay = 30, -- seconds a ragdolled corpse lingers on the ground before despawning
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
		["Biomass Fuel"] = true,
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
