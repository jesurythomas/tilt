## run_controller.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:1855-2083, per spec §5.4
class_name RunController
extends RefCounted
## In-run coordinator executing frame order steps 1-11, collision detection,
## scoring integration, life loss, and player death.

## DIVERGENCE(M11c P6): no emission yet this run — forces the next score_changed.
const NO_HUD_VALUES: Vector3i = Vector3i(-1, -1, -1)
## DIVERGENCE(M11c N3d): _collide's outcomes.
const COLLIDE_NONE: int = 0
const COLLIDE_REMOVED: int = 1
const COLLIDE_CRASH: int = 2
## DIVERGENCE(KEY R1): Battering Ram and Shatter Cascade reach — px at arena scale 1.
const BATTERING_RAM_RADIUS: float = 60.0
const SHATTER_CASCADE_RADIUS: float = 70.0
## DIVERGENCE(KEY R1): Coin Vacuum's magnet radius — the whole arena.
const COIN_VACUUM_RADIUS: float = 100000.0

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
## DIVERGENCE(MVP R5): true for the run a new player starts; the HUD shows its hint.
var is_first_run: bool = false

## Milestones. PORT: web/src/tilt-to-live/TiltGame.ts:66 (this.goals)
# PORT-NOTE: assigned after construction (GameRoot._ready) — an eleventh
# constructor parameter would pass gdlint's function-arguments-number: 10.
var goals: GoalManager = null
## Run Milestone Tracker. PORT: web/src/tilt-to-live/TiltGame.ts:83-96
var run_tracker: GoalManager.RunTracker = GoalManager.RunTracker.new()
## PORT: web/src/tilt-to-live/TiltGame.ts:97
var points_earned_this_run: int = 0
## DIVERGENCE(ECON R1): every point credited to the balance during this run (coins,
## milestones, the payout at death) after the Points Multiplier — the Run over's figure.
var points_credited_this_run: int = 0
## DIVERGENCE(ECON R1): the payout banked at death (part of points_credited_this_run).
var run_payout_credited: int = 0
## DIVERGENCE(ADS R6): true once this run's points were multiplied by a rewarded ad.
var is_reward_claimed: bool = false
## triggerPlayerDeath's `newlyCompleted` (TiltGame.ts:2086).
# PORT-NOTE: a local in the TS, read by the game-over setTimeout closure
# (:2111-2144); kept here so HudController's run_ended handler can read it.
var run_completed_goals: Array[GoalManager.Goal] = []
## DIVERGENCE(ACH R2): every achievement completed since reset_run, in completion order —
## the live ones mid-run as well as evaluate_run's at death (GameRoot's goal callback
## appends). The TS Run over listed only evaluate_run's (TiltGame.ts:2132).
var run_achievements: Array[GoalManager.Goal] = []

## renderer.triggerShake. GameRoot sets it; an empty Callable skips the shake (tests).
## PORT: web/src/tilt-to-live/TiltGame.ts:2064, :2081 (the TS calls the renderer directly)
var trigger_shake: Callable = Callable()
## The (score, multiplier, best) last sent on score_changed (M11c P6).
var _last_hud_values: Vector3i = NO_HUD_VALUES


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
	_last_hud_values = NO_HUD_VALUES
	mode = options.settings.mode
	# PORT: web/src/tilt-to-live/TiltGame.ts:1548-1551
	var mode_config: GameOptionsManager.ModeConfig = options.get_mode_config(mode)
	scores.set_mode_multiplier(mode_config.score_multiplier)
	scores.set_progression_multiplier(progression.get_score_multiplier())
	elapsed = 0.0
	points_earned_this_run = 0  # PORT: web/src/tilt-to-live/TiltGame.ts:1566
	points_credited_this_run = 0  # DIVERGENCE(ECON R1)
	run_payout_credited = 0
	is_reward_claimed = false  # DIVERGENCE(ADS R6)
	run_achievements = []  # DIVERGENCE(ACH R2)
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
	# DIVERGENCE(MVP R5): a player with no best score and no finished first run gets a
	# gentler ramp and the HUD's one-time hint.
	is_first_run = not options.settings.first_run_done and scores.stats.best_score == 0
	swarm.set_gentle(is_first_run)
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

	GameEvents.score_changed.emit(0, 1, scores.stats.best_score)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1615 — goalsHUD.updateLive's
	# evaluation half; see step 8 in update() for the split.
	goals.evaluate_live_total_goals(run_tracker)


## The run half of the cinematic's onFinish: music, then the starting orb, which
## lands after both resetRun and the cinematic's arena reset (M11b R6, M6 R7).
## PORT: web/src/tilt-to-live/TiltGame.ts:170-176
func finish_cinematic(arena_bounds: Vector2) -> void:
	if options.settings.music_enabled:
		audio.start_music()
	spawn_starting_weapon_orb(arena_bounds)


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
	# DIVERGENCE(ORB R1): the opening orb is not magnetic (Types.WeaponOrb.magnetic).
	weapons.spawn_orb(arena_bounds, starting_weapon, x, y).magnetic = false


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
	var pt_grid: int = PerfProbe.now()
	grid.update(dt)
	PerfProbe.add("s_grid", pt_grid)

	# 2. Update Particles
	var pt_particles: int = PerfProbe.now()
	# DIVERGENCE(M11c P25): queued; GameRoot integrates the frame's steps in one flush.
	particles.step(dt)
	PerfProbe.add("s_particles", pt_particles)

	# 3. Update Player Ship
	# PORT: web/src/tilt-to-live/TiltGame.ts:1881-1891
	var pt_player: int = PerfProbe.now()
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
	PerfProbe.add("s_player", pt_player)

	# 3.5 Update Gauntlet Descending Maze Walls (blocks player, pushes downwards)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1893-1904 — spec §5.4 step 4
	if mode == Types.GameMode.GAUNTLET:
		maze.update(dt, bounds, player, scores.stats.score, elapsed, particles, _on_maze_crush)

	# 4. Update Swarm Enemies
	# PORT: web/src/tilt-to-live/TiltGame.ts:1906-1914
	var pt_swarm: int = PerfProbe.now()
	swarm.update(dt, Vector2(player.x, player.y), bounds, particles, scores.stats.score, mode)
	PerfProbe.add("s_swarm", pt_swarm)

	# 5. Update Weapons
	var pt_weapons: int = PerfProbe.now()
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
	PerfProbe.add("s_weapons", pt_weapons)

	# 5.5 Update Coin Pickups (own spawn timer, independent of weapon orbs)
	# PORT: web/src/tilt-to-live/TiltGame.ts:1930-1940 — spec §5.4 step 7
	# PORT-NOTE: the Run over coins row (:2108, :2123-2130) reads coins.coins_collected
	# in HudController (M11a R17).
	var mode_config: GameOptionsManager.ModeConfig = options.get_mode_config(mode)
	var pt_coins: int = PerfProbe.now()
	# DIVERGENCE(KEY R1) Coin Vacuum: while shielded, every coin flies to the ship.
	var vacuum: bool = progression.data.perks.shield.coin_vacuum and player.has_shield()
	coins.magnet_radius = COIN_VACUUM_RADIUS if vacuum else CoinSystem.MAGNET_RADIUS
	# DIVERGENCE(ECON R1): coins bank through credit_run_points (the run's total).
	coins.update(
		dt, player, bounds, particles, audio, mode_config.score_multiplier, credit_run_points
	)
	PerfProbe.add("s_coins", pt_coins)

	# 6. Update Scores and Combos
	scores.update(dt, mode)  # PORT: web/src/tilt-to-live/TiltGame.ts:1943

	# 7. Check Collisions & Near-Misses
	var pt_collide: int = PerfProbe.now()
	check_collisions()
	PerfProbe.add("s_collide", pt_collide)

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
	var pt_goals: int = PerfProbe.now()
	goals.evaluate_live_total_goals(run_tracker)
	PerfProbe.add("s_goals", pt_goals)

	# 9. Emit HUD signal
	var pt_hud: int = PerfProbe.now()
	# DIVERGENCE(M11c P6): emit only when a HUD value changed (the TS re-renders every tick).
	var hud_values: Vector3i = Vector3i(
		scores.stats.score, scores.stats.multiplier, scores.stats.best_score
	)
	if hud_values != _last_hud_values:
		_last_hud_values = hud_values
		GameEvents.score_changed.emit(
			scores.stats.score, scores.stats.multiplier, scores.stats.best_score
		)
	PerfProbe.add("s_hud_signal", pt_hud)


## Collision detection between player ship and enemy swarm.
## PORT: web/src/tilt-to-live/TiltGame.ts:2006-2043
func check_collisions() -> void:
	if player.is_dead:
		return

	# DIVERGENCE(M11c P28): the player's x/y/radius are read once; nothing in the loop
	# moves or resizes the player (a crash returns).
	var plx: float = player.x
	var ply: float = player.y
	var plr: float = player.radius
	if EnemySwarm.use_native:
		# DIVERGENCE(M11c N3d): C++ returns, in the loop's descending order, the indices
		# that pass P21's x reject below; only those run the per-enemy body. The array
		# changes only when the body removes an enemy (a kill, which may also add or
		# drop others), so the query is re-run from the next index after each one —
		# every index is still tested on the state the loop would see.
		var start: int = swarm.enemies.size() - 1
		while start >= 0:
			var hits: PackedInt32Array = PerilNative.collision_candidates(
				swarm.enemies, plx, plr, start
			)
			start = -1
			for i: int in hits:
				var hit: int = _collide(i, plx, ply, plr)
				if hit == COLLIDE_CRASH:
					return
				if hit == COLLIDE_REMOVED:
					start = i - 1
					break
		return
	for i: int in range(swarm.enemies.size() - 1, -1, -1):
		var e: PerilEnemy = swarm.enemies[i]
		# DIVERGENCE(M11c P21): both tests in _collide need dist < player.radius +
		# e.radius + 16, and dist >= |dx|; an enemy that far off in x (1 px margin for
		# rounding) can trigger neither, so it skips the rest. Every outcome is unchanged.
		if absf(plx - e.x) > plr + e.radius + 16.0 + 1.0:
			continue
		if _collide(i, plx, ply, plr) == COLLIDE_CRASH:
			return


## check_collisions' body for enemy i: COLLIDE_REMOVED when it was killed and
## removed, COLLIDE_CRASH when the player lost a life (the loop stops), else
## COLLIDE_NONE. PORT: web/src/tilt-to-live/TiltGame.ts:2010-2042
func _collide(i: int, plx: float, ply: float, plr: float) -> int:
	var e: PerilEnemy = swarm.enemies[i]
	var dx: float = plx - e.x
	var er: float = e.radius
	var dy: float = ply - e.y
	var dist: float = sqrt(dx * dx + dy * dy)

	# Direct Touch / Collision
	if dist < plr + er:
		if player.has_shield():
			# Shield rams and kills red dot
			handle_enemy_killed(e, Types.WeaponType.SHIELD)
			particles.emit_explosion(e.x, e.y, Color("#3ddc97"), 20)
			swarm.enemies.remove_at(i)
			if progression.data.perks.shield.battering_ram:  # DIVERGENCE(KEY R1) Battering Ram
				_ram_burst(e.x, e.y)
			return COLLIDE_REMOVED
		if e.frozen:
			# Ramming frozen dot shatters it
			audio.play_ice_shatter()
			scores.register_kill(e.x, e.y, Types.WeaponType.FREEZE, audio)
			particles.emit_ice_shatter(e.x, e.y, 16)
			swarm.enemies.remove_at(i)
			if progression.data.perks.freeze.shatter_cascade:  # DIVERGENCE(KEY R1) Shatter Cascade
				_shatter_cascade(e.x, e.y)
			return COLLIDE_REMOVED
		# Crash costs a life
		scores.stats.killer = str(Types.EnemyType.find_key(e.type)).to_lower()  # DIVERGENCE(MVP R6)
		lose_life()
		return COLLIDE_CRASH

	# Close Call / Near-Miss Detection
	if dist < plr + er + 16.0 and player.close_call_timer <= 0.0:
		player.close_call_timer = 0.75
		scores.register_close_call(player.x, player.y, audio)
		GameEvents.close_call.emit()  # DIVERGENCE(MVP Week 1)
	return COLLIDE_NONE


## DIVERGENCE(KEY R1) Battering Ram: a ram also kills every dot near the rammed one. Removals only
## below or at the collision index are safe: check_collisions re-queries from i − 1
## after each kill (N3d).
func _ram_burst(x: float, y: float) -> void:
	var r: float = BATTERING_RAM_RADIUS * weapons.scale
	grid.apply_explosion(x, y, 10.0, r * 2.0)
	for j: int in range(swarm.enemies.size() - 1, -1, -1):
		var o: PerilEnemy = swarm.enemies[j]
		if (o.x - x) * (o.x - x) + (o.y - y) * (o.y - y) <= r * r:
			handle_enemy_killed(o, Types.WeaponType.SHIELD)
			particles.emit_sparks(o.x, o.y, 8, Color("#3ddc97"), 160.0)
			swarm.enemies.remove_at(j)


## DIVERGENCE(KEY R1) Shatter Cascade: a shatter also shatters the frozen dots near it.
func _shatter_cascade(x: float, y: float) -> void:
	var r: float = SHATTER_CASCADE_RADIUS * weapons.scale
	for j: int in range(swarm.enemies.size() - 1, -1, -1):
		var o: PerilEnemy = swarm.enemies[j]
		if o.frozen and (o.x - x) * (o.x - x) + (o.y - y) * (o.y - y) <= r * r:
			scores.register_kill(o.x, o.y, Types.WeaponType.FREEZE, audio)
			particles.emit_ice_shatter(o.x, o.y, 8)
			swarm.enemies.remove_at(j)


## Handles enemy destruction by weapons or shield.
## PORT: web/src/tilt-to-live/TiltGame.ts:1981-2004
func handle_enemy_killed(enemy: PerilEnemy, weapon_type: Types.WeaponType) -> void:
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


## DIVERGENCE(ECON R1): banks `amount` through the Points Multiplier and adds what was
## credited to points_credited_this_run (reset at each run start; the death tick's step 8
## live goals, after run_ended, still count). Returns the credit.
func credit_run_points(amount: int) -> int:
	var credited: int = progression.add_points_credited(amount)
	points_credited_this_run += credited
	return credited


## DIVERGENCE(ADS R6): true while the run has points a rewarded ad may multiply.
func can_claim_reward() -> bool:
	return not is_reward_claimed and points_credited_this_run > 0


## DIVERGENCE(ADS R6): makes the run's points `multiplier` times what it credited, once a run.
## The bonus skips the Points Multiplier, which those points already carry. Returns the bonus.
func claim_reward(multiplier: int) -> int:
	if not can_claim_reward():
		return 0
	is_reward_claimed = true
	var bonus: int = progression.add_points_bonus(points_credited_this_run * (multiplier - 1))
	points_credited_this_run += bonus
	return bonus


## The maze's crush callback: lose_life, naming the wall as the killer (DIVERGENCE(MVP R6)).
func _on_maze_crush() -> void:
	scores.stats.killer = "maze_wall"
	lose_life()


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
	if is_first_run:  # DIVERGENCE(MVP R5)
		options.settings.first_run_done = true
		options.save()
	# DIVERGENCE(ECON R1): bank the run payout (seconds alive, kills, mode) before the
	# milestones and run_ended, so the Run over reads the whole run's total.
	var mode_mult: float = options.get_mode_config(mode).score_multiplier
	run_payout_credited = credit_run_points(
		ProgressionManager.run_payout(scores.stats.survival_time, scores.stats.kills, mode_mult)
	)
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
