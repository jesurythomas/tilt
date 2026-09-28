# gdlint:disable=max-file-lines
## weapon_system.gd
## PORTS: web/src/tilt-to-live/WeaponSystem.ts (923 lines, source commit 7be9614)
## max-file-lines is suppressed (as enemy_swarm.gd's): KEY R1's keystone effects
## pushed the one-file port past 1,000 lines (LAW 3 keeps it one file).
class_name WeaponSystem
extends RefCounted
## Weapon orb spawning and the seven superweapons.
##
## PORT-NOTE: WeaponSystem.render() (WeaponSystem.ts:612-831) and
## renderOrbGlyph() (:833-923) relocate to the render layers (spec §4.2/D4,
## §5.5): orbs and glyphs to render/entity_layer.gd, weapon FX to
## render/effect_layer.gd, because CanvasItem 2D drawing belongs to Node2D
## render layers.
##
## PORT-NOTE: perk ranks arrive as ProgressionManager.WeaponPerks, the port of
## the `perks?: WeaponPerks` parameter (WeaponSystem.ts:61, :396). A null
## record reads as all-zero, matching every `perks?.x.y || 0` chain.

## DIVERGENCE(M11c P32): the missile snapshot's x index (see _missile_snapshot).
const SNAP_QUANT: float = 16.0
const SNAP_OFFSET: float = 65536.0
const SNAP_INDEX_BITS: int = 20

## DIVERGENCE(KEY R1): the added keystones' numbers (plan 2026-09-28-achievements-keystones-ui.md).
## Ranges in px at arena scale 1 (multiplied by `scale` like the TS's tuned ranges).
const EVENT_HORIZON_CORE: float = 54.0
const DARK_HARVEST_STEP: float = 0.05
const DARK_HARVEST_MAX: float = 2.0
const CLUSTER_CHILD_LIFETIME: float = 1.2
const CLUSTER_CHILD_SPEED: float = 300.0
const HYPER_CRUISE: float = 620.0
const HYPER_AGILITY: float = 16.0
const SECOND_SALVO_DELAY: float = 0.6
const HEAVY_BEAM_WIDTH: float = 28.0
const RAPID_SWEEP_FACTOR: float = 1.5
const FALLOUT_RADIUS_FRACTION: float = 0.4
const FALLOUT_SECONDS: float = 3.0
const CHAIN_REACTION_CHANCE: float = 0.125
const CHAIN_REACTION_RADIUS: float = 60.0
const STUN_WAVE_REACH: float = 1.5
const STUN_WAVE_SECONDS: float = 2.0
const CRYO_NOVA_RADIUS: float = 200.0
const ICE_ARMOR_SECONDS: float = 2.0
const OVERCHARGE_RADIUS: float = 180.0
const PLASMA_ARC_RADIUS: float = 45.0

## Live weapon orbs in the arena. PORT: web/src/tilt-to-live/WeaponSystem.ts:14
var orbs: Array[Types.WeaponOrb] = []

## Active superweapons currently expanding/firing. PORT: web/src/tilt-to-live/WeaponSystem.ts:15
var active_weapons: Array[Types.ActiveWeapon] = []

## Active homing missiles. PORT: web/src/tilt-to-live/WeaponSystem.ts:16
var missiles: Array[Types.HomingMissile] = []

## Active lightning arcs. PORT: web/src/tilt-to-live/WeaponSystem.ts:17
var lightning_arcs: Array[Types.LightningArc] = []

## Callback fired when any weapon is collected and activated.
## PORT: web/src/tilt-to-live/WeaponSystem.ts:18
var on_weapon_activated: Callable = Callable()

## The seven superweapon types, in drop-table iteration order. Unread, exactly
## as in the TS. PORT: web/src/tilt-to-live/WeaponSystem.ts:25-33
var weapon_types: Array[Types.WeaponType] = [
	Types.WeaponType.NUKE,
	Types.WeaponType.MISSILES,
	Types.WeaponType.LIGHTNING,
	Types.WeaponType.LASER,
	Types.WeaponType.VORTEX,
	Types.WeaponType.FREEZE,
	Types.WeaponType.SHIELD,
]

## Scale factor for orb and blast radius. PORT: web/src/tilt-to-live/WeaponSystem.ts:35
var scale: float = 1.0

var _next_orb_id: int = 1
var _next_weapon_id: int = 1
var _next_missile_id: int = 1
var _orb_spawn_timer: float = 2.0  # PORT: web/src/tilt-to-live/WeaponSystem.ts:23

## DIVERGENCE(M11c P32): the missile snapshot (see update's step 4).
var _snap_x: PackedFloat64Array = PackedFloat64Array()
var _snap_y: PackedFloat64Array = PackedFloat64Array()
var _snap_r: PackedFloat64Array = PackedFloat64Array()
var _snap_by_id: Dictionary[int, PerilEnemy] = {}
var _snap_max_r: float = 0.0
var _snap_order: PackedInt32Array = PackedInt32Array()
var _snap_sorted_q: PackedFloat64Array = PackedFloat64Array()

## DIVERGENCE(KEY R1): Second Salvo's pending launches (seconds left, missile count), and whether an
## Overcharge pulse waits for the power-up shield to end.
var _salvo_timers: Array[float] = []
var _salvo_counts: Array[int] = []
var _overcharge_armed: bool = false


func _init() -> void:
	reset()


## Sets the arena scale factor. PORT: web/src/tilt-to-live/WeaponSystem.ts:37-39
func set_scale(p_scale: float) -> void:
	scale = clampf(p_scale, 0.5, 1.8)  # PORT: web/src/tilt-to-live/WeaponSystem.ts:38


## Resets all orbs and active weapons. PORT: web/src/tilt-to-live/WeaponSystem.ts:41-50
func reset() -> void:
	orbs = []
	active_weapons = []
	missiles = []
	lightning_arcs = []
	_next_orb_id = 1
	_next_weapon_id = 1
	_next_missile_id = 1
	_orb_spawn_timer = 1.5  # PORT: web/src/tilt-to-live/WeaponSystem.ts:49
	_salvo_timers = []  # DIVERGENCE(KEY R1)
	_salvo_counts = []
	_overcharge_armed = false


## Updates orb spawning, collection collisions, and active weapon expansion.
## PORT: web/src/tilt-to-live/WeaponSystem.ts:52-367
func update(
	dt: float,
	player: PlayerShip,
	enemies: Array[PerilEnemy],
	bounds: Vector2,
	particles: ParticleEngine,
	grid: VectorGrid,
	audio: AudioBank,
	on_enemy_killed: Callable,
	perks: ProgressionManager.WeaponPerks = null,
	game_mode: Types.GameMode = Types.GameMode.CLASSIC
) -> void:
	# 1. Weapon Orb Spawning. PORT: web/src/tilt-to-live/WeaponSystem.ts:64-74
	_orb_spawn_timer -= dt
	if _orb_spawn_timer <= 0.0:
		if orbs.size() < 5:  # PORT: web/src/tilt-to-live/WeaponSystem.ts:67
			var type: Types.WeaponType = get_random_weapon_type(game_mode)
			spawn_orb(bounds, type)
		var is_code_red: bool = game_mode == Types.GameMode.CODE_RED
		# PORT: web/src/tilt-to-live/WeaponSystem.ts:73
		_orb_spawn_timer = (2.2 if is_code_red else 3.0) + randf() * 1.5

	# 2. Update Orbs (lifetime and collection). PORT: web/src/tilt-to-live/WeaponSystem.ts:76-99
	for i: int in range(orbs.size() - 1, -1, -1):
		var orb: Types.WeaponOrb = orbs[i]
		orb.lifetime -= dt

		if orb.lifetime <= 0.0:
			orbs.remove_at(i)
			continue

		# Check collision with player ship. PORT: web/src/tilt-to-live/WeaponSystem.ts:86-90
		var dx: float = player.x - orb.x
		var dy: float = player.y - orb.y
		var dist: float = sqrt(dx * dx + dy * dy)

		if dist < player.radius + orb.radius:
			# Collect orb! PORT: web/src/tilt-to-live/WeaponSystem.ts:92-98
			activate_weapon(
				orb.type,
				orb.x,
				orb.y,
				player,
				enemies,
				particles,
				grid,
				audio,
				on_enemy_killed,
				perks
			)
			if on_weapon_activated.is_valid():
				on_weapon_activated.call(orb.type)
			audio.play_orb_pickup()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:95
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:96
			particles.emit_sparks(orb.x, orb.y, 20, get_weapon_color(orb.type), 140.0)
			orbs.remove_at(i)

	# 3. Update Active Weapons (Nuke, Laser, Vortex).
	# PORT: web/src/tilt-to-live/WeaponSystem.ts:101-280
	for i: int in range(active_weapons.size() - 1, -1, -1):
		var w: Types.ActiveWeapon = active_weapons[i]
		w.duration -= dt

		# PORT-NOTE: `w.data?.x` (WeaponSystem.ts:160, :188, :198, :260) — data is
		# Types.ts:64's any-typed bag (types.gd:111-113), held as a Dictionary keyed
		# by the TS property names. Absent data reads as an empty bag.
		var data: Dictionary = w.data if w.data != null else {}

		match w.type:
			Types.WeaponType.NUKE when data.get("fallout", false):
				# DIVERGENCE(KEY R1) Fallout Zone: a fixed burn zone that kills what enters it.
				for e_idx: int in range(enemies.size() - 1, -1, -1):
					var e: PerilEnemy = enemies[e_idx]
					var fdx: float = e.x - w.x
					var fdy: float = e.y - w.y
					if fdx * fdx + fdy * fdy <= (w.radius + e.radius) * (w.radius + e.radius):
						on_enemy_killed.call(e, Types.WeaponType.NUKE)
						particles.emit_sparks(e.x, e.y, 6, Color("#9dff4d"), 140.0)
						enemies.remove_at(e_idx)
			Types.WeaponType.NUKE:
				# Expanding blast ring. PORT: web/src/tilt-to-live/WeaponSystem.ts:108-111
				var progress: float = 1.0 - w.duration / w.max_duration
				# PORT-NOTE: the fallback is the table base, not the ranked value —
				# WeaponSystem.ts:110 reads .base directly
				var base_radius: float = (
					w.max_radius
					if not is_nan(w.max_radius)
					else (Tuning.get_tuned_value("nuke", "radius", 0) * scale)
				)
				w.radius = base_radius * progress

				# Vaporize enemies inside blast radius.
				# PORT: web/src/tilt-to-live/WeaponSystem.ts:113-124
				var bursts: Array[Vector2] = []  # DIVERGENCE(KEY R1) Chain Reaction
				var chain_reaction: bool = data.get("chainReaction", false)
				for e_idx: int in range(enemies.size() - 1, -1, -1):
					var e: PerilEnemy = enemies[e_idx]
					var edx: float = e.x - w.x
					var edy: float = e.y - w.y
					var e_dist: float = sqrt(edx * edx + edy * edy)

					if e_dist <= w.radius + e.radius + 15.0:  # PORT: web/src/tilt-to-live/WeaponSystem.ts:119
						on_enemy_killed.call(e, Types.WeaponType.NUKE)
						# DIVERGENCE(M2.5 §10): measured on SM_A556E — emit_explosion
						# (16 sparks + shockwave ring per enemy) caused frame rate drops when
						# clearing dozens of dots simultaneously. Emitting 6 sparks preserves
						# vibrant feedback without starving the mobile GPU.
						particles.emit_sparks(e.x, e.y, 6, Color("#ff3366"), 160.0)
						if chain_reaction and randf() < CHAIN_REACTION_CHANCE:
							bursts.append(Vector2(e.x, e.y))
						enemies.remove_at(e_idx)
				for burst: Vector2 in bursts:
					_burst(
						burst,
						CHAIN_REACTION_RADIUS * scale,
						Types.WeaponType.NUKE,
						enemies,
						particles,
						grid,
						on_enemy_killed,
						Color("#ffb14d")
					)

				# Distort grid outward. PORT: web/src/tilt-to-live/WeaponSystem.ts:127
				grid.apply_explosion(w.x, w.y, 16.0, w.radius + 30.0)
			Types.WeaponType.LASER:
				# Dual-ended beam sweeps around the ship. PORT: web/src/tilt-to-live/WeaponSystem.ts:132-136
				w.x = player.x
				w.y = player.y
				# PORT-NOTE: `(w.angle || 0)` treats an angle of exactly 0 as unset; 0 + x == x,
				# so the NAN test is the only observable difference — preserved.
				# DIVERGENCE(KEY R1) Rapid Sweep: 1.5× the TS's 3.5π rad/s.
				var sweep: float = RAPID_SWEEP_FACTOR if data.get("rapidSweep", false) else 1.0
				w.angle = (w.angle if not is_nan(w.angle) else 0.0) + dt * PI * 3.5 * sweep
				# DIVERGENCE(KEY R1) Heavy Beam: the TS's 14 px hit margin doubled.
				var beam_margin: float = HEAVY_BEAM_WIDTH if data.get("heavyBeam", false) else 14.0
				var beam_length: float = (
					w.radius
					if w.radius != 0.0
					else Tuning.get_tuned_value("laser", "length", 0) * scale
				)
				var cos_a: float = cos(w.angle)
				var sin_a: float = sin(w.angle)

				# PORT: web/src/tilt-to-live/WeaponSystem.ts:142-157
				for e_idx: int in range(enemies.size() - 1, -1, -1):
					var e: PerilEnemy = enemies[e_idx]
					var rel_x: float = e.x - w.x
					var rel_y: float = e.y - w.y
					var proj: float = rel_x * cos_a + rel_y * sin_a
					if absf(proj) <= beam_length:
						var perp_dist: float = absf(-rel_x * sin_a + rel_y * cos_a)
						if perp_dist <= e.radius + beam_margin:  # PORT: web/src/tilt-to-live/WeaponSystem.ts:151
							on_enemy_killed.call(e, Types.WeaponType.LASER)
							# PORT: web/src/tilt-to-live/WeaponSystem.ts:153
							particles.emit_sparks(e.x, e.y, 14, Color("#cc22ff"), 200.0)
							enemies.remove_at(e_idx)

				# Laser Cross-Beam keystone. PORT: web/src/tilt-to-live/WeaponSystem.ts:159-179
				# PORT-NOTE: the beam body is duplicated exactly as WeaponSystem.ts:142-157
				# and :164-178 duplicate it — LAW 4 forbids a helper the TS does not have.
				var cross_beam: bool = data.get("crossBeam", false)
				if cross_beam:
					var cos_b: float = cos(w.angle + PI / 2.0)
					var sin_b: float = sin(w.angle + PI / 2.0)
					for e_idx: int in range(enemies.size() - 1, -1, -1):
						var e: PerilEnemy = enemies[e_idx]
						var rel_x: float = e.x - w.x
						var rel_y: float = e.y - w.y
						var proj: float = rel_x * cos_b + rel_y * sin_b
						if absf(proj) <= beam_length:
							var perp_dist: float = absf(-rel_x * sin_b + rel_y * cos_b)
							if perp_dist <= e.radius + beam_margin:  # PORT: web/src/tilt-to-live/WeaponSystem.ts:172
								on_enemy_killed.call(e, Types.WeaponType.LASER)
								# PORT: web/src/tilt-to-live/WeaponSystem.ts:174
								particles.emit_sparks(e.x, e.y, 14, Color("#cc22ff"), 200.0)
								enemies.remove_at(e_idx)
			Types.WeaponType.VORTEX:
				# PORT: web/src/tilt-to-live/WeaponSystem.ts:184
				var pull_radius: float = (
					w.radius
					if w.radius != 0.0
					else Tuning.get_tuned_value("blackhole", "radius", 0) * scale
				)
				var pull_radius2: float = pull_radius * pull_radius
				var gravity_rank: int = data.get("gravity", 0)
				# DIVERGENCE(KEY R1) Event Horizon widens the TS's 30 px kill core; Dark Harvest feeds it.
				var core: float = EVENT_HORIZON_CORE if data.get("eventHorizon", false) else 30.0
				var dark_harvest: bool = data.get("darkHarvest", false)

				# Event Horizon Cloak. PORT: web/src/tilt-to-live/WeaponSystem.ts:187-196
				# DIVERGENCE(ECON R5): innate (user 2026-09-28: "for blackhole make being
				# invulerable a already innate upgrade") — the TS gated it on the
				# invulnerableInside keystone (:187), which left the Armory.
				var ship_dist: float = Vector2(player.x - w.x, player.y - w.y).length()
				if ship_dist <= pull_radius:
					player.activate_shield(0.3)  # PORT: web/src/tilt-to-live/WeaponSystem.ts:191
					if randf() < 0.25:  # PORT: web/src/tilt-to-live/WeaponSystem.ts:192
						# PORT: web/src/tilt-to-live/WeaponSystem.ts:193
						particles.emit_sparks(player.x, player.y, 1, Color("#b84dff"), 40.0)

				# PORT: web/src/tilt-to-live/WeaponSystem.ts:198
				var gravity_multiplier: float = 1.0 + float(gravity_rank) * 0.2

				# DIVERGENCE(M11c P33): the pull reads each Enemy field once into a local and
				# writes it back once (the same operations in the same order, so the same
				# values) — each property access costs about as much as the arithmetic.
				var wx: float = w.x
				var wy: float = w.y
				for e_idx: int in range(enemies.size() - 1, -1, -1):
					var e: PerilEnemy = enemies[e_idx]
					var ex: float = e.x
					var ey: float = e.y
					var edx: float = wx - ex
					var edy: float = wy - ey
					var dist2: float = edx * edx + edy * edy

					if dist2 < pull_radius2 and dist2 > 0.1:  # PORT: web/src/tilt-to-live/WeaponSystem.ts:206
						var dist: float = sqrt(dist2)
						if dist <= core:  # PORT: web/src/tilt-to-live/WeaponSystem.ts:208 (30)
							on_enemy_killed.call(e, Types.WeaponType.VORTEX)
							audio.play_dot_pop(randi() % 5)  # PORT: web/src/tilt-to-live/WeaponSystem.ts:211
							# PORT: web/src/tilt-to-live/WeaponSystem.ts:212
							particles.emit_sparks(e.x, e.y, 14, Color("#bb66ff"), 180.0)
							enemies.remove_at(e_idx)
							var harvested: float = data.get("harvested", 0.0)
							if dark_harvest and harvested < DARK_HARVEST_MAX:
								w.duration += DARK_HARVEST_STEP
								data["harvested"] = harvested + DARK_HARVEST_STEP
						else:
							var norm_dist: float = dist / pull_radius
							var t: float = maxf(0.0, 1.0 - norm_dist)
							# PORT: web/src/tilt-to-live/WeaponSystem.ts:218
							var gravity_accel: float = (
								(450.0 + 1350.0 * (t * t)) * gravity_multiplier
							)
							var evx: float = e.vx
							var evy: float = e.vy
							evx += (edx / dist) * gravity_accel * dt
							evy += (edy / dist) * gravity_accel * dt
							# PORT: web/src/tilt-to-live/WeaponSystem.ts:225
							var swirl_accel: float = (300.0 + 750.0 * t) * dt * gravity_multiplier
							evx += (-edy / dist) * swirl_accel
							evy += (edx / dist) * swirl_accel
							e.vx = evx
							e.vy = evy
							# PORT: web/src/tilt-to-live/WeaponSystem.ts:230
							var direct_suction: float = (90.0 + 340.0 * t) * dt * gravity_multiplier
							e.x = ex + (edx / dist) * direct_suction
							e.y = ey + (edy / dist) * direct_suction

				# Pulsing grid distortion. PORT: web/src/tilt-to-live/WeaponSystem.ts:238-239
				var pulse: float = 1.0 + 0.35 * sin((w.max_duration - w.duration) * 8.0)
				grid.apply_implosion(w.x, w.y, 16.0 * pulse, pull_radius * 0.85)

				# Accretion dust motes. PORT: web/src/tilt-to-live/WeaponSystem.ts:242-252
				if randf() < 0.45:
					var angle: float = randf() * PI * 2.0
					# PORT: web/src/tilt-to-live/WeaponSystem.ts:244
					var spawn_r: float = 50.0 + randf() * (pull_radius * 0.5)
					# PORT: web/src/tilt-to-live/WeaponSystem.ts:249
					particles.emit_sparks(
						w.x + cos(angle) * spawn_r,
						w.y + sin(angle) * spawn_r,
						1,
						Color("#b84dff") if randf() < 0.5 else Color("#00e5ff"),
						70.0
					)

		if w.duration <= 0.0:
			if w.type == Types.WeaponType.NUKE and not data.get("fallout", false):
				_nuke_ended(w, data, enemies)
			if w.type == Types.WeaponType.VORTEX:
				# Collapse shockwave. PORT: web/src/tilt-to-live/WeaponSystem.ts:258-277
				var supernova_collapse: bool = data.get("supernovaCollapse", false)
				# PORT: web/src/tilt-to-live/WeaponSystem.ts:260
				# PORT-NOTE: the collapse radii (260.0, Tuning.SUPERNOVA_SHOCKWAVE) are not
				# multiplied by scale, unlike the pull radius (:520) — preserved deliberately
				# as written.
				var blast_radius: float = (
					Tuning.SUPERNOVA_SHOCKWAVE if supernova_collapse else 260.0
				)
				var blast_radius2: float = blast_radius * blast_radius
				# PORT-NOTE: the collapse plays playNuke() (:262), not a vortex sound —
				# preserved deliberately as written.
				audio.play_nuke()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:262
				# PORT: web/src/tilt-to-live/WeaponSystem.ts:263-264
				particles.emit_explosion(
					w.x, w.y, Color("#9d4edd"), 65 if supernova_collapse else 45
				)
				particles.emit_explosion(w.x, w.y, Color("#00f0ff"), 35)
				# PORT: web/src/tilt-to-live/WeaponSystem.ts:265
				grid.apply_explosion(
					w.x, w.y, 32.0 if supernova_collapse else 22.0, blast_radius + 140.0
				)

				for e_idx: int in range(enemies.size() - 1, -1, -1):
					var e: PerilEnemy = enemies[e_idx]
					var dx: float = e.x - w.x
					var dy: float = e.y - w.y
					if dx * dx + dy * dy <= blast_radius2:
						on_enemy_killed.call(e, Types.WeaponType.VORTEX)
						# PORT: web/src/tilt-to-live/WeaponSystem.ts:273
						particles.emit_sparks(e.x, e.y, 12, Color("#c77dff"), 200.0)
						enemies.remove_at(e_idx)
			active_weapons.remove_at(i)

	# 4. Update Homing Missiles. PORT: web/src/tilt-to-live/WeaponSystem.ts:282-358
	# DIVERGENCE(M11c P32): the target lookup, retarget and contact scans read one
	# snapshot of the enemies (x, y, radius, id, taken once and again after any blast
	# removes enemies) instead of every missile reading every Enemy object twice per
	# tick. Enemies do not move inside this loop, so the snapshot holds their values;
	# the contact scan reads only enemies within the largest radius + 8 px in x, a
	# superset of any hit; the retarget scans the snapshot in array order with the same
	# arithmetic. Every outcome is the full scans'.
	var snap_dirty: bool = true
	for i: int in range(missiles.size() - 1, -1, -1):
		if snap_dirty:
			_missile_snapshot(enemies)
			snap_dirty = false
		var m: Types.HomingMissile = missiles[i]
		m.lifetime -= dt
		m.smoke_timer += dt

		if m.smoke_timer > 0.03:  # PORT: web/src/tilt-to-live/WeaponSystem.ts:289
			m.smoke_timer = 0.0
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:291
			particles.emit_smoke(m.x, m.y, Color(1.0, 140.0 / 255.0, 20.0 / 255.0, 0.45))

		# Retarget the closest enemy if the current target died or is missing.
		# PORT: web/src/tilt-to-live/WeaponSystem.ts:294-306
		var target: PerilEnemy = _snap_by_id.get(m.target_id, null)
		if target == null and enemies.size() > 0:
			var best_dist: float = INF
			var best: int = -1
			for k: int in range(_snap_x.size()):
				var sx: float = _snap_x[k]
				var sy: float = _snap_y[k]
				var d: float = (sx - m.x) * (sx - m.x) + (sy - m.y) * (sy - m.y)
				if d < best_dist:
					best_dist = d
					best = k
			if best >= 0:
				target = enemies[best]
				m.target_id = target.id

		# Homing guidance. PORT: web/src/tilt-to-live/WeaponSystem.ts:308-319
		if target != null:
			var dx: float = target.x - m.x
			var dy: float = target.y - m.y
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > 1.0:
				# PORT: web/src/tilt-to-live/WeaponSystem.ts:314-317 (440, 9 — m.cruise and
				# m.agility, KEY R1's Hyper Thrusters raises them)
				var target_vx: float = (dx / dist) * m.cruise
				var target_vy: float = (dy / dist) * m.cruise
				m.vx += (target_vx - m.vx) * dt * m.agility
				m.vy += (target_vy - m.vy) * dt * m.agility

		m.x += m.vx * dt
		m.y += m.vy * dt

		# Contact with any enemy. PORT: web/src/tilt-to-live/WeaponSystem.ts:324-334
		var hit: bool = false
		var reach: float = _snap_max_r + 8.0 + 1.0 / SNAP_QUANT
		var lo: int = _snap_sorted_q.bsearch(m.x - reach, true)
		var hi: int = _snap_sorted_q.bsearch(m.x + reach, false)
		for t: int in range(lo, hi):
			var k: int = _snap_order[t]
			var edx: float = _snap_x[k] - m.x
			var edy: float = _snap_y[k] - m.y
			var er: float = _snap_r[k]
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:330
			# PORT-NOTE: the 8 px missile radius here is a fixed literal, not
			# multiplied by scale like every other range in this file — preserved
			# deliberately as written (WeaponSystem.ts:330).
			if edx * edx + edy * edy <= (er + 8.0) * (er + 8.0):
				hit = true
				break

		if hit or m.lifetime <= 0.0:
			# PORT-NOTE: stands in for `perks?.x.y || 0` (WeaponSystem.ts:338) — a
			# fresh WeaponPerks is all-zero, matching the fallback.
			var p: ProgressionManager.WeaponPerks = (
				perks if perks != null else ProgressionManager.WeaponPerks.new()
			)
			# Blast radius kills the cluster; perk-tuned via WeaponTuning.
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:338
			# PORT-NOTE: the blast radius is not multiplied by scale, unlike every
			# other tuned range in this file (:401, :442, :501, :520) — preserved
			# deliberately as written.
			var blast_radius: float = Tuning.get_tuned_value(
				"missiles", "blastRadius", p.missiles.blast_radius
			)
			var blast_radius2: float = blast_radius * blast_radius

			audio.play_missile_explode()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:341
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:342
			particles.emit_explosion(m.x, m.y, Color("#ff8800"), 18)
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:343
			grid.apply_explosion(m.x, m.y, 8.0, blast_radius)

			for e_idx: int in range(enemies.size() - 1, -1, -1):
				var e: PerilEnemy = enemies[e_idx]
				var edx: float = e.x - m.x
				var edy: float = e.y - m.y
				if edx * edx + edy * edy <= blast_radius2:
					on_enemy_killed.call(e, Types.WeaponType.MISSILES)
					# PORT: web/src/tilt-to-live/WeaponSystem.ts:351
					particles.emit_sparks(e.x, e.y, 10, Color("#ffaa33"), 180.0)
					enemies.remove_at(e_idx)
					snap_dirty = true

			# DIVERGENCE(KEY R1) Cluster Split: a first-generation blast splits into two short-lived
			# missiles (appended past i, so they fly from the next tick).
			if p.missiles.cluster_split and m.generation == 0:
				for k: int in range(2):
					var a: float = randf() * TAU
					var child: Types.HomingMissile = _new_missile(
						m.x, m.y, a, CLUSTER_CHILD_SPEED * maxf(0.72, scale)
					)
					child.generation = 1
					child.lifetime = CLUSTER_CHILD_LIFETIME
					missiles.append(child)

			missiles.remove_at(i)

	# DIVERGENCE(KEY R1) Second Salvo: launches that were queued behind a missiles pickup.
	for k: int in range(_salvo_timers.size() - 1, -1, -1):
		_salvo_timers[k] -= dt
		if _salvo_timers[k] <= 0.0:
			audio.play_missile_launch()
			_launch_missiles(player.x, player.y, _salvo_counts[k], enemies, perks)
			_salvo_timers.remove_at(k)
			_salvo_counts.remove_at(k)
	# DIVERGENCE(KEY R1) Overcharge: the power-up shield has ended — one pulse around the ship.
	if _overcharge_armed and not player.has_shield():
		_overcharge_armed = false
		audio.play_missile_explode()
		_burst(
			Vector2(player.x, player.y),
			OVERCHARGE_RADIUS * scale,
			Types.WeaponType.SHIELD,
			enemies,
			particles,
			grid,
			on_enemy_killed,
			Color("#3ddc97")
		)

	# 5. Fade out Lightning Arcs. PORT: web/src/tilt-to-live/WeaponSystem.ts:360-366
	for i: int in range(lightning_arcs.size() - 1, -1, -1):
		lightning_arcs[i].intensity -= dt * 4.0  # PORT: web/src/tilt-to-live/WeaponSystem.ts:362
		if lightning_arcs[i].intensity <= 0.0:
			lightning_arcs.remove_at(i)


## Fills the missile snapshot from enemies (see update's step 4, P32): x, y, radius
## in array order, id -> enemy, and x quantised to 1/SNAP_QUANT px (rounded down),
## sorted, with the array index for each.
func _missile_snapshot(enemies: Array[PerilEnemy]) -> void:
	var n: int = enemies.size()
	_snap_x.resize(n)
	_snap_y.resize(n)
	_snap_r.resize(n)
	_snap_by_id.clear()
	_snap_max_r = 0.0
	var keys: PackedInt64Array = PackedInt64Array()
	keys.resize(n)
	for k: int in range(n):
		var e: PerilEnemy = enemies[k]
		var ex: float = e.x
		_snap_x[k] = ex
		_snap_y[k] = e.y
		_snap_r[k] = e.radius
		_snap_max_r = maxf(_snap_max_r, _snap_r[k])
		_snap_by_id[e.id] = e
		keys[k] = (floori((ex + SNAP_OFFSET) * SNAP_QUANT) << SNAP_INDEX_BITS) | k
	keys.sort()
	_snap_order.resize(n)
	_snap_sorted_q.resize(n)
	for t: int in range(n):
		_snap_order[t] = keys[t] & ((1 << SNAP_INDEX_BITS) - 1)
		_snap_sorted_q[t] = float(keys[t] >> SNAP_INDEX_BITS) / SNAP_QUANT - SNAP_OFFSET


## Activates a weapon directly, without an orb. PORT: web/src/tilt-to-live/WeaponSystem.ts:369-384
# PORT-NOTE: WeaponSystem.ts:378 overloads its ninth parameter as either the
# kill callback or the perks record and dispatches on typeof (:381-382).
# GDScript has no union types; the two parameters are separate and typed, and
# an invalid Callable stands in for the omitted callback (:381's no-op). No
# caller exists in web/src (only the built dist) — ported under LAW 3.
func trigger_weapon(
	type: Types.WeaponType,
	x: float,
	y: float,
	player: PlayerShip,
	enemies: Array[PerilEnemy],
	particles: ParticleEngine,
	grid: VectorGrid,
	audio: AudioBank,
	on_enemy_killed: Callable = Callable(),
	perks: ProgressionManager.WeaponPerks = null
) -> void:
	var on_killed: Callable = (
		on_enemy_killed
		if on_enemy_killed.is_valid()
		else func(_e: PerilEnemy, _w: Types.WeaponType) -> void: pass
	)
	activate_weapon(type, x, y, player, enemies, particles, grid, audio, on_killed, perks)


## Activates a superweapon from an orb pickup. PORT: web/src/tilt-to-live/WeaponSystem.ts:386-557
func activate_weapon(
	type: Types.WeaponType,
	x: float,
	y: float,
	player: PlayerShip,
	enemies: Array[PerilEnemy],
	particles: ParticleEngine,
	grid: VectorGrid,
	audio: AudioBank,
	on_enemy_killed: Callable,
	perks: ProgressionManager.WeaponPerks = null
) -> void:
	# PORT-NOTE: stands in for every `perks?.x.y || 0` / `!!perks?.x.y` chain in
	# WeaponSystem.ts:401-551 — a fresh WeaponPerks is all-zero and all-false.
	var p: ProgressionManager.WeaponPerks = (
		perks if perks != null else ProgressionManager.WeaponPerks.new()
	)
	match type:
		Types.WeaponType.NUKE:
			audio.play_nuke()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:400
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:401
			var max_radius: float = Tuning.get_tuned_value("nuke", "radius", p.nuke.radius) * scale
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:402
			# PORT-NOTE: 0.25 per speed rank is written inline in the TS; WeaponTuning.ts:36
			# carries the same 25 % per rank but the TS does not read it — preserved as written.
			var duration: float = 0.65 / (1.0 + float(p.nuke.speed) * 0.25)
			var w: Types.ActiveWeapon = Types.ActiveWeapon.new()
			w.id = _next_weapon_id
			_next_weapon_id += 1
			w.type = Types.WeaponType.NUKE
			w.x = x
			w.y = y
			w.duration = duration
			w.max_duration = duration
			w.radius = 10.0 * scale  # PORT: web/src/tilt-to-live/WeaponSystem.ts:410
			w.max_radius = max_radius
			# DIVERGENCE(KEY R1) the nuke's keystones ride on the weapon, as the laser's and vortex's do.
			w.data = {
				"falloutZone": p.nuke.fallout_zone,
				"chainReaction": p.nuke.chain_reaction,
				"stunWave": p.nuke.stun_wave,
			}
			active_weapons.append(w)
		Types.WeaponType.MISSILES:
			audio.play_missile_launch()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:417
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:418
			# PORT-NOTE: written `8 + rank` inline in the TS; WeaponTuning.ts:43 is the
			# same row (base 8, perRank 1) and WeaponTuning.ts:5-9 mandates this read.
			var count: int = int(Tuning.get_tuned_value("missiles", "count", p.missiles.count))
			_launch_missiles(x, y, count, enemies, p)
			if p.missiles.second_salvo:  # DIVERGENCE(KEY R1)
				_salvo_timers.append(SECOND_SALVO_DELAY)
				_salvo_counts.append(count)
		Types.WeaponType.LIGHTNING:
			audio.play_lightning()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:438
			var current_origin: Vector2 = Vector2(x, y)
			# PORT-NOTE: Set<number> (:440) as a typed Array; membership via has().
			var visited_ids: Array[int] = []
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:441
			# PORT-NOTE: written `14 + rank * 3` inline in the TS; WeaponTuning.ts:52 is
			# the same row (base 14, perRank 3) and WeaponTuning.ts:5-9 mandates this read.
			var max_chains: int = int(
				Tuning.get_tuned_value("lightning", "maxTargets", p.lightning.max_targets)
			)
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:442
			var jump_range: float = (
				Tuning.get_tuned_value("lightning", "chainRange", p.lightning.chain_range) * scale
			)
			if p.lightning.superconductor:  # DIVERGENCE(KEY R1): jump range ×2
				jump_range *= 2.0

			# DIVERGENCE(KEY R1) Forked Lightning: a second chain from the pickup, sharing the struck set.
			for fork: int in range(2 if p.lightning.forked_lightning else 1):
				current_origin = Vector2(x, y)
				_chain_lightning(current_origin, max_chains, jump_range, enemies, visited_ids)

			# Kill every electrocuted dot. PORT: web/src/tilt-to-live/WeaponSystem.ts:487-495
			var struck: Array[Vector2] = []
			for e_idx: int in range(enemies.size() - 1, -1, -1):
				var e: PerilEnemy = enemies[e_idx]
				if visited_ids.has(e.id):
					on_enemy_killed.call(e, Types.WeaponType.LIGHTNING)
					# PORT: web/src/tilt-to-live/WeaponSystem.ts:492
					particles.emit_sparks(e.x, e.y, 12, Color("#ffee33"), 220.0)
					struck.append(Vector2(e.x, e.y))
					enemies.remove_at(e_idx)
			if p.lightning.plasma_arc:  # DIVERGENCE(KEY R1) Arc Detonation
				for at: Vector2 in struck:
					_burst(
						at,
						PLASMA_ARC_RADIUS * scale,
						Types.WeaponType.LIGHTNING,
						enemies,
						particles,
						grid,
						on_enemy_killed,
						Color("#ffee33")
					)
		Types.WeaponType.LASER:
			audio.play_laser_beam()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:500
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:501
			var beam_length: float = (
				Tuning.get_tuned_value("laser", "length", p.laser.length) * scale
			)
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:502
			# PORT-NOTE: written `1.8 + rank * 0.4` inline in the TS; WeaponTuning.ts:49 is
			# the same row (base 1.8, perRank 0.4) and WeaponTuning.ts:5-9 mandates this read.
			var duration: float = Tuning.get_tuned_value("laser", "duration", p.laser.duration)
			var w: Types.ActiveWeapon = Types.ActiveWeapon.new()
			w.id = _next_weapon_id
			_next_weapon_id += 1
			w.type = Types.WeaponType.LASER
			w.x = player.x  # PORT: web/src/tilt-to-live/WeaponSystem.ts:506
			w.y = player.y
			w.duration = duration
			w.max_duration = duration
			w.radius = beam_length
			w.angle = player.angle  # PORT: web/src/tilt-to-live/WeaponSystem.ts:511
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:512 — key spelled as the TS does
			w.data = {
				"crossBeam": p.laser.cross_beam,
				"heavyBeam": p.laser.heavy_beam,  # DIVERGENCE(KEY R1)
				"rapidSweep": p.laser.rapid_sweep,
			}
			active_weapons.append(w)
		Types.WeaponType.VORTEX:
			audio.play_vortex()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:518
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:519
			# PORT-NOTE: written `4.8 + rank * 0.5` inline in the TS; WeaponTuning.ts:31 is
			# the same row (base 4.8, perRank 0.5) and WeaponTuning.ts:5-9 mandates this read.
			var duration: float = Tuning.get_tuned_value(
				"blackhole", "duration", p.blackhole.duration
			)
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:520
			var radius: float = (
				Tuning.get_tuned_value("blackhole", "radius", p.blackhole.radius) * scale
			)
			var w: Types.ActiveWeapon = Types.ActiveWeapon.new()
			w.id = _next_weapon_id
			_next_weapon_id += 1
			w.type = Types.WeaponType.VORTEX
			w.x = x
			w.y = y
			w.duration = duration
			w.max_duration = duration
			w.radius = radius
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:529-533 — keys spelled as the TS does
			w.data = {
				"invulnerableInside": p.blackhole.invulnerable_inside,
				"gravity": p.blackhole.gravity,
				"supernovaCollapse": p.blackhole.supernova_collapse,
				"eventHorizon": p.blackhole.event_horizon,  # DIVERGENCE(KEY R1)
				"darkHarvest": p.blackhole.dark_harvest,
			}
			active_weapons.append(w)
		Types.WeaponType.FREEZE:
			audio.play_freeze()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:539
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:540
			# PORT-NOTE: written `4.5 + rank * 0.7` inline in the TS; WeaponTuning.ts:56 is
			# the same row (base 4.5, perRank 0.7) and WeaponTuning.ts:5-9 mandates this read.
			var freeze_duration: float = Tuning.get_tuned_value(
				"freeze", "duration", p.freeze.duration
			)
			# PORT-NOTE: freezes inline exactly as WeaponSystem.ts:541-544 does, rather than
			# through EnemySwarm.freeze_all — this method receives the enemies array, not
			# the swarm, and the TS never calls freezeAll. See the M4 plan, Open question 2.
			for e: PerilEnemy in enemies:
				e.frozen = true
				e.freeze_timer = freeze_duration
			particles.emit_ice_shatter(x, y, 40)  # PORT: web/src/tilt-to-live/WeaponSystem.ts:545
			grid.apply_explosion(x, y, 10.0, 360.0 * scale)  # PORT: web/src/tilt-to-live/WeaponSystem.ts:546
			if p.freeze.cryo_nova:  # DIVERGENCE(KEY R1) Cryo Nova: the pickup kills what is near it
				_burst(
					Vector2(x, y),
					CRYO_NOVA_RADIUS * scale,
					Types.WeaponType.FREEZE,
					enemies,
					particles,
					grid,
					on_enemy_killed,
					Color("#88eeff")
				)
			if p.freeze.ice_armor:  # DIVERGENCE(KEY R1) Ice Armor
				player.activate_shield(ICE_ARMOR_SECONDS)
		Types.WeaponType.SHIELD:
			# PORT-NOTE: the TS plays no shield sound here (WeaponSystem.ts:550-554) —
			# only the orb-pickup sound (:95/:117 above) covers it. Preserved deliberately.
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:551
			# PORT-NOTE: written `6.0 + rank * 1.0` inline in the TS; WeaponTuning.ts:39 is
			# the same row (base 6.0, perRank 1.0) and WeaponTuning.ts:5-9 mandates this read.
			var shield_duration: float = Tuning.get_tuned_value(
				"shield", "duration", p.shield.duration
			)
			player.activate_shield(shield_duration)  # PORT: web/src/tilt-to-live/WeaponSystem.ts:552
			_overcharge_armed = p.shield.overcharge_pulse  # DIVERGENCE(KEY R1) Overcharge waits for the end
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:553
			particles.emit_sparks(player.x, player.y, 25, Color("#3ddc97"), 160.0)


## The TS's chain loop (WeaponSystem.ts:444-485), from `origin`: each jump strikes the
## nearest unstruck dot within `jump_range`, adding its id to `visited_ids` and an arc.
## DIVERGENCE(KEY R1): a function so Forked Lightning can run it twice.
func _chain_lightning(
	origin: Vector2,
	max_chains: int,
	jump_range: float,
	enemies: Array[PerilEnemy],
	visited_ids: Array[int]
) -> void:
	var current_origin: Vector2 = origin
	for chain: int in range(max_chains):
		var nearest_enemy: PerilEnemy = null
		var nearest_dist: float = jump_range

		for e: PerilEnemy in enemies:
			if visited_ids.has(e.id):
				continue
			var dx: float = e.x - current_origin.x
			var dy: float = e.y - current_origin.y
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = e

		if nearest_enemy != null:
			visited_ids.append(nearest_enemy.id)

			# Arc visual. PORT: web/src/tilt-to-live/WeaponSystem.ts:462-470
			var branches: Array[Vector2] = []
			var segments: int = 4  # PORT: web/src/tilt-to-live/WeaponSystem.ts:464
			for s: int in range(1, segments):
				var t: float = float(s) / float(segments)
				# PORT: web/src/tilt-to-live/WeaponSystem.ts:467-468
				var bx: float = (
					current_origin.x
					+ (nearest_enemy.x - current_origin.x) * t
					+ (randf() - 0.5) * 24.0 * scale
				)
				var by: float = (
					current_origin.y
					+ (nearest_enemy.y - current_origin.y) * t
					+ (randf() - 0.5) * 24.0 * scale
				)
				branches.append(Vector2(bx, by))

			var arc: Types.LightningArc = Types.LightningArc.new()
			arc.x1 = current_origin.x
			arc.y1 = current_origin.y
			arc.x2 = nearest_enemy.x
			arc.y2 = nearest_enemy.y
			arc.intensity = 1.0
			arc.branches = branches
			lightning_arcs.append(arc)

			current_origin = Vector2(nearest_enemy.x, nearest_enemy.y)
		else:
			break


## DIVERGENCE(KEY R1): kills every enemy within `radius` of `at` (a keystone's burst).
func _burst(
	at: Vector2,
	radius: float,
	type: Types.WeaponType,
	enemies: Array[PerilEnemy],
	particles: ParticleEngine,
	grid: VectorGrid,
	on_enemy_killed: Callable,
	color: Color
) -> void:
	particles.emit_explosion(at.x, at.y, color, 10)
	grid.apply_explosion(at.x, at.y, 8.0, radius)
	var r2: float = radius * radius
	for e_idx: int in range(enemies.size() - 1, -1, -1):
		var e: PerilEnemy = enemies[e_idx]
		if (e.x - at.x) * (e.x - at.x) + (e.y - at.y) * (e.y - at.y) <= r2:
			on_enemy_killed.call(e, type)
			particles.emit_sparks(e.x, e.y, 6, color, 160.0)
			enemies.remove_at(e_idx)


## DIVERGENCE(KEY R1): a nuke's blast has finished — Stun Wave freezes the survivors near it and
## Fallout Zone leaves its burn zone.
func _nuke_ended(w: Types.ActiveWeapon, data: Dictionary, enemies: Array[PerilEnemy]) -> void:
	var blast: float = w.max_radius if not is_nan(w.max_radius) else w.radius
	if data.get("stunWave", false):
		var reach2: float = (blast * STUN_WAVE_REACH) * (blast * STUN_WAVE_REACH)
		for e: PerilEnemy in enemies:
			if (e.x - w.x) * (e.x - w.x) + (e.y - w.y) * (e.y - w.y) <= reach2:
				e.frozen = true
				e.freeze_timer = maxf(e.freeze_timer, STUN_WAVE_SECONDS)
	if data.get("falloutZone", false):
		var zone: Types.ActiveWeapon = Types.ActiveWeapon.new()
		zone.id = _next_weapon_id
		_next_weapon_id += 1
		zone.type = Types.WeaponType.NUKE
		zone.x = w.x
		zone.y = w.y
		zone.duration = FALLOUT_SECONDS
		zone.max_duration = FALLOUT_SECONDS
		zone.radius = blast * FALLOUT_RADIUS_FRACTION
		zone.max_radius = zone.radius
		zone.data = {"fallout": true}
		active_weapons.append(zone)


## One salvo of `count` homing missiles from (x, y).
## PORT: web/src/tilt-to-live/WeaponSystem.ts:419-432
## DIVERGENCE(KEY R1): a function so Second Salvo can fire again; Hyper Thrusters
## locks each missile on one of the nearest enemies and raises its speed and turn gain.
func _launch_missiles(
	x: float,
	y: float,
	count: int,
	enemies: Array[PerilEnemy],
	perks: ProgressionManager.WeaponPerks
) -> void:
	var p: ProgressionManager.WeaponPerks = (
		perks if perks != null else ProgressionManager.WeaponPerks.new()
	)
	# PORT: web/src/tilt-to-live/WeaponSystem.ts:419
	var speed_mult: float = 1.0 + float(p.missiles.flight_speed) * 0.2
	var locks: Array[PerilEnemy] = []
	if p.missiles.hyper_thrusters:
		locks = enemies.duplicate()
		locks.sort_custom(
			func(a: PerilEnemy, b: PerilEnemy) -> bool:
				return (a.x - x) ** 2 + (a.y - y) ** 2 < (b.x - x) ** 2 + (b.y - y) ** 2
		)
	for i: int in range(count):
		# PORT: web/src/tilt-to-live/WeaponSystem.ts:421
		var angle: float = (float(i) * PI * 2.0) / float(count) + (randf() * 0.4 - 0.2)
		# PORT: web/src/tilt-to-live/WeaponSystem.ts:422
		var speed: float = (260.0 + randf() * 80.0) * speed_mult * maxf(0.72, scale)
		var m: Types.HomingMissile = _new_missile(x, y, angle, speed)
		if p.missiles.hyper_thrusters:
			m.cruise = HYPER_CRUISE
			m.agility = HYPER_AGILITY
			if not locks.is_empty():
				m.target_id = locks[posmod(i, locks.size())].id
		missiles.append(m)


## A missile at (x, y) flying at `angle`. PORT: web/src/tilt-to-live/WeaponSystem.ts:423-432
func _new_missile(x: float, y: float, angle: float, speed: float) -> Types.HomingMissile:
	var m: Types.HomingMissile = Types.HomingMissile.new()
	m.id = _next_missile_id
	_next_missile_id += 1
	m.x = x
	m.y = y
	m.vx = cos(angle) * speed
	m.vy = sin(angle) * speed
	m.target_id = Types.ABSENT  # PORT: web/src/tilt-to-live/WeaponSystem.ts:429 (null)
	m.lifetime = 3.5  # PORT: web/src/tilt-to-live/WeaponSystem.ts:430
	m.smoke_timer = 0.0
	return m


## Returns a weapon type drawn from the weighted drop table.
## PORT: web/src/tilt-to-live/WeaponSystem.ts:559-580
# PORT-NOTE: `_gameMode` is unused in the TS too (:559) — preserved.
func get_random_weapon_type(
	_game_mode: Types.GameMode = Types.GameMode.CLASSIC
) -> Types.WeaponType:
	# PORT: web/src/tilt-to-live/WeaponSystem.ts:562-570 — insertion order is the
	# walk order of Object.entries (:572), so it is load-bearing.
	var weights: Dictionary[Types.WeaponType, int] = {
		Types.WeaponType.MISSILES: 20,
		Types.WeaponType.NUKE: 18,
		Types.WeaponType.LASER: 18,
		Types.WeaponType.LIGHTNING: 16,
		Types.WeaponType.FREEZE: 16,
		Types.WeaponType.SHIELD: 16,
		Types.WeaponType.VORTEX: 5,
	}
	var total: int = 0
	for w: int in weights.values():
		total += w
	var roll: float = randf() * float(total)  # PORT: web/src/tilt-to-live/WeaponSystem.ts:574
	for t: Types.WeaponType in weights.keys():
		var w: int = weights[t]
		if roll < float(w):
			return t
		roll -= float(w)
	return Types.WeaponType.MISSILES  # PORT: web/src/tilt-to-live/WeaponSystem.ts:579


## Spawns a floating weapon orb. PORT: web/src/tilt-to-live/WeaponSystem.ts:582-598
func spawn_orb(
	bounds: Vector2,
	# PORT-NOTE: WeaponSystem.ts:586 falls back to getRandomWeaponType() when the
	# type is omitted; no game caller omits it, so the default is a fixed type
	specific_type: Types.WeaponType = Types.WeaponType.NUKE,
	custom_x: float = NAN,
	custom_y: float = NAN
) -> Types.WeaponOrb:
	var pad: float = maxf(30.0, 60.0 * scale)  # PORT: web/src/tilt-to-live/WeaponSystem.ts:583
	# PORT: web/src/tilt-to-live/WeaponSystem.ts:584-585
	var x: float = custom_x if not is_nan(custom_x) else (pad + randf() * (bounds.x - pad * 2.0))
	var y: float = custom_y if not is_nan(custom_y) else (pad + randf() * (bounds.y - pad * 2.0))

	var orb: Types.WeaponOrb = Types.WeaponOrb.new()
	orb.id = _next_orb_id
	_next_orb_id += 1
	orb.type = specific_type
	orb.x = x
	orb.y = y
	orb.radius = 16.0 * scale  # PORT: web/src/tilt-to-live/WeaponSystem.ts:593
	orb.spawn_time = float(Time.get_ticks_msec()) / 1000.0
	orb.lifetime = 12.0  # PORT: web/src/tilt-to-live/WeaponSystem.ts:595
	orb.pulse_offset = randf() * PI * 2.0  # PORT: web/src/tilt-to-live/WeaponSystem.ts:596
	orbs.append(orb)
	return orb


## Returns signature neon color for a weapon type.
## PORT: web/src/tilt-to-live/WeaponSystem.ts:600-610
static func get_weapon_color(type: Types.WeaponType) -> Color:
	var c: Color = Color.WHITE
	match type:
		Types.WeaponType.NUKE:
			c = Color("#ff0055")
		Types.WeaponType.MISSILES:
			c = Color("#ff8800")
		Types.WeaponType.LIGHTNING:
			c = Color("#ffdd00")
		Types.WeaponType.LASER:
			c = Color("#cc22ff")
		Types.WeaponType.VORTEX:
			c = Color("#8822ff")
		Types.WeaponType.FREEZE:
			c = Color("#8fb0ff")
		Types.WeaponType.SHIELD:
			c = Color("#3ddc97")
		_:
			c = Color.WHITE
	return c
