# gdlint:disable=max-public-methods,max-file-lines
# PORT-NOTE: ProgressionManager.ts exposes 36 public methods; LAW 3 keeps them.
# The file exceeds gdlint's 1000-line cap because it also carries the seven
# catalogs and every inner record type; splitting it is a Task 6+ concern.
## progression_manager.gd
## PORTS: web/src/tilt-to-live/ProgressionManager.ts (940 lines, source commit 7be9614)
class_name ProgressionManager
extends RefCounted
## Perk ranks, ships, cursors, enemy skins, arenas, steering tuning and the
## points economy, persisted as user://tilt_to_live_progression_v3.json.
##
## PORT-NOTE: getCursorSvgDataUri() (ProgressionManager.ts:802-871) builds the
## browser's CSS cursor image. Android has no pointer cursor and nothing in
## Godot consumes it, so it is not ported — the relocation-out M3/M4 made for
## render(). getShipSvgPreview() (:873-939) IS ported below: the Armory (M8)
## rasterises its markup with Image.load_svg_from_string.
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
##
## Private helpers with no TS member (_unique_union, _find_*, _build_*) sit
## after the public methods (CONVENTIONS §2); _resolve_ship_id and
## _get_default_data keep their TS positions.

## PORT: web/src/tilt-to-live/ProgressionManager.ts:68
enum ShipShape { CLASSIC, VIPER, PHANTOM, SOLAR, CYBER, SHURIKEN, CELESTIAL }
## DIVERGENCE(THEME R2, user 2026-09-29): the background effect each arena theme draws.
## The order is the `pattern` uniform of render/arena_background.gdshader; keep them in step.
enum ArenaPattern {
	NONE,
	STARS,
	SUN,
	CODE,
	SPARKS,
	HEAT,
	DRAFT,
	SNOW,
	RAIN,
	BUBBLES,
	SAND,
	RAYS,
	RIPPLES,
	BANDS_DIAG,
	STARS_BARS,
	BANDS,
}

## PORT: web/src/tilt-to-live/ProgressionManager.ts:119
const STORAGE_KEY: String = "tilt_to_live_progression_v3"
## The localStorage key as a user:// file (spec §4.6).
const SAVE_PATH: String = "user://" + STORAGE_KEY + ".json"

## PORT: web/src/tilt-to-live/ProgressionManager.ts:607-611 (ladder lengths)
## DIVERGENCE(ECON R2): prices rescaled with the new run payout (user 2026-09-28: "fix
## the money scaling where it isnt too easy and isnt too hard"); plan
## docs/superpowers/plans/2026-09-28-armory-economy-icons.md. TS: 4000/9000,
## 1500/3000/5500, 2000/4200/7500, 1800/3600/6500/11000, 2500/5000/9000/15000.
const EXTRA_LIVES_COSTS: Array[int] = [2500, 6000]
const HULL_COMPACT_COSTS: Array[int] = [800, 1600, 3000]
const ENEMY_SLOW_COSTS: Array[int] = [1000, 2000, 3600]
const SCORE_MULTIPLIER_COSTS: Array[int] = [500, 1000, 1800, 3000]
const POINTS_MULTIPLIER_COSTS: Array[int] = [1200, 2400, 4200, 7000]

## DIVERGENCE(ECON R2): perk rank prices, ×1.6 a rank (TS 300/600/1100/1800/2800, :558).
const PERK_COSTS: Array[int] = [250, 400, 650, 1000, 1600]
## DIVERGENCE(ECON R1): the run payout banked at death (no TS counterpart; the TS paid
## only coins and milestones): round((BASE + PER_SECOND·t + KILL_SCALE·kills^KILL_EXPONENT)
## × mode), t = seconds alive. Tuned in the plan's model (novice ~250, mid ~970 a run).
const RUN_PAYOUT_BASE: float = 60.0
const RUN_PAYOUT_PER_SECOND: float = 3.0
const RUN_PAYOUT_KILL_SCALE: float = 4.0
const RUN_PAYOUT_KILL_EXPONENT: float = 0.7
## DIVERGENCE(ECON R3): a fresh save's balance (TS 7331, :423-424).
const STARTING_POINTS: int = 500
## DIVERGENCE(ECON R4, KEY R1): Aegis left the Armory (its shield is innate, ECON R5); a
## save that bought it gets this refund once on load, and the flag clears. Keys are
## "<weapon>.<perk>" in the save's spelling; values are the TS prices. (Fallout Zone,
## Battering Ram and Shatter Cascade are coded now, KEY R1, so owners keep them.)
const DEAD_KEYSTONE_REFUNDS: Dictionary[String, int] = {
	"blackhole.invulnerableInside": 2500,
}

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
	d.points = STARTING_POINTS  # DIVERGENCE(ECON R3)
	d.lifetime_points = STARTING_POINTS  # DIVERGENCE(ECON R3)
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
	# DIVERGENCE(ECON R3): the TS reset a balance under 500 to 7331 and floored lifetime
	# points at 7331 (:491-492) — unlimited money. The saved figures now stand.
	def.points = maxi(0, SaveStore.read_int(raw, "points", STARTING_POINTS))
	def.lifetime_points = maxi(def.points, SaveStore.read_int(raw, "lifetimePoints", 0))
	_refund_dead_keystones(def)
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


## DIVERGENCE(ECON R4): refunds each owned keystone that left the Armory and clears it.
## Idempotent: the refund is written with the next save, together with the cleared flag.
func _refund_dead_keystones(d: ProgressionData) -> void:
	var all: Dictionary = d.perks.to_dict()
	for path: String in DEAD_KEYSTONE_REFUNDS:
		var parts: PackedStringArray = path.split(".")
		var weapon_perks: Dictionary = all[parts[0]]
		if weapon_perks.get(parts[1], false) == true:
			weapon_perks[parts[1]] = false
			d.points += DEAD_KEYSTONE_REFUNDS[path]
	d.perks.from_dict(all)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:517-523
# PORT-NOTE: the console.warn on failure (:521) is SaveStore's Log.warn.
func save() -> void:
	SaveStore.save_dict(SAVE_PATH, data.to_dict())


## Points earned during a run pass through here before landing in the
## player's spendable/lifetime totals, so the points-purchases multiplier
## is applied once, at this single chokepoint.
## PORT: web/src/tilt-to-live/ProgressionManager.ts:525-539
func add_points(amount: int) -> void:
	add_points_credited(amount)


## Banks `amount` (applying the points multiplier) and returns what was
## actually credited, so callers can report real earnings rather than the
## pre-multiplier figure. PORT: web/src/tilt-to-live/ProgressionManager.ts:541-550
# PORT-NOTE: lifetimePoints IS multiplied the same as points (:529-536) —
# it is a running total of everything ever credited, not a raw ledger.
# PORT-NOTE: TiltGame.ts:205-208 re-renders the goals HUD (the points balance
# in the DOM) after every addPoints; spec §5.3 makes that reach the
# points_changed signal, emitted here where the balance changes.
func add_points_credited(amount: int) -> int:
	if amount <= 0:
		return 0
	var credited: int = floori(float(amount) * get_points_multiplier())
	data.points += credited
	data.lifetime_points += credited
	save()
	GameEvents.points_changed.emit(data.points)
	return credited


## DIVERGENCE(ECON R1): the points a finished run banks (before the Points Multiplier,
## which add_points_credited applies).
static func run_payout(seconds_alive: float, kills: int, mode_multiplier: float) -> int:
	var base: float = (
		RUN_PAYOUT_BASE
		+ RUN_PAYOUT_PER_SECOND * maxf(seconds_alive, 0.0)
		+ RUN_PAYOUT_KILL_SCALE * pow(float(maxi(kills, 0)), RUN_PAYOUT_KILL_EXPONENT)
	)
	return roundi(base * mode_multiplier)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:554-560
func get_perk_cost(current_rank: int, is_keystone: bool = false, keystone_key: String = "") -> int:
	if is_keystone:
		if Tuning.KEYSTONE_COSTS.has(keystone_key):  # PORT: :556
			return Tuning.KEYSTONE_COSTS[keystone_key]
		return 2500
	return PERK_COSTS[mini(current_rank, PERK_COSTS.size() - 1)]  # DIVERGENCE(ECON R2)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:562-578
# PORT-NOTE: `(this.data.perks as any)[weapon]` and `Object.keys(p)` (:564,
# :567) are the perks record's dictionary view — WeaponPerks.to_dict() — with
# the TS key spellings, so a keystone key here is also its KEYSTONE_COSTS key.
func get_weapon_invested_points(weapon: String) -> int:
	var total: int = 0
	var p: Dictionary = SaveStore.read_dict(data.perks.to_dict(), weapon)
	if p.is_empty():
		return 0
	# DIVERGENCE(ECON R2): the rank prices are PERK_COSTS (TS :566, :571).
	for key: String in p.keys():
		var val: Variant = p[key]
		if val is int:
			var rank: int = val
			for r: int in range(rank):
				total += get_perk_cost(r)
		elif val is bool and val:
			total += get_perk_cost(0, true, key)
	return total


## PORT: web/src/tilt-to-live/ProgressionManager.ts:580-603
# PORT-NOTE: same dictionary view as get_weapon_invested_points; the edited
# view is written back through WeaponPerks.from_dict, which is a merge, so
# only the one key changes.
# PORT-NOTE: ProgressionManager.ts:580-603 is one function with seven exits
# and an elif chain; kept as one under LAW 3. gdlint's max-returns and
# no-elif-return are disabled for this function only (disable/enable region).
# gdlint:disable=max-returns,no-elif-return
func upgrade_perk(weapon: String, perk_name: String) -> bool:
	var all: Dictionary = data.perks.to_dict()
	if not all.has(weapon):
		return false
	if not (all[weapon] is Dictionary):
		return false
	var weapon_perks: Dictionary = all[weapon]
	if not weapon_perks.has(perk_name):
		return false

	var val: Variant = weapon_perks[perk_name]
	if val is bool:
		if val:
			return false  # Already unlocked
		var cost: int = get_perk_cost(0, true, perk_name)
		if data.points < cost:
			return false
		data.points -= cost
		weapon_perks[perk_name] = true
		data.perks.from_dict(all)
		save()
		return true
	elif val is int:
		var rank: int = val
		if rank >= 5:
			return false  # Max rank reached  # PORT: :594
		var cost: int = get_perk_cost(rank, false)
		if data.points < cost:
			return false
		data.points -= cost
		weapon_perks[perk_name] = rank + 1
		data.perks.from_dict(all)
		save()
		return true
	return false


# gdlint:enable=max-returns,no-elif-return


## PORT: web/src/tilt-to-live/ProgressionManager.ts:613-617
# PORT-NOTE: `number | null` — Types.ABSENT stands for null (types.gd:12-27).
func get_extra_lives_cost() -> int:
	var rank: int = data.extra_lives
	if rank >= EXTRA_LIVES_COSTS.size():
		return Types.ABSENT
	return EXTRA_LIVES_COSTS[rank]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:619-626
func buy_extra_life() -> bool:
	var cost: int = get_extra_lives_cost()
	if cost == Types.ABSENT or data.points < cost:
		return false
	data.points -= cost
	data.extra_lives += 1
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:628-632
func get_hull_compact_cost() -> int:
	var rank: int = data.hull_compact
	if rank >= HULL_COMPACT_COSTS.size():
		return Types.ABSENT
	return HULL_COMPACT_COSTS[rank]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:634-641
func buy_hull_compact() -> bool:
	var cost: int = get_hull_compact_cost()
	if cost == Types.ABSENT or data.points < cost:
		return false
	data.points -= cost
	data.hull_compact += 1
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:643-647
func get_enemy_slow_cost() -> int:
	var rank: int = data.enemy_slow
	if rank >= ENEMY_SLOW_COSTS.size():
		return Types.ABSENT
	return ENEMY_SLOW_COSTS[rank]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:649-656
func buy_enemy_slow() -> bool:
	var cost: int = get_enemy_slow_cost()
	if cost == Types.ABSENT or data.points < cost:
		return false
	data.points -= cost
	data.enemy_slow += 1
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:658-662
func get_score_multiplier_cost() -> int:
	var rank: int = data.score_multiplier
	if rank >= SCORE_MULTIPLIER_COSTS.size():
		return Types.ABSENT
	return SCORE_MULTIPLIER_COSTS[rank]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:664-671
func buy_score_multiplier() -> bool:
	var cost: int = get_score_multiplier_cost()
	if cost == Types.ABSENT or data.points < cost:
		return false
	data.points -= cost
	data.score_multiplier += 1
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:673-677
func get_points_multiplier_cost() -> int:
	var rank: int = data.points_multiplier
	if rank >= POINTS_MULTIPLIER_COSTS.size():
		return Types.ABSENT
	return POINTS_MULTIPLIER_COSTS[rank]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:679-686
func buy_points_multiplier() -> bool:
	var cost: int = get_points_multiplier_cost()
	if cost == Types.ABSENT or data.points < cost:
		return false
	data.points -= cost
	data.points_multiplier += 1
	save()
	return true


## Starting lives = 1 base + extraLives rank + the equipped ship's bonusLives,
## hard-capped at 3 total. PORT: web/src/tilt-to-live/ProgressionManager.ts:688-693
func get_starting_lives() -> int:
	var bonus: int = get_equipped_ship().bonus_lives
	return mini(3, 1 + data.extra_lives + bonus)  # PORT: :692


## PORT: web/src/tilt-to-live/ProgressionManager.ts:695-697
func get_hitbox_multiplier() -> float:
	return 1.0 - 0.06 * float(data.hull_compact)  # PORT: :696


## PORT: web/src/tilt-to-live/ProgressionManager.ts:699-701
func get_enemy_speed_multiplier() -> float:
	return 1.0 - 0.04 * float(data.enemy_slow)  # PORT: :700


## PORT: web/src/tilt-to-live/ProgressionManager.ts:703-705
func get_score_multiplier() -> float:
	return 1.0 + 0.10 * float(data.score_multiplier)  # PORT: :704


## PORT: web/src/tilt-to-live/ProgressionManager.ts:707-709
func get_points_multiplier() -> float:
	return 1.0 + 0.10 * float(data.points_multiplier)  # PORT: :708


## PORT: web/src/tilt-to-live/ProgressionManager.ts:713-723
func buy_ship(id: String) -> bool:
	var canonical: String = _resolve_ship_id(id)
	if data.unlocked_cursors.has(canonical):
		return true
	var item: ShipSkinConfig = _find_ship(canonical)
	if item == null or data.points < item.price:
		return false
	data.points -= item.price
	data.unlocked_cursors.append(canonical)
	data.equipped_cursor_id = canonical
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:725-731
func equip_ship(id: String) -> bool:
	var canonical: String = _resolve_ship_id(id)
	if not data.unlocked_cursors.has(canonical):
		return false
	data.equipped_cursor_id = canonical
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:733-735
func get_equipped_ship() -> ShipSkinConfig:
	var found: ShipSkinConfig = _find_ship(data.equipped_cursor_id)
	return found if found != null else ship_catalog[0]


## Backwards compatibility alias. PORT: web/src/tilt-to-live/ProgressionManager.ts:738
func buy_cursor(id: String) -> bool:
	return buy_ship(id)


## Backwards compatibility alias. PORT: web/src/tilt-to-live/ProgressionManager.ts:739
func equip_cursor(id: String) -> bool:
	return equip_ship(id)


## Backwards compatibility alias. PORT: web/src/tilt-to-live/ProgressionManager.ts:740
func get_equipped_cursor() -> ShipSkinConfig:
	return get_equipped_ship()


## PORT: web/src/tilt-to-live/ProgressionManager.ts:744-753
func buy_enemy_skin(id: String) -> bool:
	if data.unlocked_enemy_skins.has(id):
		return true
	var item: EnemySkinConfig = _find_enemy_skin(id)
	if item == null or data.points < item.price:
		return false
	data.points -= item.price
	data.unlocked_enemy_skins.append(id)
	data.equipped_enemy_skin_id = id
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:755-760
func equip_enemy_skin(id: String) -> bool:
	if not data.unlocked_enemy_skins.has(id):
		return false
	data.equipped_enemy_skin_id = id
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:762-764
func get_equipped_enemy_skin() -> EnemySkinConfig:
	var found: EnemySkinConfig = _find_enemy_skin(data.equipped_enemy_skin_id)
	return found if found != null else enemy_skin_catalog[0]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:768-777
func buy_arena_theme(id: String) -> bool:
	if data.unlocked_arena_themes.has(id):
		return true
	var item: ArenaThemeConfig = _find_arena_theme(id)
	if item == null or data.points < item.price:
		return false
	data.points -= item.price
	data.unlocked_arena_themes.append(id)
	data.equipped_arena_theme_id = id
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:779-784
func equip_arena_theme(id: String) -> bool:
	if not data.unlocked_arena_themes.has(id):
		return false
	data.equipped_arena_theme_id = id
	save()
	return true


## PORT: web/src/tilt-to-live/ProgressionManager.ts:786-788
func get_equipped_arena_theme() -> ArenaThemeConfig:
	var found: ArenaThemeConfig = _find_arena_theme(data.equipped_arena_theme_id)
	return found if found != null else arena_theme_catalog[0]


## PORT: web/src/tilt-to-live/ProgressionManager.ts:792-795
func set_sensitivity(value: float) -> void:
	data.tuning.sensitivity = maxf(0.5, minf(2.0, value))  # PORT: :793
	save()


## PORT: web/src/tilt-to-live/ProgressionManager.ts:797-800
func set_deadzone(value: float) -> void:
	data.tuning.deadzone = maxf(0.0, minf(16.0, value))  # PORT: :798
	save()


## The 64x64 SVG hull preview the Armory shows on each ship card.
## PORT: web/src/tilt-to-live/ProgressionManager.ts:873-939
# PORT-NOTE: the `class='...'` attributes are dropped — they addressed CSS
# rules (game.css:2324) that have no meaning in a rasterised image; every
# geometry and colour attribute is verbatim.
# PORT-NOTE: the TS switches on the *ship* id 'celestial', but no ship has
# that id — the celestial-*shaped* ship is `revenant`
# (ProgressionManager.ts:255-276), so the 'celestial' arm is dead in the web
# game and every revenant card shows the classic preview. Preserved
# deliberately (LAW 2).
# PORT-NOTE: ProgressionManager.ts:873-939 is one switch with seven exits.
# GDScript's `match` needs no early-return to stay one arm per case (unlike
# the TS `switch`/`return`), so the seven exits become a single `body` built
# per-branch and one `return head + body` — same seven outcomes, LAW 3 intact.
func get_ship_svg_preview(ship_id: String = "") -> String:
	var id: String = ship_id if not ship_id.is_empty() else data.equipped_cursor_id
	var head: String = (
		"<svg xmlns='http://www.w3.org/2000/svg' " + "width='64' height='64' viewBox='0 0 64 64'>"
	)
	var body: String = ""
	match id:
		"tactical":  # PORT: :875-885
			body = (
				"<polygon points='25,50 28,60 31,50' fill='#ff5500' opacity='0.85'/>"
				+ "<polygon points='33,50 36,60 39,50' fill='#ff5500' opacity='0.85'/>"
				+ "<polygon points='25.6,25.6 17.6,30.4 25.6,33.6' fill='#ff2a4b'/>"
				+ "<polygon points='38.4,25.6 46.4,30.4 38.4,33.6' fill='#ff2a4b'/>"
				+ "<polygon points='32,3.2 24,28.8 9.6,48 14.4,52.8 25.6,44.8 "
				+ "22.4,54.4 41.6,54.4 38.4,44.8 49.6,52.8 54.4,48 40,28.8' "
				+ "fill='#161924' stroke='#ff2a4b' stroke-width='2.2' stroke-linejoin='round'/>"
				+ "<circle cx='9.6' cy='48' r='3.2' fill='#ff2a4b'/>"
				+ "<circle cx='54.4' cy='48' r='3.2' fill='#ff2a4b'/>"
				+ "<polygon points='32,19.2 28,35.2 32,40 36,35.2' fill='#ff6680'/>"
				+ "</svg>"
			)
		"singularity":  # PORT: :887-893
			body = (
				"<polygon points='28,48 32,58 36,48' fill='#9933ff' opacity='0.9'/>"
				+ "<polygon points='32,3.1 11.6,28.6 16.7,55.8 32,42.2 47.3,55.8 52.4,28.6' "
				+ "fill='#160826' stroke='#b84dff' stroke-width='2.2' stroke-linejoin='round'/>"
				+ "<line x1='32' y1='3.1' x2='32' y2='42.2' stroke='#d88dff' stroke-width='1.2'/>"
				+ "<polygon points='32,25.2 25.9,35.4 32,42.2 38.1,35.4' fill='#e099ff'/>"
				+ "</svg>"
			)
		"solar":  # PORT: :895-904
			body = (
				"<polygon points='22,50 25,58 28,50' fill='#ffaa00' opacity='0.85'/>"
				+ "<polygon points='30,48 32,58 34,48' fill='#ffffff' opacity='0.95'/>"
				+ "<polygon points='36,50 39,58 42,50' fill='#ffaa00' opacity='0.85'/>"
				+ "<polygon points='26.6,3.2 37.4,3.2 48.2,24.8 48.2,39.2 57.2,53.6 53.6,57.2 41,50 "
				+ "32,55.4 23,50 10.4,57.2 6.8,53.6 15.8,39.2 15.8,24.8' "
				+ "fill='#ffd700' stroke='#ff8800' stroke-width='2.2' stroke-linejoin='round'/>"
				+ "<rect x='19.4' y='28.4' width='5.4' height='7.2' fill='#aa7700'/>"
				+ "<rect x='39.2' y='28.4' width='5.4' height='7.2' fill='#aa7700'/>"
				+ "<polygon points='32,21.2 27.5,35.6 32,39.2 36.5,35.6' fill='#ffffff'/>"
				+ "</svg>"
			)
		"cyber":  # PORT: :906-915
			body = (
				"<polygon points='22,50 25,59 28,50' fill='#ff00aa' opacity='0.9'/>"
				+ "<polygon points='36,50 39,59 42,50' fill='#00ffff' opacity='0.9'/>"
				+ "<polyline points='9.25,35.5 5.75,46 12.75,53' "
				+ "fill='none' stroke='#00ffff' stroke-width='1.8'/>"
				+ "<polyline points='54.75,35.5 58.25,46 51.25,53' "
				+ "fill='none' stroke='#ff00aa' stroke-width='1.8'/>"
				+ "<polygon points='32,4 21.5,18 16.25,46 23.25,54.75 32,46 40.75,54.75 47.75,46 42.5,18' "
				+ "fill='#0a1220' stroke='#00ffff' stroke-width='2' stroke-linejoin='round'/>"
				+ "<rect x='26.75' y='25' width='10.5' height='10.5' "
				+ "fill='none' stroke='#ff00aa' stroke-width='1.5'/>"
				+ "<circle cx='32' cy='30.25' r='3.85' fill='#00ffcc'/>"
				+ "</svg>"
			)
		"shuriken":  # PORT: :917-922
			body = (
				"<path d='M 32,3.1 Q 40.5,18.4 35.4,28.6 L 59.2,32 Q 45.6,40.5 35.4,35.4 "
				+ "L 32,57.5 Q 23.5,45.6 28.6,35.4 L 4.8,32 Q 18.4,23.5 28.6,28.6 Z' "
				+ "fill='#082014' stroke='#00ff99' stroke-width='1.8' stroke-linejoin='round'/>"
				+ "<rect x='26.9' y='26.9' width='10.2' height='10.2' "
				+ "fill='none' stroke='#88ffcc' stroke-width='1.4'/>"
				+ "<circle cx='32' cy='32' r='4.25' fill='#00ffaa'/>"
				+ "</svg>"
			)
		"celestial":  # PORT: :924-930
			body = (
				"<ellipse cx='32' cy='43.2' rx='22.4' ry='8' "
				+ "fill='none' stroke='#ffd700' stroke-width='1.6' stroke-dasharray='6,3'/>"
				+ "<polygon points='30,48 32,60 34,48' fill='#ffffff' opacity='0.95'/>"
				+ "<path d='M 32,3.2 Q 19.2,25.6 12.8,51.2 Q 32,44.8 32,41.6 "
				+ "Q 32,44.8 51.2,51.2 Q 44.8,25.6 32,3.2 Z' "
				+ "fill='#f8fafc' stroke='#ffd700' stroke-width='1.8' stroke-linejoin='round'/>"
				+ "<polygon points='32,22.4 27.2,33.6 32,36.8 36.8,33.6' fill='#38bdf8'/>"
				+ "</svg>"
			)
		_:  # PORT: :932-937
			body = (
				"<polygon points='26,50 32,59 38,50' fill='#00ddff' opacity='0.85'/>"
				+ "<polygon points='32,3.5 14.9,54.8 32,45.3 49.1,54.8' "
				+ "fill='#ffffff' stroke='#00ddff' stroke-width='2.2' stroke-linejoin='round'/>"
				+ "<polygon points='32,22.5 26.3,39.6 32,35.8 37.7,39.6' fill='#00ffee'/>"
				+ "</svg>"
			)
	return head + body


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


# The `catalog.find(c => c.id === id)` idiom (:716, :734, :746, :763, :770,
# :787): the first entry with that id, or null.
func _find_ship(id: String) -> ShipSkinConfig:
	for ship: ShipSkinConfig in ship_catalog:
		if ship.id == id:
			return ship
	return null


func _find_enemy_skin(id: String) -> EnemySkinConfig:
	for skin: EnemySkinConfig in enemy_skin_catalog:
		if skin.id == id:
			return skin
	return null


func _find_arena_theme(id: String) -> ArenaThemeConfig:
	for arena: ArenaThemeConfig in arena_theme_catalog:
		if arena.id == id:
			return arena
	return null


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

	# DIVERGENCE(THEME R1, user 2026-09-29: "add more variety to the map backgrounds and enemy

	# backgrounds", five concept pairs and five country-colour pairs): appended after the TS's six.

	var arctic_skin: EnemySkinConfig = EnemySkinConfig.new()

	arctic_skin.id = "arctic"

	arctic_skin.name = "Frostbite"

	arctic_skin.price = 1600

	arctic_skin.description = "Glacial ice orbs laced with pale crystal frost."

	arctic_skin.glow_color = Color(150 / 255.0, 225 / 255.0, 255 / 255.0, 0.4)

	arctic_skin.body_gradient = [Color("#e8fbff"), Color("#7fd0f0"), Color("#1d6a99")]

	arctic_skin.pupil_color = Color("#02182a")

	arctic_skin.border_color = Color("#d5f4ff")

	out.append(arctic_skin)

	var ember_skin: EnemySkinConfig = EnemySkinConfig.new()

	ember_skin.id = "ember"

	ember_skin.name = "Ashen Husk"

	ember_skin.price = 1600

	ember_skin.description = "Burnt grey husks flecked with dark soot and a hot orange eye."

	ember_skin.glow_color = Color(200 / 255.0, 110 / 255.0, 60 / 255.0, 0.35)

	ember_skin.body_gradient = [Color("#b0a8a2"), Color("#5d5450"), Color("#231d1b")]

	ember_skin.pupil_color = Color("#ff6a1a")

	ember_skin.border_color = Color("#9a8f88")

	out.append(ember_skin)

	var neon_skin: EnemySkinConfig = EnemySkinConfig.new()

	neon_skin.id = "neon"

	neon_skin.name = "Sakura Pulse"

	neon_skin.price = 1600

	neon_skin.description = "Neon-pink blossoms with a petal ring around a dark eye."

	neon_skin.glow_color = Color(255 / 255.0, 110 / 255.0, 190 / 255.0, 0.42)

	neon_skin.body_gradient = [Color("#ffd0e6"), Color("#ff5cad"), Color("#8a1a5e")]

	neon_skin.pupil_color = Color("#1a0033")

	neon_skin.border_color = Color("#ffb0d8")

	out.append(neon_skin)

	var ocean_skin: EnemySkinConfig = EnemySkinConfig.new()

	ocean_skin.id = "ocean"

	ocean_skin.name = "Anglerfish"

	ocean_skin.price = 1600

	ocean_skin.description = "Deep-sea orbs speckled with bioluminescent green lures."

	ocean_skin.glow_color = Color(60 / 255.0, 255 / 255.0, 190 / 255.0, 0.42)

	ocean_skin.body_gradient = [Color("#5fd8b0"), Color("#0a6a66"), Color("#021c24")]

	ocean_skin.pupil_color = Color("#b6ff5c")

	ocean_skin.border_color = Color("#34ffc0")

	out.append(ocean_skin)

	var desert_skin: EnemySkinConfig = EnemySkinConfig.new()

	desert_skin.id = "desert"

	desert_skin.name = "Sandstorm"

	desert_skin.price = 1600

	desert_skin.description = "Wind-carved sand spheres streaked with dune ripples."

	desert_skin.glow_color = Color(230 / 255.0, 170 / 255.0, 80 / 255.0, 0.4)

	desert_skin.body_gradient = [Color("#f3d9a0"), Color("#c98a3a"), Color("#6b3f12")]

	desert_skin.pupil_color = Color("#2b1400")

	desert_skin.border_color = Color("#f0c880")

	out.append(desert_skin)

	var ph_skin: EnemySkinConfig = EnemySkinConfig.new()

	ph_skin.id = "ph"

	ph_skin.name = "Sampaguita"

	ph_skin.price = 1800

	ph_skin.description = "Deep-blue orbs with a gold radiance and red rim (Philippine colours)."

	ph_skin.glow_color = Color(252 / 255.0, 209 / 255.0, 22 / 255.0, 0.4)

	ph_skin.body_gradient = [Color("#5b8cff"), Color("#0038a8"), Color("#001a54")]

	ph_skin.pupil_color = Color("#fcd116")

	ph_skin.border_color = Color("#e0243a")

	out.append(ph_skin)

	var jp_skin: EnemySkinConfig = EnemySkinConfig.new()

	jp_skin.id = "jp"

	jp_skin.name = "Hinode"

	jp_skin.price = 1800

	jp_skin.description = "Crimson orbs ringed in white (Japanese colours)."

	jp_skin.glow_color = Color(230 / 255.0, 20 / 255.0, 60 / 255.0, 0.42)

	jp_skin.body_gradient = [Color("#ffe8ec"), Color("#e5163f"), Color("#7a0a20")]

	jp_skin.pupil_color = Color("#ffffff")

	jp_skin.border_color = Color("#ffffff")

	out.append(jp_skin)

	var br_skin: EnemySkinConfig = EnemySkinConfig.new()

	br_skin.id = "br"

	br_skin.name = "Verde Ouro"

	br_skin.price = 1800

	br_skin.description = "Green orbs with golden diagonal bands (Brazilian colours)."

	br_skin.glow_color = Color(0 / 255.0, 200 / 255.0, 80 / 255.0, 0.4)

	br_skin.body_gradient = [Color("#ffef66"), Color("#00b34a"), Color("#004d1f")]

	br_skin.pupil_color = Color("#002776")

	br_skin.border_color = Color("#ffdf00")

	out.append(br_skin)

	var us_skin: EnemySkinConfig = EnemySkinConfig.new()

	us_skin.id = "us"

	us_skin.name = "Star Spangled"

	us_skin.price = 1800

	us_skin.description = "Red orbs with white bars and a navy eye (American colours)."

	us_skin.glow_color = Color(220 / 255.0, 40 / 255.0, 70 / 255.0, 0.4)

	us_skin.body_gradient = [Color("#ffffff"), Color("#d42a4f"), Color("#5a0f25")]

	us_skin.pupil_color = Color("#0a3161")

	us_skin.border_color = Color("#ffffff")

	out.append(us_skin)

	var de_skin: EnemySkinConfig = EnemySkinConfig.new()

	de_skin.id = "de"

	de_skin.name = "Gilded Ember"

	de_skin.price = 1800

	de_skin.description = "Black-red orbs with gold vertical bands (German colours)."

	de_skin.glow_color = Color(255 / 255.0, 206 / 255.0, 0 / 255.0, 0.4)

	de_skin.body_gradient = [Color("#ffe066"), Color("#dd0000"), Color("#3a0000")]

	de_skin.pupil_color = Color("#000000")

	de_skin.border_color = Color("#ffce00")

	out.append(de_skin)

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
	void_arena.pattern = ArenaPattern.NONE
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
	synthwave.pattern = ArenaPattern.SUN
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
	nebula.pattern = ArenaPattern.STARS
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
	matrix.pattern = ArenaPattern.CODE
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
	supernova.pattern = ArenaPattern.HEAT
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
	blueprint.pattern = ArenaPattern.DRAFT
	out.append(blueprint)

	# DIVERGENCE(THEME R1, user 2026-09-29: "add more variety to the map backgrounds and enemy

	# backgrounds", five concept pairs and five country-colour pairs): appended after the TS's six.

	var arctic_arena: ArenaThemeConfig = ArenaThemeConfig.new()

	arctic_arena.id = "arctic"

	arctic_arena.name = "Arctic Lattice"

	arctic_arena.price = 1400

	arctic_arena.description = "Frozen slate night with pale-ice grid lines and drifting snow."

	arctic_arena.bg_gradient = [Color("#10222e"), Color("#08131b"), Color("#03080c")]

	arctic_arena.grid_color = Color(170 / 255.0, 230 / 255.0, 255 / 255.0, 0.24)

	arctic_arena.boundary_color = Color(200 / 255.0, 240 / 255.0, 255 / 255.0, 0.55)

	arctic_arena.dust_color = Color("#cfefff")
	arctic_arena.pattern = ArenaPattern.SNOW

	out.append(arctic_arena)

	var ember_arena: ArenaThemeConfig = ArenaThemeConfig.new()

	ember_arena.id = "ember"

	ember_arena.name = "Ember Ruins"

	ember_arena.price = 1400

	ember_arena.description = "Charred rust-brown ruins with smouldering orange grid lines."

	ember_arena.bg_gradient = [Color("#241612"), Color("#120a08"), Color("#070303")]

	ember_arena.grid_color = Color(200 / 255.0, 110 / 255.0, 60 / 255.0, 0.22)

	ember_arena.boundary_color = Color(220 / 255.0, 120 / 255.0, 60 / 255.0, 0.5)

	ember_arena.dust_color = Color("#c96a3a")
	ember_arena.pattern = ArenaPattern.SPARKS

	out.append(ember_arena)

	var neon_arena: ArenaThemeConfig = ArenaThemeConfig.new()

	neon_arena.id = "neon"

	neon_arena.name = "Neon Tokyo Night"

	neon_arena.price = 1400

	neon_arena.description = "Deep indigo city night with teal grid lines and hot-pink glow."

	neon_arena.bg_gradient = [Color("#1a0f36"), Color("#0d0720"), Color("#05030f")]

	neon_arena.grid_color = Color(0 / 255.0, 230 / 255.0, 210 / 255.0, 0.22)

	neon_arena.boundary_color = Color(255 / 255.0, 80 / 255.0, 170 / 255.0, 0.5)

	neon_arena.dust_color = Color("#ff5cad")
	neon_arena.pattern = ArenaPattern.RAIN

	out.append(neon_arena)

	var ocean_arena: ArenaThemeConfig = ArenaThemeConfig.new()

	ocean_arena.id = "ocean"

	ocean_arena.name = "Deep Ocean"

	ocean_arena.price = 1400

	ocean_arena.description = "Abyssal teal water with sea-green grid lines and glowing plankton."

	ocean_arena.bg_gradient = [Color("#04202b"), Color("#020f16"), Color("#01060a")]

	ocean_arena.grid_color = Color(0 / 255.0, 190 / 255.0, 200 / 255.0, 0.22)

	ocean_arena.boundary_color = Color(0 / 255.0, 220 / 255.0, 200 / 255.0, 0.5)

	ocean_arena.dust_color = Color("#34ffc0")
	ocean_arena.pattern = ArenaPattern.BUBBLES

	out.append(ocean_arena)

	var desert_arena: ArenaThemeConfig = ArenaThemeConfig.new()

	desert_arena.id = "desert"

	desert_arena.name = "Desert Signal"

	desert_arena.price = 1400

	desert_arena.description = "Dusk ochre dunes with burnt-orange grid lines and blown sand."

	desert_arena.bg_gradient = [Color("#2b1808"), Color("#150b03"), Color("#080401")]

	desert_arena.grid_color = Color(230 / 255.0, 150 / 255.0, 50 / 255.0, 0.22)

	desert_arena.boundary_color = Color(240 / 255.0, 160 / 255.0, 60 / 255.0, 0.5)

	desert_arena.dust_color = Color("#e6b56a")
	desert_arena.pattern = ArenaPattern.SAND

	out.append(desert_arena)

	var ph_arena: ArenaThemeConfig = ArenaThemeConfig.new()

	ph_arena.id = "ph"

	ph_arena.name = "Perlas Archipelago"

	ph_arena.price = 1600

	ph_arena.description = "Midnight blue seas, gold grid lines, red edge (Philippine colours)."

	ph_arena.bg_gradient = [Color("#061a4a"), Color("#030d28"), Color("#01061a")]

	ph_arena.grid_color = Color(252 / 255.0, 209 / 255.0, 22 / 255.0, 0.22)

	ph_arena.boundary_color = Color(206 / 255.0, 17 / 255.0, 38 / 255.0, 0.55)

	ph_arena.dust_color = Color("#fcd116")
	ph_arena.pattern = ArenaPattern.RAYS

	out.append(ph_arena)

	var jp_arena: ArenaThemeConfig = ArenaThemeConfig.new()

	jp_arena.id = "jp"

	jp_arena.name = "Rising Sun"

	jp_arena.price = 1600

	jp_arena.description = "Ink-dark night, white grid lines, crimson edge (Japanese colours)."

	jp_arena.bg_gradient = [Color("#1f0a10"), Color("#10050a"), Color("#080205")]

	jp_arena.grid_color = Color(255 / 255.0, 255 / 255.0, 255 / 255.0, 0.2)

	jp_arena.boundary_color = Color(230 / 255.0, 20 / 255.0, 60 / 255.0, 0.55)

	jp_arena.dust_color = Color("#ffffff")
	jp_arena.pattern = ArenaPattern.RIPPLES

	out.append(jp_arena)

	var br_arena: ArenaThemeConfig = ArenaThemeConfig.new()

	br_arena.id = "br"

	br_arena.name = "Carnaval"

	br_arena.price = 1600

	br_arena.description = "Rainforest green, golden grid lines, bright edge (Brazilian colours)."

	br_arena.bg_gradient = [Color("#03230f"), Color("#01120a"), Color("#000804")]

	br_arena.grid_color = Color(255 / 255.0, 223 / 255.0, 0 / 255.0, 0.22)

	br_arena.boundary_color = Color(0 / 255.0, 200 / 255.0, 80 / 255.0, 0.5)

	br_arena.dust_color = Color("#ffdf00")
	br_arena.pattern = ArenaPattern.BANDS_DIAG

	out.append(br_arena)

	var us_arena: ArenaThemeConfig = ArenaThemeConfig.new()

	us_arena.id = "us"

	us_arena.name = "Liberty Grid"

	us_arena.price = 1600

	us_arena.description = "Navy night with white grid lines and a red edge (American colours)."

	us_arena.bg_gradient = [Color("#0a1a3a"), Color("#050d20"), Color("#02060f")]

	us_arena.grid_color = Color(255 / 255.0, 255 / 255.0, 255 / 255.0, 0.2)

	us_arena.boundary_color = Color(220 / 255.0, 40 / 255.0, 70 / 255.0, 0.55)

	us_arena.dust_color = Color("#ffffff")
	us_arena.pattern = ArenaPattern.STARS_BARS

	out.append(us_arena)

	var de_arena: ArenaThemeConfig = ArenaThemeConfig.new()

	de_arena.id = "de"

	de_arena.name = "Black Forest"

	de_arena.price = 1600

	de_arena.description = "Near-black woods with gold grid lines and a red edge (German colours)."

	de_arena.bg_gradient = [Color("#17130b"), Color("#0b0905"), Color("#040302")]

	de_arena.grid_color = Color(255 / 255.0, 206 / 255.0, 0 / 255.0, 0.22)

	de_arena.boundary_color = Color(221 / 255.0, 0 / 255.0, 0 / 255.0, 0.55)

	de_arena.dust_color = Color("#ffce00")
	de_arena.pattern = ArenaPattern.BANDS

	out.append(de_arena)

	return out


## PORT: web/src/tilt-to-live/ProgressionManager.ts:9-15
class BlackholePerks:
	extends RefCounted
	var duration: int = 0
	var radius: int = 0
	var gravity: int = 0
	var invulnerable_inside: bool = false
	var supernova_collapse: bool = false
	## DIVERGENCE(KEY R1): a keystone the TS never coded (plan 2026-09-28).
	var event_horizon: bool = false
	var dark_harvest: bool = false

	func to_dict() -> Dictionary:
		return {
			"duration": duration,
			"radius": radius,
			"gravity": gravity,
			"invulnerableInside": invulnerable_inside,
			"supernovaCollapse": supernova_collapse,
			"eventHorizon": event_horizon,
			"darkHarvest": dark_harvest,
		}

	func from_dict(d: Dictionary) -> void:
		duration = SaveStore.read_int(d, "duration", duration)
		radius = SaveStore.read_int(d, "radius", radius)
		gravity = SaveStore.read_int(d, "gravity", gravity)
		invulnerable_inside = SaveStore.read_bool(d, "invulnerableInside", invulnerable_inside)
		supernova_collapse = SaveStore.read_bool(d, "supernovaCollapse", supernova_collapse)
		event_horizon = SaveStore.read_bool(d, "eventHorizon", event_horizon)
		dark_harvest = SaveStore.read_bool(d, "darkHarvest", dark_harvest)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:16-20
class NukePerks:
	extends RefCounted
	var radius: int = 0
	var speed: int = 0
	var fallout_zone: bool = false
	## DIVERGENCE(KEY R1): a keystone the TS never coded (plan 2026-09-28).
	var chain_reaction: bool = false
	var stun_wave: bool = false

	func to_dict() -> Dictionary:
		return {
			"radius": radius,
			"speed": speed,
			"falloutZone": fallout_zone,
			"chainReaction": chain_reaction,
			"stunWave": stun_wave,
		}

	func from_dict(d: Dictionary) -> void:
		radius = SaveStore.read_int(d, "radius", radius)
		speed = SaveStore.read_int(d, "speed", speed)
		fallout_zone = SaveStore.read_bool(d, "falloutZone", fallout_zone)
		chain_reaction = SaveStore.read_bool(d, "chainReaction", chain_reaction)
		stun_wave = SaveStore.read_bool(d, "stunWave", stun_wave)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:21-25
class ShieldPerks:
	extends RefCounted
	var duration: int = 0
	var radius: int = 0
	var battering_ram: bool = false
	## DIVERGENCE(KEY R1): a keystone the TS never coded (plan 2026-09-28).
	var overcharge_pulse: bool = false
	var coin_vacuum: bool = false

	func to_dict() -> Dictionary:
		return {
			"duration": duration,
			"radius": radius,
			"batteringRam": battering_ram,
			"overchargePulse": overcharge_pulse,
			"coinVacuum": coin_vacuum,
		}

	func from_dict(d: Dictionary) -> void:
		duration = SaveStore.read_int(d, "duration", duration)
		radius = SaveStore.read_int(d, "radius", radius)
		battering_ram = SaveStore.read_bool(d, "batteringRam", battering_ram)
		overcharge_pulse = SaveStore.read_bool(d, "overchargePulse", overcharge_pulse)
		coin_vacuum = SaveStore.read_bool(d, "coinVacuum", coin_vacuum)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:26-30
class MissilesPerks:
	extends RefCounted
	var count: int = 0
	var blast_radius: int = 0
	var flight_speed: int = 0
	## DIVERGENCE(KEY R1): a keystone the TS never coded (plan 2026-09-28).
	var cluster_split: bool = false
	var hyper_thrusters: bool = false
	var second_salvo: bool = false

	func to_dict() -> Dictionary:
		return {
			"count": count,
			"blastRadius": blast_radius,
			"flightSpeed": flight_speed,
			"clusterSplit": cluster_split,
			"hyperThrusters": hyper_thrusters,
			"secondSalvo": second_salvo,
		}

	func from_dict(d: Dictionary) -> void:
		count = SaveStore.read_int(d, "count", count)
		blast_radius = SaveStore.read_int(d, "blastRadius", blast_radius)
		flight_speed = SaveStore.read_int(d, "flightSpeed", flight_speed)
		cluster_split = SaveStore.read_bool(d, "clusterSplit", cluster_split)
		hyper_thrusters = SaveStore.read_bool(d, "hyperThrusters", hyper_thrusters)
		second_salvo = SaveStore.read_bool(d, "secondSalvo", second_salvo)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:31-35
class LaserPerks:
	extends RefCounted
	var length: int = 0
	var duration: int = 0
	var cross_beam: bool = false
	## DIVERGENCE(KEY R1): a keystone the TS never coded (plan 2026-09-28).
	var heavy_beam: bool = false
	var rapid_sweep: bool = false

	func to_dict() -> Dictionary:
		return {
			"length": length,
			"duration": duration,
			"crossBeam": cross_beam,
			"heavyBeam": heavy_beam,
			"rapidSweep": rapid_sweep,
		}

	func from_dict(d: Dictionary) -> void:
		length = SaveStore.read_int(d, "length", length)
		duration = SaveStore.read_int(d, "duration", duration)
		cross_beam = SaveStore.read_bool(d, "crossBeam", cross_beam)
		heavy_beam = SaveStore.read_bool(d, "heavyBeam", heavy_beam)
		rapid_sweep = SaveStore.read_bool(d, "rapidSweep", rapid_sweep)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:36-39
class LightningPerks:
	extends RefCounted
	var max_targets: int = 0
	var chain_range: int = 0
	## DIVERGENCE(KEY R1): a keystone the TS never coded (plan 2026-09-28).
	var plasma_arc: bool = false
	var superconductor: bool = false
	var forked_lightning: bool = false

	func to_dict() -> Dictionary:
		return {
			"maxTargets": max_targets,
			"chainRange": chain_range,
			"plasmaArc": plasma_arc,
			"superconductor": superconductor,
			"forkedLightning": forked_lightning,
		}

	func from_dict(d: Dictionary) -> void:
		max_targets = SaveStore.read_int(d, "maxTargets", max_targets)
		chain_range = SaveStore.read_int(d, "chainRange", chain_range)
		plasma_arc = SaveStore.read_bool(d, "plasmaArc", plasma_arc)
		superconductor = SaveStore.read_bool(d, "superconductor", superconductor)
		forked_lightning = SaveStore.read_bool(d, "forkedLightning", forked_lightning)


## PORT: web/src/tilt-to-live/ProgressionManager.ts:40-43
class FreezePerks:
	extends RefCounted
	var duration: int = 0
	var shatter_cascade: bool = false
	## DIVERGENCE(KEY R1): a keystone the TS never coded (plan 2026-09-28).
	var cryo_nova: bool = false
	var ice_armor: bool = false

	func to_dict() -> Dictionary:
		return {
			"duration": duration,
			"shatterCascade": shatter_cascade,
			"cryoNova": cryo_nova,
			"iceArmor": ice_armor,
		}

	func from_dict(d: Dictionary) -> void:
		duration = SaveStore.read_int(d, "duration", duration)
		shatter_cascade = SaveStore.read_bool(d, "shatterCascade", shatter_cascade)
		cryo_nova = SaveStore.read_bool(d, "cryoNova", cryo_nova)
		ice_armor = SaveStore.read_bool(d, "iceArmor", ice_armor)


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
	## DIVERGENCE(THEME R2): the background effect (no TS counterpart).
	var pattern: ArenaPattern = ArenaPattern.NONE


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
