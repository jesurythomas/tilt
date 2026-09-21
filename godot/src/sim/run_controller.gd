## run_controller.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1855-2083, per spec §5.4
class_name RunController
extends RefCounted
## In-run coordinator executing frame order steps 1-11, collision detection,
## scoring integration, life loss, and player death.

var player: PlayerShip = null
var swarm: EnemySwarm = null
var weapons: WeaponSystem = null
var particles: ParticleEngine = null
var grid: VectorGrid = null
var scores: ScoreManager = null
var audio: AudioBank = null

var lives: int = 1
var max_lives: int = 1
var elapsed: float = 0.0
var is_run_active: bool = false
var bounds: Vector2 = Vector2.ZERO

## Perk ranks passed into the weapon system every tick.
## PORT: web/src/tilt-to-live/TiltGame.ts:1926 (this.progression.data.perks)
# TODO(M7): assign progression.data.perks here once ProgressionManager loads
# the save; until then every rank is 0 and every keystone false.
var perks: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()


func _init(
	p_player: PlayerShip,
	p_swarm: EnemySwarm,
	p_weapons: WeaponSystem,
	p_particles: ParticleEngine,
	p_grid: VectorGrid,
	p_scores: ScoreManager,
	p_audio: AudioBank
) -> void:
	player = p_player
	swarm = p_swarm
	weapons = p_weapons
	particles = p_particles
	grid = p_grid
	scores = p_scores
	audio = p_audio
	# PORT: web/src/tilt-to-live/TiltGame.ts:212-218
	weapons.on_weapon_activated = _on_weapon_activated


## Resets all simulation state for a new run.
## PORT: web/src/tilt-to-live/TiltGame.ts:1785-1815
func reset_run(arena_bounds: Vector2) -> void:
	bounds = arena_bounds
	elapsed = 0.0
	lives = max_lives
	is_run_active = true

	player.reset(bounds.x * 0.5, bounds.y * 0.5)
	# The shield.radius perk's only consumer is the bubble the ship draws.
	# PORT: web/src/tilt-to-live/TiltGame.ts:1572-1574
	player.set_shield_radius(Tuning.get_tuned_value("shield", "radius", perks.shield.radius))
	swarm.reset()
	weapons.reset()
	particles.reset()
	scores.reset()
	grid.resize(bounds.x, bounds.y)

	spawn_starting_weapon_orb(bounds)
	GameEvents.score_changed.emit(0, 1, scores.stats.best_score)


## Spawns the initial weapon orb offset from the player spawn point.
## PORT: web/src/tilt-to-live/TiltGame.ts:1964-1979
func spawn_starting_weapon_orb(arena_bounds: Vector2) -> void:
	var angle: float = randf() * TAU
	var dist: float = minf(arena_bounds.x, arena_bounds.y) * 0.28
	var margin: float = 60.0
	var x: float = clampf(arena_bounds.x * 0.5 + cos(angle) * dist, margin, arena_bounds.x - margin)
	var y: float = clampf(arena_bounds.y * 0.5 + sin(angle) * dist, margin, arena_bounds.y - margin)
	weapons.spawn_orb(arena_bounds, Types.WeaponType.NUKE, x, y)


## Executes fixed frame order simulation steps (spec §5.4).
## PORT: web/src/tilt-to-live/TiltGame.ts:1855-1958
func update(
	dt: float,
	effective_mode: Types.ControlMode,
	mouse_pos: Vector2,
	move_vector: Vector2,
	tilt_vector: Vector2
) -> void:
	if not is_run_active or player.is_dead:
		return

	elapsed += dt

	# 1. Update Grid
	grid.update(dt)

	# 2. Update Particles
	particles.update(dt)

	# 3. Update Player Ship
	player.update(
		dt,
		mouse_pos,
		bounds,
		particles,
		effective_mode,
		move_vector,
		1.0,
		4.0,
		1.0,
		1.0,
		Color("#00ddff"),
		tilt_vector
	)

	# 4. Update Swarm Enemies
	swarm.update(dt, Vector2(player.x, player.y), bounds, particles, scores.stats.score)

	# 5. Update Weapons
	weapons.update(
		dt,
		player,
		swarm.enemies,
		bounds,
		particles,
		grid,
		audio,
		Callable(self, "handle_enemy_killed"),
		perks
	)

	# 6. Update Scores and Combos
	scores.update(dt)

	# 7. Check Collisions & Near-Misses
	check_collisions()

	# 8. Emit HUD signal
	GameEvents.score_changed.emit(
		scores.stats.score, scores.stats.multiplier, scores.stats.best_score
	)


## Collision detection between player ship and enemy swarm.
## PORT: web/src/tilt-to-live/TiltGame.ts:2006-2043
func check_collisions() -> void:
	if player.is_dead:
		return

	for i: int in range(swarm.enemies.size() - 1, -1, -1):
		var e: Types.Enemy = swarm.enemies[i]
		var dx: float = player.x - e.x
		var dy: float = player.y - e.y
		var dist: float = sqrt(dx * dx + dy * dy)

		# Direct Touch / Collision
		if dist < player.radius + e.radius:
			if player.has_shield():
				# Shield rams and kills red dot
				handle_enemy_killed(e, Types.WeaponType.SHIELD)
				particles.emit_explosion(e.x, e.y, Color("#3ddc97"), 20)
				swarm.enemies.remove_at(i)
				continue
			elif e.frozen:
				# Ramming frozen dot shatters it
				audio.play_ice_shatter()
				scores.register_kill(e.x, e.y, Types.WeaponType.FREEZE, audio)
				particles.emit_ice_shatter(e.x, e.y, 16)
				swarm.enemies.remove_at(i)
				continue
			else:
				# Crash costs a life
				lose_life()
				return

		# Close Call / Near-Miss Detection
		if dist < player.radius + e.radius + 16.0 and player.close_call_timer <= 0.0:
			player.close_call_timer = 0.75
			scores.register_close_call(player.x, player.y, audio)


## Handles enemy destruction by weapons or shield.
## PORT: web/src/tilt-to-live/TiltGame.ts:1981-2004
# TODO(M9): runTracker weapon-kill counters (TiltGame.ts:1986-2003)
func handle_enemy_killed(enemy: Types.Enemy, weapon_type: Types.WeaponType) -> void:
	scores.register_kill(enemy.x, enemy.y, weapon_type, audio)
	grid.apply_explosion(enemy.x, enemy.y, 4.5, 60.0)
	swarm.on_enemy_killed(enemy, particles)
	GameEvents.enemy_killed.emit(enemy, weapon_type)


## Decrements lives or triggers player death.
## PORT: web/src/tilt-to-live/TiltGame.ts:2050-2069
func lose_life() -> void:
	if player.is_dead:
		return
	if player.has_shield():
		return

	lives -= 1
	GameEvents.life_lost.emit(lives)

	if lives > 0:
		player.activate_shield(3.0)
		audio.play_siren()
		particles.emit_explosion(player.x, player.y, Color("#5b8cff"), 30)
		grid.apply_explosion(player.x, player.y, 14.0, 220.0)
	else:
		trigger_player_death()


## Handles fatal player collision, stopping run and showing game over.
## PORT: web/src/tilt-to-live/TiltGame.ts:2071-2083
func trigger_player_death() -> void:
	player.is_dead = true
	is_run_active = false
	audio.play_player_death()
	audio.stop_music()

	particles.emit_explosion(player.x, player.y, Color.WHITE, 50)
	particles.emit_explosion(player.x, player.y, Color("#5b8cff"), 30)
	grid.apply_explosion(player.x, player.y, 22.0, 380.0)

	scores.finalize_game()
	GameEvents.run_ended.emit(scores.stats.score, scores.stats)
	GameEvents.phase_changed.emit(Types.GamePhase.GAME_OVER)


## Relays a weapon pickup to the UI bus. PORT: web/src/tilt-to-live/TiltGame.ts:212-218
# PORT-NOTE: the TS callback only bumps runTracker.nukesDetonated and
# runTracker.missilesFired (+16 per pickup, TiltGame.ts:216 — a fixed 16, not
# the launched count; preserved for M9). The HUD/goal side is the
# weapon_activated signal per spec §5.3.
# TODO(M9): runTracker counters (nukesDetonated, missilesFired += 16).
func _on_weapon_activated(type: Types.WeaponType) -> void:
	GameEvents.weapon_activated.emit(type)
