# Prototype Roadmap (MVP): Spore Tide Dawn

This roadmap defines the phases needed to build a functional prototype (Minimum Viable Product - MVP) focused exclusively on critical gameplay mechanics, without worrying about detailed maps, complex 3D models, or final UI.

---

## Phase 1: Time Cycle and Purifier Zone (Core)
The goal of this phase is to have the basic container of the game working: time runs, and being outside the dome deals damage.

* **1.1 Day/Night Clock and Cycle:**
  * Central server script to control the game's time of day.
  * State changes in a continuous loop: Day (e.g. 3 minutes for testing) and Night (e.g. 3 minutes for testing).
* **1.2 The Purifier and the Air Dome:**
  * Create a basic object (a transparent cylinder or sphere) representing the clean-air dome area.
  * Client/server script that detects whether a player is inside or outside the protective zone:
    * *Inside:* No damage, mask filter regenerates.
    * *Outside:* The mask filter decreases; once it reaches 0, the player starts taking periodic spore damage.
* **1.3 Catalyst (Fuel) Consumption:**
  * The Purifier consumes a variable called `Catalyst` per second.
  * If it reaches 0, the size of the safe zone drastically shrinks to a minimum emergency radius.

---

## Phase 2: Enemy Movement and Assault AI
In this phase we introduce the basic threats that will attack both the Purifier and the players.

* **2.1 Wildling Spawner (Mycomorphs):**
  * A simple spawn point outside the base that activates only during the night.
  * Spawns zombies using basic Roblox models (Blocks with green/purple textures).
* **2.2 Basic Hostile AI:**
  * Behavior: The Wildling seeks and walks toward the **Purifier**. If a player gets in its line of sight, it switches targets to attack the player.
  * If the Wildling reaches the Purifier, it physically attacks the object, reducing its health (`PurifierHealth`).
* **2.3 Basic Variants:**
  * *Basic Spore-walker:* Normal speed, medium damage.
  * *Fast Sprout Runner:* Fast speed, low health.

---

## Phase 3: Combat and Basic Building
Players must be able to defend themselves and block the Wildlings' paths.

* **3.1 Basic Test Weapons:**
  * *Scrap Machete (Melee):* A simple Roblox Tool script that, on click, detects hits (Raycast or Touched) and deals damage to Wildlings.
  * *Improvised Pistol (Ranged):* A basic weapon that fires simple projectiles (Raycast), consuming ammo from the inventory.
* **3.2 Scrap Collection:**
  * Place interactive cubes ("Scrap Piles") on the map. On interaction (E key), the player receives an amount of `Scrap` in their inventory.
* **3.3 Assembly Console and Structures:**
  * Basic building interface: select a structure to place by paying `Scrap`.
  * Two structures to test:
    * *Basic Wall:* A solid barrier that blocks Wildlings' path and has health.
    * *Electric Fence:* Blocks passage and damages enemies on contact (requires the Purifier to have catalyst/energy).

---

## Phase 4: Bio-Recall Protocol (Save and Checkpoint)
The key mechanic to avoid losing the run and to restart the day.

* **4.1 Saved State at 6:00 AM (Snapshot):**
  * When the day starts (6:00 AM), the server stores in memory:
    * The state and positions of built structures (block type, HP, position).
    * Players' inventory, health, ammo, and prism shards.
    * The Purifier's fuel and HP.
* **4.2 Team Death Detection (Temporary Game Over):**
  * A script monitors the health of all active players.
  * If every player's health reaches 0 (especially during the night):
    * Time freezes.
    * An on-screen effect is shown ("Bio-Recall Protocol activated...").
* **4.3 State Restoration:**
  * Remove all active Wildlings.
  * Destroy all structures built *during the failed day* and re-instantiate the ones from the 6:00 AM Snapshot.
  * Revive players at the base with the inventory restored from the Snapshot.
  * Reset the clock to the start of that same day (6:00 AM).
