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
##
## PORT-NOTE: partial port for Module 2 per spec §8 M2. Implements seeker tracking,
## flocking separation, continuous seeker director pacing, and bounds bouncing.
## Remaining 12 enemy types and 8 formations land in Module 3.

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
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:890
	var count: int = 16 if is_tight else mini(16, 12 + current_score / 10000)
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
	var spacing: float = 22.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:918

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
			if absi(i - gap_index) <= 2:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:928
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
			enemy.radius = 8.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:936
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
			if absi(i - gap_index) <= 2:  # PORT: web/src/tilt-to-live/EnemySwarm.ts:951
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
			enemy.radius = 8.0 * scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:959
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
	_particles: ParticleEngine,
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
			# In M2, all spawns are seekers until M3 adds elite types.
			spawn_seeker(bounds)
			spawn_seeker(bounds)
		else:
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:83-84
			var base_interval: float = maxf(0.42, 1.35 - time_reduction - score_reduction)
			_spawn_timer = base_interval + randf() * 0.15
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:98
			var spawn_count: int = 2 if (current_score >= 12000 and randf() < 0.25) else 1
			for s: int in range(spawn_count):
				spawn_seeker(bounds)

	# 2. Coordinated Formation Waves. PORT: web/src/tilt-to-live/EnemySwarm.ts:106-132
	if _wave_timer <= 0.0:
		# TODO(M3): spawn wall, arrow, circle and gauntlet formations.
		_wave_timer = 6.0 + randf() * 2.0

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

		match e.type:
			Types.EnemyType.SEEKER:
				update_seeker(e, player_pos, dt, current_score, is_code_red)
			Types.EnemyType.ARROW_DRONE:
				update_arrow_drone(e, dt)
			Types.EnemyType.CIRCLE_DOT:
				update_circle_dot(e, player_pos, dt)
			Types.EnemyType.WALL_DOT:
				update_wall_dot(e, dt)
			# PORT-NOTE: no spawner in EnemySwarm.ts ever creates a spike_mine; the
			# arm is ported because the dispatch has it (:169-172) — preserved
			# deliberately.
			Types.EnemyType.SPIKE_MINE:
				e.x += e.vx * dt * speed_scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:170
				e.y += e.vy * dt * speed_scale  # PORT: web/src/tilt-to-live/EnemySwarm.ts:171
			_:
				# TODO(M3): update behaviours for remaining 12 enemy types.
				pass

		# Remove out of bounds drones that completed sweeps.
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:200-207
		if (
			(
				e.type == Types.EnemyType.ARROW_DRONE
				or e.type == Types.EnemyType.WALL_DOT
				or e.type == Types.EnemyType.BULLET
			)
			and (e.x < -140.0 or e.x > bounds.x + 140.0 or e.y < -140.0 or e.y > bounds.y + 140.0)
		):
			enemies.remove_at(i)
			continue

		# Clamp standard enemies inside playfield.
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:209-216
		if (
			e.type != Types.EnemyType.ARROW_DRONE
			and e.type != Types.EnemyType.WALL_DOT
			and e.type != Types.EnemyType.BULLET
			and e.orbit_center == Vector2.ZERO
			and e.parent_carrier_id == Types.ABSENT
		):
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

	# 4. Inter-Dot Flocking Separation.
	# PORT: web/src/tilt-to-live/EnemySwarm.ts:219-221
	apply_flocking_separation()


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


## Applies pairwise repulsive separation force to prevent clustering.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:510-540
func apply_flocking_separation() -> void:
	var min_distance: float = 16.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:511
	var min_distance2: float = min_distance * min_distance
	var count: int = enemies.size()

	for i: int in range(count):
		var a: Types.Enemy = enemies[i]
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:517
		if (
			a.frozen
			or a.type == Types.EnemyType.WALL_DOT
			or a.type == Types.EnemyType.BULLET
			or a.orbit_center != Vector2.ZERO
			or a.parent_carrier_id != Types.ABSENT
		):
			continue
		for j: int in range(i + 1, count):
			var b: Types.Enemy = enemies[j]
			# PORT: web/src/tilt-to-live/EnemySwarm.ts:521
			if (
				b.frozen
				or b.type == Types.EnemyType.WALL_DOT
				or b.type == Types.EnemyType.BULLET
				or b.orbit_center != Vector2.ZERO
				or b.parent_carrier_id != Types.ABSENT
			):
				continue
			var dx: float = b.x - a.x
			var dy: float = b.y - a.y
			var dist2: float = dx * dx + dy * dy

			# PORT: web/src/tilt-to-live/EnemySwarm.ts:527-537
			if dist2 < min_distance2 and dist2 > 0.0001:
				var dist: float = sqrt(dist2)
				var push: float = (min_distance - dist) * 0.15  # PORT: web/src/tilt-to-live/EnemySwarm.ts:529
				var px: float = (dx / dist) * push
				var py: float = (dy / dist) * push
				a.x -= px
				a.y -= py
				b.x += px
				b.y += py


## Handles enemy-death reactions (child satellite flinging, pulsar split).
## PORT: web/src/tilt-to-live/EnemySwarm.ts:1141-1189
func on_enemy_killed(_enemy: Types.Enemy, _particles: ParticleEngine = null) -> void:
	# TODO(M3): carrier satellite release, pulsar mini-seeker splitting.
	pass
