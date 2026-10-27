-- ============================================================================
-- PALEONTOLOGY MOD FOR LUANTI / MINETEST
-- Spawns large lying voxel dinosaur skeletons in the world made of diggable,
-- placeable small 3D voxel bone blocks (nodeboxes) so players can excavate
-- fossils and rebuild their own dinosaurs!
-- Works across all Luanti-compatible games (Minetest Game, MineClone2, etc.)
-- License: MIT (c) 2026 ronrob-lu
-- ============================================================================

PALEONTOLOGY = {}

-- ============================================================================
-- CONFIGURATION (Edit PALEONTOLOGY.MODE below)
-- ============================================================================
-- Two spawn modes are supported:
--   "buried"  (DEFAULT) : Skeletons spawn 2-4 nodes underground beneath normal
--                         terrain. Players must dig to discover them. No fences
--                         and no surface markers are placed.
--   "exposed"           : Skeletons spawn already excavated on the surface inside
--                         a cleared dirt-path excavation pit surrounded by a
--                         2-node-high rectangular wooden fence enclosure.
PALEONTOLOGY.MODE = "buried"

-- Spawn frequency & notification settings:
PALEONTOLOGY.SPAWN_CHANCE = 2        -- Spawn in 1 out of N surface mapchunks (2 = very frequent!)
PALEONTOLOGY.NOTIFY_PLAYERS = true   -- Send chat message with coordinates when near a fossil
PALEONTOLOGY.NOTIFY_RADIUS = 250     -- Max distance (in nodes) to notify players on generation
PALEONTOLOGY.PROXIMITY_RADIUS = 60   -- Distance (in nodes) to alert players when walking near a fossil
PALEONTOLOGY.MIN_BURIED_DEPTH = 2    -- Minimum burial depth (nodes below surface)
PALEONTOLOGY.MAX_BURIED_DEPTH = 4    -- Maximum burial depth (nodes below surface)

-- Allow minetest.conf override if explicitly set by server administrator
if minetest and minetest.settings then
	local conf_mode = minetest.settings:get("paleontology_mode")
	if conf_mode == "buried" or conf_mode == "exposed" then
		PALEONTOLOGY.MODE = conf_mode
	end
	local conf_notify = minetest.settings:get_bool("paleontology_notify_players")
	if conf_notify ~= nil then
		PALEONTOLOGY.NOTIFY_PLAYERS = conf_notify
	end
	local conf_chance = tonumber(minetest.settings:get("paleontology_spawn_chance"))
	if conf_chance and conf_chance >= 1 then
		PALEONTOLOGY.SPAWN_CHANCE = math.floor(conf_chance)
	end
end

local modname = (minetest and minetest.get_current_modname and minetest.get_current_modname()) or "paleontology"
local modpath = (minetest and minetest.get_modpath and minetest.get_modpath(modname)) or "."

-- ============================================================================
-- GAME DETECTION LOGIC
-- ============================================================================

function PALEONTOLOGY.detect_game()
	local raw_id = "unknown"
	if minetest and minetest.get_game_info then
		local ok, info = pcall(minetest.get_game_info)
		if ok and type(info) == "table" and type(info.id) == "string" and info.id ~= "" then
			raw_id = info.id:lower()
		end
	end

	-- Distinguish between "minetest_game" (default), "mineclone2" (MCL), and others
	if raw_id == "minetest_game" or raw_id == "minetest" or raw_id == "mtg" then
		return "minetest_game", raw_id
	elseif raw_id == "mineclone2" or raw_id == "mineclonia" or raw_id == "voxelibre" or raw_id == "mineclone5" or raw_id:find("mineclon") then
		return "mineclone2", raw_id
	end

	-- Secondary detection by checking loaded core mods when game_info.id is custom
	if minetest and minetest.get_modpath then
		if minetest.get_modpath("mcl_core") then
			return "mineclone2", raw_id
		elseif minetest.get_modpath("default") then
			return "minetest_game", raw_id
		end
	end

	return "other", raw_id
end

PALEONTOLOGY.GAME_ID, PALEONTOLOGY.RAW_GAME_ID = PALEONTOLOGY.detect_game()

-- ============================================================================
-- NODE COMPATIBILITY TABLE & SAFE NODE RESOLUTION
-- ============================================================================

PALEONTOLOGY.NODE_COMPAT = {
	minetest_game = {
		dirt  = "default:dirt",
		grass = "default:dirt_with_grass",
		sand  = "default:sand",
		fence = "default:fence_wood",
		wood  = "default:wood",
		path  = "default:dirt_with_dry_grass",
		stone = "default:stone",
	},
	mineclone2 = {
		dirt  = "mcl_core:dirt",
		grass = "mcl_core:grass",
		sand  = "mcl_core:sand",
		fence = "mcl_fences:wood",
		wood  = "mcl_core:wood",
		path  = "mcl_core:grass_path",
		stone = "mcl_core:stone",
	},
	other = {
		dirt  = "default:dirt",
		grass = "default:dirt_with_grass",
		sand  = "default:sand",
		fence = "default:fence_wood",
		wood  = "default:wood",
		path  = "default:dirt",
		stone = "default:stone",
	},
}

-- Ordered fallback candidates for each node role across Luanti games
local FALLBACK_CANDIDATES = {
	dirt = {
		"default:dirt",
		"mcl_core:dirt",
		"mcl_core:coarse_dirt",
		"rp_default:dirt",
		"nodes_nature:Soil",
		"hades_core:dirt",
	},
	grass = {
		"default:dirt_with_grass",
		"mcl_core:grass",
		"mcl_core:dirt_with_grass",
		"rp_default:dirt_with_grass",
		"hades_core:dirt_with_grass",
	},
	sand = {
		"default:sand",
		"mcl_core:sand",
		"rp_default:sand",
		"default:desert_sand",
	},
	fence = {
		"default:fence_wood",
		"mcl_fences:wood",
		"mcl_fences:oak_fence",
		"mcl_fences:fence",
		"default:fence_junglewood",
		"default:fence_pine_wood",
		"rp_default:fence_oak",
	},
	wood = {
		"default:wood",
		"mcl_core:wood",
		"mcl_trees:wood_oak",
		"rp_default:planks_oak",
		"default:junglewood",
		"default:pine_wood",
	},
	path = {
		"default:dirt_with_dry_grass",
		"mcl_core:grass_path",
		"mcl_core:dirt_path",
		"mcl_core:coarse_dirt",
		"default:dirt",
		"mcl_core:dirt",
		"default:sand",
		"mcl_core:sand",
	},
	stone = {
		"default:stone",
		"mcl_core:stone",
		"rp_default:stone",
	},
}

function PALEONTOLOGY.node_exists(name)
	if not name or name == "" then
		return false
	end
	if name == "air" or name == "ignore" then
		return true
	end
	return minetest and minetest.registered_nodes and minetest.registered_nodes[name] ~= nil
end

function PALEONTOLOGY.resolve_node(role)
	local game_key = PALEONTOLOGY.GAME_ID or "other"
	local compat = PALEONTOLOGY.NODE_COMPAT[game_key] or PALEONTOLOGY.NODE_COMPAT.other

	local primary = compat[role]
	if PALEONTOLOGY.node_exists(primary) then
		return primary
	end

	local candidates = FALLBACK_CANDIDATES[role]
	if candidates then
		for _, candidate in ipairs(candidates) do
			if PALEONTOLOGY.node_exists(candidate) then
				return candidate
			end
		end
	end

	if minetest and minetest.registered_nodes then
		for reg_name, def in pairs(minetest.registered_nodes) do
			local groups = def and def.groups
			if groups and reg_name ~= "air" and reg_name ~= "ignore" and not reg_name:find("^paleontology:") then
				if role == "fence" and (groups.fence or reg_name:find("fence")) then
					return reg_name
				elseif role == "wood" and (groups.wood or groups.planks) then
					return reg_name
				elseif role == "sand" and groups.sand then
					return reg_name
				elseif (role == "dirt" or role == "path") and (groups.soil or groups.dirt or groups.crumbly) then
					return reg_name
				elseif role == "grass" and (groups.spreading_dirt_type or (groups.soil and reg_name:find("grass"))) then
					return reg_name
				elseif role == "stone" and (groups.stone or groups.cracky) then
					return reg_name
				end
			end
		end
	end

	return nil
end

function PALEONTOLOGY.safe_set_node(pos, node_name, param2)
	if not pos or not node_name then
		return false
	end
	if not PALEONTOLOGY.node_exists(node_name) then
		return false
	end
	minetest.set_node(pos, { name = node_name, param2 = param2 or 0 })
	return true
end

function PALEONTOLOGY.is_surface_node(node_name)
	if not node_name or node_name == "air" or node_name == "ignore" or node_name:find("^paleontology:") then
		return false
	end
	local def = minetest.registered_nodes and minetest.registered_nodes[node_name]
	if not def then
		return false
	end

	local groups = def.groups or {}
	if def.liquidtype and def.liquidtype ~= "none" then
		return false
	end
	if groups.water or groups.lava or groups.liquid or groups.leaves or groups.tree or groups.wood or groups.fence then
		return false
	end

	local dirt_node = PALEONTOLOGY.resolve_node("dirt")
	local grass_node = PALEONTOLOGY.resolve_node("grass")
	local sand_node = PALEONTOLOGY.resolve_node("sand")
	local path_node = PALEONTOLOGY.resolve_node("path")

	if node_name == dirt_node or node_name == grass_node or node_name == sand_node or node_name == path_node then
		return true
	end

	if groups.soil or groups.sand or groups.dirt or groups.spreading_dirt_type or groups.crumbly then
		if def.walkable ~= false then
			return true
		end
	end

	if node_name:find("dirt") or node_name:find("grass") or node_name:find("sand") or node_name:find("podzol") or node_name:find("mycelium") then
		if def.walkable ~= false then
			return true
		end
	end

	return false
end

function PALEONTOLOGY.is_clear_above(node_name)
	if not node_name or node_name == "air" then
		return true
	end
	local def = minetest.registered_nodes and minetest.registered_nodes[node_name]
	if not def then
		return false
	end
	if def.liquidtype and def.liquidtype ~= "none" then
		return false
	end
	local groups = def.groups or {}
	if groups.water or groups.lava or groups.liquid then
		return false
	end
	if def.buildable_to or def.walkable == false
		or groups.flora or groups.grass or groups.dry_grass or groups.plant
		or groups.leaves or groups.tree or groups.snowy or groups.attached_node then
		return true
	end
	return false
end

-- ============================================================================
-- SHADED VOXEL BONE TEXTURE GENERATOR (16x16 Pixel-Art Fossil Texture)
-- ============================================================================
-- Creates a crisp, multi-tone 16x16 voxel bone texture with beveled block
-- borders, marrow pores, and warm ivory shading so small voxel bone blocks
-- have unmistakable 3D depth in Luanti without needing external PNG downloads.
-- ============================================================================

function PALEONTOLOGY.get_bone_texture()
	-- Multi-tone 16x16 pixel-art fossil bone texture built with native Luanti texture modifiers:
	-- Outer bevel border (#B8AE96), inner bone surface (#EAE2CE), highlight ridges (#F8F4E8),
	-- and fossil marrow/joint details (#9E937B & #CFC5AE).
	local tex = table.concat({
		"[combine:16x16",
		":0,0=\\[fill\\:16x16\\:#B8AE96",
		":1,1=\\[fill\\:14x14\\:#E8E0CC",
		":2,2=\\[fill\\:12x12\\:#F4EFE0",
		":1,1=\\[fill\\:14x1\\:#FAF6EC",
		":1,1=\\[fill\\:1x14\\:#FAF6EC",
		":3,4=\\[fill\\:3x2\\:#D2C8B2",
		":9,3=\\[fill\\:4x2\\:#D8CEB8",
		":4,9=\\[fill\\:5x2\\:#CEC4AE",
		":11,10=\\[fill\\:2x3\\:#C4B9A2",
		":6,6=\\[fill\\:4x4\\:#EFE9D8",
		":7,7=\\[fill\\:2x2\\:#9E937B",
	}, "")
	return tex
end

function PALEONTOLOGY.get_bone_dark_texture()
	local tex = table.concat({
		"[combine:16x16",
		":0,0=\\[fill\\:16x16\\:#9E937B",
		":1,1=\\[fill\\:14x14\\:#D6CCB6",
		":2,2=\\[fill\\:12x12\\:#E5DDD0",
		":4,4=\\[fill\\:8x8\\:#C8BEAA",
		":6,6=\\[fill\\:4x4\\:#8A7F68",
	}, "")
	return tex
end

-- ============================================================================
-- DIGGABLE VOXEL BONE BLOCKS (Small 3D Nodebox Fossil Parts)
-- ============================================================================
-- Players can dig any part of a dinosaur skeleton with a pickaxe or by hand,
-- collect the small bone blocks, and place them back down in any direction
-- (facedir) to reconstruct dinosaurs!
-- ============================================================================

local bone_tex = PALEONTOLOGY.get_bone_texture()
local bone_joint_tex = PALEONTOLOGY.get_bone_dark_texture()

local common_bone_groups = {
	cracky = 3,
	crumbly = 2,
	oddly_breakable_by_hand = 2,
	fossil_bone = 1,
	-- mcl_core compatibility groups so pickaxes and hands mine smoothly in MineClone2
	pickaxey = 1,
	handy = 1,
}

local function register_bone_node(subname, desc, nodeboxes, tiles_override)
	minetest.register_node("paleontology:" .. subname, {
		description = desc,
		drawtype = "nodebox",
		tiles = tiles_override or {
			bone_tex,       -- Top (+Y)
			bone_joint_tex, -- Bottom (-Y)
			bone_tex,       -- Right (+X)
			bone_tex,       -- Left (-X)
			bone_joint_tex, -- Back (+Z)
			bone_joint_tex, -- Front (-Z)
		},
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		is_ground_content = false,
		groups = common_bone_groups,
		_mcl_hardness = 0.8,
		_mcl_blast_resistance = 3.0,
		node_box = {
			type = "fixed",
			fixed = nodeboxes,
		},
		selection_box = {
			type = "fixed",
			fixed = nodeboxes,
		},
	})
end

-- 1. Dinosaur Spine Vertebra (Centrum + Vertebral Discs + Dorsal Neural Spine + Rib Knobs)
register_bone_node("bone_vertebra", "Dinosaur Spine Bone (Vertebra)", {
	{ -0.20, -0.20, -0.50,  0.20,  0.20,  0.50 }, -- Central spinal column shaft
	{ -0.30, -0.28, -0.42,  0.30,  0.28, -0.18 }, -- Anterior vertebral disc
	{ -0.30, -0.28,  0.18,  0.30,  0.28,  0.42 }, -- Posterior vertebral disc
	{ -0.08,  0.20, -0.30,  0.08,  0.50,  0.05 }, -- Dorsal neural spine process
	{ -0.06,  0.34, -0.10,  0.06,  0.50,  0.28 }, -- Dorsal spine tip angled back
	{ -0.50, -0.10, -0.16, -0.20,  0.12,  0.16 }, -- Left transverse rib process
	{  0.20, -0.10, -0.16,  0.50,  0.12,  0.16 }, -- Right transverse rib process
})

-- 2. Dinosaur Upper Rib Arch (Stepped small voxel bars curving outward and downward)
register_bone_node("bone_rib", "Dinosaur Rib Bone (Upper Arch)", {
	{ -0.50,  0.10, -0.14, -0.06,  0.34,  0.14 }, -- Inner rib head connecting to spine
	{ -0.16, -0.04, -0.14,  0.22,  0.22,  0.14 }, -- Mid-upper rib curve
	{  0.08, -0.26, -0.14,  0.38,  0.04,  0.14 }, -- Outer rib flank
	{  0.18, -0.50, -0.14,  0.44, -0.18,  0.14 }, -- Lower descending rib shaft
})

-- 3. Dinosaur Lower Rib Tip (Completes the deep hollow chest cavity)
register_bone_node("bone_rib_tip", "Dinosaur Rib Bone (Lower Curve)", {
	{  0.16,  0.08, -0.12,  0.42,  0.50,  0.12 }, -- Upper connection to bone_rib
	{ -0.08, -0.20, -0.12,  0.30,  0.14,  0.12 }, -- Inward lower chest curve
	{ -0.40, -0.38, -0.10,  0.02, -0.12,  0.10 }, -- Sternal rib tip
})

-- 4. Dinosaur Skull Cranium (Hollow eye sockets, brow crests, braincase, palate)
register_bone_node("bone_skull", "Dinosaur Skull Cranium Block", {
	{ -0.44,  0.22, -0.50,  0.44,  0.46,  0.50 }, -- Top cranium roof
	{ -0.50,  0.28, -0.38, -0.34,  0.50,  0.38 }, -- Left supraorbital brow crest
	{  0.34,  0.28, -0.38,  0.50,  0.50,  0.38 }, -- Right supraorbital brow crest
	{ -0.46, -0.34, -0.50, -0.26,  0.24, -0.20 }, -- Left back postorbital pillar
	{  0.26, -0.34, -0.50,  0.46,  0.24, -0.20 }, -- Right back postorbital pillar
	{ -0.44, -0.34,  0.18, -0.26,  0.24,  0.50 }, -- Left front lacrimal pillar (leaves hollow eye socket!)
	{  0.26, -0.34,  0.18,  0.44,  0.24,  0.50 }, -- Right front lacrimal pillar
	{ -0.46, -0.38, -0.50, -0.28, -0.16,  0.50 }, -- Left cheekbone (jugal bar)
	{  0.28, -0.38, -0.50,  0.46, -0.16,  0.50 }, -- Right cheekbone (jugal bar)
	{ -0.32, -0.46, -0.50,  0.32, -0.28,  0.50 }, -- Lower braincase & palate floor
})

-- 5. Dinosaur Jaw & Snout (Upper maxilla, open lower mandible, and sharp voxel teeth)
register_bone_node("bone_jaw", "Dinosaur Toothed Jaw & Snout Block", {
	{ -0.34,  0.12, -0.50,  0.34,  0.36,  0.42 }, -- Upper nasal bridge
	{ -0.26, -0.02,  0.20,  0.26,  0.26,  0.48 }, -- Snout tip (premaxilla)
	{ -0.38, -0.06, -0.50, -0.22,  0.16,  0.42 }, -- Left upper maxilla
	{  0.22, -0.06, -0.50,  0.38,  0.16,  0.42 }, -- Right upper maxilla
	-- Upper sharp voxel teeth (left & right)
	{ -0.36, -0.24, -0.40, -0.24, -0.06, -0.26 },
	{ -0.36, -0.26, -0.10, -0.24, -0.06,  0.04 },
	{ -0.34, -0.22,  0.18, -0.22, -0.04,  0.32 },
	{  0.24, -0.24, -0.40,  0.36, -0.06, -0.26 },
	{  0.24, -0.26, -0.10,  0.36, -0.06,  0.04 },
	{  0.22, -0.22,  0.18,  0.34, -0.04,  0.32 },
	-- Articulated lower jaw (mandible)
	{ -0.34, -0.48, -0.50, -0.18, -0.30,  0.38 }, -- Left lower mandible
	{  0.18, -0.48, -0.50,  0.34, -0.30,  0.38 }, -- Right lower mandible
	{ -0.26, -0.46,  0.22,  0.26, -0.30,  0.44 }, -- Chin symphysis
	-- Lower voxel teeth pointing upward
	{ -0.30, -0.30, -0.26, -0.20, -0.16, -0.14 },
	{ -0.28, -0.30,  0.04, -0.18, -0.16,  0.16 },
	{  0.20, -0.30, -0.26,  0.30, -0.16, -0.14 },
	{  0.18, -0.30,  0.04,  0.28, -0.16,  0.16 },
})

-- 6. Dinosaur Pelvis / Hip Girdle
register_bone_node("bone_pelvis", "Dinosaur Pelvis Hip Bone", {
	{ -0.24, -0.14, -0.50,  0.24,  0.28,  0.50 }, -- Sacral spine core
	{ -0.48,  0.04, -0.44, -0.24,  0.44,  0.44 }, -- Left ilium hip blade
	{  0.24,  0.04, -0.44,  0.48,  0.44,  0.44 }, -- Right ilium hip blade
	{ -0.46, -0.48, -0.38, -0.22,  0.04, -0.12 }, -- Left ischium strut
	{  0.22, -0.48, -0.38,  0.46,  0.04, -0.12 }, -- Right ischium strut
	{ -0.46, -0.48,  0.12, -0.22,  0.04,  0.38 }, -- Left pubis strut
	{  0.22, -0.48,  0.12,  0.46,  0.04,  0.38 }, -- Right pubis strut
})

-- 7. Dinosaur Limb Bone (Femur / Tibia / Humerus with condyle knuckles)
register_bone_node("bone_limb", "Dinosaur Limb Bone (Femur / Shin)", {
	{ -0.16, -0.16, -0.50,  0.16,  0.16,  0.50 }, -- Slender bone shaft
	{ -0.30, -0.24, -0.50, -0.04,  0.24, -0.28 }, -- Proximal left condyle knuckle
	{  0.04, -0.24, -0.50,  0.30,  0.24, -0.28 }, -- Proximal right condyle knuckle
	{ -0.30, -0.24,  0.28, -0.04,  0.24,  0.50 }, -- Distal left condyle knuckle
	{  0.04, -0.24,  0.28,  0.30,  0.24,  0.50 }, -- Distal right condyle knuckle
})

-- 8. Dinosaur Tail Vertebra (Slender segmented tail bone with chevron fin)
register_bone_node("bone_tail", "Dinosaur Tail Bone", {
	{ -0.14, -0.14, -0.50,  0.14,  0.14,  0.50 }, -- Slender tail shaft
	{ -0.22, -0.22, -0.20,  0.22,  0.22,  0.20 }, -- Central vertebral ring
	{ -0.06,  0.14, -0.22,  0.06,  0.38,  0.14 }, -- Dorsal tail process
	{ -0.05, -0.32, -0.16,  0.05, -0.14,  0.16 }, -- Ventral chevron bone
})

-- 9. Dinosaur Three-Toed Foot Claws
register_bone_node("bone_claw", "Dinosaur Foot & Claws Bone", {
	{ -0.32, -0.36, -0.46,  0.32,  0.04, -0.12 }, -- Ankle metatarsal block
	{ -0.44, -0.48, -0.16, -0.22, -0.22,  0.32 }, -- Left toe bone
	{ -0.40, -0.50,  0.28, -0.26, -0.30,  0.48 }, -- Left sharp claw tip
	{ -0.10, -0.48, -0.16,  0.10, -0.20,  0.38 }, -- Center toe bone
	{ -0.08, -0.50,  0.34,  0.08, -0.28,  0.50 }, -- Center sharp claw tip
	{  0.22, -0.48, -0.16,  0.44, -0.22,  0.32 }, -- Right toe bone
	{  0.26, -0.50,  0.28,  0.40, -0.30,  0.48 }, -- Right sharp claw tip
})

-- Crafting cycle so players can reshape any dug bone block into any other bone part
local craft_cycle = {
	"paleontology:bone_vertebra",
	"paleontology:bone_rib",
	"paleontology:bone_rib_tip",
	"paleontology:bone_skull",
	"paleontology:bone_jaw",
	"paleontology:bone_pelvis",
	"paleontology:bone_limb",
	"paleontology:bone_tail",
	"paleontology:bone_claw",
}
if minetest and minetest.register_craft then
	for i = 1, #craft_cycle do
		local next_i = (i % #craft_cycle) + 1
		minetest.register_craft({
			output = craft_cycle[next_i],
			recipe = { { craft_cycle[i] } },
		})
	end
end

-- ============================================================================
-- PROCEDURAL .OBJ SKELETON MESH (For Entity Fallback / Compatibility)
-- ============================================================================

function PALEONTOLOGY.build_procedural_skeleton_obj()
	local verts = {
		{ -0.1, -0.1, -0.1 }, { 0.1, -0.1, -0.1 }, { 0.1, 0.1, -0.1 }, { -0.1, 0.1, -0.1 },
		{ -0.1, -0.1,  0.1 }, { 0.1, -0.1,  0.1 }, { 0.1, 0.1,  0.1 }, { -0.1, 0.1,  0.1 },
	}
	local lines = {
		"# Paleontology Voxel Skeleton Marker Mesh",
		"o Paleontology_Skeleton",
	}
	for _, v in ipairs(verts) do
		lines[#lines + 1] = string.format("v %.4f %.4f %.4f", v[1], v[2], v[3])
	end
	lines[#lines + 1] = "vt 0.0 0.0\nvt 1.0 0.0\nvt 1.0 1.0\nvt 0.0 1.0"
	lines[#lines + 1] = "vn 0.0 1.0 0.0"
	lines[#lines + 1] = "f 1/1/1 2/2/1 3/3/1\nf 1/1/1 3/3/1 4/4/1"
	return table.concat(lines, "\n") .. "\n"
end

-- ============================================================================
-- VOXEL DINOSAUR SKELETON BLUEPRINTS (10 to 13 Nodes Long, Lying Horizontally)
-- ============================================================================
-- Each blueprint is an articulated 3D voxel skeleton made of small diggable
-- bone nodeboxes (skull, toothed jaw, neck, spine, hollow curved ribs, pelvis,
-- folded femurs/shins, 3-toed claws, and sweeping tail).
--
-- Local coordinate convention before horizontal rotation (dir = 0..3):
--   dz : Length axis from tail (-5..-6) to skull/snout (+4..+6)
--   dx : Width axis from left side (-3) to right side (+3)
--   dy : Vertical elevation relative to skeleton base (0 = ground/pit floor, 1 = upper arch)
--   dir: Local facedir (0 = +Z forward, 1 = +X right, 2 = -Z back, 3 = -X left)
-- ============================================================================

function PALEONTOLOGY.get_voxel_blueprints()
	local V  = "paleontology:bone_vertebra"
	local R  = "paleontology:bone_rib"
	local RT = "paleontology:bone_rib_tip"
	local SK = "paleontology:bone_skull"
	local JW = "paleontology:bone_jaw"
	local PV = "paleontology:bone_pelvis"
	local LB = "paleontology:bone_limb"
	local TL = "paleontology:bone_tail"
	local CL = "paleontology:bone_claw"

	return {
		-- 1. TYRANNOSAURUS REX VOXEL SKELETON (11 nodes long, 5 nodes wide)
		{
			species = "Tyrannosaurus Rex",
			length = 11,
			width = 5,
			nodes = {
				-- Giant 2-tier Skull & Toothed Jaws at front (+Z)
				{ dx =  0, dy = 1, dz =  4, name = SK, dir = 0 },
				{ dx =  0, dy = 1, dz =  5, name = JW, dir = 0 },
				{ dx =  0, dy = 0, dz =  4, name = SK, dir = 0 },
				{ dx =  0, dy = 0, dz =  5, name = JW, dir = 0 },

				-- Curved Cervical Neck
				{ dx =  0, dy = 0, dz =  3, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz =  3, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz =  2, name = V,  dir = 0 },

				-- Dorsal Spine (Elevated along the back of the ribcage)
				{ dx =  0, dy = 1, dz =  1, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz =  0, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz = -1, name = V,  dir = 0 },

				-- Hollow Curved Ribcage (4 pairs of upper & lower ribs on Left and Right)
				-- Left ribs (dx = -1 upper arch, dx = -2 lower curve)
				{ dx = -1, dy = 1, dz =  2, name = R,  dir = 2 },
				{ dx = -2, dy = 0, dz =  2, name = RT, dir = 2 },
				{ dx = -1, dy = 1, dz =  1, name = R,  dir = 2 },
				{ dx = -2, dy = 0, dz =  1, name = RT, dir = 2 },
				{ dx = -1, dy = 1, dz =  0, name = R,  dir = 2 },
				{ dx = -2, dy = 0, dz =  0, name = RT, dir = 2 },
				{ dx = -1, dy = 1, dz = -1, name = R,  dir = 2 },
				{ dx = -2, dy = 0, dz = -1, name = RT, dir = 2 },

				-- Right ribs (dx = +1 upper arch, dx = +2 lower curve)
				{ dx =  1, dy = 1, dz =  2, name = R,  dir = 0 },
				{ dx =  2, dy = 0, dz =  2, name = RT, dir = 0 },
				{ dx =  1, dy = 1, dz =  1, name = R,  dir = 0 },
				{ dx =  2, dy = 0, dz =  1, name = RT, dir = 0 },
				{ dx =  1, dy = 1, dz =  0, name = R,  dir = 0 },
				{ dx =  2, dy = 0, dz =  0, name = RT, dir = 0 },
				{ dx =  1, dy = 1, dz = -1, name = R,  dir = 0 },
				{ dx =  2, dy = 0, dz = -1, name = RT, dir = 0 },

				-- T-Rex Forearms & Claws
				{ dx = -2, dy = 0, dz =  3, name = CL, dir = 0 },
				{ dx =  2, dy = 0, dz =  3, name = CL, dir = 0 },

				-- Pelvic Girdle & Folded Hind Legs (Femur + Tibia + 3-Toed Claws)
				{ dx =  0, dy = 1, dz = -2, name = PV, dir = 0 },
				{ dx =  0, dy = 0, dz = -2, name = PV, dir = 0 },
				{ dx = -1, dy = 0, dz = -2, name = LB, dir = 3 },
				{ dx = -2, dy = 0, dz = -2, name = LB, dir = 0 },
				{ dx = -2, dy = 0, dz = -3, name = LB, dir = 0 },
				{ dx = -2, dy = 0, dz = -4, name = CL, dir = 2 },
				{ dx =  1, dy = 0, dz = -2, name = LB, dir = 1 },
				{ dx =  2, dy = 0, dz = -2, name = LB, dir = 0 },
				{ dx =  2, dy = 0, dz = -3, name = LB, dir = 0 },
				{ dx =  2, dy = 0, dz = -4, name = CL, dir = 2 },

				-- Sweeping S-Curved Caudal Tail (dz = -3 to -6)
				{ dx =  0, dy = 0, dz = -3, name = TL, dir = 0 },
				{ dx =  0, dy = 0, dz = -4, name = TL, dir = 0 },
				{ dx =  1, dy = 0, dz = -5, name = TL, dir = 0 },
				{ dx =  1, dy = 0, dz = -6, name = TL, dir = 0 },
			},
		},

		-- 2. APATOSAURUS SAUROPOD VOXEL SKELETON (13 nodes long, 5 nodes wide)
		{
			species = "Apatosaurus",
			length = 13,
			width = 5,
			nodes = {
				-- Sauropod Skull & Snout at end of long curving neck
				{ dx = -1, dy = 0, dz =  6, name = JW, dir = 0 },
				{ dx = -1, dy = 0, dz =  5, name = SK, dir = 0 },

				-- Long Sweeping Cervical Neck (dz = +2 to +4)
				{ dx = -1, dy = 0, dz =  4, name = V,  dir = 0 },
				{ dx =  0, dy = 0, dz =  3, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz =  2, name = V,  dir = 0 },

				-- Massive Dorsal Spine (dz = -2 to +1)
				{ dx =  0, dy = 1, dz =  1, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz =  0, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz = -1, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz = -2, name = PV, dir = 0 },

				-- Deep Barrel Ribcage
				{ dx = -1, dy = 1, dz =  1, name = R,  dir = 2 },
				{ dx = -2, dy = 0, dz =  1, name = RT, dir = 2 },
				{ dx = -1, dy = 1, dz =  0, name = R,  dir = 2 },
				{ dx = -2, dy = 0, dz =  0, name = RT, dir = 2 },
				{ dx = -1, dy = 1, dz = -1, name = R,  dir = 2 },
				{ dx = -2, dy = 0, dz = -1, name = RT, dir = 2 },

				{ dx =  1, dy = 1, dz =  1, name = R,  dir = 0 },
				{ dx =  2, dy = 0, dz =  1, name = RT, dir = 0 },
				{ dx =  1, dy = 1, dz =  0, name = R,  dir = 0 },
				{ dx =  2, dy = 0, dz =  0, name = RT, dir = 0 },
				{ dx =  1, dy = 1, dz = -1, name = R,  dir = 0 },
				{ dx =  2, dy = 0, dz = -1, name = RT, dir = 0 },

				-- Front & Rear Pillar Legs
				{ dx = -2, dy = 0, dz =  2, name = LB, dir = 3 },
				{ dx = -3, dy = 0, dz =  2, name = CL, dir = 3 },
				{ dx =  2, dy = 0, dz =  2, name = LB, dir = 1 },
				{ dx =  3, dy = 0, dz =  2, name = CL, dir = 1 },

				{ dx = -2, dy = 0, dz = -2, name = LB, dir = 3 },
				{ dx = -3, dy = 0, dz = -2, name = CL, dir = 3 },
				{ dx =  2, dy = 0, dz = -2, name = LB, dir = 1 },
				{ dx =  3, dy = 0, dz = -2, name = CL, dir = 1 },

				-- Long Whip-Like Caudal Tail (dz = -3 to -6)
				{ dx =  0, dy = 0, dz = -3, name = TL, dir = 0 },
				{ dx =  0, dy = 0, dz = -4, name = TL, dir = 0 },
				{ dx =  1, dy = 0, dz = -5, name = TL, dir = 0 },
				{ dx =  2, dy = 0, dz = -6, name = TL, dir = 0 },
			},
		},

		-- 3. TRICERATOPS FRILLED VOXEL SKELETON (10 nodes long, 5 nodes wide)
		{
			species = "Triceratops",
			length = 10,
			width = 5,
			nodes = {
				-- Beaked Horned Snout & Wide Bone Frill Crest
				{ dx =  0, dy = 0, dz =  4, name = JW, dir = 0 },
				{ dx =  0, dy = 1, dz =  4, name = JW, dir = 0 },
				{ dx =  0, dy = 0, dz =  3, name = SK, dir = 0 },
				{ dx =  0, dy = 1, dz =  3, name = SK, dir = 0 },
				{ dx = -1, dy = 1, dz =  2, name = PV, dir = 3 }, -- Left frill shield
				{ dx =  0, dy = 1, dz =  2, name = SK, dir = 0 }, -- Center frill crest
				{ dx =  1, dy = 1, dz =  2, name = PV, dir = 1 }, -- Right frill shield

				-- Dorsal Spine & Ribcage
				{ dx =  0, dy = 1, dz =  1, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz =  0, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz = -1, name = V,  dir = 0 },
				{ dx =  0, dy = 1, dz = -2, name = PV, dir = 0 },

				{ dx = -1, dy = 1, dz =  1, name = R,  dir = 2 },
				{ dx = -2, dy = 0, dz =  1, name = RT, dir = 2 },
				{ dx = -1, dy = 1, dz =  0, name = R,  dir = 2 },
				{ dx = -2, dy = 0, dz =  0, name = RT, dir = 2 },
				{ dx = -1, dy = 1, dz = -1, name = R,  dir = 2 },
				{ dx = -2, dy = 0, dz = -1, name = RT, dir = 2 },

				{ dx =  1, dy = 1, dz =  1, name = R,  dir = 0 },
				{ dx =  2, dy = 0, dz =  1, name = RT, dir = 0 },
				{ dx =  1, dy = 1, dz =  0, name = R,  dir = 0 },
				{ dx =  2, dy = 0, dz =  0, name = RT, dir = 0 },
				{ dx =  1, dy = 1, dz = -1, name = R,  dir = 0 },
				{ dx =  2, dy = 0, dz = -1, name = RT, dir = 0 },

				-- Sturdy Quadruped Limbs
				{ dx = -2, dy = 0, dz =  2, name = LB, dir = 0 },
				{ dx = -2, dy = 0, dz =  3, name = CL, dir = 0 },
				{ dx =  2, dy = 0, dz =  2, name = LB, dir = 0 },
				{ dx =  2, dy = 0, dz =  3, name = CL, dir = 0 },
				{ dx = -2, dy = 0, dz = -2, name = LB, dir = 2 },
				{ dx = -2, dy = 0, dz = -3, name = CL, dir = 2 },
				{ dx =  2, dy = 0, dz = -2, name = LB, dir = 2 },
				{ dx =  2, dy = 0, dz = -3, name = CL, dir = 2 },

				-- Tail
				{ dx =  0, dy = 0, dz = -3, name = TL, dir = 0 },
				{ dx =  0, dy = 0, dz = -4, name = TL, dir = 0 },
				{ dx = -1, dy = 0, dz = -5, name = TL, dir = 0 },
			},
		},
	}
end

function PALEONTOLOGY.get_available_models()
	return PALEONTOLOGY.get_voxel_blueprints()
end

-- Rotate local (dx, dz) and local facedir (0..3) by cardinal rotation rot_steps (0..3)
local function rotate_offset_and_dir(dx, dz, local_dir, rot_steps)
	local r = (rot_steps or 0) % 4
	local rx, rz
	if r == 0 then
		rx, rz = dx, dz
	elseif r == 1 then
		rx, rz = dz, -dx
	elseif r == 2 then
		rx, rz = -dx, -dz
	else
		rx, rz = -dz, dx
	end
	local final_dir = ((local_dir or 0) + r) % 4
	return rx, rz, final_dir
end

-- Places an entire multi-node 3D voxel dinosaur skeleton at base_pos
function PALEONTOLOGY.place_voxel_skeleton(base_pos, blueprint, rot_steps, is_buried)
	if not base_pos or not blueprint or not blueprint.nodes then
		return
	end

	-- In buried mode, clear a small 1-node pocket inside the ribcage so the 3D ribs
	-- are immediately recognizable as soon as the player breaks the first block!
	for _, b in ipairs(blueprint.nodes) do
		local rx, rz, param2 = rotate_offset_and_dir(b.dx, b.dz, b.dir, rot_steps)
		local p = {
			x = base_pos.x + rx,
			y = base_pos.y + b.dy,
			z = base_pos.z + rz,
		}
		PALEONTOLOGY.safe_set_node(p, b.name, param2)

		if is_buried and b.dy == 1 and b.dx == 0 then
			-- Hollow cavity directly beneath the elevated dorsal spine inside the ribcage
			local hollow = { x = p.x, y = base_pos.y, z = p.z }
			local cur = minetest.get_node(hollow).name
			if not cur:find("^paleontology:") then
				PALEONTOLOGY.safe_set_node(hollow, "air", 0)
			end
		end
	end
end

-- ============================================================================
-- STATIC SKELETON SITE ENTITY ("paleontology:skeleton")
-- ============================================================================
-- Invisible site beacon entity with static_save = true and collisionbox = {0,0,0,0,0,0}
-- that persists the fossil site metadata and powers proximity discovery alerts.
-- ============================================================================

minetest.register_entity("paleontology:skeleton", {
	initial_properties = {
		visual = "sprite",
		textures = { "[fill:1x1:#00000000" },
		visual_size = { x = 0.0, y = 0.0, z = 0.0 },
		collisionbox = { 0, 0, 0, 0, 0, 0 },
		selectionbox = { 0, 0, 0, 0, 0, 0 },
		physical = false,
		pointable = false,
		static_save = true,
		shaded = false,
		infotext = "Prehistoric Dinosaur Fossil Site",
	},

	on_activate = function(self, staticdata, dtime_s)
		if not self.object then
			return
		end

		self.object:set_velocity({ x = 0, y = 0, z = 0 })
		self.object:set_acceleration({ x = 0, y = 0, z = 0 })
		self.object:set_armor_groups({ immortal = 1 })
		self.object:set_properties({
			visual = "sprite",
			textures = { "[fill:1x1:#00000000" },
			visual_size = { x = 0.0, y = 0.0, z = 0.0 },
			collisionbox = { 0, 0, 0, 0, 0, 0 },
			selectionbox = { 0, 0, 0, 0, 0, 0 },
			pointable = false,
		})

		local data = nil
		if type(staticdata) == "string" and staticdata ~= "" then
			local ok, parsed = pcall(minetest.deserialize, staticdata)
			if ok and type(parsed) == "table" then
				data = parsed
			end
		end

		if not data then
			data = {
				species = "Tyrannosaurus Rex",
				yaw = 0,
				rot_x = math.rad(90),
				mode = PALEONTOLOGY.MODE,
				voxel_placed = true,
			}
		elseif not data.voxel_placed then
			-- Automatically upgrade any legacy mesh entity into a diggable voxel skeleton
			data.voxel_placed = true
			local pos = self.object:get_pos()
			if pos then
				local base_pos = {
					x = math.floor(pos.x + 0.5),
					y = math.floor(pos.y + 0.5),
					z = math.floor(pos.z + 0.5),
				}
				local bps = PALEONTOLOGY.get_voxel_blueprints()
				PALEONTOLOGY.place_voxel_skeleton(base_pos, bps[1], math.random(0, 3), data.mode ~= "exposed")
			end
		end

		self.fossil_data = data
		self.object:set_rotation({
			x = tonumber(data.rot_x) or math.rad(90),
			y = tonumber(data.yaw) or 0,
			z = 0,
		})
		self.notify_timer = 0
		self.notified_players = {}
	end,

	on_step = function(self, dtime)
		if not PALEONTOLOGY.NOTIFY_PLAYERS or not self.object then
			return
		end
		self.notify_timer = (self.notify_timer or 0) + (dtime or 0)
		if self.notify_timer < 2.5 then
			return
		end
		self.notify_timer = 0

		local pos = self.object:get_pos()
		if not pos or not minetest.get_connected_players then
			return
		end

		local prox_radius = PALEONTOLOGY.PROXIMITY_RADIUS or 60
		self.notified_players = self.notified_players or {}
		local data = self.fossil_data or {}

		for _, player in ipairs(minetest.get_connected_players() or {}) do
			local pname = player and player:get_player_name()
			local ppos = player and player:get_pos()
			if pname and pname ~= "" and ppos and not self.notified_players[pname] then
				local dist = vector and vector.distance and vector.distance(ppos, pos)
					or math.sqrt((ppos.x - pos.x) ^ 2 + (ppos.y - pos.y) ^ 2 + (ppos.z - pos.z) ^ 2)
				if dist <= prox_radius then
					self.notified_players[pname] = true
					local mode_desc = (data.mode == "exposed") and "exposed on the surface" or "buried underground"
					minetest.chat_send_player(
						pname,
						string.format(
							"[Paleontology] You are near a %s skeleton (%dm away at %d, %d, %d — %s)!",
							tostring(data.species or "Dinosaur"),
							math.floor(dist),
							math.floor(pos.x),
							math.floor(pos.y),
							math.floor(pos.z),
							mode_desc
						)
					)
				end
			end
		end
	end,

	get_staticdata = function(self)
		if self.fossil_data then
			return minetest.serialize(self.fossil_data)
		end
		return ""
	end,

	on_blast = function(self, damage)
		return false, false, {}
	end,
})

-- ============================================================================
-- EXPOSED MODE: EXCAVATION PIT & RECTANGULAR FENCE ENCLOSURE
-- ============================================================================

function PALEONTOLOGY.create_excavation_pit(center_pos, half_x, half_z)
	if not center_pos then
		return
	end

	local dirt_node = PALEONTOLOGY.resolve_node("dirt")
	local path_node = PALEONTOLOGY.resolve_node("path") or dirt_node
	local sand_node = PALEONTOLOGY.resolve_node("sand") or dirt_node

	local existing_surface = minetest.get_node(center_pos).name
	local is_desert = (existing_surface == sand_node) or (existing_surface and existing_surface:find("sand") ~= nil)
	local floor_primary = is_desert and sand_node or path_node
	local floor_sub = is_desert and sand_node or dirt_node

	for dx = -half_x, half_x do
		for dz = -half_z, half_z do
			local x = center_pos.x + dx
			local z = center_pos.z + dz
			local is_border = (math.abs(dx) == half_x) or (math.abs(dz) == half_z)

			for dy = -3, -1 do
				PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y + dy, z = z }, floor_sub)
			end

			if is_border then
				PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y, z = z }, floor_sub)
			else
				local is_inner_step = (math.abs(dx) == half_x - 1) or (math.abs(dz) == half_z - 1)
				if is_inner_step then
					PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y - 1, z = z }, floor_sub)
					PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y, z = z }, "air")
				else
					PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y - 1, z = z }, floor_primary)
					PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y, z = z }, "air")
				end
			end

			for dy = 1, 5 do
				PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y + dy, z = z }, "air")
			end
		end
	end
end

function PALEONTOLOGY.build_fence_enclosure(center_pos, half_x, half_z)
	if not center_pos then
		return
	end

	local fence_node = PALEONTOLOGY.resolve_node("fence")
	local wood_node = PALEONTOLOGY.resolve_node("wood") or fence_node
	local dirt_node = PALEONTOLOGY.resolve_node("dirt")

	local rail_node = fence_node or wood_node
	if not rail_node then
		return
	end
	local corner_base_node = wood_node or rail_node

	for dx = -half_x, half_x do
		for dz = -half_z, half_z do
			local is_perimeter = (math.abs(dx) == half_x) or (math.abs(dz) == half_z)
			if is_perimeter then
				local x = center_pos.x + dx
				local z = center_pos.z + dz
				local is_corner = (math.abs(dx) == half_x) and (math.abs(dz) == half_z)

				if is_corner and corner_base_node then
					PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y, z = z }, corner_base_node)
				elseif dirt_node then
					PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y, z = z }, dirt_node)
				end

				PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y + 1, z = z }, rail_node)
				PALEONTOLOGY.safe_set_node({ x = x, y = center_pos.y + 2, z = z }, rail_node)
			end
		end
	end
end

-- ============================================================================
-- BURIED MODE: UNDERGROUND BURIAL LOGIC
-- ============================================================================

function PALEONTOLOGY.bury_skeleton_terrain(surface_pos, burial_pos, half_x, half_z)
	if not surface_pos or not burial_pos then
		return
	end

	local surface_node_name = minetest.get_node(surface_pos).name
	local dirt_node = PALEONTOLOGY.resolve_node("dirt")
	local grass_node = PALEONTOLOGY.resolve_node("grass") or dirt_node
	local sand_node = PALEONTOLOGY.resolve_node("sand") or dirt_node

	local is_sandy = (surface_node_name == sand_node) or (surface_node_name and surface_node_name:find("sand") ~= nil)
	local fill_node = is_sandy and sand_node or dirt_node
	local top_node = is_sandy and sand_node or grass_node

	if not fill_node then
		return
	end

	for dx = -half_x, half_x do
		for dz = -half_z, half_z do
			local x = surface_pos.x + dx
			local z = surface_pos.z + dz
			for y = burial_pos.y - 1, surface_pos.y - 1 do
				local cur = minetest.get_node({ x = x, y = y, z = z }).name
				if cur == "air" then
					PALEONTOLOGY.safe_set_node({ x = x, y = y, z = z }, fill_node)
				end
			end
			local top_cur = minetest.get_node({ x = x, y = surface_pos.y, z = z }).name
			if top_cur == "air" and top_node then
				PALEONTOLOGY.safe_set_node({ x = x, y = surface_pos.y, z = z }, top_node)
			end
		end
	end
end

-- ============================================================================
-- FOSSIL SPAWNING & PLAYER NOTIFICATION
-- ============================================================================

function PALEONTOLOGY.notify_nearby_players(pos, mode, species)
	if not PALEONTOLOGY.NOTIFY_PLAYERS then
		return
	end
	if not minetest or not minetest.get_connected_players then
		return
	end

	local players = minetest.get_connected_players()
	if not players then
		return
	end

	for _, player in ipairs(players) do
		local ppos = player and player:get_pos()
		local pname = player and player:get_player_name()
		if ppos and pname and pname ~= "" then
			local dist = vector and vector.distance and vector.distance(ppos, pos)
				or math.sqrt((ppos.x - pos.x) ^ 2 + (ppos.y - pos.y) ^ 2 + (ppos.z - pos.z) ^ 2)

			if dist <= (PALEONTOLOGY.NOTIFY_RADIUS or 250) then
				local mode_desc = (mode == "exposed")
					and "exposed on the surface"
					or "buried underground"
				minetest.chat_send_player(
					pname,
					string.format(
						"[Paleontology] Ancient %s skeleton detected nearby (%dm away at %d, %d, %d — %s)!",
						tostring(species or "Dinosaur"),
						math.floor(dist),
						math.floor(pos.x),
						math.floor(pos.y),
						math.floor(pos.z),
						mode_desc
					)
				)
			end
		end
	end
end

function PALEONTOLOGY.spawn_fossil_site(surface_pos, mode, rng)
	if not surface_pos then
		return nil
	end

	mode = (mode == "exposed") and "exposed" or "buried"

	local blueprints = PALEONTOLOGY.get_voxel_blueprints()
	local bp_idx = rng and rng:next(1, #blueprints) or math.random(1, #blueprints)
	local blueprint = blueprints[bp_idx]

	-- Random horizontal cardinal rotation (0, 90, 180, or 270 degrees)
	local rot_steps = rng and rng:next(0, 3) or math.random(0, 3)
	local yaw = rot_steps * (math.pi * 0.5)

	local len_half = math.ceil((blueprint.length or 11) * 0.5) + 2
	local wid_half = math.ceil((blueprint.width or 5) * 0.5) + 2
	local half_x = (rot_steps % 2 == 1) and len_half or wid_half
	local half_z = (rot_steps % 2 == 1) and wid_half or len_half
	half_x = math.max(5, half_x)
	half_z = math.max(5, half_z)

	local skeleton_base_pos
	if mode == "exposed" then
		-- Clear grass, create dirt-path excavation pit, and build 2-node-high fence enclosure
		PALEONTOLOGY.create_excavation_pit(surface_pos, half_x, half_z)
		PALEONTOLOGY.build_fence_enclosure(surface_pos, half_x, half_z)

		skeleton_base_pos = {
			x = surface_pos.x,
			y = surface_pos.y,
			z = surface_pos.z,
		}
		PALEONTOLOGY.place_voxel_skeleton(skeleton_base_pos, blueprint, rot_steps, false)
	else
		-- Buried mode: place 2-4 nodes underground and cover with natural terrain
		local min_d = PALEONTOLOGY.MIN_BURIED_DEPTH or 2
		local max_d = PALEONTOLOGY.MAX_BURIED_DEPTH or 4
		local depth = rng and rng:next(min_d, max_d) or math.random(min_d, max_d)

		skeleton_base_pos = {
			x = surface_pos.x,
			y = surface_pos.y - depth,
			z = surface_pos.z,
		}
		PALEONTOLOGY.bury_skeleton_terrain(surface_pos, skeleton_base_pos, half_x, half_z)
		PALEONTOLOGY.place_voxel_skeleton(skeleton_base_pos, blueprint, rot_steps, true)
	end

	local staticdata = minetest.serialize({
		species = blueprint.species,
		yaw = yaw,
		rot_x = math.rad(90),
		mode = mode,
		voxel_placed = true,
	})

	local obj = minetest.add_entity(skeleton_base_pos, "paleontology:skeleton", staticdata)
	PALEONTOLOGY.notify_nearby_players(skeleton_base_pos, mode, blueprint.species)

	minetest.log("action", string.format(
		"[paleontology] Spawned voxel %s skeleton (%s mode) at (%d, %d, %d)",
		tostring(blueprint.species),
		mode,
		skeleton_base_pos.x,
		skeleton_base_pos.y,
		skeleton_base_pos.z
	))

	return obj, skeleton_base_pos
end

-- ============================================================================
-- WORLD GENERATION (minetest.register_on_generated)
-- ============================================================================

function PALEONTOLOGY.find_surface_position(cx, cz, min_y, max_y)
	local scan_bottom = math.max(min_y, 1)
	for y = max_y - 1, scan_bottom, -1 do
		local n_cur = minetest.get_node({ x = cx, y = y, z = cz }).name
		local n_above = minetest.get_node({ x = cx, y = y + 1, z = cz }).name

		if PALEONTOLOGY.is_surface_node(n_cur) and PALEONTOLOGY.is_clear_above(n_above) then
			local valid = true
			for _, offset in ipairs({ { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } }) do
				local sx, sz = cx + offset[1], cz + offset[2]
				local found_corner = false
				for dy = 6, -6, -1 do
					local cn = minetest.get_node({ x = sx, y = y + dy, z = sz }).name
					local ca = minetest.get_node({ x = sx, y = y + dy + 1, z = sz }).name
					if PALEONTOLOGY.is_surface_node(cn) and PALEONTOLOGY.is_clear_above(ca) then
						found_corner = true
						break
					end
				end
				if not found_corner then
					valid = false
					break
				end
			end

			if valid then
				return { x = cx, y = y, z = cz }
			end
		end
	end
	return nil
end

minetest.register_on_generated(function(minp, maxp, blockseed)
	if not minp or not maxp then
		return
	end

	if maxp.y < 1 or minp.y > 160 then
		return
	end

	if (maxp.x - minp.x) < 20 or (maxp.z - minp.z) < 20 then
		return
	end

	local rng = PcgRandom and PcgRandom((blockseed or 0) + 58391) or nil

	-- Try up to 12 candidate (cx, cz) coordinates in the chunk to locate valid ground surface
	local margin = 10
	local surface_pos = nil
	for _ = 1, 12 do
		local cx = rng and rng:next(minp.x + margin, maxp.x - margin)
			or math.random(minp.x + margin, maxp.x - margin)
		local cz = rng and rng:next(minp.z + margin, maxp.z - margin)
			or math.random(minp.z + margin, maxp.z - margin)

		surface_pos = PALEONTOLOGY.find_surface_position(cx, cz, minp.y, maxp.y)
		if surface_pos then
			break
		end
	end

	if not surface_pos then
		return
	end

	local chance = math.max(1, tonumber(PALEONTOLOGY.SPAWN_CHANCE) or 2)
	local roll = rng and rng:next(1, chance) or math.random(1, chance)
	if roll ~= 1 then
		return
	end

	local active_mode = (PALEONTOLOGY.MODE == "exposed") and "exposed" or "buried"
	PALEONTOLOGY.spawn_fossil_site(surface_pos, active_mode, rng)
end)

-- ============================================================================
-- CHAT COMMAND (/spawn_fossil [buried|exposed])
-- ============================================================================

if minetest and minetest.register_chatcommand then
	minetest.register_chatcommand("spawn_fossil", {
		params = "[buried|exposed]",
		description = "Spawn a large diggable voxel dinosaur skeleton at your position (defaults to PALEONTOLOGY.MODE)",
		privs = {},
		func = function(name, param)
			local player = minetest.get_player_by_name(name)
			if not player then
				return false, "Player not found."
			end
			local ppos = player:get_pos()
			if not ppos then
				return false, "Unable to determine player position."
			end

			local mode = param and param:lower():match("^%s*(%S+)%s*$") or ""
			if mode ~= "buried" and mode ~= "exposed" then
				mode = (PALEONTOLOGY.MODE == "exposed") and "exposed" or "buried"
			end

			local target_pos = {
				x = math.floor(ppos.x + 0.5),
				y = math.floor(ppos.y - 0.5),
				z = math.floor(ppos.z + 0.5),
			}

			local _, spawned_pos = PALEONTOLOGY.spawn_fossil_site(target_pos, mode, nil)
			if spawned_pos then
				return true, string.format(
					"[Paleontology] Spawned %s voxel dinosaur skeleton at (%d, %d, %d)! Dig the bone blocks to collect & rebuild!",
					mode,
					math.floor(spawned_pos.x),
					math.floor(spawned_pos.y),
					math.floor(spawned_pos.z)
				)
			end
			return false, "Failed to spawn dinosaur fossil."
		end,
	})
end

if minetest and minetest.register_on_mods_loaded then
	minetest.register_on_mods_loaded(function()
		PALEONTOLOGY.GAME_ID, PALEONTOLOGY.RAW_GAME_ID = PALEONTOLOGY.detect_game()
		minetest.log("action", string.format(
			"[paleontology] Loaded successfully (game=%s, mode=%s, voxel_blueprints=%d)",
			tostring(PALEONTOLOGY.GAME_ID),
			tostring(PALEONTOLOGY.MODE),
			#PALEONTOLOGY.get_voxel_blueprints()
		))
	end)
end
