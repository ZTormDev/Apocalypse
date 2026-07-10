# Architecture

Code organization for *Spore Tide Dawn*. This describes where things live and what depends on
what, so a change lands in the right file the first time. Gameplay/design intent lives in
`Game_Design_Document.md` and `Prototype_Roadmap.md`; this doc is purely about code structure.

Everything is synced to Roblox Studio through Rojo (`default.project.json`). Source lives on
disk under `src/`; run `rojo serve` and connect the Studio plugin to edit live.

## Folder → Roblox mapping

| Disk (`src/`)        | Roblox location                         | Contents |
| :------------------- | :-------------------------------------- | :------- |
| `shared/`            | `ReplicatedStorage.Shared`              | Modules used by both client and server |
| `server/`            | `ServerScriptService`                   | Server systems (nested by domain) + `modules/` |
| `starterplayer/`     | `StarterPlayer.StarterPlayerScripts`    | Client UI / HUD LocalScripts |
| `tools/<Tool>/`      | `ReplicatedStorage.<Tool>` (the Tool)   | Per-tool client LocalScripts (injected into existing Tool instances) |
| `tools/_shared/`     | (shared by multiple Tools)              | `BlueprintClient` — one script mapped into both buildable Tools |

Non-script assets (the Purifier model, the weapon meshes, the `StarterCharacter` rig, the
`SporeDomeMesh`, the Tool handles) are **not** in source — they live in the saved place and Rojo
leaves them alone via `$ignoreUnknownInstances`.

## Shared modules (`ReplicatedStorage.Shared`)

The dependency floor. No shared module depends on a server or client script.

- **GameConfig** — the single source of truth for every tunable number (weapons, structures,
  enemies, purifier, economy, bio-recall). Change balance here, once. Required by nearly
  everything.
- **Tags** — CollectionService tag name constants (`Mycomorph`, `Structure`, `ElectricFence`).
- **Net** — context-aware RemoteEvent folder/event access: creates on the server, waits on the
  client. Replaces per-manager bootstrap boilerplate. Call `Net.event(folderName, eventName)`.
- **PlacementGeometry** — the build-placement math (snap + magnet + hinge rotation, zone check,
  obstruction check). Required by **both** the server placement handler and the client ghost
  preview, so they can never disagree. Depends on GameConfig + Tags.
- **ToolEffects** — reusable client cosmetic helpers (currently the weapon back-holster).

## Server (`ServerScriptService`)

Each system is an independent auto-running Script, single-responsibility, reading tunables from
GameConfig and remotes via Net. They coordinate through Workspace instances (the `Purifier`
part), `ReplicatedStorage.SporeTideState` attributes, and the shared runtime modules below —
not through direct references to each other.

- `World/WorldClock` — day/night clock, `IsNight`/`DayNumber`, lighting.
- `Base/PurifierManager` — builds the Purifier + dome; runs the fuel/health/dome-radius sim;
  owns the mask-filter oxygen + toxic damage; absorbs in-range biomass into fuel. Owns the
  purifier-related `SporeTideState` attributes.
- `Base/BiomassSpawner` — spawns/pickup(E)/drop(F)/beam for fuel canisters.
- `Economy/ScrapManager` — spawns/pickup(E)/drop(F) for Scrap piles.
- `Combat/CombatManager` — machete + pistol server-authoritative validation; owns `PistolAmmo`.
- `Enemies/MycomorphManager` — night spawn loop + AI loop (targeting/attacks).
- `Building/BuildManager` — Assembly Console shop (craft-for-Scrap), placement handler (via
  PlacementGeometry), and the Electric Fence damage tick.
- `Recall/BioRecallManager` — dawn snapshot + team-wipe restore.

### Server runtime modules (`ServerScriptService.modules`)

- **ScrapWallet** — the one place that reads/writes the stacking Scrap Tool (currency).
- **BiomassRegistry** — the tracked set of live fuel canisters, shared between BiomassSpawner
  (writes) and PurifierManager (reads/absorbs) so neither rescans the Workspace.
- **MycomorphFactory** — data-driven Wildling builder; reads `GameConfig.Enemies.Variants`.
  Adding an enemy variant is a new config row, no code here.

## Client (`StarterPlayer.StarterPlayerScripts`)

- `PlayerSporeFilter` — the HUD panel (time, mask/fuel/health bars, ammo, scrap) + toxic screen
  tint. Read-only view of server state.
- `CustomHotbar` — the custom 5-slot hotbar (native backpack disabled).
- `BuildController` — the Assembly Console shop menu; costs read from GameConfig.Structures.
- `BioRecallUI` — the team-wipe overlay.

## Tool client scripts (`ReplicatedStorage.<Tool>`)

- `ScrapMachete/MacheteClient` — target selection + SFX + holster (via ToolEffects).
- `ImprovisedPistol/PistolClient` — aim direction + muzzle-flash cosmetic.
- `Scrap/ScrapDropScript` — F-to-drop.
- `_shared/BlueprintClient` — build-mode ghost preview + place; one script mapped into both the
  Wall and Electric Fence Tools, parameterized by `Tool.Name` + GameConfig.

## Adding content (the data-driven payoff)

- **New enemy variant** — add a row to `GameConfig.Enemies.Variants`. Done.
- **New structure** — add a row to `GameConfig.Structures`, create its blueprint Tool, and map
  `_shared/BlueprintClient` into it in `default.project.json`.
- **Balance change** — edit the number in `GameConfig`. It applies everywhere that reads it.

## Tooling

- `default.project.json` — Rojo project.
- `.luaurc` — Luau analysis defaults (non-strict project-wide; pure modules opt into `--!strict`).
- `stylua.toml` — formatting (`stylua src`).
- `selene.toml` — linting (`selene src`).
- `Testing_Checklist.md` — manual smoke test after changes.
