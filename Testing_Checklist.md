# Smoke-Test Checklist

Run this after any nontrivial change to confirm the core loops still work. It's the same set of
manual checks used to verify the prototype during development, written down so a regression is
caught the same way every time. Everything is done in Studio Play mode (F5).

Before playing, if you edit scripts through Rojo: make sure `rojo serve` is running and the
Studio plugin shows **Connected**, so the latest source is synced in.

## 0. Clean start
- [ ] Press Play. Console (View > Output) shows **no red errors**.
- [ ] Console prints `Bio-Recall snapshot saved at dawn (Day 1).` shortly after start.
- [ ] The character spawns as the survivor rig, stands in a natural pose (arms down), and can
      walk with WASD.

## 1. Purifier / dome / time
- [ ] The Purifier model is visible with its glowing core; the air dome surrounds the base.
- [ ] The HUD panel (left) shows Day/time counting up, and Mask Filter / Purifier Fuel /
      Purifier Health bars.
- [ ] Walk outside the dome: the Mask Filter bar drains; once empty, health ticks down. Walk
      back inside: the filter recharges.

## 2. Economy pickups
- [ ] Find a green Biomass Catalyst canister out past the dome, press **E** to store it.
- [ ] Carry it near the Purifier and drop it (**F**): fuel jumps up and the core flashes green.
- [ ] Find a Scrap pile, press **E**; the HUD "Scrap:" count goes up (stacks, e.g. `Scrap: 5`).

## 3. Weapons
- [ ] Equip **Scrap Machete** (hotbar slot). It sits correctly in the hand; when unequipped it
      shows holstered on the back. Swing plays a sound.
- [ ] Equip **Improvised Pistol**. Firing plays the muzzle flash + sound; the HUD "Ammo:" count
      decreases and stops at 0.
- [ ] (At night) A machete hit and a pistol shot both damage a Wildling's health bar.

## 4. Enemies (night)
- [ ] Let the clock reach night (or set `IsNight`): console prints `Wildling Spawner started`.
      Wildlings spawn outside and walk toward the Purifier.
- [ ] A Wildling reaching the Purifier prints the attack line and the core flashes red; one
      reaching the player damages the player.
- [ ] Day returns: console prints `Stopping Wildling Spawner`, and existing Wildlings despawn.

## 4b. Enemy variety (data-driven)
- [ ] Over several spawns you see both `Spore-walker` (green, slower) and `Sprout Runner`
      (purple, fast) — roughly a 70/30 mix.

## 5. Building (shop + placement)
- [ ] Walk to the Assembly Console, press **E** to open the shop menu.
- [ ] Craft a **Wall** (costs 20 Scrap). Scrap decreases by 20; a Wall blueprint appears in the
      hotbar. Insufficient Scrap = nothing crafted.
- [ ] Equip the Wall blueprint: a green ghost follows the cursor. Press **R** to rotate.
- [ ] Point outside the dome or at the Purifier: the ghost turns **red** and clicking does
      nothing. Point at open ground inside the dome (ghost green) and click: the Wall builds and
      the blueprint is consumed (build mode exits).
- [ ] Place two Walls next to each other: the second **snaps flush** to the first. With them
      snapped, **R** hinges the rotation around the shared edge (not spinning in place).
- [ ] Craft + place an **Electric Fence** the same way. At night, a Wildling touching it takes
      damage (only while the Purifier has fuel).

## 6. Bio-Recall (team wipe)
- [ ] Build something, gather some Scrap, then let the character die (e.g. stay outside past 0
      filter, or set health to 0).
- [ ] The "BIO-RECALL PROTOCOL ACTIVATED" overlay fades in; after ~3s the base restores: the
      thing built that day is gone, Scrap/ammo revert to the dawn snapshot, the player respawns
      at full health, and the clock resets to 6:00 AM. Console prints the complete line.
- [ ] No orphaned `PlacementGhost` parts left in the Workspace after consuming a blueprint.

## Wrap-up
- [ ] Stop Play. Re-check Output for any warnings/errors that appeared during the run.
