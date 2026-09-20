## entity_layer.gd
## PORTS: web/src/tilt-to-live/PlayerShip.ts:271-632 (render player)
##        web/src/tilt-to-live/EnemySwarm.ts:1554-1633 (render seeker dots)
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


func _draw_enemies() -> void:
	if _swarm == null:
		return

	for e: Types.Enemy in _swarm.enemies:
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
			Color("#55bbff")
			if e.chilled
			else (Color("#ffaa00") if e.is_hazard else Color("#ee1133"))
		)
		var inner_col: Color = (
			Color("#e0f8ff")
			if e.chilled
			else (Color("#fff066") if e.is_hazard else Color("#ff6677"))
		)
		draw_circle(e_pos, e.radius, body_col)
		draw_circle(e_pos, e.radius * 0.65, inner_col)

		# Border (PORT: EnemySwarm.ts:1612-1620)
		var border_col: Color = (
			Color("#aae6ff")
			if e.chilled
			else (Color("#ffd555") if e.is_hazard else Color("#ff8899"))
		)
		draw_arc(e_pos, e.radius, 0.0, TAU, 24, border_col, 1.2)

		# Pupil / core dot (PORT: EnemySwarm.ts:1622-1632)
		var pupil_col: Color = (
			Color("#002244")
			if e.chilled
			else (Color("#221100") if e.is_hazard else Color("#110005"))
		)
		draw_circle(e_pos, e.radius * 0.38, pupil_col)


func _draw_player() -> void:
	if _player == null or _player.is_dead:
		return

	_draw_trail()

	draw_set_transform(Vector2(_player.x, _player.y), _player.angle, Vector2.ONE * _player.scale)

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
