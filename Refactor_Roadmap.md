# Refactor Roadmap: Scalable & Modular Architecture

This roadmap plans a full pass over the existing codebase (built during the Phase 1-4 prototype
and the subsequent asset/polish pass) to make it scalable, professional, and modular — without
changing any observable gameplay behavior. It's organized so each phase can be done, tested, and
committed independently.

Current state for reference: all gameplay code lives in flat folders synced via Rojo
(`src/server/`, `src/starterplayer/`, `src/shared/<ToolName>/`), as seven server Scripts, four
client LocalScripts, and five per-Tool LocalScripts. It works, but was written incrementally
across many feature requests, so responsibilities and constants ended up duplicated across files.

---

## Problems identified in the current codebase

1. **Duplicated placement geometry.** `computeSnappedCFrame`, `isWithinBuildZone`, and
   `isObstructed` are hand-copied between `BuildManager.server.luau` (authoritative) and
   `Wall/BlueprintClient.client.luau` (preview) — the comments even say "mirrors the server
   exactly." Any future tweak has to be made twice, and one day it won't be.
2. **Duplicated remote/folder bootstrap.** Every manager repeats the same
   `FindFirstChild(name) or Instance.new(...)` dance to set up its own Folder + RemoteEvents
   (`BuildEvents`, `CombatEvents`, `ScrapEvents`, `SporeEvents`, `BioRecallEvents`). Six copies of
   the same boilerplate.
3. **Duplicated/drifting constants.** `STRUCTURE_COSTS` in `BuildController.client.luau` is a
   second hand-maintained copy of `STRUCTURES[...].Cost` in `BuildManager.server.luau`. Weapon
   damage/cooldown/range numbers, enemy stats, and Purifier constants are similarly scattered as
   inline magic numbers with no single source of truth.
4. **Monolithic scripts covering multiple responsibilities.** `TimeAndPurifierManager.server.luau`
   (~400 lines) owns the day/night clock, the Purifier's fuel/health/dome-radius simulation, *and*
   the Biomass Catalyst pickup economy — three independent systems in one file.
   `BuildManager.server.luau` owns the shop/crafting economy, the console UI hookup, the placement
   math, *and* the Electric Fence damage tick.
5. **Imperative, non-data-driven content.** `MycomorphManager.buildMycomorph` hand-builds every
   part or a Wildling with inline `if variantType == "Fast"` branches. Adding a third enemy variant
   means editing procedural code instead of adding a row to a table.
6. **Repeated tag/name string literals.** `"Mycomorph"`, `"Structure"`, `"ElectricFence"` are typed
   out as raw strings in multiple files — a typo silently breaks tagging with no error.
7. **Duplicated per-player init boilerplate.** `CombatManager` and `TimeAndPurifierManager` each
   have their own `Players.PlayerAdded` hookup to initialize a different player attribute
   (`PistolAmmo`, `FilterOxygen`). No single place owns "what happens when a player joins."
8. **No shared visual-effect helpers.** The holster-clone pattern (`MacheteClient`) and the
   muzzle-flash toggle pattern (`PistolClient`) are one-off, non-reusable code even though future
   weapons will want the same kind of cosmetic tooling.
9. **No static typing.** Nothing uses `--!strict` or type annotations, so refactors like this one
   currently rely entirely on manual review to catch mismatched signatures.
10. **Flat Rojo folders won't scale.** `src/server/` and `src/shared/` are flat today (7 and 5
    entries respectively); fine now, unwieldy once there are 20+ systems.

None of these are bugs — the prototype works today, verified end-to-end this session. This is
about the *next* phase of development being sustainable.

---

## Phase 0 — Shared Foundations (do this first, touches no gameplay logic yet)

Build the shared infrastructure that later phases will slot into. Each item is additive (new
modules), so nothing existing breaks until Phase 1 starts wiring things up to use them.

- **`src/shared/Config/GameConfig.luau`** — single source of truth for every tunable number
  currently duplicated or scattered: weapon damage/range/cooldown, structure cost/health/size,
  enemy stats, Purifier fuel/dome constants, Bio-Recall timings. Both client and server require
  the same module.
- **`src/shared/Tags.luau`** — exports `Tags.Mycomorph`, `Tags.Structure`, `Tags.ElectricFence`
  as constants instead of raw strings.
- **`src/shared/Net.luau`** — one helper (`Net.getRemoteFolder(name)`, `Net.getEvent(folder, name)`)
  that replaces the six hand-copied "find-or-create Folder/RemoteEvent" blocks with a single
  declarative call per manager.
- **`src/shared/PlacementGeometry.luau`** — extracts `computeSnappedCFrame`, `isWithinBuildZone`,
  and `isObstructed` verbatim out of `BuildManager.server.luau`, required by *both* the server
  (authoritative) and `BlueprintClient.client.luau` (preview). Eliminates problem #1 entirely —
  the highest-value single change in this roadmap, since a preview/server mismatch is a real bug
  class, not just a style issue.
- Turn on `--!strict` in new modules from the start; don't retrofit old scripts yet (that's Phase 4).

**Verification:** no gameplay change expected. Smoke-test: build a Wall/Electric Fence, confirm
placement still snaps/rotates/rejects exactly as before.

---

## Phase 1 — Server-Side Modularization

Split each monolithic manager into single-responsibility modules, orchestrated by a thin Script.
Directory shape (mirrors Rojo's folder = Roblox-folder convention):

```
src/server/
  World/
    WorldClock.server.luau        -- day/night/time-of-day loop only
    PurifierCore.server.luau      -- fuel/health/dome-radius simulation + visual flash
    BiomassSpawner.server.luau    -- Biomass Catalyst pickup economy
  Building/
    BuildManager.server.luau      -- thin: wires remotes to the modules below
    StructureDefinitions.luau     -- STRUCTURES data table (from GameConfig)
    ConsoleShop.server.luau       -- craft-for-Scrap remote handler
    ElectricFenceDamage.server.luau -- the damage tick
  Combat/
    CombatManager.server.luau     -- unchanged in behavior, now requires GameConfig
  Enemies/
    MycomorphManager.server.luau  -- spawn loop + AI loop only
    MycomorphFactory.luau         -- data-driven part/Humanoid builder (see Phase 3)
  Player/
    PlayerStateManager.server.luau -- single PlayerAdded hook: FilterOxygen + PistolAmmo init
  BioRecallManager.server.luau    -- unchanged shape, now requires GameConfig/Net
  ScrapWallet.luau                -- unchanged (already the right pattern)
```

Each split is mechanical (move code, add `require`s) with **zero intended behavior change** —
this phase is refactoring, not redesigning. Do it one system at a time, verifying in Play mode
after each (the existing manual test patterns from this session — craft/build/combat/Bio-Recall
loops — double as the regression suite).

---

## Phase 2 — Client-Side Modularization

- `BlueprintClient.client.luau` (Wall + Electric Fence) requires `PlacementGeometry` from Phase 0
  instead of its own copy — the two files become nearly identical thin wrappers, which raises the
  question of whether they should just be *one* shared LocalScript parameterized by `Tool.Name`
  (they already read `structureType = Tool.Name`, so this is very close to already being unified).
- **`src/shared/ToolEffects.luau`** — extract the holster-clone helper (from `MacheteClient`) and
  the flash/particle-toggle helper (from `PistolClient`) into reusable functions, so the next
  melee or ranged weapon doesn't reimplement them.
- `BuildController.client.luau` reads costs from `GameConfig` instead of its own
  `STRUCTURE_COSTS` table (kills problem #3 for good).
- `CustomHotbar.client.luau` and `PlayerSporeFilter.client.luau` stay structurally as-is (they're
  already single-responsibility); just point their magic numbers at `GameConfig` where relevant.

---

## Phase 3 — Data-Driven Content

With `GameConfig` centralized (Phase 0) and `MycomorphFactory` extracted (Phase 1), turn the
remaining imperative branches into table-driven definitions:

- Enemy variants (`Spore-walker`, `Sprout Runner`, and future ones) become rows in a
  `GameConfig.Enemies` table (health, speed, color, spawn weight) that `MycomorphFactory` reads
  generically instead of `if variantType == "Fast"` branching.
- Structures (`Wall`, `Electric Fence`, future ones) already mostly live in one table
  (`STRUCTURES`) — move it into `GameConfig` and confirm both client cost-display and server
  crafting/building read the same table.
- Weapons (`Scrap Machete`, `Improvised Pistol`, future ones) get the same treatment: damage,
  range, cooldown as config rows instead of scattered `local X = ...` constants per script.

This is what makes adding new content (a second melee weapon, a third enemy, a new structure) a
data change instead of a multi-file code change — directly enabling the "beyond MVP" roadmap
items already noted as future work (more enemy variants, classes, Prism Shards currency).

---

## Phase 4 — Tooling & Quality

- Retrofit `--!strict` and parameter/return type annotations onto the now-smaller, single
  responsibility modules from Phases 1-2 (much easier post-split than on the original monoliths).
- Add a `selene.toml` + StyLua config for consistent linting/formatting now that the Rojo CLI
  toolchain is already in place (same npm-based install path used for Rojo itself).
- Turn this session's manual Play-mode verification steps (movement, pose, combat, crafting,
  building snap/reject, Bio-Recall full cycle) into a written **smoke-test checklist** doc
  (`Testing_Checklist.md`) so regressions are caught the same way every time, by anyone.
- Update `default.project.json` to match the new nested folder structure from Phase 1.

## Phase 5 — Documentation

- Add `Architecture.md` describing the module boundaries above (what owns what, what requires
  what) so future changes land in the right file on the first try.
- Keep `Prototype_Roadmap.md` and `Game_Design_Document.md` as the gameplay/design source of
  truth; this new doc is purely about code organization.

---

## Suggested execution order

Phase 0 unblocks everything else and fixes the one real correctness risk (#1) — do it first.
Phases 1-2 are independent of each other and can interleave. Phase 3 depends on Phase 0's
`GameConfig` existing. Phase 4-5 are cleanup once the shape has settled.

Given this is all synced live through Rojo now, each phase can be committed as its own git commit
with a clean diff, and reverted independently if something regresses.
