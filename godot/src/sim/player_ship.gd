## player_ship.gd
## PORTS: web/src/tilt-to-live/PlayerShip.ts:1-269 (633 lines total, source commit 7be9614)
class_name PlayerShip
extends RefCounted
## Tilt/pointer-driven arrow ship with inertia physics.
##
## Instantiated twice concurrently once MenuBackdrop lands (spec §5.2), so it
## must never become an autoload.
##
## PORT-NOTE: PlayerShip.ts:271-632 defines render(); per spec §4.2/D4 that
## body relocates to render/entity_layer.gd.
##
## PORT-NOTE: update() flattens two TypeScript object-literal parameters into
## typed scalars, because GDScript has no anonymous struct type.
## `tuning: {sensitivity, deadzone}` (PlayerShip.ts:101) becomes `sensitivity`
## and `deadzone`; `shipSkin?: ShipSkinConfig` (PlayerShip.ts:102) becomes the
## three fields update() actually reads — `hitbox_scale`, `turn_rate` and
## `thruster_color` (PlayerShip.ts:109-110, 241). RunController passes them
## from ProgressionManager (data.tuning, get_equipped_ship()); the M1/M2
## callers passed the TypeScript defaults (1.0, 4.0, 1.0, 1.0, #00ddff).
##
## PORT-NOTE: `bounds: {width, height}` (PlayerShip.ts:97) becomes
## `bounds: Vector2` (x = width, y = height), consistent with the
## Vector2-for-point-records rule in types.gd.

const BASE_MAX_SPEED: float = 540.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:52
const BASE_ACCELERATION: float = 1800.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:53
const DAMPING: float = 0.88  # PORT: web/src/tilt-to-live/PlayerShip.ts:54

## Arena-space position.
var x: float = 0.0
var y: float = 0.0
## Velocity in px/sec.
var vx: float = 0.0
var vy: float = 0.0
## Facing, radians. PORT: web/src/tilt-to-live/PlayerShip.ts:14
var angle: float = -PI / 2.0
## Arena scale, driven by resize(). PORT: web/src/tilt-to-live/PlayerShip.ts:15
var scale: float = 1.0
## Seconds of shield remaining.
var shield_timer: float = 0.0
## True between death and the next reset().
var is_dead: bool = false
## Close-call cooldown, read by ScoreManager in M2.
var close_call_timer: float = 0.0
## Most recent positions, newest first, for the wake ribbon.
var trail_history: Array[Vector2] = []

## Collision radius. PORT: web/src/tilt-to-live/PlayerShip.ts:39-41
var radius: float:
	get:
		return 9.0 * scale * _ship_hitbox_scale * _hitbox_multiplier

## Top speed at the current scale. PORT: web/src/tilt-to-live/PlayerShip.ts:56-58
var max_speed: float:
	get:
		return BASE_MAX_SPEED * maxf(0.72, scale)

## Acceleration at the current scale. PORT: web/src/tilt-to-live/PlayerShip.ts:60-62
var acceleration: float:
	get:
		return BASE_ACCELERATION * maxf(0.72, scale)

## Shield bubble radius, read by render/entity_layer.gd.
## PORT: web/src/tilt-to-live/PlayerShip.ts:33
var shield_radius: float = 20.0

var _ship_hitbox_scale: float = 1.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:20
var _ship_turn_rate: float = 1.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:21
var _hitbox_multiplier: float = 1.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:25
var _engine_particle_timer: float = 0.0
var _trail_sample_timer: float = 0.0


func _init(start_x: float, start_y: float) -> void:
	reset(start_x, start_y)


## Sets the purchasable hull-compact multiplier. PORT: web/src/tilt-to-live/PlayerShip.ts:27-29
func set_hitbox_multiplier(m: float) -> void:
	_hitbox_multiplier = m


## Sets the shield bubble radius from the equipped perk.
## PORT: web/src/tilt-to-live/PlayerShip.ts:35-37
func set_shield_radius(r: float) -> void:
	shield_radius = r


## Clamps and applies a new arena scale. PORT: web/src/tilt-to-live/PlayerShip.ts:43-45
func set_scale(new_scale: float) -> void:
	scale = maxf(0.5, minf(1.8, new_scale))


## Returns the ship to its starting pose, alive and at rest.
## PORT: web/src/tilt-to-live/PlayerShip.ts:72-84
func reset(new_x: float, new_y: float) -> void:
	x = new_x
	y = new_y
	vx = 0.0
	vy = 0.0
	angle = -PI / 2.0
	shield_timer = 0.0
	is_dead = false
	close_call_timer = 0.0
	_engine_particle_timer = 0.0
	_trail_sample_timer = 0.0
	trail_history = []


## Extends the shield timer to at least duration seconds.
## PORT: web/src/tilt-to-live/PlayerShip.ts:86-88
func activate_shield(duration: float = 6.0) -> void:
	shield_timer = maxf(shield_timer, duration)


## Returns whether the shield is currently up.
## PORT: web/src/tilt-to-live/PlayerShip.ts:90-92
func has_shield() -> bool:
	return shield_timer > 0.0


## Advances one simulation step. PORT: web/src/tilt-to-live/PlayerShip.ts:94-269
# PORT-NOTE: the 12 parameters are the TypeScript's 9 (PlayerShip.ts:94-104)
# with the two object-literal parameters flattened into five scalars —
# `tuning: {sensitivity, deadzone}` and `shipSkin?: ShipSkinConfig` become
# `sensitivity`, `deadzone`, `hitbox_scale`, `turn_rate`, `thruster_color`.
# The arity is dictated by the port surface, not by design choice here.
# gdlint:ignore=function-arguments-number
func update(
	dt: float,
	target_mouse: Vector2,
	bounds: Vector2,
	particles: ParticleEngine,
	control_mode: Types.ControlMode,
	move_vector: Vector2,
	sensitivity: float,
	deadzone: float,
	hitbox_scale: float,
	turn_rate: float,
	thruster_color: Color,
	gyro_vector: Vector2
) -> void:
	if is_dead:
		return

	_ship_hitbox_scale = hitbox_scale
	_ship_turn_rate = turn_rate

	if shield_timer > 0.0:
		shield_timer -= dt
	if close_call_timer > 0.0:
		close_call_timer -= dt

	var effective_sensitivity: float = sensitivity if sensitivity != 0.0 else 1.0
	var dx: float = target_mouse.x - x
	var dy: float = target_mouse.y - y
	var dist: float = sqrt(dx * dx + dy * dy)

	if control_mode == Types.ControlMode.GYRO:
		var is_tilting: bool = gyro_vector.x != 0.0 or gyro_vector.y != 0.0
		if is_tilting:
			var tilt_mag: float = sqrt(
				gyro_vector.x * gyro_vector.x + gyro_vector.y * gyro_vector.y
			)
			var clamped_mag: float = minf(1.0, tilt_mag)
			var effective_speed: float = max_speed * clamped_mag * effective_sensitivity
			var dir_x: float = gyro_vector.x / tilt_mag
			var dir_y: float = gyro_vector.y / tilt_mag
			var target_vx: float = dir_x * effective_speed
			var target_vy: float = dir_y * effective_speed

			# PORT: web/src/tilt-to-live/PlayerShip.ts:137-139
			var accel_rate: float = acceleration * dt * 1.25
			vx += (target_vx - vx) * minf(1.0, accel_rate / 180.0)
			vy += (target_vy - vy) * minf(1.0, accel_rate / 180.0)
		else:
			# PORT: web/src/tilt-to-live/PlayerShip.ts:142-145
			vx *= pow(DAMPING, dt * 60.0)
			vy *= pow(DAMPING, dt * 60.0)
			if absf(vx) < 0.5:
				vx = 0.0
			if absf(vy) < 0.5:
				vy = 0.0
	elif control_mode == Types.ControlMode.KEYBOARD:
		var is_moving: bool = move_vector.x != 0.0 or move_vector.y != 0.0
		if is_moving:
			var target_vx: float = move_vector.x * max_speed
			var target_vy: float = move_vector.y * max_speed

			# PORT: web/src/tilt-to-live/PlayerShip.ts:154-156
			var accel_rate: float = acceleration * dt
			vx += (target_vx - vx) * minf(1.0, accel_rate / 180.0)
			vy += (target_vy - vy) * minf(1.0, accel_rate / 180.0)
		else:
			# PORT: web/src/tilt-to-live/PlayerShip.ts:159-162
			vx *= pow(DAMPING, dt * 60.0)
			vy *= pow(DAMPING, dt * 60.0)
			if absf(vx) < 0.5:
				vx = 0.0
			if absf(vy) < 0.5:
				vy = 0.0
	else:
		if dist > deadzone:
			var dir_x: float = dx / dist
			var dir_y: float = dy / dist

			# PORT: web/src/tilt-to-live/PlayerShip.ts:171-173
			var effective_reach: float = maxf(40.0, 160.0 / effective_sensitivity)
			var tilt_scale: float = minf(1.0, (dist - deadzone) / effective_reach)
			var target_speed: float = max_speed * tilt_scale

			var target_vx: float = dir_x * target_speed
			var target_vy: float = dir_y * target_speed

			# PORT: web/src/tilt-to-live/PlayerShip.ts:179-181
			var accel_rate: float = acceleration * dt
			vx += (target_vx - vx) * minf(1.0, accel_rate / 200.0)
			vy += (target_vy - vy) * minf(1.0, accel_rate / 200.0)
		else:
			# PORT: web/src/tilt-to-live/PlayerShip.ts:184-185
			vx *= pow(DAMPING, dt * 60.0)
			vy *= pow(DAMPING, dt * 60.0)

	x += vx * dt
	y += vy * dt

	# PORT: web/src/tilt-to-live/PlayerShip.ts:194-202
	var current_speed: float = sqrt(vx * vx + vy * vy)
	var target_angle: float = angle
	if current_speed > 20.0:
		target_angle = atan2(vy, vx)
	elif control_mode == Types.ControlMode.MOUSE and dist > deadzone:
		target_angle = atan2(dy, dx)
	elif control_mode == Types.ControlMode.GYRO and (gyro_vector.x != 0.0 or gyro_vector.y != 0.0):
		target_angle = atan2(gyro_vector.y, gyro_vector.x)

	# PORT: web/src/tilt-to-live/PlayerShip.ts:205-208
	var diff: float = target_angle - angle
	while diff < -PI:
		diff += PI * 2.0
	while diff > PI:
		diff -= PI * 2.0
	angle += diff * minf(1.0, dt * 16.0 * _ship_turn_rate)

	# PORT: web/src/tilt-to-live/PlayerShip.ts:211-226
	var pad: float = radius + 6.0
	if x < pad:
		x = pad
		vx = absf(vx) * 0.4
	elif x > bounds.x - pad:
		x = bounds.x - pad
		vx = -absf(vx) * 0.4

	if y < pad:
		y = pad
		vy = absf(vy) * 0.4
	elif y > bounds.y - pad:
		y = bounds.y - pad
		vy = -absf(vy) * 0.4

	# PORT: web/src/tilt-to-live/PlayerShip.ts:229-258
	_engine_particle_timer += dt
	if _engine_particle_timer > 0.02 and current_speed > 40.0:
		_engine_particle_timer = 0.0
		var back_dist: float = 14.0
		var spread: float = 5.0

		var rear_x: float = x - cos(angle) * back_dist
		var rear_y: float = y - sin(angle) * back_dist

		var norm_x: float = -sin(angle)
		var norm_y: float = cos(angle)

		var flame_col: Color = Color("#00ffee") if has_shield() else thruster_color
		particles.emit_sparks(
			rear_x + norm_x * spread, rear_y + norm_y * spread, 1, flame_col, 40.0
		)
		particles.emit_sparks(
			rear_x - norm_x * spread, rear_y - norm_y * spread, 1, flame_col, 40.0
		)

	# PORT: web/src/tilt-to-live/PlayerShip.ts:261-268
	_trail_sample_timer += dt
	if _trail_sample_timer > 0.016:
		_trail_sample_timer = 0.0
		trail_history.push_front(Vector2(x, y))
		if trail_history.size() > 14:
			trail_history.pop_back()
