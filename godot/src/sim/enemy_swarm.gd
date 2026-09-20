## enemy_swarm.gd
## PORTS: web/src/tilt-to-live/EnemySwarm.ts (1650 lines, source commit 7be9614)
class_name EnemySwarm
extends RefCounted
## Red dot swarm intelligence, seeker movement, flocking separation and wave director.
##
## PORT-NOTE: partial port for Module 2 per spec §8 M2. Implements seeker tracking,
## flocking separation, continuous seeker director pacing, and bounds bouncing.
## Remaining 12 enemy types and 8 formations land in Module 3.
##
## PORT-NOTE: EnemySwarm.render() relocates to render/entity_layer.gd (spec §4.2/D4)
## because CanvasItem 2D drawing belongs to Node2D render layers.

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
			_:
				# TODO(M3): update behaviours for remaining 12 enemy types.
				pass

		# Clamp standard enemies inside playfield.
		# PORT: web/src/tilt-to-live/EnemySwarm.ts:209-216
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


## Applies pairwise repulsive separation force to prevent clustering.
## PORT: web/src/tilt-to-live/EnemySwarm.ts:510-540
func apply_flocking_separation() -> void:
	var min_distance: float = 16.0  # PORT: web/src/tilt-to-live/EnemySwarm.ts:511
	var min_distance2: float = min_distance * min_distance
	var count: int = enemies.size()

	for i: int in range(count):
		var a: Types.Enemy = enemies[i]
		if a.frozen:
			continue
		for j: int in range(i + 1, count):
			var b: Types.Enemy = enemies[j]
			if b.frozen:
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
