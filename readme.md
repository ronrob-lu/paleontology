# 🦖 PALEONTOLOGY — Unleash Prehistoric Giants Beneath Your Luanti World! 🦴

### **Turn Every Expedition Into a Jurassic Discovery. Dig Deep. Unearth History. Build Your Own Natural History Museum.**

What if every time you struck a shovel into the earth or crested a distant hill, a **colossal, 10-meter prehistoric dinosaur skeleton** could be waiting to be discovered?

Welcome to **Paleontology** — the ultimate zero-dependency fossil & excavation mod for **Luanti / Minetest**. Engineered from the ground up to work seamlessly on **every Luanti engine and game** out of the box, *Paleontology* transforms ordinary world generation into a breathtaking archaeological adventure!

---

## ✨ Blockbuster Features

* 🦴 **Colossal, Lifelike Dinosaur Fossils** — Encounter massive, 7-to-11-node-long horizontal skeletons lying flat in the earth, complete with articulated skulls, jaws, ribcages, dorsal spines, and sweeping tails, plus support for **Tyrannosaurus Rex, Apatosaurus, Triceratops, Stegosaurus, Parasaurolophus, and Velociraptor** specimens!
* ⛏️ **Dual Gameplay Modes (`"buried"` & `"exposed"`)** — Flip a single switch in `init.lua` to choose between hardcore underground prospecting (`buried`) or ready-made surface dig sites complete with cleared dirt-path pits and 2-node-high wooden fence enclosures (`exposed`)!
* 🌍 **Universal Cross-Game Compatibility** — Automatically detects **Minetest Game**, **MineClone2 / VoxeLibre / Mineclonia**, and custom Luanti games, dynamically adapting terrain nodes, paths, and fences without a single crash or missing texture.
* 🏛️ **100% Static & Immortal Relics** — Fossils are registered as lightweight, persistent static entities (`static_save = true`) with zero lag, zero mob AI overhead, and non-blocking collision boxes (`{0,0,0,0,0,0}`) so you can build glass museum floors or walk right around your excavation!
* 🎨 **Authentic Bone-White Fossil Patina** — Every specimen renders in striking ivory bone-white coloring with subtle ambient underground visibility so your discoveries gleam in the torchlight as you dig them out.
* 📡 **Field Expedition Alerts** — Optional proximity chat notifications alert nearby explorers when a newly generated prehistoric specimen is waiting nearby!
* 🚀 **Zero External Downloads Required** — Everything works right out of the box, powered by built-in procedural 3D `.obj` skeleton mesh generation and bundled dinosaur models.

---

## 💡 Why You Need This Mod

Vanilla underground exploration gets repetitive fast. Once you've seen one dirt layer or desert dune, you've seen them all.

**Paleontology changes the game forever:**
1. **Gives Digging & Exploring Real Purpose:** Every mining trip, desert trek, or landscaping project carries the thrill of stumbling across a prehistoric giant (`1 in 8` surface chunks by default).
2. **Instant Landmark & Base Inspiration:** Found a buried *Tyrannosaurus* or *Apatosaurus* beneath your plains? Excavate the pit, install glass viewing walkways, add floodlights, and turn your discovery into a server-wide tourist attraction!
3. **Drop-In Server Safe:** No heavy mob pathfinding, no destructive grieving, and no hard dependencies. Install it on a brand-new world or an existing multiplayer server in seconds.

---

## 🛠️ Installation Instructions

Getting started takes less than 30 seconds:

1. **Download or Clone** the `paleontology` folder into your Luanti / Minetest `mods/` directory:
   ```bash
   cd ~/.minetest/mods/   # or your Luanti mods directory
   git clone https://github.com/ronrob-lu/paleontology.git
   ```
2. **Enable the Mod:**
   * Launch **Luanti / Minetest**.
   * Select your world and click **Configure** (or **Select Mods**).
   * Check **Paleontology** (`paleontology`), click **Save**, and launch your world!
3. **Optional Admin Command:**
   * Want to preview a fossil immediately? Grant yourself `server` privilege and run:
     ```text
     /spawn_fossil exposed
     /spawn_fossil buried
     ```

---

## ⚙️ Configuration Guide (Switching Between Buried & Exposed Modes)

Switching how fossils generate in your world is effortless. Open [`init.lua`](init.lua) and edit the single configuration variable right at the top of the file:

```lua
-- Choose your gameplay style at the very top of init.lua:
PALEONTOLOGY.MODE = "buried"   -- DEFAULT: Buried 3-6 nodes underground (dig to find!)
-- PALEONTOLOGY.MODE = "exposed" -- Surface excavation pit + 2-node-high wooden fence enclosure!
```

### 🔍 Mode Comparison

| Mode | Where Fossils Spawn | Surface Appearance | Best For |
| :--- | :--- | :--- | :--- |
| **`"buried"`** *(Default)* | **3 to 6 nodes underground** beneath natural grass, dirt, or sand | Completely hidden — **no fences, no markers**. Players must excavate to uncover them! | Survival worlds, treasure hunters, realistic archaeology |
| **`"exposed"`** | **Right on the surface** inside a cleared dirt-path / sand excavation pit | Surrounded by a **2-node-high rectangular wooden fence enclosure** with corner posts and rails | Sightseeing, creative servers, roleplay worlds, instant landmarks |

### Additional Settings in `init.lua` (or `minetest.conf`)
* `PALEONTOLOGY.SPAWN_CHANCE = 8` — Controls rarity (`1` fossil per `8` surface mapchunks by default; set to `1` for every chunk!).
* `PALEONTOLOGY.NOTIFY_PLAYERS = true` — Set to `false` to disable chat alerts when players are near a fossil.
* `PALEONTOLOGY.NOTIFY_RADIUS = 200` — Distance in nodes for generation discovery notifications.
* `PALEONTOLOGY.PROXIMITY_RADIUS = 45` — Distance in nodes to alert players when walking near an existing fossil.

---

## 🎮 Compatibility List

**Paleontology** is built with an intelligent game-detection and node-fallback engine (`minetest.get_game_info().id` + `minetest.registered_nodes` verification) so it runs everywhere:

* ✅ **Luanti / Minetest 5.6+** *(5.6, 5.7, 5.8, 5.9, 5.10+)*
* ✅ **Minetest Game** (`minetest_game` — uses `default:dirt`, `default:dirt_with_grass`, `default:sand`, `default:fence_wood`, `default:wood`)
* ✅ **MineClone2 / VoxeLibre / Mineclonia** (`mineclone2` — uses `mcl_core:dirt`, `mcl_core:grass`, `mcl_core:sand`, `mcl_fences:wood`, `mcl_core:wood`)
* ✅ **Repixture, Asuna, Exile, Hades Revisited, and Custom Luanti Games** (via automatic node group & fallback resolution)
* ✅ **Optional Mob Pack Integration:** Compatible with `mobs_redo`, `mobs_animal`, and `mcl_mobs`.

---

## 📸 Screenshots

> *Add your in-game expedition screenshots below!*

| ⛏️ **Buried Mode — Underground Discovery** | 🚧 **Exposed Mode — Fenced Excavation Site** |
| :---: | :---: |
| ![Buried Fossil Discovery Placeholder]() | ![Exposed Excavation Site Placeholder]() |
| *Unearthing a massive bone-white skeleton 5 nodes beneath the surface.* | *A complete surface dig pit enclosed by a 2-node-high wooden fence perimeter.* |

---

## 🏆 Credits & License

* **Created & Engineered by:** **ronrob-lu (2026)**
* **3D Dinosaur Models:** LowPoly Dinosaur Models by `@Quaternius` (CC0 1.0 Public Domain) + Built-in Procedural Lua Skeleton Generator.
* **License:** Released under the [MIT License](license.md) — Copyright (c) 2026 **ronrob-lu**.
