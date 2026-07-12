# Gameplay Roadmap: Spore Tide Dawn — From Solid Prototype to a Complete, Fun Game

This roadmap picks up where `Prototype_Roadmap.md` and `Refactor_Roadmap.md` left off (both are
done — see their status headers). It plans everything still needed to turn the current build into
a real, complete, fun gameplay loop, using `Game_Design_Document.md` as the design source of truth
and `Survive_the_Apocalypse_Info.md` (+ the `wiki/` folder) as the feature reference from the
original game we're reimagining.

**Explicitly out of scope here, on purpose:** map layout/POI design, 3D models, textures, and
sound/music. Every phase below is systems and mechanics only — placeholder geometry (the same
Neon-marker-part pattern already used for `ItemSpawnPoint`/`ScrapSpawnPoint`/`ZombieSpawnZone`) is
enough to build and test each system. Art and audio get their own pass later.

---

## Current Baseline (already built — not re-listed below)

Day/night phase cycle with a scaling horde and staggered multi-zone spawning; Purifier with fuel,
health, 5 levels, dome radius, and interactable refueling; oxygen/mask-filter mechanic; Bio-Recall
death-checkpoint reset; two starter weapons (melee + ranged) with headshots and hit feedback;
Scrap + Biomass Fuel gathering; Wall/Electric Fence building; two enemy variants with ragdoll
death; full Health/Hunger/Thirst survival loop with three consumables; a real Belt+Backpack
inventory with drag & drop; a central Points-based daily spawn system; an ammo economy; and a
matching custom UI (hotbar, backpack, prompts, status HUD, horde banner, crosshair).

This is a genuinely playable defend-and-survive loop already. Everything below is about turning it
into the *full* game the GDD describes.

---

## Extended Lore Equivalence Table

The GDD's Section 2 covers the systems already built. These are the additional pairings needed for
the phases below, kept consistent with the same "industrial + bioluminescent fungus" tone:

| Original Concept | Spore Tide Dawn Equivalent |
| :--- | :--- |
| Perks / Perk Crate | **Mutation Shards** — bio-augments equipped one-per-class, earned through play (no gambling/loot-box mechanic — see Phase A) |
| Survivors | **Stray Wanderers** — rescuable NPCs found periodically, recruited by dropping a specific item |
| Turret | **Sentry Spike** — automated defense structure |
| Farm Plot | **Spore Vat** — passive food-growing structure |
| Weapon Upgrader | **Fabrication Bench**, an upgrade to the Assembly Console |
| Weapon mods (Swift/Lethal/Glacial/Infernal/Electric) | **Catalyst Mods**: Kinetic (firerate), Caustic (damage), Crystalize (slow/freeze), Ignis Spore (burn), Static Bloom (chain damage) |
| Supply Drops | **Orbital Cargo Pods** |
| Blood Moon | **The Convergence** — a periodic, much larger horde night |
| Bandit Raid | **Exiled Raid** — the Exiled Outpost's hostiles periodically attack the base instead of a normal horde |
| Emeralds / Prism Shards | Already named in the GDD — see Phase A for earn sources |
| Barbed Wire / Bear Trap | **Spore Barrier** / **Snare Trap** |
| Watchtower / Floodlight / UV Light | **Overwatch Post** / **Ward Light** (Wildlings avoid lit ground at night) |
| Boost Pad | **Kinetic Pad** |
| Badges | Kept as-is (native Roblox badges) |

---

## Phase A — Classes & Progression (highest priority: the single biggest gap)

Right now every player is functionally identical. The GDD already designs 5 classes with unique
abilities and passives; nothing about them exists in code yet. This is the change most likely to
make the game feel like a *real* game rather than a tech demo.

- **`GameConfig.Classes`**: one row per class (Techsmith, Kineticist, Inoculator, Tactician,
  Wasteland Hunter) — starting kit, passive multipliers, ability id/cooldown/effect params.
- **Class selection**: a simple pick screen on first spawn (or a rotating default for solo
  testing), stored as a player attribute; `SurvivalService`/`CombatManager` read the passive
  multipliers where relevant (structure durability, repair speed, damage, movement speed, etc.).
- **`AbilityManager`** (new server module + a generic `AbilityClient`): one active ability per
  class on a cooldown, triggered by a keybind, server-validated like every other action here.
  Start with the two simplest to validate the architecture (Techsmith's repair drone, Wasteland
  Hunter's ammo craft), then add the rest.
- **Prism Shards** (currency): a `PrismWallet` module mirroring `ScrapWallet`. Earn sources: night
  survived, Wildling kills, milestone completion (Phase F). No Robux/invite-reward sources — this
  project has no monetization layer yet, and that's a separate concern from gameplay.
- **Mutation Shards (Perks)**: reuse the wiki's stat-modifier list (melee dmg, hunger drain,
  firerate, headshot dmg, speed, regen, etc.) as `GameConfig.Mutations` rows. Earned as horde-kill
  or milestone rewards (not purchased/gacha'd — keeps the fun without the predatory-monetization
  baggage of the original's crate system). One equipped per class at a time.

## Phase B — Expanded Threats

Only 2 of the GDD's 6 enemy variants exist. This phase makes nights meaningfully varied instead of
"more of the same two zombies."

- **Spore Bloater**: explodes on death (area damage + slows players/damages structures in radius)
  — needs an on-death-effect hook in `MycomorphFactory` (currently only ragdoll+despawn).
  **Tox-Spitter**: ranged attack + can climb (needs a distinct AI branch in `MycomorphManager`,
  since all current AI assumes melee-range contact). **Bark Guard**: frontal damage resistance
  (needs a hit-direction check in `CombatManager`'s damage application). **Screecher**: on
  detecting a player, pulls every Wildling in the zone toward that position (an aggro-broadcast
  hook). Each is a data row + one new, reusable AI behavior primitive — same data-driven pattern
  the two existing variants already use.
- **The Convergence** (Blood Moon equivalent): every N nights (config value), `HordeDirector`
  applies a large multiplier to zombie count/stats instead of the normal night curve, with its own
  warning banner variant.
- **Exiled Raid** (Bandit Raid equivalent): a rare night type where the horde is replaced/joined by
  hostile human NPCs with their own weapons instead of melee Wildlings — reuses the zone-spawn
  system with a different unit roster.

## Phase C — Weapon & Loadout Depth

- More weapons across melee and ranged (reuse the existing `Tool` + `PickupVfx` + `ItemDropSystem`
  pipeline — adding a weapon is now "a `GameConfig` row + a Handle," proven by how cheap the
  consumables were to add).
- **Rarity tiers** (Common → Mythic): a multiplier table applied to base weapon stats, surfaced as
  a colored name/border in the hotbar/backpack UI we already built.
- **Fabrication Bench**: an Assembly Console upgrade tier. Spend Prism Shards to roll one Catalyst
  Mod onto an equipped weapon (one active mod at a time, matching the original's design).
- **Throwables**: spore-lure and spore-repel devices (reflavored Molotov/Flashbang/Tear Gas) as a
  new equippable category with an arc-throw + area-effect pattern.

## Phase D — Base Defense Expansion

- **Sentry Spike** (Turret): auto-targets and fires at Wildlings in range, capped per-base by
  player count (mirrors the original's scaling table). Reuses `BuildManager`'s placement/ghost
  system plus a new server-side targeting loop similar to `MycomorphManager`'s AI loop, but firing
  outward instead of walking.
- **Snare Trap / Spore Barrier**: cheap, low-durability slow/damage structures for chokepoints.
- **Ward Light**: a placeable structure that suppresses Wildling aggro/pathing within its radius at
  night (a lighter-weight alternative to the dome for forward outposts).
- **Structure repair**: a tool + prompt that restores a damaged structure's HP over time/cost,
  since right now damaged structures have no recovery path except full destruction.

## Phase E — Economy & Progression Loop

- **Spore Vat** (Farm Plot): passive food generation over real time, capped count per base,
  reusing the "grows automatically, harvest resets timer" pattern from the wiki.
- **Assembly Console tiers**: gate structures/recipes behind console level (mirrors the original's
  Crafting Table levels 1-5), giving players a clear "what do I unlock next" progression axis.
- **Orbital Cargo Pods**: a periodic event (tied to Phase F's Comms Array milestone) that drops a
  better-loot crate defended by extra Wildlings, using the existing horde-warning UI pattern.

## Phase F — World Objectives (systems only, no map layout)

These map 1:1 to the GDD's Section 8 milestones, built exactly like the existing `ZombieSpawnZone`
placeholder-marker pattern — no actual map design needed to build and test the systems.

- **Vent Towers (4)**: a new `VentTowerPoint`-tagged marker + a repair/reactivation interaction
  (multi-stage, needs scrap/tools). Reactivating one reduces regional spore density — mechanically,
  a per-tower zone that lowers oxygen drain rate and/or Wildling spawn weight nearby.
- **Orbital Comms Array + Decrypter Core**: a fetch objective (the Core drops from the Exiled
  Outpost raid, Phase B) that repairs a console unlocking Orbital Cargo Pods (Phase E).
- **Starlink Sync** (Day-100 equivalent): per the GDD, this is deliberately *not* an escape/end-run
  — it's a prestige unlock. Reaching it grants a permanent buff track and the game continues
  (infinite survival), which fits this being a live base-defense loop rather than a run-based
  escape game.

## Phase G — Cooperative & Life Systems

- **Downed state**: right now a player at 0 HP is just dead (triggering the team-wipe check
  immediately). Add a "downed" intermediate state — crawl, can't fight, bleeds out over N
  seconds unless a teammate revives — before Bio-Recall's team-wipe logic kicks in. This is a
  meaningful co-op depth addition that the current all-or-nothing death lacks.
- **Stray Wanderers** (Survivors): NPCs that appear periodically, recruited by dropping a specific
  item near them, then follow the recruiting player or stay at base to passively loot/heal/fight —
  reuses the Humanoid-rig-clone pattern from `MycomorphFactory`, just non-hostile and player-aligned.

## Phase H — Environmental Systems

- **Spore Weather**: Toxic Fog (reduces Wildling detection range and player visibility — a config
  multiplier, no new geometry needed), Mycelial Discharge (a lightning equivalent that randomly
  "charges" a Wildling with a speed buff), Acid Rain (a periodic event that force-respawns
  breakables/Wildlings early, giving a burst of fresh loot).
- **Hard Mode toggle**: a lobby-level difficulty flag that scales `HordeDirector`'s curve harder
  and enables an "Infected" elite-variant tag on top of the Phase B roster.

## Phase I — Meta Polish (lower priority, do last)

- **Persistence**: Prism Shards, unlocked classes/mutations, and best-night-reached need a
  DataStore-backed player profile module — currently nothing survives a server restart. This is a
  hard dependency for Phases A/C/E/F actually *mattering* across sessions, so schedule it once
  those systems' shapes are locked in, not before.
- **Badges**: tie Roblox badges to real milestones (first Convergence survived, Vent Tower
  reactivated, Day 100/Starlink Sync, etc.) — cheap to add once the milestones themselves exist.
- **Daily quest board equivalent**: optional; only worth it once there's a lobby/hub screen to put
  it in.

---

## Suggested Execution Order

**A → B → C/D (parallel) → E → F → G → H → I.**

Phase A (classes) is both the most impactful for "fun" and the thing every later system should be
aware of (abilities interacting with structures, weapons, milestones), so it goes first. B
(threats) and C/D (weapons/defense) are independent of each other and can interleave — both just
need Phase A's data shape to exist so class passives can hook into them later. E depends on C/D
existing (nothing to spend Prism Shards on otherwise). F is self-contained but thematically pays
off more once E's Cargo Pods exist to reward it. G and H are additive polish that can slot in
anywhere once the core loop (A-F) is solid. I is explicitly last — it's the "make it stick across
sessions" layer, not new gameplay.

Each phase is independently testable in Play mode the same way prior phases were (per
`Testing_Checklist.md`'s pattern) — build it, verify the loop, commit, move to the next.
