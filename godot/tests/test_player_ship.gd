## test_player_ship.gd
## PORTS: nothing — new file, covers src/sim/player_ship.gd
extends GutTest
## Covers the radius formula, scale clamp, the three control modes, angular
## alignment and the boundary bounce.

const BOUNDS: Vector2 = Vector2(1280.0, 720.0)

var _particles: ParticleEngine = null


func before_each() -> void:
	_particles = ParticleEngine.new()


func _step(
	ship: PlayerShip, control_mode: Types.ControlMode, target: Vector2, gyro: Vector2, steps: int
) -> void:
	for i: int in range(steps):
		ship.update(
			1.0 / 120.0,
			target,
			BOUNDS,
			_particles,
			control_mode,
			Vector2.ZERO,
			1.0,
			4.0,
			1.0,
			1.0,
			Color("#00ddff"),
			gyro
		)


func test_radius_is_nine_times_the_scale_chain() -> void:
	var ship: PlayerShip = PlayerShip.new(100.0, 100.0)
	ship.set_scale(1.0)
	assert_almost_eq(ship.radius, 9.0, 0.0001, "PlayerShip.ts:40 — 9 * scale * hitbox * mult")
	ship.set_hitbox_multiplier(0.5)
	assert_almost_eq(ship.radius, 4.5, 0.0001, "the hull-compact multiplier halves it")


func test_set_scale_clamps_to_the_ported_range() -> void:
	var ship: PlayerShip = PlayerShip.new(0.0, 0.0)
	ship.set_scale(0.1)
	assert_almost_eq(ship.scale, 0.5, 0.0001, "floor is 0.5 — PlayerShip.ts:44")
	ship.set_scale(9.0)
	assert_almost_eq(ship.scale, 1.8, 0.0001, "ceiling is 1.8 — PlayerShip.ts:44")


func test_reset_restores_the_initial_pose() -> void:
	var ship: PlayerShip = PlayerShip.new(0.0, 0.0)
	ship.vx = 100.0
	ship.is_dead = true
	ship.reset(50.0, 60.0)
	assert_almost_eq(ship.x, 50.0, 0.0001, "reset places the ship")
	assert_almost_eq(ship.vx, 0.0, 0.0001, "reset clears velocity")
	assert_almost_eq(ship.angle, -PI / 2.0, 0.0001, "reset faces up — PlayerShip.ts:77")
	assert_false(ship.is_dead, "reset revives the ship")


func test_gyro_tilt_drives_the_ship_along_the_tilt_vector() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	_step(ship, Types.ControlMode.GYRO, Vector2(640.0, 360.0), Vector2(1.0, 0.0), 30)
	assert_gt(ship.x, 640.0, "a rightward tilt moves the ship right")
	assert_almost_eq(ship.y, 360.0, 0.5, "a pure-x tilt does not move it vertically")


func test_neutral_gyro_damps_velocity_to_a_standstill() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	ship.vx = 300.0
	_step(ship, Types.ControlMode.GYRO, Vector2(640.0, 360.0), Vector2.ZERO, 200)
	assert_almost_eq(ship.vx, 0.0, 0.0001, "neutral tilt snaps sub-0.5 velocity to zero")


func test_mouse_mode_steers_toward_the_pointer() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	_step(ship, Types.ControlMode.MOUSE, Vector2(900.0, 360.0), Vector2.ZERO, 30)
	assert_gt(ship.x, 640.0, "the ship accelerates toward the pointer")


func test_mouse_inside_the_deadzone_does_not_accelerate() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	_step(ship, Types.ControlMode.MOUSE, Vector2(642.0, 360.0), Vector2.ZERO, 30)
	assert_almost_eq(ship.x, 640.0, 0.0001, "2px < the 4px deadzone — PlayerShip.ts:166")


func test_the_boundary_bounces_the_ship_back_inside() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	ship.set_scale(1.0)
	_step(ship, Types.ControlMode.GYRO, Vector2.ZERO, Vector2(1.0, 0.0), 600)
	var pad: float = ship.radius + 6.0  # PORT: web/src/tilt-to-live/PlayerShip.ts:211
	assert_almost_eq(ship.x, BOUNDS.x - pad, 0.51, "the ship stops at the padded edge")
	assert_lte(ship.vx, 0.0, "the bounce reverses horizontal velocity")


func test_moving_fast_emits_engine_sparks() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	_step(ship, Types.ControlMode.GYRO, Vector2.ZERO, Vector2(1.0, 0.0), 60)
	assert_gt(_particles.particles.size(), 0, "twin engine exhaust fires above 40 px/s")


func test_trail_history_is_capped() -> void:
	var ship: PlayerShip = PlayerShip.new(640.0, 360.0)
	_step(ship, Types.ControlMode.GYRO, Vector2.ZERO, Vector2(1.0, 0.0), 600)
	assert_lte(ship.trail_history.size(), 14, "trail is capped at 14 — PlayerShip.ts:265")
