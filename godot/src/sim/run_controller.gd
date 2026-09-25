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

## The player's save. PORT: web/src/tilt-to-live/TiltGame.ts:55 (this.progression)
var progression: ProgressionManager = null
## Mode and settings. PORT: web/src/tilt-to-live/TiltGame.ts:65 (this.options)
var options: GameOptionsManager = null
## Coin pickups. PORT: web/src/tilt-to-live/TiltGame.ts:51
var coins: CoinSystem = null

## Descending walls. PORT: web/src/tilt-to-live/TiltGame.ts:62 (this.gauntletMaze)
# PORT-NOTE: assigned after construction (GameRoot._ready), as goals is.
var maze: GauntletMaze = null
## The mode this run was reset with (M10 R4).
# PORT-NOTE: the TS reads options.settings.mode every tick (TiltGame.ts:1860),
# in updateHUD (:2159) and at game over (:2091); nothing there can change it
# mid-run. The run captures it at reset all the same (M10 R4).
var mode: Types.GameMode = Types.GameMode.CLASSIC

## Milestones. PORT: web/src/tilt-to-live/TiltGame.ts:66 (this.goals)
# PORT-NOTE: assigned after construction (GameRoot._ready) — an eleventh
# constructor parameter would pass gdlint's function-arguments-number: 10.
var goals: GoalManager = null
## Run Milestone Tracker. PORT: web/src/tilt-to-live/TiltGame.ts:83-96
var run_tracker: GoalManager.RunTracker = GoalManager.RunTracker.new()
## PORT: web/src/tilt-to-live/TiltGame.ts:97
var points_earned_this_run: int = 0
## triggerPlayerDeath's `newlyCompleted` (TiltGame.ts:2086).
# PORT-NOTE: a local in the TS, read by the game-over setTimeout closure
# (:2111-2144); kept here so HudController's run_ended handler can read it.
var run_completed_goals: Array[GoalManager.Goal] = []

## renderer.triggerShake. GameRoot sets it; an empty Callable skips the shake (tests).
## PORT: web/src/tilt-to-live/TiltGame.ts:2064, :2081 (the TS calls the renderer directly)
var trigger_shake: Callable = Callable()


# PORT-NOTE: ten parameters is gdlint's limit and exactly the systems
# TiltGame.update()/resetRun() touch that this class owns.
func _init(
	p_player: PlayerShip,
	p_swarm: EnemySwarm,
	p_weapons: WeaponSystem,
	p_particles: ParticleEngine,
	p_grid: VectorGrid,
	p_scores: ScoreManager,
	p_audio: AudioBank,
	p_progression: ProgressionManager,
	p_options: GameOptionsManager,
	p_coins: CoinSystem
) -> void:
	player = p_player
	swarm = p_swarm
	weapons = p_weapons
	particles = p_particles
	grid = p_grid
	scores = p_scores
	audio = p_audio
	progression = p_progression
	options = p_options
	coins = p_coins
	# PORT: web/src/tilt-to-live/TiltGame.ts:212-218
	weapons.on_weapon_activated = _on_weapon_activated


## Resets all simulation state for a new run.
## PORT: web/src/tilt-to-live/TiltGame.ts:1547-1610
func reset_run(arena_bounds: Vector2) -> void:
	bounds = arena_bounds
	mode = options.settings.mode
	# PORT: web/src/tilt-to-live/TiltGame.ts:1548-1551
	var mode_config: GameOptionsManager.ModeConfig = options.get_mode_config(mode)
	scores.set_mode_multiplier(mode_config.score_multiplier)
	scores.set_progression_multiplier(progression.get_score_multiplier())
	elapsed = 0.0
	points_earned_this_run = 0  # PORT: web/src/tilt-to-live/TiltGame.ts:1566
	# PORT: web/src/tilt-to-live/TiltGame.ts:1567-1568
	max_lives = progression.get_starting_lives()
	lives = max_lives
	is_run_active = true
	# Hull Compact shrinks the hitbox; it stacks with the equipped ship's own hitboxScale.
	# PORT: web/src/tilt-to-live/TiltGame.ts:1570
	player.set_hitbox_multiplier(progression.get_hitbox_multiplier())

	player.reset(bounds.x * 0.5, bounds.y * 0.5)
	# The shield.radius perk's only consumer is the bubble the ship draws.
	# PORT: web/src/tilt-to-live/TiltGame.ts:1572-1574
	player.set_shield_radius(
		Tuning.get_tuned_value("shield", "radius", progression.data.perks.shield.radius)
	)
	# PORT-NOTE: railProgress (:1575-1576) is not ported — see goals_hud.gd's header.
	# PORT: web/src/tilt-to-live/TiltGame.ts:1578-1591
	run_tracker = GoalManager.RunTracker.new()
	run_tracker.mode = GameOptionsManager.MODE_IDS[mode]
	swarm.reset()
	swarm.set_speed_scale(progression.get_enemy_speed_multiplier())  # PORT: :1599
	weapons.reset()
	coins.reset()  # PORT: :1601
	particles.reset()
	scores.reset()
	maze.reset(bounds.x, bounds.y)  # PORT: web/src/tilt-to-live/TiltGame.ts:1604
	grid.resize(bounds.x, bounds.y)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1607-1610 (M5 R11)
	audio.set_muted(not options.settings.sfx_enabled)
	audio.set_sfx_volume(options.settings.sfx_volume)
	audio.set_music_volume(options.settings.music_volume)
	# PORT: web/src/tilt-to-live/TiltGame.ts:170-172 — the cinematic's completion
	# callback starts music, then spawns the starting orb; reset_run stands in for
	# that callback until the cinematic exists (M6 R7).
	# TODO(M11b): move this and spawn_starting_weapon_orb to the cinematic's end.
	if options.settings.music_enabled:
		audio.start_music()

	spawn_starting_weapon_orb(bounds)
	GameEvents.score_changed.emit(0, 1, scores.stats.best_score)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1615 — goalsHUD.updateLive's
	# evaluation half; see step 8 in update() for the split.
	goals.evaluate_live_total_goals(run_tracker)


## Spawns the equipped ship's starting weapon orb offset from the spawn point.
## PORT: web/src/tilt-to-live/TiltGame.ts:1964-1979
# PORT-NOTE: the `!startingWeapon` guard (:1966) is dead — every catalog ship
# sets one (ProgressionManager.ts:138-264) — and an enum cannot be absent, so
# it has no port.
func spawn_starting_weapon_orb(arena_bounds: Vector2) -> void:
	var starting_weapon: Types.WeaponType = progression.get_equipped_ship().starting_weapon
	var angle: float = randf() * TAU
	var dist: float = minf(arena_bounds.x, arena_bounds.y) * 0.28
	var margin: float = 60.0
	var x: float = clampf(arena_bounds.x * 0.5 + cos(angle) * dist, margin, arena_bounds.x - margin)
	var y: float = clampf(arena_bounds.y * 0.5 + sin(angle) * dist, margin, arena_bounds.y - margin)
	weapons.spawn_orb(arena_bounds, starting_weapon, x, y)


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
	# PORT: web/src/tilt-to-live/TiltGame.ts:1881-1891
	var ship: ProgressionManager.ShipSkinConfig = progression.get_equipped_ship()
	player.update(
		dt,
		mouse_pos,
		bounds,
		particles,
		effective_mode,
		move_vector,
		progression.data.tuning.sensitivity,
		progression.data.tuning.deadzone,
		ship.hitbox_scale,
		ship.turn_rate,
		ship.thruster_color,
		tilt_vector
	)

	# 3.5 Update Gauntlet Descending Maze Walls (blocks player, pushes downwards)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1893-1904 — spec §5.4 step 4
	if mode == Types.GameMode.GAUNTLET:
		maze.update(dt, bounds, player, scores.stats.score, elapsed, particles, lose_life)

	# 4. Update Swarm Enemies
	# PORT: web/src/tilt-to-live/TiltGame.ts:1906-1914
	swarm.update(dt, Vector2(player.x, player.y), bounds, particles, scores.stats.score, mode)

	# 5. Update Weapons
	# PORT: web/src/tilt-to-live/TiltGame.ts:1916-1928
	weapons.update(
		dt,
		player,
		swarm.enemies,
		bounds,
		particles,
		grid,
		audio,
		Callable(self, "handle_enemy_killed"),
		progression.data.perks,
		mode
	)

	# 5.5 Update Coin Pickups (own spawn timer, independent of weapon orbs)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1930-1940 — spec §5.4 step 7
	# PORT-NOTE: the Run over coins row (:2108, :2123-2130) reads coins.coins_collected
	# in HudController (M11a R17).
	var mode_config: GameOptionsManager.ModeConfig = options.get_mode_config(mode)
	coins.update(
		dt,
		player,
		bounds,
		particles,
		audio,
		mode_config.score_multiplier,
		progression.add_points_credited
	)

	# 6. Update Scores and Combos
	scores.update(dt, mode)  # PORT: web/src/tilt-to-live/TiltGame.ts:1943

	# 7. Check Collisions & Near-Misses
	check_collisions()

	# 8. Update Run Tracker & Goals HUD
	# PORT: web/src/tilt-to-live/TiltGame.ts:1949-1954
	run_tracker.score = scores.stats.score
	run_tracker.kills = scores.stats.kills
	run_tracker.multiplier = scores.stats.multiplier
	run_tracker.survival_time = elapsed
	run_tracker.close_calls = scores.stats.close_calls
	# PORT-NOTE: goalsHUD.updateLive (:1954, GoalsHUD.ts:242-255) is the
	# evaluation below plus a rail-height write. The height changes only when a
	# goal completes, and every completion reaches GoalsHUD.render() through
	# GameRoot's callbacks, so the sim keeps only the evaluation (spec §5.3).
	# PORT-NOTE: on the death tick this runs after trigger_player_death's
	# evaluate_run has committed the run into goals.cumulative, so total_*
	# metrics count this run twice for this one call and can complete a
	# cumulative goal early. TiltGame.update() does the same (:2086 then :1954).
	# Preserved deliberately (LAW 2); raised in HANDOFF open questions.
	goals.evaluate_live_total_goals(run_tracker)

	# 9. Emit HUD signal
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
func handle_enemy_killed(enemy: Types.Enemy, weapon_type: Types.WeaponType) -> void:
	scores.register_kill(enemy.x, enemy.y, weapon_type, audio)
	grid.apply_explosion(enemy.x, enemy.y, 4.5, 60.0)
	swarm.on_enemy_killed(enemy, particles)
	# Update weapon kill statistics for milestones. PORT: web/src/tilt-to-live/TiltGame.ts:1986-2003
	match weapon_type:
		Types.WeaponType.VORTEX:
			run_tracker.vortex_absorbs += 1
		Types.WeaponType.LASER:
			run_tracker.laser_slices += 1
		Types.WeaponType.MISSILES:
			run_tracker.missiles_fired += 1
		Types.WeaponType.FREEZE:
			run_tracker.freeze_shatters += 1
		Types.WeaponType.SHIELD:
			run_tracker.shield_rams += 1
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
		_shake(14.0 * options.get_shake_multiplier())  # PORT: web/src/tilt-to-live/TiltGame.ts:2064
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
	_shake(24.0 * options.get_shake_multiplier())  # PORT: web/src/tilt-to-live/TiltGame.ts:2081

	scores.finalize_game()
	# Finalize run goals check (capped at 3 run milestones, plus any cumulative
	# total milestones). PORT: web/src/tilt-to-live/TiltGame.ts:2085-2086
	run_completed_goals = goals.evaluate_run(run_tracker)
	GameEvents.run_ended.emit(scores.stats.score, scores.stats)
	GameEvents.phase_changed.emit(Types.GamePhase.GAME_OVER)


## Tracks superweapon activation, then relays the pickup to the UI bus.
## PORT: web/src/tilt-to-live/TiltGame.ts:212-218
# PORT-NOTE: missiles count a fixed 16 per pickup (:216), not the launched
# salvo size — preserved deliberately.
func _on_weapon_activated(type: Types.WeaponType) -> void:
	if type == Types.WeaponType.NUKE:
		run_tracker.nukes_detonated += 1
	elif type == Types.WeaponType.MISSILES:
		run_tracker.missiles_fired += 16  # PORT: :216
	GameEvents.weapon_activated.emit(type)


func _shake(amount: float) -> void:
	if trigger_shake.is_valid():
		trigger_shake.call(amount)
