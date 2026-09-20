## entity_layer.gd
## PORTS: web/src/tilt-to-live/PlayerShip.ts:271-632 (render player)
##        web/src/tilt-to-live/EnemySwarm.ts:1191-1648 (render)
##        web/src/tilt-to-live/WeaponSystem.ts:616-638, 793-851 (render weapons)
##        per spec §5.5 and D4
class_name EntityLayer
extends Node2D
## Middle render layer. Draws weapon orbs, active weapons, enemies, and player ship.
##
## PORT-NOTE: PlayerShip.ts:359-592 branches over six alternate ship shapes
## driven by the equipped ShipSkinConfig. Ship skins are M7/M8, so M1/M2 draws the
## default classic arrow (PlayerShip.ts:594-617) alone.
## TODO(M7): the viper, phantom, solar, cyber, shuriken and celestial shapes.

## PORT: web/src/tilt-to-live/PlayerShip.ts:284-292 (the classic skin defaults)
const HULL_COLOR: Color = Color("#ffffff")
const PRIMARY_COLOR: Color = Color("#00ddff")
const ACCENT_COLOR: Color = Color("#00ffee")
const THRUSTER_COLOR: Color = Color("#00ddff")
## PORT: web/src/tilt-to-live/PlayerShip.ts:290
const TRAIL_COLOR: Color = Color(0.0, 220.0 / 255.0, 1.0, 0.4)
## PORT: web/src/tilt-to-live/PlayerShip.ts:356-357 (shielded stroke and core)
const SHIELD_STROKE: Color = Color("#00ffff")

## The ship this layer draws. Null until bind() or bind_entities() is called.
var _player: PlayerShip = null
## The enemy swarm this layer draws. Null until bind_entities() is called.
var _swarm: EnemySwarm = null
## The weapon system this layer draws. Null until bind_entities() is called.
var _weapons: WeaponSystem = null
## Run clock in seconds, driving the pulsing shield and thruster flicker.
var _elapsed: float = 0.0
## Outer high contrast halo toggle. PORT: web/src/tilt-to-live/EnemySwarm.ts:1558
var _high_contrast_halo: bool = true

# DIVERGENCE(M2.5 §6.1): the playfield is inset from the viewport, so every
# draw call in playfield-local coordinates is translated by this.
var _arena_origin: Vector2 = Vector2.ZERO


func _draw() -> void:
	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)
	_draw_weapons()
	_draw_enemies()
	_draw_player()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Gives this layer the ship it draws (M1 backward compatibility).
func bind(player: PlayerShip) -> void:
	_player = player


## Gives this layer all entity systems it draws. Called by GameRoot.
func bind_entities(
	player: PlayerShip, swarm: EnemySwarm = null, weapons: WeaponSystem = null
) -> void:
	_player = player
	_swarm = swarm
	_weapons = weapons


## Run clock, for the pulsing shield and thruster flicker.
func set_elapsed(elapsed: float) -> void:
	_elapsed = elapsed


## Sets whether enemy high contrast halo is drawn.
func set_high_contrast_halo(enabled: bool) -> void:
	_high_contrast_halo = enabled


## Sets the playfield's top-left corner in viewport space. Called by GameRoot.
func set_arena_origin(origin: Vector2) -> void:
	_arena_origin = origin


func _draw_weapons() -> void:
	if _weapons == null:
		return

	# 1. Active weapons (PORT: web/src/tilt-to-live/WeaponSystem.ts:616-638)
	for w: Types.ActiveWeapon in _weapons.active_weapons:
		if w.type == Types.WeaponType.NUKE:
			var progress: float = 1.0 - w.duration / w.max_duration
			var alpha: float = maxf(0.0, 1.0 - progress)

			# Outer expanding shockwave ring (PORT: WeaponSystem.ts:622-626)
			draw_arc(
				Vector2(w.x, w.y),
				w.radius,
				0.0,
				TAU,
				64,
				Color(1.0, 0.0, 85.0 / 255.0, alpha * 0.9),
				maxf(1.0, 6.0 * alpha)
			)

			# Inner secondary shockwave ring (PORT: WeaponSystem.ts:628-632)
			draw_arc(
				Vector2(w.x, w.y),
				maxf(1.0, w.radius - 8.0),
				0.0,
				TAU,
				64,
				Color(1.0, 230.0 / 255.0, 120.0 / 255.0, alpha * 0.8),
				maxf(1.0, 3.0 * alpha)
			)

			# Inner translucent core (PORT: WeaponSystem.ts:634-638)
			draw_circle(
				Vector2(w.x, w.y), w.radius, Color(1.0, 30.0 / 255.0, 80.0 / 255.0, alpha * 0.25)
			)

	# 2. Floating weapon orbs (PORT: web/src/tilt-to-live/WeaponSystem.ts:793-830)
	for orb: Types.WeaponOrb in _weapons.orbs:
		var is_expiring: bool = orb.lifetime < 3.0 and (int(_elapsed * 8.0) % 2 == 0)
		if is_expiring:
			continue

		var pulse: float = 0.88 + 0.12 * sin(_elapsed * 6.0 + orb.pulse_offset)
		var orb_col: Color = _weapons.get_weapon_color(orb.type)
		var orb_pos: Vector2 = Vector2(orb.x, orb.y)

		# Outer pulsing glow (PORT: WeaponSystem.ts:804-807)
		var glow_col: Color = Color(orb_col.r, orb_col.g, orb_col.b, 0.2)
		draw_circle(orb_pos, (orb.radius + 8.0) * pulse, glow_col)

		# Translucent bubble fill (PORT: WeaponSystem.ts:809-817)
		var bubble_col: Color = Color(orb_col.r, orb_col.g, orb_col.b, 0.65)
		draw_circle(orb_pos, orb.radius, bubble_col)

		# Sharp neon perimeter (PORT: WeaponSystem.ts:820-822)
		draw_arc(orb_pos, orb.radius, 0.0, TAU, 32, Color.WHITE, 1.8)

		# Glyph symbols (PORT: WeaponSystem.ts:833-851)
		_draw_orb_glyph(orb_pos, orb.type)


func _draw_orb_glyph(pos: Vector2, type: Types.WeaponType) -> void:
	match type:
		Types.WeaponType.NUKE:
			# Center dot
			draw_circle(pos, 2.5, Color.WHITE)
			# 3 radioactive trefoil arcs
			for i: int in range(3):
				var a: float = (float(i) * TAU) / 3.0
				draw_arc(pos, 8.0, a - 0.45, a + 0.45, 16, Color.WHITE, 1.6)
		_:
			# Default center dot
			draw_circle(pos, 3.0, Color.WHITE)


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1191-1648 (render)
## PORT-NOTE: skin (EnemySkinConfig) is M7; every branch below ports only the
## non-skin arm of its ternaries. TODO(M7): enemy skins (skin.bodyGradient,
## borderColor, glowColor, pupilColor).
## PORT-NOTE: charger, artillery and carrier gate the skin on
## skin.id !== 'classic' (EnemySwarm.ts:1260, :1293, :1406) while pulsar,
## specter and the default dot gate on skin alone (:1476, :1521, :1561) — M7
## must preserve the asymmetry.
## PORT-NOTE: createRadialGradient (EnemySwarm.ts:1370, :1484, :1531, :1589) is
## not baked as a texture in this module. Per the M2 precedent at :187-199
## (Open question 3), each two/three-stop gradient is approximated as two flat
## draw_circle calls: the full radius filled with the middle stop's colour,
## then a smaller circle at (radius * middle-stop-position) filled with the
## innermost stop's colour. The outermost stop is dropped by this technique.
## _gameMode is unused in the TS (EnemySwarm.ts:1196) and gets no port.
func _draw_enemies() -> void:
	if _swarm == null:
		return

	for e: Types.Enemy in _swarm.enemies:
		if e.frozen:
			_draw_frozen_dot(e)
			continue
		if e.type == Types.EnemyType.CHARGER:
			_draw_charger(e)
			continue
		if e.type == Types.EnemyType.ARTILLERY:
			_draw_artillery(e)
			continue
		if e.type == Types.EnemyType.BULLET:
			_draw_bullet(e)
			continue
		if e.type == Types.EnemyType.CARRIER:
			_draw_carrier(e)
			continue
		if e.parent_carrier_id != Types.ABSENT:
			_draw_satellite(e)
			continue
		if e.type == Types.EnemyType.PULSAR:
			_draw_pulsar(e)
			continue
		if e.type == Types.EnemyType.SPECTER:
			_draw_specter(e)
			continue
		_draw_default_dot(e)


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1204-1222
func _draw_frozen_dot(e: Types.Enemy) -> void:
	var pos: Vector2 = Vector2(e.x, e.y)
	draw_circle(pos, e.radius + 3.0, Color(136.0 / 255.0, 238.0 / 255.0, 1.0, 0.45))
	draw_arc(pos, e.radius + 1.0, 0.0, TAU, 24, Color.WHITE, 1.5)
	draw_circle(pos, e.radius - 1.0, Color("#4488aa"))


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1225-1286
func _draw_charger(e: Types.Enemy) -> void:
	# PORT: EnemySwarm.ts:1226
	var angle: float = (
		atan2(e.vy, e.vx)
		if e.state == Types.EnemyState.CHARGING
		else (e.aim_angle if not is_nan(e.aim_angle) else 0.0)
	)
	draw_set_transform(_arena_origin + Vector2(e.x, e.y), angle, Vector2.ONE)

	# Laser telegraph line while aiming (PORT: EnemySwarm.ts:1229-1243)
	if e.state == Types.EnemyState.AIMING:
		var dash_offset: float = fmod(_elapsed * 50.0, 16.0)  # PORT: EnemySwarm.ts:1232
		var telegraph_col: Color = Color(
			1.0, 60.0 / 255.0, 30.0 / 255.0, 0.4 + 0.4 * sin(_elapsed * 22.0)
		)  # PORT: EnemySwarm.ts:1233
		_draw_dashed_line_offset(
			Vector2(14.0, 0.0), Vector2(480.0, 0.0), 8.0, 6.0, -dash_offset, telegraph_col, 1.5
		)  # PORT: EnemySwarm.ts:1235-1240

	# Rocket thruster plume if charging (PORT: EnemySwarm.ts:1247-1257)
	if e.state == Types.EnemyState.CHARGING:
		var jet_len: float = 14.0 + randf() * 8.0  # PORT: EnemySwarm.ts:1249
		var plume: PackedVector2Array = PackedVector2Array(
			[Vector2(-8.0, -4.0), Vector2(-8.0 - jet_len, 0.0), Vector2(-8.0, 4.0)]
		)  # PORT: EnemySwarm.ts:1250-1256
		draw_colored_polygon(plume, Color("#ffaa00"))  # PORT: EnemySwarm.ts:1250

	# Arrowhead delta dart chassis (PORT: EnemySwarm.ts:1259-1272)
	# PORT-NOTE: the skin.id !== 'classic' branch (:1260-1261) is M7; only the
	# non-skin fallback is ported.
	var hull_col: Color = (
		Color("#ff2a00") if e.state == Types.EnemyState.CHARGING else Color("#dd1c00")
	)  # PORT: EnemySwarm.ts:1260
	var hull: PackedVector2Array = PackedVector2Array(
		[Vector2(14.0, 0.0), Vector2(-10.0, -11.0), Vector2(-6.0, 0.0), Vector2(-10.0, 11.0)]
	)  # PORT: EnemySwarm.ts:1266-1269
	draw_colored_polygon(hull, hull_col)
	draw_polyline(_closed(hull), Color("#ffaa33"), 1.8)  # PORT: EnemySwarm.ts:1261-1264

	# Cockpit / energy crystal core (PORT: EnemySwarm.ts:1274-1282)
	# PORT-NOTE: the skin.pupilColor branch (:1275) is M7; only the non-skin
	# fallback (#FFB14D) is ported.
	# PORT: EnemySwarm.ts:1275
	var core_col: Color = Color.WHITE if e.state == Types.EnemyState.CHARGING else Color("#FFB14D")
	var core: PackedVector2Array = PackedVector2Array(
		[Vector2(6.0, 0.0), Vector2(-2.0, -3.5), Vector2(0.0, 0.0), Vector2(-2.0, 3.5)]
	)  # PORT: EnemySwarm.ts:1277-1280
	draw_colored_polygon(core, core_col)

	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1289-1350
## PORT-NOTE: the skin.id !== 'classic' branches (:1293, :1311-1312, :1339)
## are M7; only the non-skin fallback of each is ported.
func _draw_artillery(e: Types.Enemy) -> void:
	var angle: float = e.aim_angle if not is_nan(e.aim_angle) else 0.0  # PORT: EnemySwarm.ts:1290
	draw_set_transform(_arena_origin + Vector2(e.x, e.y), angle, Vector2.ONE)

	# Cannon barrel (PORT: EnemySwarm.ts:1295-1299)
	var barrel_rect: Rect2 = Rect2(4.0, -4.0, 18.0, 8.0)
	draw_rect(barrel_rect, Color("#180e22"))
	draw_rect(barrel_rect, Color("#ff0066"), false, 1.5)

	# Muzzle charge flash if preparing to fire (PORT: EnemySwarm.ts:1302-1308)
	if not is_nan(e.fire_cooldown) and e.fire_cooldown < 0.8:
		var charge_ratio: float = (0.8 - e.fire_cooldown) / 0.8  # PORT: EnemySwarm.ts:1303
		draw_circle(
			Vector2(22.0, 0.0),
			3.0 + charge_ratio * 4.0,
			Color(1.0, 0.0, 150.0 / 255.0, 0.5 + charge_ratio * 0.5)
		)  # PORT: EnemySwarm.ts:1304-1306

	# Heavy hexagonal hull (PORT: EnemySwarm.ts:1310-1327)
	var hex_radius: float = 13.0  # PORT: EnemySwarm.ts:1317
	var hex: PackedVector2Array = PackedVector2Array()
	for h: int in range(6):
		var a: float = float(h) * PI / 3.0  # PORT: EnemySwarm.ts:1319
		hex.append(Vector2(cos(a) * hex_radius, sin(a) * hex_radius))
	draw_colored_polygon(hex, Color("#1c0a1a"))
	draw_polyline(_closed(hex), Color("#ff0077"), 2.2)

	# Armored cross struts (PORT: EnemySwarm.ts:1329-1335)
	var strut_col: Color = Color(1.0, 1.0, 1.0, 0.25)
	draw_line(Vector2(-hex_radius, 0.0), Vector2(hex_radius, 0.0), strut_col, 1.0)
	draw_line(Vector2(0.0, -hex_radius), Vector2(0.0, hex_radius), strut_col, 1.0)

	# Pulsing optic sensor eye (PORT: EnemySwarm.ts:1337-1346)
	var optic_pulse: float = 0.8 + 0.2 * sin(_elapsed * 14.0)  # PORT: EnemySwarm.ts:1338
	draw_circle(Vector2.ZERO, 5.0 * optic_pulse, Color("#ff00bb"))
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1353-1385
func _draw_bullet(e: Types.Enemy) -> void:
	var angle: float = atan2(e.vy, e.vx)  # PORT: EnemySwarm.ts:1354
	draw_set_transform(_arena_origin + Vector2(e.x, e.y), angle, Vector2.ONE)

	# Plasma comet tail (PORT: EnemySwarm.ts:1358-1367)
	var tail: PackedVector2Array = PackedVector2Array(
		[Vector2(-18.0, 0.0), Vector2(0.0, -4.0), Vector2(0.0, 4.0)]
	)
	var tail_colors: PackedColorArray = PackedColorArray(
		[
			Color(1.0, 0.0, 128.0 / 255.0, 0.0),
			Color(1.0, 0.0, 180.0 / 255.0, 0.85),
			Color(1.0, 0.0, 180.0 / 255.0, 0.85)
		]
	)  # PORT: EnemySwarm.ts:1359-1360
	draw_polygon(tail, tail_colors)

	# Core plasma energy ball (PORT: EnemySwarm.ts:1370-1373, two-circle rule)
	draw_circle(Vector2.ZERO, e.radius, Color("#ff2299"))
	draw_circle(Vector2.ZERO, e.radius * 0.5, Color.WHITE)
	draw_arc(Vector2.ZERO, e.radius, 0.0, TAU, 24, Color.WHITE, 1.2)  # PORT: EnemySwarm.ts:1379-1381

	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1388-1444
## PORT-NOTE: the skin.id !== 'classic' branches (:1406, :1417-1418, :1432)
## are M7; only the non-skin fallback of each is ported.
func _draw_carrier(e: Types.Enemy) -> void:
	var carrier_pos: Vector2 = Vector2(e.x, e.y)

	# Tether lines to child satellites, under the standing arena transform
	# (PORT: EnemySwarm.ts:1390-1401)
	for sat: Types.Enemy in _swarm.enemies:
		if sat.parent_carrier_id == e.id:
			var tether_col: Color = Color(
				0.0, 229.0 / 255.0, 1.0, 0.4 + 0.3 * sin(_elapsed * 12.0 + float(sat.id))
			)  # PORT: EnemySwarm.ts:1393
			draw_line(carrier_pos, Vector2(sat.x, sat.y), tether_col, 1.2)

	# PORT: EnemySwarm.ts:1403
	draw_set_transform(_arena_origin + carrier_pos, _elapsed * 0.45, Vector2.ONE)

	# Pulsing orbital shield ring (PORT: EnemySwarm.ts:1406-1414)
	_draw_dashed_arc(
		Vector2.ZERO,
		e.radius + 8.0,
		10.0,
		8.0,
		-_elapsed * 30.0,
		Color(1.0, 30.0 / 255.0, 80.0 / 255.0, 0.45),
		2.0
	)

	# Diamond dreadnought mothership hull (PORT: EnemySwarm.ts:1416-1429)
	var diamond: PackedVector2Array = PackedVector2Array(
		[
			Vector2(e.radius + 4.0, 0.0),
			Vector2(0.0, -e.radius - 4.0),
			Vector2(-e.radius - 4.0, 0.0),
			Vector2(0.0, e.radius + 4.0)
		]
	)  # PORT: EnemySwarm.ts:1423-1426
	draw_colored_polygon(diamond, Color("#220816"))
	draw_polyline(_closed(diamond), Color("#ff2a55"), 2.4)

	# Inner glowing core (PORT: EnemySwarm.ts:1431-1440)
	draw_circle(Vector2.ZERO, 8.0, Color("#ff1144"))
	draw_circle(Vector2.ZERO, 3.5, Color.WHITE)

	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1447-1466
func _draw_satellite(e: Types.Enemy) -> void:
	var pos: Vector2 = Vector2(e.x, e.y)
	draw_arc(pos, e.radius + 3.0, 0.0, TAU, 24, Color("#00e5ff"), 1.5)
	draw_circle(pos, e.radius + 2.0, Color(0.0, 229.0 / 255.0, 1.0, 0.35))
	draw_circle(pos, e.radius * 0.5, Color.WHITE)


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1469-1513
## PORT-NOTE: skin gates the borderColor/bodyGradient/pupilColor branches
## alone (:1476, :1483, :1490, :1498), unlike charger/artillery/carrier which
## gate on skin.id !== 'classic' — M7 must preserve this asymmetry.
func _draw_pulsar(e: Types.Enemy) -> void:
	var pos: Vector2 = Vector2(e.x, e.y)
	# PORT: EnemySwarm.ts:1470
	var pulse_phase: float = (2.2 - e.pulse_timer) / 2.2 if not is_nan(e.pulse_timer) else 0.0
	var ring_radius: float = e.radius + 5.0 + pulse_phase * 16.0  # PORT: EnemySwarm.ts:1471
	var ring_alpha: float = maxf(0.0, (1.0 - pulse_phase) * 0.8)  # PORT: EnemySwarm.ts:1472,1475
	draw_arc(
		pos, ring_radius, 0.0, TAU, 24, Color(1.0, 71.0 / 255.0, 87.0 / 255.0, ring_alpha), 2.0
	)  # PORT: EnemySwarm.ts:1476-1480

	# Core vibrant body gradient (PORT: EnemySwarm.ts:1483-1487, two-circle rule)
	draw_circle(pos, e.radius, Color("#ee1133"))
	draw_circle(pos, e.radius * 0.6, Color("#ff8899"))
	draw_arc(pos, e.radius, 0.0, TAU, 24, Color("#ffa502"), 2.2)  # PORT: EnemySwarm.ts:1490-1495

	# Eight-point spinning star core (PORT: EnemySwarm.ts:1499-1509)
	var star: PackedVector2Array = PackedVector2Array()
	for p: int in range(8):
		var a: float = float(p) * PI / 4.0 + _elapsed * 3.0  # PORT: EnemySwarm.ts:1501
		var r: float = e.radius * 0.55 if p % 2 == 0 else e.radius * 0.22  # PORT: EnemySwarm.ts:1502
		star.append(Vector2(cos(a) * r, sin(a) * r))
	draw_colored_polygon(star, Color.WHITE)  # PORT: EnemySwarm.ts:1498


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1516-1552
## PORT-NOTE: skin gates the borderColor/bodyGradient/pupilColor branches
## alone (:1521, :1530, :1537, :1545), matching pulsar's asymmetry — see
## _draw_pulsar's PORT-NOTE.
func _draw_specter(e: Types.Enemy) -> void:
	var pos: Vector2 = Vector2(e.x, e.y)
	# PORT: EnemySwarm.ts:1517
	var alpha: float = e.stealth_opacity if not is_nan(e.stealth_opacity) else 0.65

	# PORT: EnemySwarm.ts:1521-1528
	_draw_dashed_arc(pos, e.radius + 3.0, 4.0, 4.0, -_elapsed * 25.0, Color("#a78bfa", alpha), 1.6)

	# Core vibrant body gradient (PORT: EnemySwarm.ts:1530-1534, two-circle rule)
	draw_circle(pos, e.radius, Color("#8b5cf6", alpha))
	draw_circle(pos, e.radius * 0.65, Color("#c4b5fd", alpha))
	# PORT: EnemySwarm.ts:1537-1542
	draw_arc(pos, e.radius, 0.0, TAU, 24, Color("#e0e7ff", alpha), 1.5)

	# PORT: EnemySwarm.ts:1545-1548
	draw_circle(pos, 2.5, Color(1.0, 1.0, 1.0, alpha))


## PORT: web/src/tilt-to-live/EnemySwarm.ts:1554-1643 (default dot + turret indicator)
func _draw_default_dot(e: Types.Enemy) -> void:
	var e_pos: Vector2 = Vector2(e.x, e.y)
	var pulse: float = 0.85 + 0.15 * sin(_elapsed * 9.0 + float(e.id))

	# Outer glow & high contrast halo (PORT: EnemySwarm.ts:1557-1572)
	if _high_contrast_halo:
		var halo_col: Color = (
			Color(140.0 / 255.0, 240.0 / 255.0, 1.0, 0.7)
			if e.chilled
			else (
				Color(1.0, 180.0 / 255.0, 0.0, 0.7)
				if e.is_hazard
				else Color(1.0, 30.0 / 255.0, 60.0 / 255.0, 0.7)
			)
		)
		draw_arc(e_pos, (e.radius + 5.0) * pulse, 0.0, TAU, 24, halo_col, 1.2)

	# Outer glow color (PORT: EnemySwarm.ts:1574-1586)
	var glow_col: Color = (
		Color(130.0 / 255.0, 230.0 / 255.0, 1.0, 0.55)
		if e.chilled
		else (
			Color(1.0, 170.0 / 255.0, 0.0, 0.45)
			if e.is_hazard
			else Color(1.0, 30.0 / 255.0, 60.0 / 255.0, 0.35)
		)
	)
	draw_circle(e_pos, (e.radius + 4.0) * pulse, glow_col)

	# Core vibrant body (PORT: EnemySwarm.ts:1588-1610)
	var body_col: Color = (
		Color("#55bbff") if e.chilled else (Color("#ffaa00") if e.is_hazard else Color("#ee1133"))
	)
	var inner_col: Color = (
		Color("#e0f8ff") if e.chilled else (Color("#fff066") if e.is_hazard else Color("#ff6677"))
	)
	draw_circle(e_pos, e.radius, body_col)
	draw_circle(e_pos, e.radius * 0.65, inner_col)

	# Border (PORT: EnemySwarm.ts:1612-1620)
	var border_col: Color = (
		Color("#aae6ff") if e.chilled else (Color("#ffd555") if e.is_hazard else Color("#ff8899"))
	)
	draw_arc(e_pos, e.radius, 0.0, TAU, 24, border_col, 1.2)

	# Pupil / core dot (PORT: EnemySwarm.ts:1622-1632)
	var pupil_col: Color = (
		Color("#002244") if e.chilled else (Color("#221100") if e.is_hazard else Color("#110005"))
	)
	draw_circle(e_pos, e.radius * 0.38, pupil_col)

	# Turret dot warning indicator (PORT: EnemySwarm.ts:1635-1643)
	if (
		e.type == Types.EnemyType.TURRET_DOT
		and not is_nan(e.target_angle)
		and e.orbit_center == Vector2.ZERO
	):
		draw_set_transform(_arena_origin + e_pos, e.target_angle, Vector2.ONE)
		draw_line(
			Vector2(e.radius, 0.0),
			Vector2(e.radius + 18.0, 0.0),
			Color(1.0, 50.0 / 255.0, 50.0 / 255.0, 0.5),
			1.5
		)
		draw_set_transform(_arena_origin, 0.0, Vector2.ONE)


## PORT-NOTE: Godot has no dash offset or dashed arc; this helper and
## _draw_dashed_arc below are the setLineDash equivalent, analogous to
## _closed(). Both walk the dash pattern in arc-length from a phase computed
## from line_dash_offset, matching Canvas2D's animated dash behaviour.
func _draw_dashed_line_offset(
	from: Vector2,
	to: Vector2,
	dash: float,
	gap: float,
	line_dash_offset: float,
	color: Color,
	width: float
) -> void:
	var delta: Vector2 = to - from
	var length: float = delta.length()
	if length <= 0.0:
		return
	var direction: Vector2 = delta / length
	var period: float = dash + gap
	var s: float = fposmod(-line_dash_offset, period) - period
	while s < length:
		var s0: float = maxf(s, 0.0)
		var s1: float = minf(s + dash, length)
		if s1 > s0:
			draw_line(from + direction * s0, from + direction * s1, color, width)
		s += period


func _draw_dashed_arc(
	center: Vector2,
	radius: float,
	dash: float,
	gap: float,
	line_dash_offset: float,
	color: Color,
	width: float
) -> void:
	var length: float = TAU * radius
	if length <= 0.0:
		return
	var period: float = dash + gap
	var s: float = fposmod(-line_dash_offset, period) - period
	while s < length:
		var s0: float = maxf(s, 0.0)
		var s1: float = minf(s + dash, length)
		if s1 > s0:
			draw_arc(center, radius, s0 / radius, s1 / radius, 6, color, width)
		s += period


func _draw_player() -> void:
	if _player == null or _player.is_dead:
		return

	_draw_trail()

	# DIVERGENCE(M2.5 §6.1): draw_set_transform replaces rather than composes, so the
	# playfield origin must be re-applied here or the ship draws off its collision position.
	draw_set_transform(
		_arena_origin + Vector2(_player.x, _player.y), _player.angle, Vector2.ONE * _player.scale
	)

	if _player.has_shield():
		_draw_shield()

	var stroke_col: Color = SHIELD_STROKE if _player.has_shield() else PRIMARY_COLOR
	var core_col: Color = SHIELD_STROKE if _player.has_shield() else ACCENT_COLOR

	# PORT: web/src/tilt-to-live/PlayerShip.ts:596-607 (classic white arrow)
	var hull: PackedVector2Array = PackedVector2Array(
		[Vector2(15.0, 0.0), Vector2(-12.0, -9.0), Vector2(-7.0, 0.0), Vector2(-12.0, 9.0)]
	)
	draw_colored_polygon(hull, HULL_COLOR)
	draw_polyline(_closed(hull), stroke_col, 1.8)

	# PORT: web/src/tilt-to-live/PlayerShip.ts:609-616
	var cockpit: PackedVector2Array = PackedVector2Array(
		[Vector2(5.0, 0.0), Vector2(-4.0, -3.0), Vector2(-2.0, 0.0), Vector2(-4.0, 3.0)]
	)
	draw_colored_polygon(cockpit, core_col)

	# PORT: web/src/tilt-to-live/PlayerShip.ts:620-629
	var flame_col: Color = ACCENT_COLOR if _player.has_shield() else THRUSTER_COLOR
	var flame_len: float = 6.0 + randf() * 6.0
	var flame: PackedVector2Array = PackedVector2Array(
		[Vector2(-13.0, -3.5), Vector2(-13.0 - flame_len, 0.0), Vector2(-13.0, 3.5)]
	)
	draw_colored_polygon(flame, flame_col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## PORT: web/src/tilt-to-live/PlayerShip.ts:296-312
func _draw_trail() -> void:
	if _player.trail_history.size() <= 1:
		return
	for i: int in range(_player.trail_history.size() - 1):
		var pt1: Vector2 = _player.trail_history[i]
		var pt2: Vector2 = _player.trail_history[i + 1]
		var progress: float = 1.0 - float(i) / float(_player.trail_history.size())
		var col: Color = (
			Color(0.0, 1.0, 220.0 / 255.0, progress * 0.45)
			if _player.has_shield()
			else Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, progress * 0.42)
		)
		draw_line(pt1, pt2, col, progress * 5.5 * _player.scale)


## PORT: web/src/tilt-to-live/PlayerShip.ts:319-353
func _draw_shield() -> void:
	var shield_radius: float = _player.shield_radius
	var pulse: float = 0.75 + sin(_elapsed * 8.0) * 0.25

	# PORT-NOTE: 64 segments is a rasterisation choice; the canvas arc()
	# PlayerShip.ts:328 draws a mathematically smooth circle.
	draw_arc(
		Vector2.ZERO,
		shield_radius,
		0.0,
		PI * 2.0,
		64,
		Color(0.0, 1.0, 200.0 / 255.0, pulse * 0.8),
		2.5
	)
	draw_circle(Vector2.ZERO, shield_radius, Color(0.0, 1.0, 220.0 / 255.0, 0.15))

	var hex: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var a: float = (i * PI) / 3.0 + _elapsed * 2.0
		hex.append(Vector2(cos(a) * (shield_radius - 2.0), sin(a) * (shield_radius - 2.0)))
	draw_polyline(_closed(hex), Color(180.0 / 255.0, 1.0, 240.0 / 255.0, pulse * 0.5), 1.0)


## PORT-NOTE: draw_polyline does not close its own loop; this is the
## ctx.closePath() equivalent used by the hull outline and shield hex facets.
func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = points.duplicate()
	out.append(points[0])
	return out
