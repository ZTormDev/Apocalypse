# Game Design Document (GDD): Spore Tide Dawn

This document defines the conceptual vision, mechanics, setting, and structure of our game, **Spore Tide Dawn**. It is designed to capture the essence of the original survival game while completely reimagining its theme, names, and lore to create a 100% original IP and avoid accusations of copying.

---

## 1. Lore and Setting: The Mycelium Plague
Forget the typical gray city with classic zombies.

**Spore Tide Dawn** is set in a post-apocalyptic world where a meteorite carrying a cosmic fungus, the **Star Mycelium**, infected the planet. The air is saturated with toxic spores. The infected aren't ordinary undead; they are **Wildlings (Mycomorphs)**, mutants whose bodies have fused with plants, parasitic fungi, and glowing spores.

* **Visual Style:** Abandoned urban zones reclaimed by nature, covered in bioluminescent moss, giant mushrooms that glow at night (purple, green, and cyan tones), and a dense toxic fog surrounding the map.
* **The Danger of the Air:** The outside air is poisonous. Players need to stay near their base or use filter masks to survive outdoors.

---

## 2. Equivalence Table (Originality vs. Essence)
To ensure originality, we've mapped each key element of the base game to a unique concept within our universe:

| Original Concept | Equivalent in "Spore Tide Dawn" | Reason and How It Works |
| :--- | :--- | :--- |
| **Zombies** | **Wildlings / Mycomorphs** | Mutants fused with vegetation and bioluminescent spores. |
| **Generator** | **The Toxin Purifier (Tox-Filter)** | Central machine that cleans the air and generates an "Oxygen Dome" safe zone around the base. |
| **Gasoline / Fuel** | **Biomass Catalyst / Ether Cells** | Refined organic element that keeps the purifier running. |
| **Crafting Table** | **Assembly Console** | Tech station for forging defenses and tools. |
| **Emeralds (Currency)** | **Prism Shards** | Crystals formed by the meteorite's radiation, used as currency. |
| **Traveling Merchant** | **The Silent Scavenger** | A nomadic survivor in a hermetic protection suit who trades gear. |
| **Power Plants (4/4)**| **Vent Towers** | Regional purifier towers. Reactivating them cleans the air of entire quadrants. |
| **Radio Tower** | **Orbital Comms Array** | Satellite antenna to request heavy cargo drops from space. |
| **Radio Part** | **Decrypter Core** | Tech device needed to repair the Orbital Comms Array. |
| **Bandit Outpost** | **Exiled Outpost** | Settlements of hostile humans immune to spores due to minor mutations. |
| **Escape (Day 100)** | **Starlink Sync** | Instead of escaping, "Day 100" unlocks full space communication, enabling a "Prestige" mode or simply infinite survival with massive buffs. |

---

## 3. Redesigned Game Loop (The Core Loop)

### Day Phase: Gathering and Oxygen (6:00 AM - 6:00 PM)
* Players venture out to explore the ruins of the city.
* **Oxygen Mechanic:** Outside the base, players' oxygen tanks slowly deplete when they enter zones with high spore density. They must loot air filters or return to the base's protective dome to recharge.
* **Objectives:** Gather scrap, prism shards, biomass for the purifier, and blueprints.

### Night Phase: The Spore Tide (6:00 PM - 6:00 AM)
* As night falls, the environment's fungi glow intensely and release a huge amount of spores that enrage the **Wildlings**.
* Waves of Mycomorphs attack the base trying to destroy the **Purifier**.
* Players defend using weapons and tech traps built inside the dome.

---

## 4. Death Checkpoint System: "Dome Reset"
We want players to never lose their run when they die. This is justified perfectly through the lore:

* **The Cloning Protocol (Bio-Recall):** The Purifier has an emergency life-support module. At the start of each morning (6:00 AM), the system scans and saves the players' DNA and gear.
* **The Time/Physical Loop:** If the whole team dies during the night:
  1. The Purifier activates the **Bio-Recall** protocol.
  2. The players' bodies are reconstituted at the base in their exact state from 6:00 AM that morning.
  3. **Consequence:** The base returns to the state it was in when the day started. You lose the materials gathered *during that failed day*, but keep all progress, previous upgrades, and accumulated builds from the day before.
  4. This prevents the game from softlocking and gives the player infinite chances to redesign their defense strategy for that specific night.

---

## 5. The Purifier: Mechanics and Fuel
The Purifier is the heart of the base. If it shuts down or is destroyed, the base becomes uninhabitable.

* **Protection Dome:** Its level determines the diameter of the safe area where players can breathe without filters and where electric defenses work.
* **Fuel Consumption:** Consumes Biomass Catalyst. If it runs out of fuel:
  * The air dome shrinks.
  * Poisonous fog enters the base, dealing constant damage to players without masks.
  * Wildlings gain health regeneration inside the toxic area.
* **Maintenance:** If Wildlings destroy the Purifier, it enters "Emergency Mode" (minimum survival dome) and players must spend valuable scrap to manually reactivate it.

---

## 6. Class System (Reimagined)
All classes start with a **Scrap Machete** instead of a baseball bat, keeping the melee essence but with a sharper, more industrial design.

1. **Techsmith - *Ex-Engineer*:**
   * *Ability:* Places mini repair drones that heal damaged structures.
   * *Passives:* +25% structure durability, repairs structures 50% faster.
2. **Kineticist - *Ex-Psychic*:**
   * *Ability:* Creates a temporary telekinetic barrier that repels projectiles and pushes back Wildlings.
   * *Passives:* Rechargeable personal energy shield.
3. **Inoculator - *Ex-Necromancer*:**
   * *Ability:* Fires darts that infect a Wildling, making it attack its allies for a short time.
   * *Passives:* Partial immunity to toxic fog zones without a mask.
4. **Tactician - *Ex-Operator/Commander*:**
   * *Ability:* Deploys a radar that reveals enemy weak points in the area, increasing the whole team's critical damage.
   * *Passives:* Increases nearby allies' weapon reload speed.
5. **Wasteland Hunter - *Ex-Outlaw*:**
   * *Ability:* Starts with a bolt-action hunting rifle and can craft special improvised ammo.
   * *Passives:* +15% movement speed while exploring outside the dome.

---

## 7. Enemies: Mycelium Plague Variants
Zombies are redesigned visually and mechanically under the spore concept:

* **Basic Spore-walker:** Humanoid covered in vegetation. Slow basic attack.
* **Fast Sprout Runner:** Recently infected, with exposed roots that give it extreme speed.
* **Spore Bloater:** Its torso is a giant inflated mushroom. On death, it bursts, releasing a cloud of acidic spores that damages structures and slows players.
* **Tox-Spitter:** Fires acidic sap projectiles at long range. Can climb walls.
* **Bark Guard - *Ex-Riot*:** Wildling fused with reinforced bark and scrap metal. Immune to light frontal damage.
* **Screecher - *Ex-Screamer*:** Its head is a giant flower that opens to emit a sonic shriek that draws every Wildling in the sector.

---

## 8. Map Milestones (Regional Progression)
For the map to have clear objectives, players must repair old infrastructure:

1. **Vent Towers (4 total):** Reactivating each one permanently purifies the air in a map quadrant, removing the need for gas masks in that area and reducing spore density (making local Wildlings weaker).
2. **Orbital Comms Array:** Located at a fixed, dangerous point. To repair it, you need the **Decrypter Core**, hidden in the *Exiled Outpost*.
   * *Effect when repaired:* Unlocks a console at the base from which you can request "Orbital Supply Crates" (with rare blueprints and mythic weapons) in exchange for prism shards.
