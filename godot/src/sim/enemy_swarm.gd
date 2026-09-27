# gdlint:ignore=max-public-methods
# gdlint:disable=max-file-lines
## enemy_swarm.gd
## PORTS: web/src/tilt-to-live/EnemySwarm.ts (1649 lines, source commit 7be9614)
class_name EnemySwarm
extends RefCounted
## Red dot swarm intelligence, the thirteen enemy behaviours, every formation
## and the wave director.
##
## PORT-NOTE: EnemySwarm.ts has 21 public methods and, with Law 1 citations,
## more than 1000 lines. Law 3 forbids splitting a ported module, so both
## gdlint limits are suppressed here, following audio_bank.gd:1. max-file-lines
## is reported on the last line, which is why it needs `disable`, not `ignore`.
##
## PORT-NOTE: EnemySwarm.render() (EnemySwarm.ts:1191-1648) relocates to
## render/entity_layer.gd (spec §4.2/D4) because CanvasItem 2D drawing belongs
## to Node2D render layers.

## DIVERGENCE(M11c P29): wall-formation dot spacing (TS 22), radius (TS 8) and gap
## half-width in slots (TS 2); see spawn_wall_formation.
const WALL_SPACING: float = 32.0
const WALL_RADIUS: float = 10.5
const WALL_GAP_HALF: int = 1
## DIVERGENCE(M11c P15): separation switches to the windowed sweep at this many
## candidates (bench 2026-09-27: the sweep is 2-5x faster from 40 up).
const SWEEP_MIN_CANDIDATES: int = 32
## DIVERGENCE(M11c P15): how far xs[ii] may move within its own round before the
## round falls back to the plain scan (px).
const SWEEP_SLACK: float = 4.0
## DIVERGENCE(M11c P15): re-index once any x has drifted this far (px).
const SWEEP_REBUILD: float = 8.0
## DIVERGENCE(M11c P15): the index quantises x to 1/16 px.
const SWEEP_QUANT: float = 16.0
## DIVERGENCE(M11c P15): keeps quantised x positive for positions off the arena.
const SWEEP_OFFSET: float = 65536.0
## DIVERGENCE(M11c P15): low bits of an index key hold the candidate index.
const SWEEP_INDEX_BITS: int = 20
const SWEEP_INDEX_MASK: int = (1 << SWEEP_INDEX_BITS) - 1
## DIVERGENCE(M11c P17): the empty satellite list.
const _NO_SATELLITES: Array[Types.Enemy] = []
## DIVERGENCE(M11c N2): separation runs in C++ when the PerilNative extension is
## loaded; false forces the GDScript sweep (the oracles compare both).
static var use_native: bool = true
static var _native: Object = null

## Live active enemies. PORT: web/src/tilt-to-live/EnemySwarm.ts:9
var enemies: Array[Types.Enemy] = []

## Scale factor for enemy radius and speed. PORT: web/src/tilt-to-live/EnemySwarm.ts:20
var scale: float = 1.0

## Progression-driven uniform movement slow. PORT: web/src/tilt-to-live/EnemySwarm.ts:30
var speed_scale: float = 1.0

var _next_enemy_id: int = 1
var _spawn_timer: float = 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:39
var _wave_timer: float = 4.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:40
var _elapsed: float = 0.0
var _wall_direction_cycle: int = 0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:14
## DIVERGENCE(M11c P17): this tick's satellites per carrier id (see _build_satellite_map).
var _sats_by_carrier: Dictionary[int, Array] = {}
var _sats_by_carrier_valid: bool = false


func _init() -> void:
	reset()


## Sets the arena scale factor. PORT: web/src/tilt-to-live/EnemySwarm.ts:22-24
func set_scale(p_scale: float) -> void:
	scale = clampf(p_scale, 0.5, 1.8)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:23


## Sets the speed multiplier from progression perks. PORT: web/src/tilt-to-live/EnemySwarm.ts:32-34
func set_speed_scale(p_scale: float) -> void:
	speed_scale = clampf(p_scale, 0.1, 2.0)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:33


## Resets all enemies and timers. PORT: web/src/tilt-to-live/EnemySwarm.ts:36-43
func reset() -> void:
	enemies = []
	_next_enemy_id = 1
	_spawn_timer = 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:39
	_wave_timer = 4.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:40
	_elapsed = 0.0
	_wall_direction_cycle = 0


## Spawns a single seeker dot at an arena edge or custom position.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:544-574
func spawn_seeker(bounds: Vector2, custom_x: float = NAN, custom_y: float = NAN) -> Types.Enemy:
	var x: float = custom_x
	var y: float = custom_y

	if is_nan(x) or is_nan(y):
		var edge: int = randi() % 4  # PORT: web/src/tilt-to-live/EnemySwarm.ts:548
		var margin: float = 20.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:549
		match edge:
			0:
				x = randf() * bounds.x
				y = -margin
			1:
				x = bounds.x + margin
				y = randf() * bounds.y
			2:
				x = randf() * bounds.x
				y = bounds.y + margin
			_:
				x = -margin
				y = randf() * bounds.y

	var enemy: Types.Enemy = Types.Enemy.new()
	enemy.id = _next_enemy_id
	_next_enemy_id += 1
	enemy.type = Types.EnemyType.SEEKER
	enemy.x = x
	enemy.y = y
	enemy.vx = 0.0
	enemy.vy = 0.0
	enemy.radius = 8.5 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:566
	enemy.frozen = false
	enemy.freeze_timer = 0.0
	enemy.age = 0.0
	enemy.health = 1.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:570
	enemies.append(enemy)
	return enemy


## Spawns a charger enemy at an arena edge, aimed at the player.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:576-607
func spawn_charger(bounds: Vector2, player_pos: Vector2) -> Types.Enemy:
	var edge: int = randi() % 4  # PORT: web/src/tilt-to-live/EnemySwarm.ts:577
	var margin: float = 25.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:578
	var x: float = 0.0
	var y: float = 0.0
	match edge:
		0:
			x = randf() * bounds.x
			y = -margin
		1:
			x = bounds.x + margin
			y = randf() * bounds.y
		2:
			x = randf() * bounds.x
			y = bounds.y + margin
		_:
			x = -margin
			y = randf() * bounds.y

	# PORT: web/src/tilt-to-live/EnemySwarm.ts:588
	var aim_angle: float = atan2(player_pos.y - y, player_pos.x - x)

	var enemy: Types.Enemy = Types.Enemy.new()
	enemy.id = _next_enemy_id
	_next_enemy_id += 1
	enemy.type = Types.EnemyType.CHARGER
	enemy.x = x
	enemy.y = y
	enemy.vx = 0.0
	enemy.vy = 0.0
	enemy.radius = 11.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:596
	enemy.frozen = false
	enemy.freeze_timer = 0.0
	enemy.age = 0.0
	enemy.health = 1.0
	enemy.state = Types.EnemyState.AIMING  # PORT: web/src/tilt-to-live/EnemySwarm.ts:601
	enemy.aim_angle = aim_angle
	enemy.aim_timer = 1.1  # PORT: web/src/tilt-to-live/EnemySwarm.ts:603
	enemies.append(enemy)
	return enemy


## Spawns a pulsar enemy at an arena edge.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:609-635
func spawn_pulsar(bounds: Vector2, _player_pos: Vector2) -> Types.Enemy:
	var edge: int = randi() % 4  # PORT: web/src/tilt-to-live/EnemySwarm.ts:610
	var margin: float = 26.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:611
	var x: float = 0.0
	var y: float = 0.0
	match edge:
		0:
			x = randf() * bounds.x
			y = -margin
		1:
			x = bounds.x + margin
			y = randf() * bounds.y
		2:
			x = randf() * bounds.x
			y = bounds.y + margin
		_:
			x = -margin
			y = randf() * bounds.y

	var enemy: Types.Enemy = Types.Enemy.new()
	enemy.id = _next_enemy_id
	_next_enemy_id += 1
	enemy.type = Types.EnemyType.PULSAR
	enemy.x = x
	enemy.y = y
	enemy.vx = 0.0
	enemy.vy = 0.0
	enemy.radius = 12.5 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:628
	enemy.frozen = false
	enemy.freeze_timer = 0.0
	enemy.age = 0.0
	enemy.health = 2.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:632
	enemy.pulse_timer = 2.2  # PORT: web/src/tilt-to-live/EnemySwarm.ts:633
	enemies.append(enemy)
	return enemy


## Spawns a specter enemy at an arena edge.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:637-667
func spawn_specter(bounds: Vector2, _player_pos: Vector2) -> Types.Enemy:
	var edge: int = randi() % 4  # PORT: web/src/tilt-to-live/EnemySwarm.ts:640
	var margin: float = 20.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:641
	var x: float = 0.0
	var y: float = 0.0
	match edge:
		0:
			x = randf() * bounds.x
			y = -margin
		1:
			x = bounds.x + margin
			y = randf() * bounds.y
		2:
			x = randf() * bounds.x
			y = bounds.y + margin
		_:
			x = -margin
			y = randf() * bounds.y

	var enemy: Types.Enemy = Types.Enemy.new()
	enemy.id = _next_enemy_id
	_next_enemy_id += 1
	enemy.type = Types.EnemyType.SPECTER
	enemy.x = x
	enemy.y = y
	enemy.vx = 0.0
	enemy.vy = 0.0
	enemy.radius = 8.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:658
	enemy.frozen = false
	enemy.freeze_timer = 0.0
	enemy.age = 0.0
	enemy.health = 1.0
	enemy.stealth_opacity = 0.8  # PORT: web/src/tilt-to-live/EnemySwarm.ts:663
	enemies.append(enemy)
	return enemy


## Spawns an artillery enemy at an arena edge, aimed at the player.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:669-699
func spawn_artillery(bounds: Vector2, player_pos: Vector2) -> Types.Enemy:
	var edge: int = randi() % 4  # PORT: web/src/tilt-to-live/EnemySwarm.ts:670
	var margin: float = 28.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:671
	var x: float = 0.0
	var y: float = 0.0
	match edge:
		0:
			x = randf() * bounds.x
			y = -margin
		1:
			x = bounds.x + margin
			y = randf() * bounds.y
		2:
			x = randf() * bounds.x
			y = bounds.y + margin
		_:
			x = -margin
			y = randf() * bounds.y

	# PORT: web/src/tilt-to-live/EnemySwarm.ts:681
	var aim_angle: float = atan2(player_pos.y - y, player_pos.x - x)

	var enemy: Types.Enemy = Types.Enemy.new()
	enemy.id = _next_enemy_id
	_next_enemy_id += 1
	enemy.type = Types.EnemyType.ARTILLERY
	enemy.x = x
	enemy.y = y
	enemy.vx = 0.0
	enemy.vy = 0.0
	enemy.radius = 13.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:689
	enemy.frozen = false
	enemy.freeze_timer = 0.0
	enemy.age = 0.0
	enemy.health = 2.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:693
	enemy.aim_angle = aim_angle
	enemy.fire_cooldown = 2.2 + randf() * 0.8  # PORT: web/src/tilt-to-live/EnemySwarm.ts:695
	enemies.append(enemy)
	return enemy


## Spawns a bullet travelling from an origin point towards a target.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:701-722
func spawn_bullet(origin_x: float, origin_y: float, target_pos: Vector2) -> Types.Enemy:
	var dx: float = target_pos.x - origin_x
	var dy: float = target_pos.y - origin_y
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:704
	var dist: float = maxf(1.0, sqrt(dx * dx + dy * dy))
	var speed: float = 260.0 * maxf(0.72, scale)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:705

	var bullet: Types.Enemy = Types.Enemy.new()
	bullet.id = _next_enemy_id
	_next_enemy_id += 1
	bullet.type = Types.EnemyType.BULLET
	bullet.x = origin_x
	bullet.y = origin_y
	bullet.vx = (dx / dist) * speed
	bullet.vy = (dy / dist) * speed
	bullet.radius = 5.5 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:714
	bullet.frozen = false
	bullet.freeze_timer = 0.0
	bullet.age = 0.0
	bullet.health = 1.0
	enemies.append(bullet)
	return bullet


## Spawns a carrier and its four protective orbiting satellite mini-dots.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:724-776
func spawn_carrier(bounds: Vector2, _player_pos: Vector2) -> Types.Enemy:
	var edge: int = randi() % 4  # PORT: web/src/tilt-to-live/EnemySwarm.ts:725
	var margin: float = 35.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:726
	var x: float = 0.0
	var y: float = 0.0
	match edge:
		0:
			x = randf() * bounds.x
			y = -margin
		1:
			x = bounds.x + margin
			y = randf() * bounds.y
		2:
			x = randf() * bounds.x
			y = bounds.y + margin
		_:
			x = -margin
			y = randf() * bounds.y

	var carrier: Types.Enemy = Types.Enemy.new()
	carrier.id = _next_enemy_id
	_next_enemy_id += 1
	carrier.type = Types.EnemyType.CARRIER
	carrier.x = x
	carrier.y = y
	carrier.vx = 0.0
	carrier.vy = 0.0
	carrier.radius = 18.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:743
	carrier.frozen = false
	carrier.freeze_timer = 0.0
	carrier.age = 0.0
	carrier.health = 4.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:747
	enemies.append(carrier)

	# PORT: web/src/tilt-to-live/EnemySwarm.ts:751-772
	var satellite_count: int = 4  # PORT: web/src/tilt-to-live/EnemySwarm.ts:752
	for k: int in range(satellite_count):
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:754
		var angle: float = (float(k) * PI * 2.0) / float(satellite_count)
		var orbit_radius: float = 38.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:755

		var satellite: Types.Enemy = Types.Enemy.new()
		satellite.id = _next_enemy_id
		_next_enemy_id += 1
		satellite.type = Types.EnemyType.SEEKER
		satellite.x = x + cos(angle) * orbit_radius
		satellite.y = y + sin(angle) * orbit_radius
		satellite.vx = 0.0
		satellite.vy = 0.0
		satellite.radius = 6.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:763
		satellite.frozen = false
		satellite.freeze_timer = 0.0
		satellite.age = 0.0
		satellite.health = 1.0
		satellite.parent_carrier_id = carrier.id  # PORT: web/src/tilt-to-live/EnemySwarm.ts:768
		satellite.orbit_angle = angle  # PORT: web/src/tilt-to-live/EnemySwarm.ts:769
		satellite.orbit_radius = orbit_radius
		enemies.append(satellite)

	return carrier


## Spawns an immediate, dramatic start armada tailored to the mode.
## Called by the cinematic's handover (TiltEntranceCinematic.ts:196, :200;
## EntranceCinematic._finish, M10 R3).
## PORT: web/src/tilt-to-live/EnemySwarm.ts:781-799
func spawn_mode_armada(mode: Types.GameMode, bounds: Vector2, player_pos: Vector2) -> void:
	if mode == Types.GameMode.CODE_RED:
		var count: int = 24  # PORT: web/src/tilt-to-live/EnemySwarm.ts:784
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:785
		var radius: float = minf(bounds.x, bounds.y) * 0.44
		for i: int in range(count):
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:787
			var angle: float = (float(i) * PI * 2.0) / float(count)
			var x: float = player_pos.x + cos(angle) * radius
			var y: float = player_pos.y + sin(angle) * radius
			spawn_seeker(bounds, x, y)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:790
	else:
		var count: int = 8  # PORT: web/src/tilt-to-live/EnemySwarm.ts:794
		for i: int in range(count):
			spawn_seeker(bounds)


## Picks one of the five classic formations at random and spawns it.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:801-826
func trigger_random_formation(player_pos: Vector2, bounds: Vector2, current_score: int = 0) -> void:
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:806
	var choices: Array[String] = ["arrow", "circle", "wall", "turret", "snake"]
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:807
	var choice: String = choices[randi() % choices.size()]

	match choice:
		"arrow":
			spawn_arrow_formation(bounds)
		"circle":
			spawn_circle_encirclement(player_pos, bounds, current_score)
		"wall":
			spawn_wall_formation(bounds)
		"turret":
			spawn_turret(bounds)
		"snake":
			spawn_snake(bounds)


## Picks one of the three gauntlet-safe formations at random and spawns it.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:828-849
func trigger_gauntlet_formation(
	_player_pos: Vector2, bounds: Vector2, _current_score: int = 0
) -> void:
	# Gauntlet mode strictly excludes 'wall' (vertical/horizontal sweeps) and
	# 'circle' (encirclements). Only fair directional waves that can be
	# navigated alongside descending walls.
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:835
	var choices: Array[String] = ["arrow", "turret", "snake"]
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:836
	var choice: String = choices[randi() % choices.size()]

	match choice:
		"arrow":
			spawn_arrow_formation(bounds)
		"turret":
			spawn_turret(bounds)
		"snake":
			spawn_snake(bounds)


## Spawns a wing of seven arrow drones sweeping from one screen edge, or two
## wings from both edges. PORT: web/src/tilt-to-live/EnemySwarm.ts:851-882
func spawn_arrow_formation(bounds: Vector2, is_dual_pincer: bool = false) -> void:
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:852
	var wings: Array[bool] = []
	if is_dual_pincer:
		wings = [true, false]
	else:
		wings = [randf() < 0.5]

	for from_left: bool in wings:
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:855
		var start_x: float = -60.0 if from_left else bounds.x + 60.0
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:856
		var start_y: float = 100.0 + randf() * (bounds.y - 200.0)
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:857
		var speed: float = (260.0 if from_left else -260.0) * maxf(0.72, scale)

		# PORT: web/src/tilt-to-live/EnemySwarm.ts:859-864
		var row_offsets: Array[Vector2] = [
			Vector2(0.0, 0.0),
			Vector2(-22.0, -18.0),
			Vector2(-22.0, 18.0),
			Vector2(-44.0, -36.0),
			Vector2(-44.0, 36.0),
			Vector2(-66.0, -54.0),
			Vector2(-66.0, 54.0),
		]

		for off: Vector2 in row_offsets:
			var enemy: Types.Enemy = Types.Enemy.new()
			enemy.id = _next_enemy_id
			_next_enemy_id += 1
			enemy.type = Types.EnemyType.ARROW_DRONE
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:870
			enemy.x = start_x + (off.x * scale if from_left else -off.x * scale)
			enemy.y = start_y + off.y * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:871
			enemy.vx = speed
			enemy.vy = 0.0
			enemy.radius = 8.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:874
			enemy.frozen = false
			enemy.freeze_timer = 0.0
			enemy.age = 0.0
			enemy.health = 1.0
			enemies.append(enemy)


## Spawns a ring of circle dots around the player that pauses, then closes in.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:884-914
func spawn_circle_encirclement(
	player_pos: Vector2, _bounds: Vector2, current_score: int = 0, is_tight: bool = false
) -> void:
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:890 — the shape (tight fixed, else a
	# score ramp); DIVERGENCE(M11c P9): user ruling 2026-09-26, "too close together,
	# near impossible to slip past" — fewer dots (TS: 16 tight, 12-16 ramp).
	var count: int = 11 if is_tight else mini(10, 8 + current_score / 10000)
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:891
	var radius: float = (180.0 if is_tight else 260.0) * scale
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:892
	var pause_duration: float = 0.75 if is_tight else 1.25

	for i: int in range(count):
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:895
		var angle: float = (float(i) * PI * 2.0) / float(count)
		var x: float = player_pos.x + cos(angle) * radius
		var y: float = player_pos.y + sin(angle) * radius

		var enemy: Types.Enemy = Types.Enemy.new()
		enemy.id = _next_enemy_id
		_next_enemy_id += 1
		enemy.type = Types.EnemyType.CIRCLE_DOT
		enemy.x = x
		enemy.y = y
		enemy.vx = 0.0
		enemy.vy = 0.0
		enemy.radius = 8.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:906
		enemy.frozen = false
		enemy.freeze_timer = 0.0
		enemy.age = 0.0
		enemy.special_timer = pause_duration  # PORT: web/src/tilt-to-live/EnemySwarm.ts:910
		enemy.health = 1.0
		enemies.append(enemy)


## Spawns a wall of dots sweeping in from one edge with a five-dot gap for the
## player to pass through. PORT: web/src/tilt-to-live/EnemySwarm.ts:916-967
func spawn_wall_formation(bounds: Vector2) -> void:
	var horizontal: bool = randf() < 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:917
	# DIVERGENCE(M11c P29, user 2026-09-27: "space them out a bit more", then "go a bit
	# wider, smaller ships still cant pass"): spacing 22 -> WALL_SPACING (32) x scale,
	# ~30% fewer dots per wall. To keep ships from slipping between dots the radius
	# grows 8 -> WALL_RADIUS (10.5): half the spacing (16) stays under the smallest
	# non-Singularity contact distance, Shuriken 0.85 x max hull compact 0.82:
	# 9 x 0.697 + 10.5 = 16.77 (all scale-relative). The gap skips 3 slots, not 5, so
	# its clear width stays near the TS's (4 x 32 - 21 = 107 vs 6 x 22 - 16 = 116).
	# Singularity (hitbox 0.40) passes; with max hull compact it already did in the TS.
	var spacing: float = WALL_SPACING * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:918

	if horizontal:
		var from_top: bool = randf() < 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:921
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:922
		var y: float = -30.0 if from_top else bounds.y + 30.0
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:923
		var vy: float = (140.0 if from_top else -140.0) * maxf(0.72, scale)
		var num_dots: int = floori(bounds.x / spacing)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:924
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:925
		var gap_index: int = 2 + floori(randf() * float(num_dots - 4))

		for i: int in range(num_dots):
			if absi(i - gap_index) <= WALL_GAP_HALF:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:928
				continue
			var enemy: Types.Enemy = Types.Enemy.new()
			enemy.id = _next_enemy_id
			_next_enemy_id += 1
			enemy.type = Types.EnemyType.WALL_DOT
			# PORT-NOTE: the `10.0` offset (EnemySwarm.ts:932) is unscaled in the
			# TS despite `spacing` being scaled — preserved deliberately.
			enemy.x = float(i) * spacing + 10.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:932
			enemy.y = y
			enemy.vx = 0.0
			enemy.vy = vy
			enemy.radius = WALL_RADIUS * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:936
			enemy.frozen = false
			enemy.freeze_timer = 0.0
			enemy.age = 0.0
			enemy.health = 1.0
			enemies.append(enemy)
	else:
		var from_left: bool = randf() < 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:944
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:945
		var x: float = -30.0 if from_left else bounds.x + 30.0
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:946
		var vx: float = (140.0 if from_left else -140.0) * maxf(0.72, scale)
		var num_dots: int = floori(bounds.y / spacing)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:947
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:948
		var gap_index: int = 2 + floori(randf() * float(num_dots - 4))

		for i: int in range(num_dots):
			if absi(i - gap_index) <= WALL_GAP_HALF:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:951
				continue
			var enemy: Types.Enemy = Types.Enemy.new()
			enemy.id = _next_enemy_id
			_next_enemy_id += 1
			enemy.type = Types.EnemyType.WALL_DOT
			enemy.x = x
			# PORT-NOTE: the `10.0` offset (EnemySwarm.ts:956) is unscaled in the
			# TS despite `spacing` being scaled — preserved deliberately.
			enemy.y = float(i) * spacing + 10.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:956
			enemy.vx = vx
			enemy.vy = 0.0
			enemy.radius = WALL_RADIUS * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:959
			enemy.frozen = false
			enemy.freeze_timer = 0.0
			enemy.age = 0.0
			enemy.health = 1.0
			enemies.append(enemy)


## Spawns a sequential gauntlet wall corridor, cycling through top-down,
## right-left, bottom-up and left-right on successive calls.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:972-1063
# PORT-NOTE: no caller in web/src — GauntletMaze.ts builds the gauntlet walls.
# Dead in the TS; preserved deliberately (M10 R7).
func spawn_sequential_gauntlet_wall(bounds: Vector2) -> void:
	var dir: int = _wall_direction_cycle % 4  # PORT: web/src/tilt-to-live/EnemySwarm.ts:973
	_wall_direction_cycle += 1
	var spacing: float = 22.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:975
	var speed: float = 150.0 * maxf(0.72, scale)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:976

	if dir == 0:
		var num_dots: int = floori(bounds.x / spacing)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:980
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:981
		var gap_index: int = floori(float(num_dots) * 0.25)
		for i: int in range(num_dots):
			if absi(i - gap_index) <= 3:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:983
				continue
			var enemy: Types.Enemy = Types.Enemy.new()
			enemy.id = _next_enemy_id
			_next_enemy_id += 1
			enemy.type = Types.EnemyType.WALL_DOT
			enemy.x = float(i) * spacing + 10.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:988
			enemy.y = -30.0
			enemy.vx = 0.0
			enemy.vy = speed
			enemy.radius = 8.5 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:991
			enemy.frozen = false
			enemy.freeze_timer = 0.0
			enemy.age = 0.0
			enemy.health = 1.0
			enemy.is_hazard = true
			enemies.append(enemy)
	elif dir == 1:
		var num_dots: int = floori(bounds.y / spacing)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1001
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:1002
		var gap_index: int = floori(float(num_dots) * 0.7)
		for i: int in range(num_dots):
			if absi(i - gap_index) <= 3:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1004
				continue
			var enemy: Types.Enemy = Types.Enemy.new()
			enemy.id = _next_enemy_id
			_next_enemy_id += 1
			enemy.type = Types.EnemyType.WALL_DOT
			enemy.x = bounds.x + 30.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1008
			enemy.y = float(i) * spacing + 10.0
			enemy.vx = -speed
			enemy.vy = 0.0
			enemy.radius = 8.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1012
			enemy.frozen = false
			enemy.freeze_timer = 0.0
			enemy.age = 0.0
			enemy.health = 1.0
			enemy.is_hazard = true
			enemies.append(enemy)
	elif dir == 2:
		var num_dots: int = floori(bounds.x / spacing)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1022
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:1023
		var gap_index: int = floori(float(num_dots) * 0.75)
		for i: int in range(num_dots):
			if absi(i - gap_index) <= 3:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1025
				continue
			var enemy: Types.Enemy = Types.Enemy.new()
			enemy.id = _next_enemy_id
			_next_enemy_id += 1
			enemy.type = Types.EnemyType.WALL_DOT
			enemy.x = float(i) * spacing + 10.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1030
			enemy.y = bounds.y + 30.0
			enemy.vx = 0.0
			enemy.vy = -speed
			enemy.radius = 8.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1033
			enemy.frozen = false
			enemy.freeze_timer = 0.0
			enemy.age = 0.0
			enemy.health = 1.0
			enemy.is_hazard = true
			enemies.append(enemy)
	else:
		var num_dots: int = floori(bounds.y / spacing)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1043
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:1044
		var gap_index: int = floori(float(num_dots) * 0.3)
		for i: int in range(num_dots):
			if absi(i - gap_index) <= 3:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1046
				continue
			var enemy: Types.Enemy = Types.Enemy.new()
			enemy.id = _next_enemy_id
			_next_enemy_id += 1
			enemy.type = Types.EnemyType.WALL_DOT
			enemy.x = -30.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1050
			enemy.y = float(i) * spacing + 10.0
			enemy.vx = speed
			enemy.vy = 0.0
			enemy.radius = 8.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1054
			enemy.frozen = false
			enemy.freeze_timer = 0.0
			enemy.age = 0.0
			enemy.health = 1.0
			enemy.is_hazard = true
			enemies.append(enemy)
	# PORT-NOTE: the top-down wall uses radius 8.5 * scale (:991) while the
	# other three use unscaled 8.5 (:1012, :1033, :1054) — preserved
	# deliberately.


## Spawns a central rotating obstacle gate of six hazard turret dots.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:1068-1094
# PORT-NOTE: no caller in web/src — GauntletMaze.ts builds the gauntlet walls.
# Dead in the TS; preserved deliberately (M10 R7).
func spawn_rotating_gate(bounds: Vector2) -> void:
	var cx: float = bounds.x / 2.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1069
	var cy: float = bounds.y / 2.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1070
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:1071
	var speed: float = (1.0 if randf() < 0.5 else -1.0) * 0.75
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:1072
	var offsets: Array[float] = [-80.0, -56.0, -32.0, 32.0, 56.0, 80.0]

	# PORT-NOTE: the gate ignores this.scale entirely — preserved deliberately.
	for off: float in offsets:
		var enemy: Types.Enemy = Types.Enemy.new()
		enemy.id = _next_enemy_id
		_next_enemy_id += 1
		enemy.type = Types.EnemyType.TURRET_DOT
		enemy.x = cx + off
		enemy.y = cy
		enemy.vx = 0.0
		enemy.vy = 0.0
		enemy.radius = 8.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1082
		enemy.frozen = false
		enemy.freeze_timer = 0.0
		enemy.age = 0.0
		enemy.health = 1.0
		enemy.orbit_center = Vector2(cx, cy)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1087
		enemy.orbit_radius = absf(off)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1088
		enemy.orbit_speed = speed
		enemy.target_angle = 0.0 if off > 0.0 else PI  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1090
		enemy.is_hazard = true
		enemies.append(enemy)


## Spawns a single slow-drifting three-health turret dot at a random position.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:1098-1116
func spawn_turret(bounds: Vector2) -> void:
	var pad: float = 80.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1099
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:1100
	var x: float = pad + randf() * (bounds.x - pad * 2.0)
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:1101
	var y: float = pad + randf() * (bounds.y - pad * 2.0)

	var enemy: Types.Enemy = Types.Enemy.new()
	enemy.id = _next_enemy_id
	_next_enemy_id += 1
	enemy.type = Types.EnemyType.TURRET_DOT
	enemy.x = x
	enemy.y = y
	enemy.vx = (randf() - 0.5) * 30.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1108
	enemy.vy = (randf() - 0.5) * 30.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1109
	enemy.radius = 12.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1110
	enemy.frozen = false
	enemy.freeze_timer = 0.0
	enemy.age = 0.0
	enemy.health = 3.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1114
	enemies.append(enemy)


## Spawns an eight-segment snake, head first, trailing along the x axis.
# PORT-NOTE: named _bounds in the TS yet read at :1119-1120 — preserved
# deliberately.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:1118-1139
func spawn_snake(_bounds: Vector2) -> void:
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:1119
	var start_x: float = 60.0 + randf() * (_bounds.x - 120.0)
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:1120
	var start_y: float = 60.0 + randf() * (_bounds.y - 120.0)
	var length: int = 8  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1121

	for i: int in range(length):
		var enemy: Types.Enemy = Types.Enemy.new()
		enemy.id = _next_enemy_id
		_next_enemy_id += 1
		enemy.type = Types.EnemyType.SNAKE_SEGMENT
		enemy.x = start_x - float(i) * 14.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1127
		enemy.y = start_y
		enemy.vx = 110.0 * maxf(0.72, scale)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1129
		enemy.vy = 0.0
		enemy.radius = (10.0 if i == 0 else 8.0) * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1131
		enemy.frozen = false
		enemy.freeze_timer = 0.0
		enemy.age = 0.0
		enemy.health = 1.0
		enemies.append(enemy)


## Updates continuous spawning, individual enemy physics and flocking separation.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:45-221
func update(
	dt: float,
	player_pos: Vector2,
	bounds: Vector2,
	particles: ParticleEngine,
	current_score: int = 0,
	game_mode: Types.GameMode = Types.GameMode.CLASSIC
) -> void:
	_elapsed += dt
	_spawn_timer -= dt
	_wave_timer -= dt

	var is_code_red: bool = game_mode == Types.GameMode.CODE_RED

	# 1. Continuous Seeker Spawning with Mode Escalation.
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:59-104
	if _spawn_timer <= 0.0:
		var time_reduction: float = _elapsed * 0.005  # PORT: web/src/tilt-to-live/EnemySwarm.ts:61
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:62
		var score_reduction: float = minf(0.35, (float(current_score) / 30000.0) * 0.35)

		if is_code_red:
			_spawn_timer = 0.32 + randf() * 0.12  # PORT: web/src/tilt-to-live/EnemySwarm.ts:66
			if current_score >= 24000 and randf() < 0.28:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:67
				spawn_carrier(bounds, player_pos)
			elif current_score >= 16000 and randf() < 0.26:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:69
				spawn_pulsar(bounds, player_pos)
			elif current_score >= 10000 and randf() < 0.30:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:71
				spawn_artillery(bounds, player_pos)
			elif current_score >= 6000 and randf() < 0.28:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:73
				spawn_specter(bounds, player_pos)
			elif current_score >= 2500 and randf() < 0.35:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:75
				spawn_charger(bounds, player_pos)
			else:
				# PORT: web/src/tilt-to-live/EnemySwarm.ts:78-79
				spawn_seeker(bounds)
				spawn_seeker(bounds)
		else:
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:83-84
			var base_interval: float = maxf(0.42, 1.35 - time_reduction - score_reduction)
			_spawn_timer = base_interval + randf() * 0.15
			# Variety unlock: chargers at 5k, specters at 10k, artillery at
			# 16k, pulsars at 22k, carriers at 32k.
			if current_score >= 32000 and randf() < 0.22:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:87
				spawn_carrier(bounds, player_pos)
			elif current_score >= 22000 and randf() < 0.26:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:89
				spawn_pulsar(bounds, player_pos)
			elif current_score >= 16000 and randf() < 0.28:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:91
				spawn_artillery(bounds, player_pos)
			elif current_score >= 10000 and randf() < 0.26:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:93
				spawn_specter(bounds, player_pos)
			elif current_score >= 5000 and randf() < 0.32:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:95
				spawn_charger(bounds, player_pos)
			else:
				# PORT: web/src/tilt-to-live/EnemySwarm.ts:98
				var spawn_count: int = 2 if (current_score >= 12000 and randf() < 0.25) else 1
				for s: int in range(spawn_count):
					spawn_seeker(bounds)

	# 2. Coordinated Formation Waves with Mode Specialization.
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:106-132
	if _wave_timer <= 0.0:
		if is_code_red:
			var roll: float = randf()  # PORT: web/src/tilt-to-live/EnemySwarm.ts:110
			if roll < 0.35:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:111
				spawn_wall_formation(bounds)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:112
			elif roll < 0.70:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:113
				spawn_arrow_formation(bounds, true)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:114
			else:
				# PORT: web/src/tilt-to-live/EnemySwarm.ts:116
				spawn_circle_encirclement(player_pos, bounds, current_score, true)
			_wave_timer = 3.6 + randf() * 1.2  # PORT: web/src/tilt-to-live/EnemySwarm.ts:118
		elif game_mode == Types.GameMode.GAUNTLET:
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:121
			trigger_gauntlet_formation(player_pos, bounds, current_score)
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:122
			var score_wave_reduction: float = minf(2.0, (float(current_score) / 25000.0) * 2.0)
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:123
			var base_wave_interval: float = maxf(8.5, 13.5 - _elapsed * 0.02 - score_wave_reduction)
			_wave_timer = base_wave_interval + randf() * 2.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:124
		else:
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:127
			trigger_random_formation(player_pos, bounds, current_score)
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:128
			var score_wave_reduction: float = minf(2.0, (float(current_score) / 25000.0) * 2.0)
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:129
			var base_wave_interval: float = maxf(5.5, 10.0 - _elapsed * 0.02 - score_wave_reduction)
			_wave_timer = base_wave_interval + randf() * 2.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:130

	# DIVERGENCE(M11c P1): debug-only probe sections for the per-enemy loop and separation.
	var pt_loop: int = PerfProbe.now()
	_build_satellite_map()
	# DIVERGENCE(M11c P23): update_seeker's per-tick constants (the same expressions,
	# in the same order, so the same values) are computed once here, and its body is
	# inlined below — a call per seeker per tick cost as much as the arithmetic.
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:235-240, :249
	var score_speed_bonus: float = minf(25.0, (float(current_score) / 25000.0) * 25.0)
	var seeker_speed: float = (
		minf(195.0, 105.0 + _elapsed * 0.5 + score_speed_bonus) * maxf(0.72, scale)
	)
	if is_code_red:
		seeker_speed *= 1.35  # PORT: web/src/tilt-to-live/EnemySwarm.ts:240
	var seeker_steer: float = (4.5 if is_code_red else 3.2) * dt
	var px: float = player_pos.x
	var py: float = player_pos.y
	# 3. Update Individual Enemy Physics & Logic.
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:134-217
	for i: int in range(enemies.size() - 1, -1, -1):
		var e: Types.Enemy = enemies[i]
		e.age += dt

		if e.frozen:
			e.freeze_timer -= dt
			if e.freeze_timer <= 0.0:
				e.frozen = false
			continue

		var etype: int = e.type
		match etype:
			Types.EnemyType.SEEKER:
				# update_seeker, inlined (P23). PORT: web/src/tilt-to-live/EnemySwarm.ts:223-256
				# DIVERGENCE(M11c P27): x/y/vx/vy are read into locals once and written
				# back once (the same expressions on the same values), and the clamp
				# below runs here on those locals — each Enemy property access costs
				# about as much as the arithmetic.
				var ex: float = e.x
				var ey: float = e.y
				var evx: float = e.vx
				var evy: float = e.vy
				var sdx: float = px - ex
				var sdy: float = py - ey
				var sdist: float = sqrt(sdx * sdx + sdy * sdy)
				if sdist > 1.0:
					var target_speed: float = seeker_speed
					if e.chilled:
						target_speed *= 0.45  # PORT: web/src/tilt-to-live/EnemySwarm.ts:243
					var target_vx: float = (sdx / sdist) * target_speed
					var target_vy: float = (sdy / sdist) * target_speed
					evx += (target_vx - evx) * seeker_steer
					evy += (target_vy - evy) * seeker_steer
				ex += evx * dt * speed_scale
				ey += evy * dt * speed_scale
				# The clamp below, for a seeker (never a sweep type).
				# PORT: web/src/tilt-to-live/EnemySwarm.ts:209-216
				if e.orbit_center == Vector2.ZERO and e.parent_carrier_id == Types.ABSENT:
					var spad: float = e.radius
					if ex < spad:
						ex = spad
						evx = absf(evx) * 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:212
					if ex > bounds.x - spad:
						ex = bounds.x - spad
						evx = -absf(evx) * 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:213
					if ey < spad:
						ey = spad
						evy = absf(evy) * 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:214
					if ey > bounds.y - spad:
						ey = bounds.y - spad
						evy = -absf(evy) * 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:215
				e.x = ex
				e.y = ey
				e.vx = evx
				e.vy = evy
				continue
			Types.EnemyType.ARROW_DRONE, Types.EnemyType.WALL_DOT:
				# update_arrow_drone / update_wall_dot, inlined with the sweep cull below.
				# DIVERGENCE(M11c P28): the same expressions; x/y are read once for both.
				# PORT: web/src/tilt-to-live/EnemySwarm.ts:285-288, :200-207
				var wx: float = e.x + e.vx * dt * speed_scale
				var wy: float = e.y + e.vy * dt * speed_scale
				e.x = wx
				e.y = wy
				if wx < -140.0 or wx > bounds.x + 140.0 or wy < -140.0 or wy > bounds.y + 140.0:
					enemies.remove_at(i)
				continue
			Types.EnemyType.CIRCLE_DOT:
				update_circle_dot(e, player_pos, dt)
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:162-168
			Types.EnemyType.TURRET_DOT:
				if e.orbit_center != Vector2.ZERO:
					update_rotating_gate_dot(e, dt)
				else:
					update_turret_dot(e, player_pos, dt)
			# PORT-NOTE: no spawner in EnemySwarm.ts ever creates a spike_mine; the
			# arm is ported because the dispatch has it (:169-172) — preserved
			# deliberately.
			Types.EnemyType.SPIKE_MINE:
				e.x += e.vx * dt * speed_scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:170
				e.y += e.vy * dt * speed_scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:171
			Types.EnemyType.SNAKE_SEGMENT:
				update_snake_segment(e, dt)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:173-175
			Types.EnemyType.CHARGER:
				update_charger(e, player_pos, dt, particles)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:176-178
			Types.EnemyType.ARTILLERY:
				update_artillery(e, player_pos, dt)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:179-181
			Types.EnemyType.BULLET:
				update_bullet(e, dt, bounds)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:182-183
				# PORT: web/src/tilt-to-live/EnemySwarm.ts:184-187
				# PORT-NOTE: the 140-px cull at :202 also names bullets, but this
				# 60-px cull always fires first — preserved deliberately.
				if (
					e.age > 4.5
					or e.x < -60.0
					or e.x > bounds.x + 60.0
					or e.y < -60.0
					or e.y > bounds.y + 60.0
				):
					enemies.remove_at(i)
					continue
			Types.EnemyType.CARRIER:
				update_carrier(e, player_pos, dt)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:189-191
			Types.EnemyType.PULSAR:
				update_pulsar(e, player_pos, dt, particles)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:192-194
			Types.EnemyType.SPECTER:
				update_specter(e, player_pos, dt)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:195-197

		# DIVERGENCE(M11c P17): the type is read once for both tests below (no update_*
		# changes it).
		var sweeps: bool = (
			etype == Types.EnemyType.ARROW_DRONE
			or etype == Types.EnemyType.WALL_DOT
			or etype == Types.EnemyType.BULLET
		)
		# Remove out of bounds drones that completed sweeps.
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:200-207
		if sweeps:
			# P27: x/y read once; a sweep type is never clamped, so it is done here.
			var wx: float = e.x
			var wy: float = e.y
			if wx < -140.0 or wx > bounds.x + 140.0 or wy < -140.0 or wy > bounds.y + 140.0:
				enemies.remove_at(i)
			continue

		# Clamp standard enemies inside playfield.
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:209-216
		if e.orbit_center == Vector2.ZERO and e.parent_carrier_id == Types.ABSENT:
			var pad: float = e.radius
			if e.x < pad:
				e.x = pad
				e.vx = absf(e.vx) * 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:212
			if e.x > bounds.x - pad:
				e.x = bounds.x - pad
				e.vx = -absf(e.vx) * 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:213
			if e.y < pad:
				e.y = pad
				e.vy = absf(e.vy) * 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:214
			if e.y > bounds.y - pad:
				e.y = bounds.y - pad
				e.vy = -absf(e.vy) * 0.5  # PORT: web/src/tilt-to-live/EnemySwarm.ts:215

	_sats_by_carrier_valid = false
	PerfProbe.add("s_swarm_loop", pt_loop)
	var pt_sep: int = PerfProbe.now()
	# 4. Inter-Dot Flocking Separation.
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:219-221
	apply_flocking_separation()
	PerfProbe.add("s_swarm_sep", pt_sep)


## DIVERGENCE(M11c P17): carrier id -> its satellites in array order, for this tick's
## update loop. Satellites never leave the array inside the loop (only bullets and
## sweep dots do) and parent_carrier_id changes only in on_enemy_killed.
func _build_satellite_map() -> void:
	_sats_by_carrier.clear()
	for e: Types.Enemy in enemies:
		if e.parent_carrier_id != Types.ABSENT:
			if not _sats_by_carrier.has(e.parent_carrier_id):
				var list: Array[Types.Enemy] = []
				_sats_by_carrier[e.parent_carrier_id] = list
			_sats_by_carrier[e.parent_carrier_id].append(e)
	_sats_by_carrier_valid = true


## Updates seeker velocity steering towards player position.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:223-256
func update_seeker(
	e: Types.Enemy,
	player_pos: Vector2,
	dt: float,
	current_score: int = 0,
	is_code_red: bool = false
) -> void:
	var dx: float = player_pos.x - e.x
	var dy: float = player_pos.y - e.y
	var dist: float = sqrt(dx * dx + dy * dy)

	if dist > 1.0:
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:235-237
		var score_speed_bonus: float = minf(25.0, (float(current_score) / 25000.0) * 25.0)
		var target_speed: float = (
			minf(195.0, 105.0 + _elapsed * 0.5 + score_speed_bonus) * maxf(0.72, scale)
		)

		if is_code_red:
			target_speed *= 1.35  # PORT: web/src/tilt-to-live/EnemySwarm.ts:240
		if e.chilled:
			target_speed *= 0.45  # PORT: web/src/tilt-to-live/EnemySwarm.ts:243

		var target_vx: float = (dx / dist) * target_speed
		var target_vy: float = (dy / dist) * target_speed
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:249
		var steer_strength: float = (4.5 if is_code_red else 3.2) * dt
		e.vx += (target_vx - e.vx) * steer_strength
		e.vy += (target_vy - e.vy) * steer_strength

	e.x += e.vx * dt * speed_scale
	e.y += e.vy * dt * speed_scale


## Integrates an arrow drone's straight-line sweep velocity.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:258-261
func update_arrow_drone(e: Types.Enemy, dt: float) -> void:
	e.x += e.vx * dt * speed_scale
	e.y += e.vy * dt * speed_scale


## Updates a circle dot: paused while special_timer counts down, then steers
## towards the player. PORT: web/src/tilt-to-live/EnemySwarm.ts:263-283
func update_circle_dot(e: Types.Enemy, player_pos: Vector2, dt: float) -> void:
	if not is_nan(e.special_timer) and e.special_timer > 0.0:
		e.special_timer -= dt
		e.vx = 0.0
		e.vy = 0.0
		return

	var dx: float = player_pos.x - e.x
	var dy: float = player_pos.y - e.y
	var dist: float = sqrt(dx * dx + dy * dy)

	if dist > 1.0:
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:276
		var speed: float = (75.0 + _elapsed * 0.4) * maxf(0.72, scale)
		e.vx = (dx / dist) * speed
		e.vy = (dy / dist) * speed

	e.x += e.vx * dt * speed_scale
	e.y += e.vy * dt * speed_scale


## Integrates a wall dot's straight-line sweep velocity.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:285-288
func update_wall_dot(e: Types.Enemy, dt: float) -> void:
	e.x += e.vx * dt * speed_scale
	e.y += e.vy * dt * speed_scale


## Updates a rotating gate dot: orbits its centre at a fixed radius and speed.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:290-296
func update_rotating_gate_dot(e: Types.Enemy, dt: float) -> void:
	if e.orbit_center == Vector2.ZERO or is_nan(e.orbit_radius) or is_nan(e.orbit_speed):
		return  # PORT: web/src/tilt-to-live/EnemySwarm.ts:291
	if is_nan(e.target_angle):
		e.target_angle = 0.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:292
	e.target_angle += e.orbit_speed * dt * speed_scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:293
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:294
	e.x = e.orbit_center.x + cos(e.target_angle) * e.orbit_radius
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:295
	e.y = e.orbit_center.y + sin(e.target_angle) * e.orbit_radius


## Updates a free turret dot: aims at the player, easing towards the target
## angle, and drifts on its own velocity. PORT: web/src/tilt-to-live/EnemySwarm.ts:298-309
func update_turret_dot(e: Types.Enemy, player_pos: Vector2, dt: float) -> void:
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:299
	var target_angle: float = atan2(player_pos.y - e.y, player_pos.x - e.x)
	if is_nan(e.target_angle):
		e.target_angle = target_angle  # PORT: web/src/tilt-to-live/EnemySwarm.ts:300

	var diff: float = target_angle - e.target_angle
	while diff < -PI:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:303
		diff += PI * 2.0
	while diff > PI:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:304
		diff -= PI * 2.0
	e.target_angle += diff * minf(1.0, dt * 2.5)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:305

	e.x += e.vx * dt * speed_scale
	e.y += e.vy * dt * speed_scale


## Updates a snake segment: leaderless segments drift and occasionally re-aim;
## followers close the gap on their leader. PORT: web/src/tilt-to-live/EnemySwarm.ts:311-335
func update_snake_segment(e: Types.Enemy, dt: float) -> void:
	if e.leader_id == Types.ABSENT:
		e.x += e.vx * dt * speed_scale
		e.y += e.vy * dt * speed_scale
		if randf() < 0.05:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:315
			var speed: float = 120.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:316
			var angle: float = randf() * PI * 2.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:317
			e.vx = cos(angle) * speed
			e.vy = sin(angle) * speed
	else:
		# PORT-NOTE: nothing in EnemySwarm.ts assigns leaderId, so every segment
		# is a leader and this branch is unreachable; it also moves without dt
		# — preserved deliberately.
		var leader: Types.Enemy = null
		for other: Types.Enemy in enemies:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:322
			if other.id == e.leader_id:
				leader = other
				break
		if leader != null:
			var dx: float = leader.x - e.x
			var dy: float = leader.y - e.y
			var dist: float = sqrt(dx * dx + dy * dy)
			var target_dist: float = 18.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:327
			if dist > target_dist:
				var factor: float = (dist - target_dist) / dist  # PORT: web/src/tilt-to-live/EnemySwarm.ts:329
				e.x += dx * factor * 0.4  # PORT: web/src/tilt-to-live/EnemySwarm.ts:330
				e.y += dy * factor * 0.4  # PORT: web/src/tilt-to-live/EnemySwarm.ts:331


## Updates a charger through its aim, charge and cool cycle.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:337-391
func update_charger(
	e: Types.Enemy, player_pos: Vector2, dt: float, particles: ParticleEngine
) -> void:
	# PORT-NOTE: spawn_charger always sets both (:601-603), so these defaults
	# are dead for spawned chargers — preserved deliberately.
	if e.state == Types.ABSENT:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:338
		e.state = Types.EnemyState.AIMING
	if is_nan(e.aim_timer):  # PORT: web/src/tilt-to-live/EnemySwarm.ts:339
		e.aim_timer = 1.1

	if e.state == Types.EnemyState.AIMING:
		var dx: float = player_pos.x - e.x
		var dy: float = player_pos.y - e.y
		e.aim_angle = atan2(dy, dx)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:344

		var creep_speed: float = 35.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:347
		e.vx = cos(e.aim_angle) * creep_speed
		e.vy = sin(e.aim_angle) * creep_speed
		e.x += e.vx * dt * speed_scale
		e.y += e.vy * dt * speed_scale

		e.aim_timer -= dt
		if e.aim_timer <= 0.0:
			e.state = Types.EnemyState.CHARGING
			e.special_timer = 0.75  # PORT: web/src/tilt-to-live/EnemySwarm.ts:356
			var charge_speed: float = 480.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:357
			e.vx = cos(e.aim_angle) * charge_speed
			e.vy = sin(e.aim_angle) * charge_speed
	elif e.state == Types.EnemyState.CHARGING:
		e.x += e.vx * dt * speed_scale
		e.y += e.vy * dt * speed_scale

		if randf() < 0.6:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:365
			# PORT-NOTE: `||` treats undefined, NaN and 0 alike, all giving 0
			# (EnemySwarm.ts:366) — preserved deliberately.
			var back_angle: float = (0.0 if is_nan(e.aim_angle) else e.aim_angle) + PI
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:367
			particles.emit_thruster_sparks(e.x, e.y, back_angle, Color("#ff5500"))

		if not is_nan(e.special_timer):  # PORT: web/src/tilt-to-live/EnemySwarm.ts:370
			e.special_timer -= dt
			if e.special_timer <= 0.0:
				e.state = Types.EnemyState.COOLING
				e.special_timer = 0.9  # PORT: web/src/tilt-to-live/EnemySwarm.ts:374
	elif e.state == Types.EnemyState.COOLING:
		e.vx *= pow(0.08, dt)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:378
		e.vy *= pow(0.08, dt)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:379
		e.x += e.vx * dt * speed_scale
		e.y += e.vy * dt * speed_scale

		if not is_nan(e.special_timer):  # PORT: web/src/tilt-to-live/EnemySwarm.ts:383
			e.special_timer -= dt
			if e.special_timer <= 0.0:
				e.state = Types.EnemyState.AIMING
				e.aim_timer = 1.1  # PORT: web/src/tilt-to-live/EnemySwarm.ts:387


## Updates artillery: holds a distance band from the player, strafes, and
## fires timed bullets. PORT: web/src/tilt-to-live/EnemySwarm.ts:393-436
func update_artillery(e: Types.Enemy, player_pos: Vector2, dt: float) -> void:
	# PORT-NOTE: three different cooldowns — 2.2 at spawn (:695), 2.6 here,
	# 2.8 on reload (:426) — preserved deliberately.
	if is_nan(e.fire_cooldown):  # PORT: web/src/tilt-to-live/EnemySwarm.ts:394
		e.fire_cooldown = 2.6 + randf() * 0.8  # PORT: web/src/tilt-to-live/EnemySwarm.ts:394

	var dx: float = player_pos.x - e.x
	var dy: float = player_pos.y - e.y
	var dist: float = sqrt(dx * dx + dy * dy)
	e.aim_angle = atan2(dy, dx)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:399

	var move_vx: float = 0.0
	var move_vy: float = 0.0
	if dist > 1.0:
		var nx: float = dx / dist
		var ny: float = dy / dist
		if dist < 220.0:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:406
			move_vx -= nx * 65.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:407
			move_vy -= ny * 65.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:408
		elif dist > 320.0:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:409
			move_vx += nx * 60.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:410
			move_vy += ny * 60.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:411
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:413
		var strafe_dir: float = 1.0 if e.id % 2 == 0 else -1.0
		move_vx += -ny * strafe_dir * 40.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:414
		move_vy += nx * strafe_dir * 40.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:415

	var steer: float = 3.0 * dt  # PORT: web/src/tilt-to-live/EnemySwarm.ts:418
	e.vx += (move_vx - e.vx) * steer
	e.vy += (move_vy - e.vy) * steer
	e.x += e.vx * dt * speed_scale
	e.y += e.vy * dt * speed_scale

	e.fire_cooldown -= dt
	if e.fire_cooldown <= 0.0:
		e.fire_cooldown = 2.8 + randf() * 0.8  # PORT: web/src/tilt-to-live/EnemySwarm.ts:426
		var barrel_len: float = 22.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:427
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:428
		var fire_x: float = e.x + cos(e.aim_angle) * barrel_len
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:429
		var fire_y: float = e.y + sin(e.aim_angle) * barrel_len
		spawn_bullet(fire_x, fire_y, player_pos)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:430

		e.vx -= cos(e.aim_angle) * 90.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:433
		e.vy -= sin(e.aim_angle) * 90.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:434


## Integrates a bullet's straight-line flight. The bounds argument is unused
## in the TypeScript and kept only to match its signature.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:438-441
func update_bullet(e: Types.Enemy, dt: float, _bounds: Vector2) -> void:
	e.x += e.vx * dt * speed_scale
	e.y += e.vy * dt * speed_scale


## Updates a carrier: steers gently towards the player and carries its
## orbiting satellites along with it. PORT: web/src/tilt-to-live/EnemySwarm.ts:443-471
func update_carrier(e: Types.Enemy, player_pos: Vector2, dt: float) -> void:
	var dx: float = player_pos.x - e.x
	var dy: float = player_pos.y - e.y
	var dist: float = sqrt(dx * dx + dy * dy)

	if dist > 1.0:
		var target_speed: float = 55.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:449
		var target_vx: float = (dx / dist) * target_speed
		var target_vy: float = (dy / dist) * target_speed
		e.vx += (target_vx - e.vx) * 1.5 * dt  # PORT: web/src/tilt-to-live/EnemySwarm.ts:452
		e.vy += (target_vy - e.vy) * 1.5 * dt  # PORT: web/src/tilt-to-live/EnemySwarm.ts:453

	e.x += e.vx * dt * speed_scale
	e.y += e.vy * dt * speed_scale

	# PORT-NOTE: update() iterates in reverse (:135), so a satellite runs
	# update_seeker first and is then overwritten here by its carrier, which
	# always has the lower index — preserved deliberately.
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:459-470
	# DIVERGENCE(M11c P17): inside update() the satellites come from the per-tick map
	# (same enemies, same ascending order; each position depends only on its own
	# carrier), not from a scan of every enemy per carrier.
	var sats: Array[Types.Enemy] = enemies
	if _sats_by_carrier_valid:
		sats = _sats_by_carrier.get(e.id, _NO_SATELLITES)
	for sat: Types.Enemy in sats:
		if sat.parent_carrier_id == e.id:
			if is_nan(sat.orbit_angle):
				sat.orbit_angle = 0.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:462
			if is_nan(sat.orbit_radius):
				sat.orbit_radius = 38.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:463
			sat.orbit_angle += 2.0 * dt * speed_scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:464
			sat.x = e.x + cos(sat.orbit_angle) * sat.orbit_radius
			sat.y = e.y + sin(sat.orbit_angle) * sat.orbit_radius
			sat.vx = 0.0
			sat.vy = 0.0


## Updates a pulsar: steers towards the player and pulses sparks on a
## periodic timer. PORT: web/src/tilt-to-live/EnemySwarm.ts:473-492
func update_pulsar(
	e: Types.Enemy, player_pos: Vector2, dt: float, particles: ParticleEngine
) -> void:
	var dx: float = player_pos.x - e.x
	var dy: float = player_pos.y - e.y
	var dist: float = sqrt(dx * dx + dy * dy)

	if dist > 1.0:
		var speed: float = 72.0 * maxf(0.72, scale)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:479
		e.vx += ((dx / dist) * speed - e.vx) * 2.2 * dt  # PORT: web/src/tilt-to-live/EnemySwarm.ts:480
		e.vy += ((dy / dist) * speed - e.vy) * 2.2 * dt  # PORT: web/src/tilt-to-live/EnemySwarm.ts:481

	e.x += e.vx * dt * speed_scale
	e.y += e.vy * dt * speed_scale

	if is_nan(e.pulse_timer):
		e.pulse_timer = 2.2  # PORT: web/src/tilt-to-live/EnemySwarm.ts:486
	e.pulse_timer -= dt
	if e.pulse_timer <= 0.0:
		e.pulse_timer = 2.2  # PORT: web/src/tilt-to-live/EnemySwarm.ts:489
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:490
		particles.emit_sparks(e.x, e.y, 14, Color("#ff4757"), 140.0)


## Updates a specter: steers towards the player and phases its visibility
## with age. PORT: web/src/tilt-to-live/EnemySwarm.ts:494-508
func update_specter(e: Types.Enemy, player_pos: Vector2, dt: float) -> void:
	var dx: float = player_pos.x - e.x
	var dy: float = player_pos.y - e.y
	var dist: float = sqrt(dx * dx + dy * dy)

	if dist > 1.0:
		var speed: float = 145.0 * maxf(0.72, scale)  # PORT: web/src/tilt-to-live/EnemySwarm.ts:500
		e.vx += ((dx / dist) * speed - e.vx) * 3.8 * dt  # PORT: web/src/tilt-to-live/EnemySwarm.ts:501
		e.vy += ((dy / dist) * speed - e.vy) * 3.8 * dt  # PORT: web/src/tilt-to-live/EnemySwarm.ts:502

	e.x += e.vx * dt * speed_scale
	e.y += e.vy * dt * speed_scale

	# PORT: web/src/tilt-to-live/EnemySwarm.ts:507
	e.stealth_opacity = 0.25 + 0.75 * pow(sin(e.age * 3.2), 2.0)


## Indices of the enemies separation may move, in array order.
## DIVERGENCE(M11c P4): the eligibility test runs once per enemy per tick instead of
## once per pair; the i<j visiting order and the arithmetic are unchanged.
func separation_candidates() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in range(enemies.size()):
		var e: Types.Enemy = enemies[i]
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:517, :521
		if (
			e.frozen
			or e.type == Types.EnemyType.WALL_DOT
			or e.type == Types.EnemyType.BULLET
			or e.orbit_center != Vector2.ZERO
			or e.parent_carrier_id != Types.ABSENT
		):
			continue
		out.append(i)
	return out


## Applies pairwise repulsive separation force to prevent clustering.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:510-540
# PORT-NOTE: the pair loop runs over separation_candidates() (M11c P4), on packed
# 64-bit copies of x/y written back at the end. The loop writes only x/y, so
# eligibility cannot change mid-loop; GDScript floats are 64-bit, so the copies are
# exact; a pair with dx*dx >= min_distance2 can never pass dist2 < min_distance2, so
# rejecting it early changes nothing. The result is identical to the TS pair loop.
func apply_flocking_separation() -> void:
	var min_distance: float = 16.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:511
	var min_distance2: float = min_distance * min_distance
	var idx: PackedInt32Array = separation_candidates()
	var n: int = idx.size()
	var xs: PackedFloat64Array = PackedFloat64Array()
	var ys: PackedFloat64Array = PackedFloat64Array()
	xs.resize(n)
	ys.resize(n)
	for k: int in range(n):
		xs[k] = enemies[idx[k]].x
		ys[k] = enemies[idx[k]].y

	if n >= SWEEP_MIN_CANDIDATES:
		var native: Object = _native_separator()
		if native != null:
			# DIVERGENCE(M11c N2): the same sweep in C++ (native/src/peril_native.cpp),
			# bit-identical (the oracles run both paths); it returns xs then ys.
			var r: PackedFloat64Array = native.call("separate", xs, ys, min_distance)
			for k: int in range(n):
				var m: Types.Enemy = enemies[idx[k]]
				m.x = r[k]
				m.y = r[n + k]
			return
		_separate_sweep(xs, ys, min_distance, min_distance2)
	else:
		for ii: int in range(n):
			_separate_round(xs, ys, ii, ii + 1, n, min_distance, min_distance2)

	for k: int in range(n):
		enemies[idx[k]].x = xs[k]
		enemies[idx[k]].y = ys[k]


## The native separator, or null when the extension is missing or use_native is off.
## Made through ClassDB so this script still compiles without the library.
static func _native_separator() -> Object:
	if not use_native:
		return null
	if _native == null and ClassDB.class_exists("PerilNative"):
		_native = ClassDB.instantiate("PerilNative")
	return _native


## One round of the pair loop: ii against every jj in [from, to), in order.
func _separate_round(
	xs: PackedFloat64Array,
	ys: PackedFloat64Array,
	ii: int,
	from: int,
	to: int,
	min_distance: float,
	min_distance2: float
) -> void:
	for jj: int in range(from, to):
		# The dx reject inline (as _separate_pair's first test) keeps the scan call-free.
		var dx: float = xs[jj] - xs[ii]
		if dx * dx >= min_distance2:
			continue
		_separate_pair(xs, ys, ii, jj, min_distance, min_distance2)


## One pair of the loop. True when it pushed.
func _separate_pair(
	xs: PackedFloat64Array,
	ys: PackedFloat64Array,
	ii: int,
	jj: int,
	min_distance: float,
	min_distance2: float
) -> bool:
	var dx: float = xs[jj] - xs[ii]
	if dx * dx >= min_distance2:
		return false
	var dy: float = ys[jj] - ys[ii]
	var dist2: float = dx * dx + dy * dy

	# PORT: web/src/tilt-to-live/EnemySwarm.ts:527-537
	if dist2 < min_distance2 and dist2 > 0.0001:
		var dist: float = sqrt(dist2)
		var push: float = (min_distance - dist) * 0.15  # PORT: web/src/tilt-to-live/EnemySwarm.ts:529
		var px: float = (dx / dist) * push
		var py: float = (dy / dist) * push
		xs[ii] -= px
		ys[ii] -= py
		xs[jj] += px
		ys[jj] += py
		return true
	return false


## DIVERGENCE(M11c P15): the pair loop visiting only the jj that can reach ii.
## Pairs are still visited ii ascending, then jj ascending; a skipped pair is one
## whose |dx| >= min_distance at its visit, which the loop above would also skip
## (a no-op), so the result is bit-identical (oracle: test_enemy_swarm_separation).
## Each round's window over an x-sorted index is padded by `drift` (how far any x
## has moved since the index was built) and SWEEP_SLACK (how far xs[ii] may move
## during its own round); if xs[ii] moves further, the round finishes with the
## plain scan from where it is.
## DIVERGENCE(M11c P26): the window also drops every k with |ys[k] - y0| >= min_distance
## + SWEEP_SLACK (+ 1/SWEEP_QUANT for rounding). A k > ii moves in round ii only at its
## own visit, so ys[k] then equals ys[k] at the window build; ys[ii] stays within
## SWEEP_SLACK of y0 (else the plain-scan fallback runs), so a dropped k has |dy| >=
## min_distance at its visit and the loop above would not push it either.
func _separate_sweep(
	xs: PackedFloat64Array, ys: PackedFloat64Array, min_distance: float, min_distance2: float
) -> void:
	var n: int = xs.size()
	var built_x: PackedFloat64Array = xs.duplicate()
	var order: PackedInt32Array = PackedInt32Array()
	var sorted_q: PackedFloat64Array = PackedFloat64Array()
	_sweep_index(xs, order, sorted_q)
	var drift: float = 0.0
	var window: PackedInt32Array = PackedInt32Array()
	var reach_y: float = min_distance + SWEEP_SLACK + 1.0 / SWEEP_QUANT
	for ii: int in range(n):
		var x0: float = xs[ii]
		var y0: float = ys[ii]
		var reach: float = min_distance + drift + SWEEP_SLACK + 1.0 / SWEEP_QUANT
		var lo: int = sorted_q.bsearch(x0 - reach, true)
		var hi: int = sorted_q.bsearch(x0 + reach, false)
		window.clear()
		for t: int in range(lo, hi):
			var k: int = order[t]
			if k > ii and absf(ys[k] - y0) < reach_y:
				window.append(k)
		var size: int = window.size()
		if size > 1:
			window.sort()
		for w: int in range(size):
			var jj: int = window[w]
			# _separate_pair, inlined (a call per pair costs as much as the pair).
			var dx: float = xs[jj] - xs[ii]
			if dx * dx >= min_distance2:
				continue
			var dy: float = ys[jj] - ys[ii]
			var dist2: float = dx * dx + dy * dy
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:527-537
			if dist2 < min_distance2 and dist2 > 0.0001:
				var dist: float = sqrt(dist2)
				var push: float = (min_distance - dist) * 0.15  # PORT: web/src/tilt-to-live/EnemySwarm.ts:529
				var px: float = (dx / dist) * push
				var py: float = (dy / dist) * push
				xs[ii] -= px
				ys[ii] -= py
				xs[jj] += px
				ys[jj] += py
				drift = maxf(drift, absf(xs[jj] - built_x[jj]))
				if absf(xs[ii] - x0) >= SWEEP_SLACK or absf(ys[ii] - y0) >= SWEEP_SLACK:
					# The window no longer covers ii: scan every later jj in order,
					# still tracking how far each pushed jj drifts.
					for later: int in range(jj + 1, n):
						var ldx: float = xs[later] - xs[ii]
						if ldx * ldx >= min_distance2:
							continue
						if _separate_pair(xs, ys, ii, later, min_distance, min_distance2):
							drift = maxf(drift, absf(xs[later] - built_x[later]))
					break
		if drift >= SWEEP_REBUILD:
			built_x = xs.duplicate()
			_sweep_index(xs, order, sorted_q)
			drift = 0.0


## Fills order with 0..n-1 sorted by x (quantised to 1/SWEEP_QUANT px, rounded
## down) and sorted_q with those quantised x values, ascending.
func _sweep_index(
	xs: PackedFloat64Array, order: PackedInt32Array, sorted_q: PackedFloat64Array
) -> void:
	var n: int = xs.size()
	var keys: PackedInt64Array = PackedInt64Array()
	keys.resize(n)
	for k: int in range(n):
		var q: int = floori((xs[k] + SWEEP_OFFSET) * SWEEP_QUANT)
		keys[k] = (q << SWEEP_INDEX_BITS) | k
	keys.sort()
	order.resize(n)
	sorted_q.resize(n)
	for t: int in range(n):
		order[t] = keys[t] & SWEEP_INDEX_MASK
		sorted_q[t] = float(keys[t] >> SWEEP_INDEX_BITS) / SWEEP_QUANT - SWEEP_OFFSET


## Handles enemy-death reactions (child satellite flinging, pulsar split).
# PORT-NOTE: never removes enemy itself — TiltGame.ts:1984 calls this and
# TiltGame.ts:2021 splices the dead enemy out — preserved deliberately.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:1141-1182
func on_enemy_killed(enemy: Types.Enemy, particles: ParticleEngine = null) -> void:
	if enemy.type == Types.EnemyType.CARRIER:
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:1143-1155
		for e: Types.Enemy in enemies:
			if e.parent_carrier_id == enemy.id:
				e.parent_carrier_id = Types.ABSENT  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1146
				var scatter_angle: float = randf() * PI * 2.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1147
				var speed: float = 160.0 + randf() * 80.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1148
				e.vx = cos(scatter_angle) * speed
				e.vy = sin(scatter_angle) * speed
				if particles != null:
					# PORT: web/src/tilt-to-live/EnemySwarm.ts:1152
					particles.emit_sparks(e.x, e.y, 8, Color("#00e5ff"), 200.0)
		if particles != null:
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:1157
			particles.emit_explosion(enemy.x, enemy.y, Color("#ff1155"), 40)
	elif enemy.type == Types.EnemyType.PULSAR:
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:1160-1177
		for i: int in range(2):
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:1162
			var angle: float = float(i) * PI + (randf() * 0.8 - 0.4)
			var speed: float = 135.0 + randf() * 45.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1163

			var mini_seeker: Types.Enemy = Types.Enemy.new()
			mini_seeker.id = _next_enemy_id
			_next_enemy_id += 1
			mini_seeker.type = Types.EnemyType.SEEKER
			mini_seeker.x = enemy.x + cos(angle) * 10.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1167
			mini_seeker.y = enemy.y + sin(angle) * 10.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1168
			mini_seeker.vx = cos(angle) * speed
			mini_seeker.vy = sin(angle) * speed
			mini_seeker.radius = 6.5 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:1171
			mini_seeker.frozen = false
			mini_seeker.freeze_timer = 0.0
			mini_seeker.age = 0.0
			mini_seeker.health = 1.0
			enemies.append(mini_seeker)
		if particles != null:
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:1179
			particles.emit_explosion(enemy.x, enemy.y, Color("#ff4757"), 24)


## Freezes every active enemy for a duration.
# PORT-NOTE: no TypeScript caller exists (WeaponSystem.ts:541-544 freezes
# inline); ported because spec §8 M3 names it. M4 ruled (plan Open question 2)
# that the freeze weapon freezes inline as the TS does — WeaponSystem.update()
# receives the enemies array, not the swarm — so this stays callerless.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:1184-1189
# PORT: web/src/tilt-to-live/EnemySwarm.ts:1184
func freeze_all(duration: float = 7.0) -> void:
	for e: Types.Enemy in enemies:
		e.frozen = true
		e.freeze_timer = duration
