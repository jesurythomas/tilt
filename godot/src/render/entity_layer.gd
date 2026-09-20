## entity_layer.gd
## PORTS: web/src/tilt-to-live/PlayerShip.ts:271-632 (render), per spec §4.2 and D4
class_name EntityLayer
extends Node2D
## Middle render layer. M1 draws the player ship only.
##
## PORT-NOTE: PlayerShip.ts:359-592 branches over six alternate ship shapes
## driven by the equipped ShipSkinConfig. Ship skins are M7/M8, so M1 draws the
## default classic arrow (PlayerShip.ts:594-617) alone.
## TODO(M7): the viper, phantom, solar, cyber, shuriken and celestial shapes.
## TODO(M2): enemies, weapon orbs and active weapons (spec §5.5).

## PORT: web/src/tilt-to-live/PlayerShip.ts:284-292 (the classic skin defaults)
const HULL_COLOR: Color = Color("#ffffff")
const PRIMARY_COLOR: Color = Color("#00ddff")
const ACCENT_COLOR: Color = Color("#00ffee")
const THRUSTER_COLOR: Color = Color("#00ddff")
## PORT: web/src/tilt-to-live/PlayerShip.ts:290
const TRAIL_COLOR: Color = Color(0.0, 220.0 / 255.0, 1.0, 0.4)
## PORT: web/src/tilt-to-live/PlayerShip.ts:356-357 (shielded stroke and core)
const SHIELD_STROKE: Color = Color("#00ffff")

## The ship this layer draws. Null until bind() is called.
var _player: PlayerShip = null
## Run clock in seconds, driving the pulsing shield and thruster flicker.
var _elapsed: float = 0.0


## Gives this layer the ship it draws. Called by GameRoot.
func bind(player: PlayerShip) -> void:
	_player = player


## Run clock, for the pulsing shield and thruster flicker.
func set_elapsed(elapsed: float) -> void:
	_elapsed = elapsed


func _draw() -> void:
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
