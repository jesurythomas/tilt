## weapon_system.gd
## PORTS: web/src/tilt-to-live/WeaponSystem.ts (924 lines, source commit 7be9614)
class_name WeaponSystem
extends RefCounted
## Weapon orb spawning and superweapon detonation engine.
##
## PORT-NOTE: partial port for Module 2 per spec §8 M2. Implements orb spawning,
## player-orb collection, and the nuke superweapon. Remaining 6 weapons land in
## Module 4.
##
## PORT-NOTE: WeaponSystem.render() relocates to render/entity_layer.gd (spec §4.2/D4)
## because CanvasItem 2D drawing belongs to Node2D render layers.

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

## Scale factor for orb and blast radius. PORT: web/src/tilt-to-live/WeaponSystem.ts:35
var scale: float = 1.0

var _next_orb_id: int = 1
var _next_weapon_id: int = 1
var _next_missile_id: int = 1
var _orb_spawn_timer: float = 2.0  # PORT: web/src/tilt-to-live/WeaponSystem.ts:23


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


## Updates orb spawning, collection collisions, and active weapon expansion.
## PORT: web/src/tilt-to-live/WeaponSystem.ts:52-280
func update(
	dt: float,
	player: PlayerShip,
	enemies: Array[Types.Enemy],
	bounds: Vector2,
	particles: ParticleEngine,
	grid: VectorGrid,
	audio: AudioBank,
	on_enemy_killed: Callable,
	_perks: Variant = null,
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
				orb.type, orb.x, orb.y, player, enemies, particles, grid, audio, on_enemy_killed
			)
			if on_weapon_activated.is_valid():
				on_weapon_activated.call(orb.type)
			audio.play_orb_pickup()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:95
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:96
			particles.emit_sparks(orb.x, orb.y, 20, get_weapon_color(orb.type), 140.0)
			orbs.remove_at(i)

	# 3. Update Active Weapons (Nuke). PORT: web/src/tilt-to-live/WeaponSystem.ts:101-280
	for i: int in range(active_weapons.size() - 1, -1, -1):
		var w: Types.ActiveWeapon = active_weapons[i]
		w.duration -= dt

		match w.type:
			Types.WeaponType.NUKE:
				# Expanding blast ring. PORT: web/src/tilt-to-live/WeaponSystem.ts:108-111
				var progress: float = 1.0 - w.duration / w.max_duration
				var base_radius: float = (
					w.max_radius
					if not is_nan(w.max_radius)
					else (Tuning.get_tuned_value("nuke", "radius", 0) * scale)
				)
				w.radius = base_radius * progress

				# Vaporize enemies inside blast radius.
				# PORT: web/src/tilt-to-live/WeaponSystem.ts:113-124
				for e_idx: int in range(enemies.size() - 1, -1, -1):
					var e: Types.Enemy = enemies[e_idx]
					var edx: float = e.x - w.x
					var edy: float = e.y - w.y
					var e_dist: float = sqrt(edx * edx + edy * edy)

					if e_dist <= w.radius + e.radius + 15.0:  # PORT: web/src/tilt-to-live/WeaponSystem.ts:119
						on_enemy_killed.call(e, Types.WeaponType.NUKE)
						# PORT: web/src/tilt-to-live/WeaponSystem.ts:121
						particles.emit_explosion(e.x, e.y, Color("#ff3366"), 16)
						enemies.remove_at(e_idx)

				# Distort grid outward. PORT: web/src/tilt-to-live/WeaponSystem.ts:127
				grid.apply_explosion(w.x, w.y, 16.0, w.radius + 30.0)
			_:
				# TODO(M4): update logic for laser, vortex, missiles, etc.
				pass

		if w.duration <= 0.0:
			active_weapons.remove_at(i)


## Activates a superweapon from an orb pickup. PORT: web/src/tilt-to-live/WeaponSystem.ts:386-557
func activate_weapon(
	type: Types.WeaponType,
	x: float,
	y: float,
	_player: PlayerShip,
	_enemies: Array[Types.Enemy],
	_particles: ParticleEngine,
	_grid: VectorGrid,
	audio: AudioBank,
	_on_enemy_killed: Callable,
	_perks: Variant = null
) -> void:
	match type:
		Types.WeaponType.NUKE:
			audio.play_nuke()  # PORT: web/src/tilt-to-live/WeaponSystem.ts:400
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:401-402
			var max_radius: float = Tuning.get_tuned_value("nuke", "radius", 0) * scale
			var duration: float = 0.65
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
			active_weapons.append(w)
		_:
			# TODO(M4): activation logic for missiles, lightning, laser, vortex, freeze, shield.
			pass


## Returns random weapon type based on game mode.
## PORT: web/src/tilt-to-live/WeaponSystem.ts:559-580
func get_random_weapon_type(
	_game_mode: Types.GameMode = Types.GameMode.CLASSIC
) -> Types.WeaponType:
	# In Module 2, returns NUKE so all spawned orbs are operable.
	# TODO(M4): weighted random selection across all 7 weapons.
	return Types.WeaponType.NUKE


## Spawns a floating weapon orb. PORT: web/src/tilt-to-live/WeaponSystem.ts:582-598
func spawn_orb(
	bounds: Vector2,
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
func get_weapon_color(type: Types.WeaponType) -> Color:
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
