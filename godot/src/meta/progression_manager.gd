## progression_manager.gd
## PORTS: web/src/tilt-to-live/ProgressionManager.ts (940 lines, source commit 7be9614)
class_name ProgressionManager
extends RefCounted
## Perk ranks, ships, cursors, enemy skins, arenas, steering tuning and the
## points economy, persisted as user://tilt_to_live_progression_v3.json.
##
## PORT-NOTE: getCursorSvgDataUri() (ProgressionManager.ts:802-871) and
## getShipSvgPreview() (:873-939) build SVG markup for the browser's CSS
## cursor and the Armory's <img> preview. Neither has a consumer in Godot —
## Android has no pointer cursor and the Armory is a Control scene — so
## neither is ported, the same relocation-out M3/M4 made for render().
## TODO(M8): the Armory decides how a ship preview is drawn.
##
## PORT-NOTE: ProgressionManager.ts:9-43 types each weapon's perks as an
## anonymous nested object. GDScript needs named types, so each nesting is an
## inner class named <Weapon>Perks; the field names inside are the TS names
## snake_cased and unchanged. Ranks default to 0 and keystones to false, which
## is exactly what `perks?.x.y || 0` / `!!perks?.x.y` read when perks is absent.
##
## PORT-NOTE: the save shape is JSON.stringify(this.data) (:519) with the TS
## camelCase keys. Every record below carries to_dict()/from_dict() — the only
## place the camelCase spellings appear — so the file a web build wrote loads
## here unchanged (spec §4.6).

## PORT: web/src/tilt-to-live/ProgressionManager.ts:68
enum ShipShape { CLASSIC, VIPER, PHANTOM, SOLAR, CYBER, SHURIKEN, CELESTIAL }

## PORT: web/src/tilt-to-live/ProgressionManager.ts:119
const STORAGE_KEY: String = "tilt_to_live_progression_v3"
## The localStorage key as a user:// file (spec §4.6).
const SAVE_PATH: String = "user://" + STORAGE_KEY + ".json"

## The player's progression. PORT: web/src/tilt-to-live/ProgressionManager.ts:122
var data: ProgressionData = null

## The seven ships. PORT: web/src/tilt-to-live/ProgressionManager.ts:127-276
## Ship hitbox/turn display strings derive directly from the numeric fields:
##   hitbox% = round(hitboxScale * 50), turn% = round(turnRate * 60)
var ship_catalog: Array[ShipSkinConfig] = []
## The same array as ship_catalog. PORT: web/src/tilt-to-live/ProgressionManager.ts:278
var cursor_catalog: Array[ShipSkinConfig] = []
## PORT: web/src/tilt-to-live/ProgressionManager.ts:280-341
var enemy_skin_catalog: Array[EnemySkinConfig] = []
## PORT: web/src/tilt-to-live/ProgressionManager.ts:343-404
var arena_theme_catalog: Array[ArenaThemeConfig] = []


## PORT: web/src/tilt-to-live/ProgressionManager.ts:406-408
# PORT-NOTE: the TS initialises the catalogs as field initialisers, which run
# before the constructor body; here they are built first for the same effect.
func _init() -> void:
	ship_catalog = _build_ship_catalog()
	cursor_catalog = ship_catalog
	enemy_skin_catalog = _build_enemy_skin_catalog()
	arena_theme_catalog = _build_arena_theme_catalog()
	data = load_data()


## PORT: web/src/tilt-to-live/ProgressionManager.ts:410-419
func _resolve_ship_id(id: String) -> String:
	var map: Dictionary[String, String] = {
		"arrow": "classic",
		"viper": "tactical",
		"phantom": "singularity",
		"aegis": "solar",
		"matrix": "cyber",
	}
	return map.get(id.to_lower(), id)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:421-478
func _get_default_data() -> ProgressionData:
	var d: ProgressionData = ProgressionData.new()
	d.points = 7331  # PORT: web/src/tilt-to-live/ProgressionManager.ts:423
	d.lifetime_points = 7331  # PORT: web/src/tilt-to-live/ProgressionManager.ts:424
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:425-461
	d.perks.blackhole.duration = 3
	d.perks.blackhole.radius = 2
	d.perks.blackhole.gravity = 4
	d.perks.blackhole.invulnerable_inside = false
	d.perks.blackhole.supernova_collapse = false
	d.perks.nuke.radius = 1
	d.perks.nuke.speed = 0
	d.perks.nuke.fallout_zone = false
	d.perks.shield.duration = 0
	d.perks.shield.radius = 0
	d.perks.shield.battering_ram = false
	d.perks.missiles.count = 5
	d.perks.missiles.blast_radius = 0
	d.perks.missiles.flight_speed = 0
	d.perks.laser.length = 2
	d.perks.laser.duration = 0
	d.perks.laser.cross_beam = false
	d.perks.lightning.max_targets = 0
	d.perks.lightning.chain_range = 0
	d.perks.freeze.duration = 0
	d.perks.freeze.shatter_cascade = false
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:462-467
	d.equipped_cursor_id = "classic"
	d.unlocked_cursors = ["classic", "tactical", "singularity"]
	d.equipped_enemy_skin_id = "classic"
	d.unlocked_enemy_skins = ["classic"]
	d.equipped_arena_theme_id = "void"
	d.unlocked_arena_themes = ["void"]
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:468-471
	d.tuning.sensitivity = 1.0
	d.tuning.deadzone = 4.0
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:472-476
	d.extra_lives = 0
	d.hull_compact = 0
	d.enemy_slow = 0
	d.score_multiplier = 0
	d.points_multiplier = 0
	return d


## PORT: web/src/tilt-to-live/ProgressionManager.ts:480-515
# PORT-NOTE: the try/catch (:512-514) is SaveStore's quarantine: a file that
# does not parse is moved aside and load_dict returns {}, which is the `!raw`
# branch (:483). A key of the wrong type keeps the default where the TS spread
# would carry the junk value through — the typed records cannot hold it.
func load_data() -> ProgressionData:
	var raw: Dictionary = SaveStore.load_dict(SAVE_PATH)
	var def: ProgressionData = _get_default_data()
	if raw.is_empty():
		return def

	# {...def, ...parsed} plus the perks and tuning deep merges (:488-490, :493-510)
	def.from_dict(raw)
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:491
	var parsed_points: int = SaveStore.read_int(raw, "points", 0)
	def.points = parsed_points if parsed_points >= 500 else 7331
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:492
	def.lifetime_points = maxi(SaveStore.read_int(raw, "lifetimePoints", 0), 7331)
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:504-506
	def.unlocked_cursors = _unique_union(
		["classic", "tactical", "singularity"], SaveStore.read_string_array(raw, "unlockedCursors")
	)
	def.unlocked_enemy_skins = _unique_union(
		["classic"], SaveStore.read_string_array(raw, "unlockedEnemySkins")
	)
	def.unlocked_arena_themes = _unique_union(
		["void"], SaveStore.read_string_array(raw, "unlockedArenaThemes")
	)
	return def


## PORT: web/src/tilt-to-live/ProgressionManager.ts:517-523
# PORT-NOTE: the console.warn on failure (:521) is SaveStore's Log.warn.
func save() -> void:
	SaveStore.save_dict(SAVE_PATH, data.to_dict())


# `Array.from(new Set([...base, ...extra]))` (ProgressionManager.ts:504-506):
# every element once, in first-seen order.
func _unique_union(base: Array[String], extra: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for item: String in base:
		if not out.has(item):
			out.append(item)
	for item: String in extra:
		if not out.has(item):
			out.append(item)
	return out


# PORT: web/src/tilt-to-live/ProgressionManager.ts:127-276
# PORT-NOTE: each TS object literal becomes a typed record filled field by
# field; the field order inside each block is the TS order.
func _build_ship_catalog() -> Array[ShipSkinConfig]:
	var out: Array[ShipSkinConfig] = []

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:128-148
	var classic: ShipSkinConfig = ShipSkinConfig.new()
	classic.id = "classic"
	classic.name = "Arrow"
	classic.trait_text = "Balanced"
	classic.price = 0
	classic.description = "The iconic high-agility balanced arrow craft with sharp delta wings."
	classic.hitbox = "50%"
	classic.turn = "60%"
	classic.hitbox_scale = 1.0
	classic.turn_rate = 1.0
	classic.starting_weapon = Types.WeaponType.SHIELD
	classic.tint = Color("#5B8CFF")
	classic.svg_path = "M40 24 L14 10 L19 24 L14 38 Z"
	classic.hull_color = Color("#ffffff")
	classic.primary_color = Color("#5B8CFF")
	classic.accent_color = Color("#8FB0FF")
	classic.thruster_color = Color("#5B8CFF")
	classic.trail_color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.4)
	classic.tether_color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.25)
	classic.shape = ShipShape.CLASSIC
	out.append(classic)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:149-169
	var tactical: ShipSkinConfig = ShipSkinConfig.new()
	tactical.id = "tactical"
	tactical.name = "Viper"
	tactical.trait_text = "Aggressive"
	tactical.price = 0
	tactical.description = "Aggressive forward-swept fighter jet with high turn speed."
	tactical.hitbox = "60%"
	tactical.turn = "81%"
	tactical.hitbox_scale = 1.20
	tactical.turn_rate = 1.35
	tactical.starting_weapon = Types.WeaponType.MISSILES
	tactical.tint = Color("#FF8A94")
	tactical.svg_path = "M40 24 L12 8 L20 24 L12 40 Z"
	tactical.hull_color = Color("#161924")
	tactical.primary_color = Color("#FF8A94")
	tactical.accent_color = Color("#ff2a4b")
	tactical.thruster_color = Color("#ff5500")
	tactical.trail_color = Color(255.0 / 255.0, 138.0 / 255.0, 148.0 / 255.0, 0.4)
	tactical.tether_color = Color(255.0 / 255.0, 138.0 / 255.0, 148.0 / 255.0, 0.35)
	tactical.shape = ShipShape.VIPER
	out.append(tactical)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:170-190
	var singularity: ShipSkinConfig = ShipSkinConfig.new()
	singularity.id = "singularity"
	singularity.name = "Phantom"
	singularity.trait_text = "Evasive"
	singularity.price = 0
	singularity.description = (
		"Ultra-thin evasive voidcraft with minuscule hitbox to slip past dense " + "swarms."
	)
	singularity.hitbox = "20%"
	singularity.turn = "48%"
	singularity.hitbox_scale = 0.40
	singularity.turn_rate = 0.80
	singularity.starting_weapon = Types.WeaponType.FREEZE
	singularity.tint = Color("#A78BFA")
	singularity.svg_path = "M42 24 L10 12 L22 24 L10 36 Z"
	singularity.hull_color = Color("#160826")
	singularity.primary_color = Color("#A78BFA")
	singularity.accent_color = Color("#b84dff")
	singularity.thruster_color = Color("#9933ff")
	singularity.trail_color = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0, 0.4)
	singularity.tether_color = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0, 0.35)
	singularity.shape = ShipShape.PHANTOM
	out.append(singularity)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:191-211
	var solar: ShipSkinConfig = ShipSkinConfig.new()
	solar.id = "solar"
	solar.name = "Aegis"
	solar.trait_text = "Heavy"
	solar.price = 600
	solar.description = (
		"Heavy reinforced armored chassis with immense presence and slower turn " + "rate."
	)
	solar.hitbox = "95%"
	solar.turn = "27%"
	solar.hitbox_scale = 1.90
	solar.turn_rate = 0.45
	solar.starting_weapon = Types.WeaponType.NUKE
	solar.tint = Color("#FFB14D")
	solar.svg_path = "M41 24 L33 9 L17 9 L7 24 L17 39 L33 39 Z"
	solar.hull_color = Color("#ffd700")
	solar.primary_color = Color("#FFB14D")
	solar.accent_color = Color("#ffffff")
	solar.thruster_color = Color("#ffaa00")
	solar.trail_color = Color(255.0 / 255.0, 177.0 / 255.0, 77.0 / 255.0, 0.4)
	solar.tether_color = Color(255.0 / 255.0, 177.0 / 255.0, 77.0 / 255.0, 0.35)
	solar.shape = ShipShape.SOLAR
	out.append(solar)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:212-232
	var cyber: ShipSkinConfig = ShipSkinConfig.new()
	cyber.id = "cyber"
	cyber.name = "Matrix"
	cyber.trait_text = "Fast cooldown"
	cyber.price = 800
	cyber.description = ("Digital diamond vector hull tuned for fast responses and tight maneuvers.")
	cyber.hitbox = "53%"
	cyber.turn = "78%"
	cyber.hitbox_scale = 1.05
	cyber.turn_rate = 1.30
	cyber.starting_weapon = Types.WeaponType.LIGHTNING
	cyber.tint = Color("#3DDC97")
	cyber.svg_path = "M24 6 L40 24 L24 42 L8 24 Z"
	cyber.hull_color = Color("#0a1220")
	cyber.primary_color = Color("#3DDC97")
	cyber.accent_color = Color("#00ffff")
	cyber.thruster_color = Color("#ff00aa")
	cyber.trail_color = Color(61.0 / 255.0, 220.0 / 255.0, 151.0 / 255.0, 0.4)
	cyber.tether_color = Color(61.0 / 255.0, 220.0 / 255.0, 151.0 / 255.0, 0.32)
	cyber.shape = ShipShape.CYBER
	out.append(cyber)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:233-253
	var shuriken: ShipSkinConfig = ShipSkinConfig.new()
	shuriken.id = "shuriken"
	shuriken.name = "Shuriken"
	shuriken.trait_text = "Spin drift"
	shuriken.price = 1000
	shuriken.description = (
		"Starframe chassis boasting extreme rotational acceleration and spin " + "agility."
	)
	shuriken.hitbox = "43%"
	shuriken.turn = "96%"
	shuriken.hitbox_scale = 0.85
	shuriken.turn_rate = 1.60
	shuriken.starting_weapon = Types.WeaponType.LASER
	shuriken.tint = Color("#8FB0FF")
	shuriken.svg_path = "M24 6 L30 18 L42 24 L30 30 L24 42 L18 30 L6 24 L18 18 Z"
	shuriken.hull_color = Color("#082014")
	shuriken.primary_color = Color("#8FB0FF")
	shuriken.accent_color = Color("#88ffcc")
	shuriken.thruster_color = Color("#5b8cff")
	shuriken.trail_color = Color(143.0 / 255.0, 176.0 / 255.0, 255.0 / 255.0, 0.4)
	shuriken.tether_color = Color(143.0 / 255.0, 176.0 / 255.0, 255.0 / 255.0, 0.35)
	shuriken.shape = ShipShape.SHURIKEN
	out.append(shuriken)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:254-275
	var revenant: ShipSkinConfig = ShipSkinConfig.new()
	revenant.id = "revenant"
	revenant.name = "Revenant"
	revenant.trait_text = "Second wind"
	revenant.price = 2500
	revenant.description = (
		"A ghostly celestial hull reforged from lost light, granting one extra "
		+ "life to rise again."
	)
	revenant.hitbox = "68%"
	revenant.turn = "54%"
	revenant.hitbox_scale = 1.35
	revenant.turn_rate = 0.90
	revenant.starting_weapon = Types.WeaponType.VORTEX
	revenant.bonus_lives = 1
	revenant.tint = Color("#FFB14D")
	revenant.svg_path = "M40 24 L16 8 L22 24 L16 40 Z"
	revenant.hull_color = Color("#f8fafc")
	revenant.primary_color = Color("#FFB14D")
	revenant.accent_color = Color("#38bdf8")
	revenant.thruster_color = Color("#38bdf8")
	revenant.trail_color = Color(255.0 / 255.0, 177.0 / 255.0, 77.0 / 255.0, 0.4)
	revenant.tether_color = Color(255.0 / 255.0, 177.0 / 255.0, 77.0 / 255.0, 0.35)
	revenant.shape = ShipShape.CELESTIAL
	out.append(revenant)

	return out


# PORT: web/src/tilt-to-live/ProgressionManager.ts:280-341
func _build_enemy_skin_catalog() -> Array[EnemySkinConfig]:
	var out: Array[EnemySkinConfig] = []

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:281-290
	var classic: EnemySkinConfig = EnemySkinConfig.new()
	classic.id = "classic"
	classic.name = "Classic Crimson"
	classic.price = 0
	classic.description = "The iconic evil red dots with sinister crimson body and dark pupil."
	classic.glow_color = Color(255.0 / 255.0, 30.0 / 255.0, 60.0 / 255.0, 0.35)
	classic.body_gradient = [Color("#ff6677"), Color("#ee1133"), Color("#990011")]
	classic.pupil_color = Color("#110005")
	classic.border_color = Color("#ff8899")
	out.append(classic)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:291-300
	var toxic: EnemySkinConfig = EnemySkinConfig.new()
	toxic.id = "toxic"
	toxic.name = "Toxic Biohazard"
	toxic.price = 400
	toxic.description = "Radioactive neon-green cellular organisms with bubbling caustic cores."
	toxic.glow_color = Color(0.0 / 255.0, 255.0 / 255.0, 100.0 / 255.0, 0.35)
	toxic.body_gradient = [Color("#88ff99"), Color("#11ee44"), Color("#007722")]
	toxic.pupil_color = Color("#021805")
	toxic.border_color = Color("#aaffbb")
	out.append(toxic)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:301-310
	var glitch: EnemySkinConfig = EnemySkinConfig.new()
	glitch.id = "glitch"
	glitch.name = "Cyber Glitch"
	glitch.price = 600
	glitch.description = (
		"Polygon wireframe cyber dots flickering between electric cyan and hot " + "magenta."
	)
	glitch.glow_color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.4)
	glitch.body_gradient = [Color("#88ffff"), Color("#00bfff"), Color("#0044aa")]
	glitch.pupil_color = Color("#ff0077")
	glitch.border_color = Color("#5B8CFF")
	out.append(glitch)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:311-320
	var magma: EnemySkinConfig = EnemySkinConfig.new()
	magma.id = "magma"
	magma.name = "Molten Magma"
	magma.price = 800
	magma.description = "Volcanic burning ember cores encased in cracked obsidian rock."
	magma.glow_color = Color(255.0 / 255.0, 120.0 / 255.0, 0.0 / 255.0, 0.4)
	magma.body_gradient = [Color("#ffcc00"), Color("#ff5500"), Color("#881100")]
	magma.pupil_color = Color("#2b0800")
	magma.border_color = Color("#ffaa33")
	out.append(magma)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:321-330
	var void_skin: EnemySkinConfig = EnemySkinConfig.new()
	void_skin.id = "void"
	void_skin.name = "Abyssal Void"
	void_skin.price = 1000
	void_skin.description = ("Pitch-black shadow orbs surrounded by a pulsating violet event horizon.")
	void_skin.glow_color = Color(180.0 / 255.0, 50.0 / 255.0, 255.0 / 255.0, 0.45)
	void_skin.body_gradient = [Color("#9944ff"), Color("#330066"), Color("#080014")]
	void_skin.pupil_color = Color("#ffffff")
	void_skin.border_color = Color("#cc88ff")
	out.append(void_skin)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:331-340
	var gold: EnemySkinConfig = EnemySkinConfig.new()
	gold.id = "gold"
	gold.name = "Midas Gold"
	gold.price = 1500
	gold.description = "Polished metallic reflective 24K gold spheres with radiant star gleams."
	gold.glow_color = Color(255.0 / 255.0, 215.0 / 255.0, 0.0 / 255.0, 0.45)
	gold.body_gradient = [Color("#fff6b3"), Color("#FFB14D"), Color("#aa7700")]
	gold.pupil_color = Color("#442a00")
	gold.border_color = Color("#fff088")
	out.append(gold)

	return out


# PORT: web/src/tilt-to-live/ProgressionManager.ts:343-404
func _build_arena_theme_catalog() -> Array[ArenaThemeConfig]:
	var out: Array[ArenaThemeConfig] = []

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:344-353
	var void_arena: ArenaThemeConfig = ArenaThemeConfig.new()
	void_arena.id = "void"
	void_arena.name = "Void Vector"
	void_arena.price = 0
	void_arena.description = "Deep midnight void canvas with classic reactive cyan vector mesh."
	void_arena.bg_gradient = [Color("#100c1e"), Color("#090712"), Color("#040308")]
	void_arena.grid_color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.18)
	void_arena.boundary_color = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.4)
	void_arena.dust_color = Color("#5B8CFF")
	out.append(void_arena)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:354-363
	var synthwave: ArenaThemeConfig = ArenaThemeConfig.new()
	synthwave.id = "synthwave"
	synthwave.name = "Synthwave Sunset"
	synthwave.price = 400
	synthwave.description = "Ultraviolet to magenta gradient with electric hot-pink grid lines."
	synthwave.bg_gradient = [Color("#280838"), Color("#140020"), Color("#08000d")]
	synthwave.grid_color = Color(255.0 / 255.0, 0.0 / 255.0, 160.0 / 255.0, 0.22)
	synthwave.boundary_color = Color(255.0 / 255.0, 0.0 / 255.0, 180.0 / 255.0, 0.5)
	synthwave.dust_color = Color("#ff00aa")
	out.append(synthwave)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:364-373
	var nebula: ArenaThemeConfig = ArenaThemeConfig.new()
	nebula.id = "nebula"
	nebula.name = "Cosmic Nebula"
	nebula.price = 600
	nebula.description = (
		"Living deep-space expanse with cobalt-purple stars and drifting violet " + "dust."
	)
	nebula.bg_gradient = [Color("#0f1738"), Color("#070b1c"), Color("#02040b")]
	nebula.grid_color = Color(130.0 / 255.0, 90.0 / 255.0, 255.0 / 255.0, 0.22)
	nebula.boundary_color = Color(150.0 / 255.0, 100.0 / 255.0, 255.0 / 255.0, 0.5)
	nebula.dust_color = Color("#aa77ff")
	out.append(nebula)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:374-383
	var matrix: ArenaThemeConfig = ArenaThemeConfig.new()
	matrix.id = "matrix"
	matrix.name = "Matrix Terminal"
	matrix.price = 800
	matrix.description = (
		"Dark circuit-board grid with emerald data pulses and digital matrix " + "ambience."
	)
	matrix.bg_gradient = [Color("#041a0d"), Color("#020d06"), Color("#010502")]
	matrix.grid_color = Color(0.0 / 255.0, 255.0 / 255.0, 120.0 / 255.0, 0.22)
	matrix.boundary_color = Color(0.0 / 255.0, 255.0 / 255.0, 120.0 / 255.0, 0.5)
	matrix.dust_color = Color("#00ff88")
	out.append(matrix)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:384-393
	var supernova: ArenaThemeConfig = ArenaThemeConfig.new()
	supernova.id = "supernova"
	supernova.name = "Supernova Furnace"
	supernova.price = 1000
	supernova.description = "Blazing solar core with incandescent amber-orange heatwave grid lines."
	supernova.bg_gradient = [Color("#2e0c00"), Color("#140500"), Color("#080200")]
	supernova.grid_color = Color(255.0 / 255.0, 130.0 / 255.0, 0.0 / 255.0, 0.24)
	supernova.boundary_color = Color(255.0 / 255.0, 140.0 / 255.0, 0.0 / 255.0, 0.55)
	supernova.dust_color = Color("#ffaa00")
	out.append(supernova)

	# PORT: web/src/tilt-to-live/ProgressionManager.ts:394-403
	var blueprint: ArenaThemeConfig = ArenaThemeConfig.new()
	blueprint.id = "blueprint"
	blueprint.name = "Architectural Blueprint"
	blueprint.price = 1200
	blueprint.description = (
		"Classic CAD drafting technical navy with crisp white coordinate grid " + "lines."
	)
	blueprint.bg_gradient = [Color("#0c2848"), Color("#061628"), Color("#020b16")]
	blueprint.grid_color = Color(255.0 / 255.0, 255.0 / 255.0, 255.0 / 255.0, 0.28)
	blueprint.boundary_color = Color(255.0 / 255.0, 255.0 / 255.0, 255.0 / 255.0, 0.65)
	blueprint.dust_color = Color("#ffffff")
	out.append(blueprint)

	return out


## PORT: web/src/tilt-to-live/ProgressionManager.ts:9-15
class BlackholePerks:
	extends RefCounted
	var duration: int = 0
	var radius: int = 0
	var gravity: int = 0
	var invulnerable_inside: bool = false
	var supernova_collapse: bool = false

	func to_dict() -> Dictionary:
		return {
			"duration": duration,
			"radius": radius,
			"gravity": gravity,
			"invulnerableInside": invulnerable_inside,
			"supernovaCollapse": supernova_collapse,
		}

	func from_dict(d: Dictionary) -> void:
		duration = SaveStore.read_int(d, "duration", duration)
		radius = SaveStore.read_int(d, "radius", radius)
		gravity = SaveStore.read_int(d, "gravity", gravity)
		invulnerable_inside = SaveStore.read_bool(d, "invulnerableInside", invulnerable_inside)
		supernova_collapse = SaveStore.read_bool(d, "supernovaCollapse", supernova_collapse)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:16-20
class NukePerks:
	extends RefCounted
	var radius: int = 0
	var speed: int = 0
	var fallout_zone: bool = false

	func to_dict() -> Dictionary:
		return {"radius": radius, "speed": speed, "falloutZone": fallout_zone}

	func from_dict(d: Dictionary) -> void:
		radius = SaveStore.read_int(d, "radius", radius)
		speed = SaveStore.read_int(d, "speed", speed)
		fallout_zone = SaveStore.read_bool(d, "falloutZone", fallout_zone)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:21-25
class ShieldPerks:
	extends RefCounted
	var duration: int = 0
	var radius: int = 0
	var battering_ram: bool = false

	func to_dict() -> Dictionary:
		return {"duration": duration, "radius": radius, "batteringRam": battering_ram}

	func from_dict(d: Dictionary) -> void:
		duration = SaveStore.read_int(d, "duration", duration)
		radius = SaveStore.read_int(d, "radius", radius)
		battering_ram = SaveStore.read_bool(d, "batteringRam", battering_ram)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:26-30
class MissilesPerks:
	extends RefCounted
	var count: int = 0
	var blast_radius: int = 0
	var flight_speed: int = 0

	func to_dict() -> Dictionary:
		return {"count": count, "blastRadius": blast_radius, "flightSpeed": flight_speed}

	func from_dict(d: Dictionary) -> void:
		count = SaveStore.read_int(d, "count", count)
		blast_radius = SaveStore.read_int(d, "blastRadius", blast_radius)
		flight_speed = SaveStore.read_int(d, "flightSpeed", flight_speed)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:31-35
class LaserPerks:
	extends RefCounted
	var length: int = 0
	var duration: int = 0
	var cross_beam: bool = false

	func to_dict() -> Dictionary:
		return {"length": length, "duration": duration, "crossBeam": cross_beam}

	func from_dict(d: Dictionary) -> void:
		length = SaveStore.read_int(d, "length", length)
		duration = SaveStore.read_int(d, "duration", duration)
		cross_beam = SaveStore.read_bool(d, "crossBeam", cross_beam)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:36-39
class LightningPerks:
	extends RefCounted
	var max_targets: int = 0
	var chain_range: int = 0

	func to_dict() -> Dictionary:
		return {"maxTargets": max_targets, "chainRange": chain_range}

	func from_dict(d: Dictionary) -> void:
		max_targets = SaveStore.read_int(d, "maxTargets", max_targets)
		chain_range = SaveStore.read_int(d, "chainRange", chain_range)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:40-43
class FreezePerks:
	extends RefCounted
	var duration: int = 0
	var shatter_cascade: bool = false

	func to_dict() -> Dictionary:
		return {"duration": duration, "shatterCascade": shatter_cascade}

	func from_dict(d: Dictionary) -> void:
		duration = SaveStore.read_int(d, "duration", duration)
		shatter_cascade = SaveStore.read_bool(d, "shatterCascade", shatter_cascade)


## Per-weapon perk ranks and keystones. PORT: web/src/tilt-to-live/ProgressionManager.ts:8-44
class WeaponPerks:
	extends RefCounted
	var blackhole: BlackholePerks = BlackholePerks.new()
	var nuke: NukePerks = NukePerks.new()
	var shield: ShieldPerks = ShieldPerks.new()
	var missiles: MissilesPerks = MissilesPerks.new()
	var laser: LaserPerks = LaserPerks.new()
	var lightning: LightningPerks = LightningPerks.new()
	var freeze: FreezePerks = FreezePerks.new()

	## The TS object shape: {"blackhole": {...}, "nuke": {...}, ...}.
	func to_dict() -> Dictionary:
		return {
			"blackhole": blackhole.to_dict(),
			"nuke": nuke.to_dict(),
			"shield": shield.to_dict(),
			"missiles": missiles.to_dict(),
			"laser": laser.to_dict(),
			"lightning": lightning.to_dict(),
			"freeze": freeze.to_dict(),
		}

	## The per-weapon deep merge of ProgressionManager.ts:493-503.
	func from_dict(d: Dictionary) -> void:
		blackhole.from_dict(SaveStore.read_dict(d, "blackhole"))
		nuke.from_dict(SaveStore.read_dict(d, "nuke"))
		shield.from_dict(SaveStore.read_dict(d, "shield"))
		missiles.from_dict(SaveStore.read_dict(d, "missiles"))
		laser.from_dict(SaveStore.read_dict(d, "laser"))
		lightning.from_dict(SaveStore.read_dict(d, "lightning"))
		freeze.from_dict(SaveStore.read_dict(d, "freeze"))


## PORT: web/src/tilt-to-live/ProgressionManager.ts:46-69
class ShipSkinConfig:
	extends RefCounted
	var id: String = ""
	var name: String = ""
	# PORT-NOTE: `trait` in the TS (ProgressionManager.ts:49) — a reserved word
	# in Godot 4.7, renamed; the save shape is unaffected (the catalog is
	# never persisted) and the fixture keeps the TS key "trait".
	var trait_text: String = ""
	var price: int = 0
	var description: String = ""
	var hitbox: String = ""
	var turn: String = ""
	var hitbox_scale: float = 1.0
	var turn_rate: float = 1.0
	# PORT-NOTE: optional in the TS (:56-58) only so fallback literals in other
	# files stay valid; every catalog entry sets it (:138-264), so the
	# `!startingWeapon` guard at TiltGame.ts:1966 is dead and the default here
	# is never read.
	var starting_weapon: Types.WeaponType = Types.WeaponType.NUKE
	# PORT-NOTE: `bonusLives?: number` read as `|| 0` (:691); 0 is that reading.
	var bonus_lives: int = 0
	var tint: Color = Color.WHITE
	# PORT-NOTE: an SVG path string the web menu renders; kept as data so the
	# catalog is a complete port, consumed by nothing in Godot.
	var svg_path: String = ""
	var hull_color: Color = Color.WHITE
	var primary_color: Color = Color.WHITE
	var accent_color: Color = Color.WHITE
	var thruster_color: Color = Color.WHITE
	var trail_color: Color = Color.WHITE
	var tether_color: Color = Color.WHITE
	var shape: ShipShape = ShipShape.CLASSIC


## PORT: web/src/tilt-to-live/ProgressionManager.ts:73-82
class EnemySkinConfig:
	extends RefCounted
	var id: String = ""
	var name: String = ""
	var price: int = 0
	var description: String = ""
	var glow_color: Color = Color.WHITE
	## [inner, mid, outer]. PORT: web/src/tilt-to-live/ProgressionManager.ts:79
	var body_gradient: Array[Color] = []
	var pupil_color: Color = Color.WHITE
	var border_color: Color = Color.WHITE


## PORT: web/src/tilt-to-live/ProgressionManager.ts:84-93
class ArenaThemeConfig:
	extends RefCounted
	var id: String = ""
	var name: String = ""
	var price: int = 0
	var description: String = ""
	var bg_gradient: Array[Color] = []
	var grid_color: Color = Color.WHITE
	var boundary_color: Color = Color.WHITE
	var dust_color: Color = Color.WHITE


## PORT: web/src/tilt-to-live/ProgressionManager.ts:95-98
class SteeringTuning:
	extends RefCounted
	## 0.5 .. 2.0 (default 1.0). PORT: web/src/tilt-to-live/ProgressionManager.ts:96
	var sensitivity: float = 1.0
	## 0 .. 16 (default 4). PORT: web/src/tilt-to-live/ProgressionManager.ts:97
	# PORT-NOTE: a float, not an int — setDeadzone (:797) clamps whatever the
	# slider gives and PlayerShip.ts:166 compares it with a float distance.
	var deadzone: float = 4.0

	func to_dict() -> Dictionary:
		return {"sensitivity": sensitivity, "deadzone": deadzone}

	func from_dict(d: Dictionary) -> void:
		sensitivity = SaveStore.read_float(d, "sensitivity", sensitivity)
		deadzone = SaveStore.read_float(d, "deadzone", deadzone)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:100-117
class ProgressionData:
	extends RefCounted
	var points: int = 0
	var lifetime_points: int = 0
	var perks: WeaponPerks = WeaponPerks.new()
	var equipped_cursor_id: String = ""
	var unlocked_cursors: Array[String] = []
	var equipped_enemy_skin_id: String = ""
	var unlocked_enemy_skins: Array[String] = []
	var equipped_arena_theme_id: String = ""
	var unlocked_arena_themes: Array[String] = []
	var tuning: SteeringTuning = SteeringTuning.new()
	## 0..2, +1 starting life per rank (hard-capped at 3 total). PORT: :112
	var extra_lives: int = 0
	## 0..3, -6% player hitbox per rank. PORT: :113
	var hull_compact: int = 0
	## 0..3, -4% enemy speed per rank. PORT: :114
	var enemy_slow: int = 0
	## 0..4, +10% in-run score per rank. PORT: :115
	var score_multiplier: int = 0
	## 0..4, +10% earned points per rank. PORT: :116
	var points_multiplier: int = 0

	## JSON.stringify(this.data) (ProgressionManager.ts:519), TS key spellings.
	func to_dict() -> Dictionary:
		return {
			"points": points,
			"lifetimePoints": lifetime_points,
			"perks": perks.to_dict(),
			"equippedCursorId": equipped_cursor_id,
			"unlockedCursors": unlocked_cursors.duplicate(),
			"equippedEnemySkinId": equipped_enemy_skin_id,
			"unlockedEnemySkins": unlocked_enemy_skins.duplicate(),
			"equippedArenaThemeId": equipped_arena_theme_id,
			"unlockedArenaThemes": unlocked_arena_themes.duplicate(),
			"tuning": tuning.to_dict(),
			"extraLives": extra_lives,
			"hullCompact": hull_compact,
			"enemySlow": enemy_slow,
			"scoreMultiplier": score_multiplier,
			"pointsMultiplier": points_multiplier,
		}

	## The `{...def, ...parsed}` shallow merge of ProgressionManager.ts:488-490
	## for the scalar fields; perks and tuning merge one level deeper (:493-510).
	## The three unlocked lists and the two point floors are applied by the
	## caller (load_data), because the TS does them after the spread.
	func from_dict(d: Dictionary) -> void:
		points = SaveStore.read_int(d, "points", points)
		lifetime_points = SaveStore.read_int(d, "lifetimePoints", lifetime_points)
		perks.from_dict(SaveStore.read_dict(d, "perks"))
		equipped_cursor_id = SaveStore.read_string(d, "equippedCursorId", equipped_cursor_id)
		if d.has("unlockedCursors"):
			unlocked_cursors = SaveStore.read_string_array(d, "unlockedCursors")
		equipped_enemy_skin_id = SaveStore.read_string(
			d, "equippedEnemySkinId", equipped_enemy_skin_id
		)
		if d.has("unlockedEnemySkins"):
			unlocked_enemy_skins = SaveStore.read_string_array(d, "unlockedEnemySkins")
		equipped_arena_theme_id = SaveStore.read_string(
			d, "equippedArenaThemeId", equipped_arena_theme_id
		)
		if d.has("unlockedArenaThemes"):
			unlocked_arena_themes = SaveStore.read_string_array(d, "unlockedArenaThemes")
		tuning.from_dict(SaveStore.read_dict(d, "tuning"))
		extra_lives = SaveStore.read_int(d, "extraLives", extra_lives)
		hull_compact = SaveStore.read_int(d, "hullCompact", hull_compact)
		enemy_slow = SaveStore.read_int(d, "enemySlow", enemy_slow)
		score_multiplier = SaveStore.read_int(d, "scoreMultiplier", score_multiplier)
		points_multiplier = SaveStore.read_int(d, "pointsMultiplier", points_multiplier)
