## test_progression_catalogs.gd
## PORTS: nothing — new file, covers ships, skins, arenas and tuning in
## src/meta/progression_manager.gd
extends GutTest
## Proves buy/equip/get for the three catalogs, the legacy ship-id aliases,
## and the clamped steering tuning setters.

## DIVERGENCE(THEME R1, user 2026-09-29): five concept and five country-colour pairs of
## arena and enemy skin follow the TS's six, appended so saved ids keep their meaning.
const NEW_PAIRS: Array[String] = [
	"arctic", "ember", "neon", "ocean", "desert", "ph", "jp", "br", "us", "de"
]

var _pm: ProgressionManager = null


func _remove_save() -> void:
	var absolute: String = ProjectSettings.globalize_path(ProgressionManager.SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove_save()
	_pm = ProgressionManager.new()
	_pm.data.points = 7331  # DIVERGENCE(ECON R3): buy from a funded save (TS start balance)


func after_each() -> void:
	_remove_save()


func test_equipped_ship_defaults_to_classic_and_falls_back_to_index_zero() -> void:
	assert_eq(_pm.get_equipped_ship().id, "classic")
	assert_eq(_pm.get_equipped_ship().starting_weapon, Types.WeaponType.SHIELD, ":138")
	_pm.data.equipped_cursor_id = "nosuch"
	assert_eq(_pm.get_equipped_ship().id, "classic", "|| this.shipCatalog[0] (:734)")
	assert_true(_pm.get_equipped_cursor() == _pm.get_equipped_ship(), "alias (:740)")


func test_buy_ship_charges_unlocks_equips_and_saves() -> void:
	assert_eq(_pm.data.points, 7331)
	assert_true(_pm.buy_ship("solar"))
	assert_eq(_pm.data.points, 7331 - 600, ":195")
	assert_true(_pm.data.unlocked_cursors.has("solar"))
	assert_eq(_pm.data.equipped_cursor_id, "solar", "buying equips (:720)")
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.equipped_cursor_id, "solar", "saved (:721)")
	assert_eq(again.get_equipped_ship().hitbox_scale, 1.90)


func test_buy_ship_already_owned_returns_true_without_charging() -> void:
	assert_true(_pm.buy_ship("tactical"), "free and pre-unlocked (:715)")
	assert_eq(_pm.data.points, 7331)
	assert_eq(_pm.data.equipped_cursor_id, "classic", "an owned ship is not re-equipped by buying")


func test_buy_ship_refuses_unknown_and_unaffordable() -> void:
	assert_false(_pm.buy_ship("nosuch"), ":717")
	_pm.data.points = 2499
	assert_false(_pm.buy_ship("revenant"), "2500 > 2499")
	assert_false(_pm.data.unlocked_cursors.has("revenant"))
	assert_eq(_pm.data.points, 2499)


func test_legacy_ship_ids_resolve() -> void:
	assert_true(_pm.equip_ship("Viper"), "'viper' -> 'tactical', case-insensitive (:410-419)")
	assert_eq(_pm.data.equipped_cursor_id, "tactical")
	assert_true(_pm.equip_ship("ARROW"))
	assert_eq(_pm.data.equipped_cursor_id, "classic")
	assert_true(_pm.equip_ship("phantom"))
	assert_eq(_pm.data.equipped_cursor_id, "singularity")
	_pm.data.points = 100000
	assert_true(_pm.buy_ship("aegis"))
	assert_eq(_pm.data.equipped_cursor_id, "solar")
	assert_true(_pm.buy_cursor("matrix"), "alias (:738)")
	assert_eq(_pm.data.equipped_cursor_id, "cyber")


func test_equip_ship_requires_ownership() -> void:
	assert_false(_pm.equip_ship("solar"), "not unlocked (:727)")
	assert_eq(_pm.data.equipped_cursor_id, "classic")
	assert_true(_pm.equip_cursor("singularity"), "alias (:739)")
	assert_eq(_pm.data.equipped_cursor_id, "singularity")
	var again: ProgressionManager = ProgressionManager.new()
	assert_eq(again.data.equipped_cursor_id, "singularity", "equip saves (:729)")


func test_enemy_skins_buy_equip_get() -> void:
	assert_eq(_pm.get_equipped_enemy_skin().id, "classic")
	assert_false(_pm.equip_enemy_skin("gold"), "not owned (:756)")
	assert_true(_pm.buy_enemy_skin("toxic"))
	assert_eq(_pm.data.points, 7331 - 400, ":294")
	assert_eq(_pm.data.equipped_enemy_skin_id, "toxic")
	assert_eq(_pm.get_equipped_enemy_skin().name, "Toxic Biohazard")
	assert_true(_pm.buy_enemy_skin("toxic"), "owned -> true, no charge (:745)")
	assert_eq(_pm.data.points, 6931)
	assert_false(_pm.buy_enemy_skin("nosuch"))
	assert_true(_pm.equip_enemy_skin("classic"))
	assert_eq(_pm.get_equipped_enemy_skin().id, "classic")
	_pm.data.equipped_enemy_skin_id = "nosuch"
	assert_eq(_pm.get_equipped_enemy_skin().id, "classic", "|| catalog[0] (:763)")
	_pm.data.points = 1499
	assert_false(_pm.buy_enemy_skin("gold"), "1500 > 1499")


func test_arena_themes_buy_equip_get() -> void:
	assert_eq(_pm.get_equipped_arena_theme().id, "void")
	assert_false(_pm.equip_arena_theme("matrix"), "not owned (:780)")
	assert_true(_pm.buy_arena_theme("synthwave"))
	assert_eq(_pm.data.points, 7331 - 400, ":357")
	assert_eq(_pm.data.equipped_arena_theme_id, "synthwave")
	assert_eq(_pm.get_equipped_arena_theme().name, "Synthwave Sunset")
	assert_true(_pm.buy_arena_theme("synthwave"), "owned -> true (:769)")
	assert_false(_pm.buy_arena_theme("nosuch"))
	assert_true(_pm.equip_arena_theme("void"))
	_pm.data.equipped_arena_theme_id = "nosuch"
	assert_eq(_pm.get_equipped_arena_theme().id, "void", "|| catalog[0] (:787)")
	var again: ProgressionManager = ProgressionManager.new()
	assert_true(again.data.unlocked_arena_themes.has("synthwave"), "saved (:775)")


func test_tuning_setters_clamp_and_save() -> void:
	_pm.set_sensitivity(5.0)
	assert_almost_eq(_pm.data.tuning.sensitivity, 2.0, 0.0001, "max 2.0 (:793)")
	_pm.set_sensitivity(0.1)
	assert_almost_eq(_pm.data.tuning.sensitivity, 0.5, 0.0001, "min 0.5")
	_pm.set_sensitivity(1.25)
	assert_almost_eq(_pm.data.tuning.sensitivity, 1.25, 0.0001)
	_pm.set_deadzone(40.0)
	assert_almost_eq(_pm.data.tuning.deadzone, 16.0, 0.0001, "max 16 (:798)")
	_pm.set_deadzone(-3.0)
	assert_almost_eq(_pm.data.tuning.deadzone, 0.0, 0.0001, "min 0")
	_pm.set_deadzone(6.5)
	var again: ProgressionManager = ProgressionManager.new()
	assert_almost_eq(again.data.tuning.sensitivity, 1.25, 0.0001, "saved (:794)")
	assert_almost_eq(again.data.tuning.deadzone, 6.5, 0.0001, "saved (:799)")


func test_ship_svg_preview_returns_the_ts_markup() -> void:
	# PORT: web/src/tilt-to-live/ProgressionManager.ts:873-939
	var classic: String = _pm.get_ship_svg_preview("classic")
	assert_true(classic.begins_with("<svg"), "default arm (:932-937)")
	assert_true(
		classic.contains("points='32,3.5 14.9,54.8 32,45.3 49.1,54.8'"), "classic hull (:935)"
	)
	assert_true(
		_pm.get_ship_svg_preview("tactical").contains("fill='#161924'"), "viper hull (:881)"
	)
	assert_true(
		_pm.get_ship_svg_preview("shuriken").contains("M 32,3.1 Q 40.5,18.4"),
		"shuriken path (:919)"
	)
	assert_eq(_pm.get_ship_svg_preview("nonsense"), classic, "unknown ids draw the classic arrow")
	assert_eq(_pm.get_ship_svg_preview(), classic, "no argument = equippedCursorId (:873)")
	_pm.equip_ship("tactical")
	assert_eq(_pm.get_ship_svg_preview(), _pm.get_ship_svg_preview("tactical"))
	var image: Image = Image.new()
	assert_eq(
		image.load_svg_from_string(_pm.get_ship_svg_preview("revenant"), 1.0), OK, "rasterises"
	)
	assert_eq(image.get_size(), Vector2i(64, 64))


func test_the_new_arena_and_enemy_pairs_are_appended_and_well_formed() -> void:
	assert_eq(_pm.arena_theme_catalog.size(), 16)
	assert_eq(_pm.enemy_skin_catalog.size(), 16)
	for i: int in range(NEW_PAIRS.size()):
		var id: String = NEW_PAIRS[i]
		var arena: ProgressionManager.ArenaThemeConfig = _pm.arena_theme_catalog[6 + i]
		var skin: ProgressionManager.EnemySkinConfig = _pm.enemy_skin_catalog[6 + i]
		assert_eq(arena.id, id)
		assert_eq(skin.id, id)
		assert_ne(arena.name, "", id)
		assert_ne(skin.name, "", id)
		assert_gt(arena.price, 0, id)
		assert_gt(skin.price, 0, id)
		assert_eq(arena.bg_gradient.size(), 3, id)
		assert_eq(skin.body_gradient.size(), 3, id)
		assert_ne(arena.description, "", id)
		assert_ne(skin.description, "", id)


func test_the_new_ids_are_unique_within_each_catalog() -> void:
	var arenas: Dictionary = {}
	for a: ProgressionManager.ArenaThemeConfig in _pm.arena_theme_catalog:
		assert_false(arenas.has(a.id), "duplicate arena id %s" % a.id)
		arenas[a.id] = true
	var skins: Dictionary = {}
	for s: ProgressionManager.EnemySkinConfig in _pm.enemy_skin_catalog:
		assert_false(skins.has(s.id), "duplicate skin id %s" % s.id)
		skins[s.id] = true


func test_a_new_pair_can_be_bought_and_equipped() -> void:
	_pm.data.points = 10000
	assert_true(_pm.buy_arena_theme("ph"))
	assert_eq(_pm.get_equipped_arena_theme().id, "ph")
	assert_true(_pm.buy_enemy_skin("jp"))
	assert_eq(_pm.get_equipped_enemy_skin().id, "jp")
