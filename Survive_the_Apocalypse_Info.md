# Detailed Analysis: Survive the Apocalypse

This document contains a detailed analysis of the mechanics, classes, enemies, weapons, and game loop of **Survive the Apocalypse** (created by *Rubicon South*). This analysis will serve as a reference base for the development of our project.

---

## 1. General Overview
* **Developer:** Rubicon South
* **Genre:** Survival / Action / Base Defense
* **Place ID:** `90148635862803`
* **Universe ID:** `9098570654`
* **Main Objective:** Survive waves of zombies on a post-apocalyptic map, fortify a base, and complete a series of complex missions/requirements in order to **escape** via helicopter upon reaching **Day 100**.

---

## 2. Core Loop
The game is divided into daily day and night phases:

1. **Day Phase (Exploration and Looting):**
   * Players leave the base to loot city buildings for supplies (food, medicine, fuel, weapons, and building materials).
   * Daylight makes zombies less aggressive and less numerous.
2. **Night Phase (Defense and Combat):**
   * Zombies attack in waves. They become extremely aggressive and try to destroy the base and eliminate players.
   * It's vital to return to base and make use of the traps and fortifications built.
3. **Special Events:**
   * **Blood Moon:** Occurs recurrently (especially critical after day 50). Zombies get massive buffs to speed, health, and damage.

---

## 3. Base and Building Mechanics

The central base is the players' core survival hub and includes the following essential components:

### A. The Generator
* The base's power source; determines the visualization range of the **Map** (a craftable item).
* **Leveling:** Has up to 6 upgrade levels.
* **Fuel:** Must be fed with Common Fuel, Refined Fuel, or Nuclear Fuel.
* **Consequences:** If the generator runs out of fuel during the night, the horde becomes enraged (gains HP and damage buffs). If destroyed by zombies, it takes 1 to 3 nights to self-repair.

### B. The Crafting Table
Allows building defensive structures and essential utilities. Crafting cost scales with the number of active players.
* **Defense:** Electric Fences, Landmines, and military turrets (obtained by looting military bases).
* **Utilities:** Farm Plots for harvesting food, Shelves for storing items, and maps.
* **Equipment:** Crafting grenades, suppressors, etc.

---

## 4. Game Classes
Players can buy and equip different classes using the game's main currency (**Emeralds**) in the lobby or menu:

* **Guaranteed Bat:** All classes start with a baseball bat as their default basic weapon.
* **Engineer:** Highly recommended for co-op play. Their builds get +25% health, deal +20% damage, and repair structures twice as fast.
* **Necromancer:** Costs approximately 1000 emeralds. Summons helpers or has reanimation abilities.
* **Psychic:** Controls floating weapons and has a regenerating shield.
* **Outlaw:** Starts equipped with a Heavy Revolver.
* **Operator, Commander, Stalker:** Classes with tactical and military reconnaissance gear.
* **Upgrades and Perks:** Classes can equip one **Perk** at a time (melee damage buffs, health, fire rate). These are obtained by opening Perk crates or from the Perk shop.

---

## 5. Weapons and Loot System
Weapons are divided into **Melee**, **Guns**, and **Throwables**, ranging in rarity from Common to Mythic.

### A. Weapon Acquisition
* Random supply chests and barrels scattered across the map.
* Supply Drops (air drops).
* Purchases from the **Traveling Merchant**.

### B. Weapon Examples
* **Melee:** Bat, Knife, Crowbar, Riot Shield, Katana, Fire Axe, Chainsaw, Energy Sword, Power Hammer, Scythes.
* **Guns:** Pistols, shotguns (like the Ion Shotgun), assault rifles, heavy revolvers, special cannons, and the Railgun.
* **Weapon Upgrades:** A **Weapon Upgrader** exists to improve key stats such as damage, fire rate, and ammo capacity.

---

## 6. Enemies (Zombie Horde)
Enemies grow fiercer as days pass or when playing in **Hard Mode** (where zombies have better pathfinding AI and "Infested" variants appear).

* **Basic and Speedsters:** Runner (fast runners) and Crawler (crawlers).
* **Specials:**
  * **Bloater:** Explodes on death. Melee combat against them should be avoided.
  * **Screamer:** Calls more zombies with its scream. Should be eliminated as a priority (ideally in one shot).
  * **Hazmat & Riot:** Armored zombies or ones protected against environmental hazards.
  * **Phaser & Shadow Muscle:** Advanced variants with higher damage and mobility.
  * **Others:** Spitter (acid spitter), Muscle (high-health brute), Elemental, Electrified, and Skeleton.

---

## 7. Escape Requirements and Mechanics (How to Win)
To successfully complete a run and win the game, the team must meet three main objectives:

1. **Repair 4/4 Power Plants:** Randomly scattered across the map.
2. **Repair the Radio Tower:**
   * Players must find the **Radio Part**, which spawns inside chests at the **Bandit Outpost**.
   * Bring the part to the Radio Tower to repair it.
3. **Survive at least 100 days:** Endure increasingly complex waves.

Once all three requirements are met, a rescue helicopter arrives at the Radio Tower. Players must climb the rope to escape and end the run.

### Victory Rewards
* **Standard Victory:** 15 Emeralds per player.
* **First Victory Bonus:** 40 total Emeralds (including the "Escape" badge reward).
* **Solo Victory Bonus:** 25 extra Emeralds ("Soloist" badge).

---

## 8. The Map and Points of Interest (POIs)
The map combines fixed positions with randomly generated locations each run.

### Fixed Locations
* **Player Base:** The central point of defense.
* **Military Base:** Contains excellent tactical loot and turrets, but is heavily guarded.
* **The Cave:** Located in the forest area.

### Random Locations
* **Bandit Outposts:** Areas marked in orange where hostiles (raiders) spawn. Contains the radio components needed to win.
* **Power Plants:** Structures that must be reactivated.
* **The Radio Tower:** Location of the final rescue.
* **Special Zones:**
  * **The Forest:** Located in the lower-right part of the map, home to the Cave, the *Overgrown Bandit Outpost*, and the *Alien Forge*.
  * **Irradiated Zone:** Requires a gas mask to survive the harmful green night air.
