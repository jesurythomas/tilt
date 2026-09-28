## menu_backdrop.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts:70-75 (menu fields) and
##        :1650-1820 (updateMenuSimulation), per spec §5.1
class_name MenuBackdrop
extends RefCounted
## The live simulation behind the menu: an autopiloted ship that seeks orbs and
## dodges a seeker swarm. The second, independent sim instance (spec §5.2).
##
## PORT-NOTE: TiltGame.ts:1651 advances TiltGame.elapsed, which the run shares and
## resetRun zeroes (:1564); this instance keeps its own elapsed instead (M11a R14).
## PORT-NOTE: resizeCanvas (:2432-2436) never scales the menu entities, so they
## keep scale 1.0 — preserved deliberately (M11a R13).

## Strictly base power-ups. PORT: web/src/tilt-to-live/TiltGame.ts:1662
const BASE_TYPES: Array[Types.WeaponType] = [
	Types.WeaponType.NUKE,
	Types.WeaponType.MISSILES,
	Types.WeaponType.LASER,
	Types.WeaponType.FREEZE,
	Types.WeaponType.SHIELD,
	Types.WeaponType.LIGHTNING,
]
## The skinless ship's flame. PORT: web/src/tilt-to-live/PlayerShip.ts:241
const THRUSTER_COLOR: Color = Color("#00ddff")
## PORT: web/src/tilt-to-live/TiltGame.ts:1779
const SHIELD_BURST_COLOR: Color = Color("#5B8CFF")
## DIVERGENCE(UI R10, user 2026-09-28: "if left on the menu screen - it actually fills the
## map with enemies causing it to lose fps"): the TS runs EnemySwarm.update's own seeker
## timer and formation waves here uncapped (:1763-1770), and its ramp shortens both, so
## an idle menu climbed past 140 dots. They now act only below this count, and the
## menu's formations leave out the wall (72 dots at once on a phone), so one arrow,
## circle, turret or snake landing on the cap is the most there can be.
const SWARM_SPAWN_CAP: int = 24
const SWARM_FORMATIONS: Array[String] = ["arrow", "circle", "turret", "snake"]

## The autopiloted ship. PORT: web/src/tilt-to-live/TiltGame.ts:71
var menu_player: PlayerShip = PlayerShip.new(600.0, 350.0)
## PORT: web/src/tilt-to-live/TiltGame.ts:72
var menu_swarm: EnemySwarm = _capped_swarm()
## PORT: web/src/tilt-to-live/TiltGame.ts:73
var menu_weapons: WeaponSystem = WeaponSystem.new()
## Seconds this backdrop has run (M11a R14).
var elapsed: float = 0.0

var _menu_orb_timer: float = 0.0  # PORT: web/src/tilt-to-live/TiltGame.ts:74
var _menu_spawn_timer: float = 0.0  # PORT: web/src/tilt-to-live/TiltGame.ts:75
# PORT-NOTE: :1785-1805 builds a silent TiltAudio stub. An AudioBank that is never
# attach()ed has no playback, so every play_* returns at audio_bank.gd:305.
var _silent_audio: AudioBank = AudioBank.new()
var _particles: ParticleEngine = null


static func _capped_swarm() -> EnemySwarm:
	var swarm: EnemySwarm = EnemySwarm.new()
	swarm.spawn_cap = SWARM_SPAWN_CAP
	swarm.formation_pool = SWARM_FORMATIONS.duplicate()
	return swarm


## One step of the menu sim. PORT: web/src/tilt-to-live/TiltGame.ts:1650-1820
func update(dt: float, bounds: Vector2, grid: VectorGrid, particles: ParticleEngine) -> void:
	_particles = particles
	elapsed += dt
	grid.update(dt)
	particles.update(dt)

	# 1. Maintain 2 to 3 base weapon orbs. PORT: web/src/tilt-to-live/TiltGame.ts:1660-1669
	_menu_orb_timer -= dt
	if menu_weapons.orbs.size() < 2 and _menu_orb_timer <= 0.0:
		var chosen: Types.WeaponType = BASE_TYPES[floori(randf() * BASE_TYPES.size())]
		# DIVERGENCE(M11a R1): the TS band x ∈ [0.38w, 0.93w] (:1665), mirrored to
		# stay clear of Main.dc.html's right-hand panel.
		var spawn_x: float = bounds.x - (bounds.x * 0.38 + randf() * (bounds.x * 0.55))
		var spawn_y: float = 80.0 + randf() * (bounds.y - 160.0)  # PORT: :1666
		menu_weapons.spawn_orb(bounds, chosen, spawn_x, spawn_y)
		_menu_orb_timer = 2.5 + randf() * 2.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1668

	# 2. Maintain 12 to 16 seekers. PORT: web/src/tilt-to-live/TiltGame.ts:1672-1676
	_menu_spawn_timer -= dt
	if menu_swarm.enemies.size() < 14 and _menu_spawn_timer <= 0.0:
		menu_swarm.spawn_seeker(bounds)
		_menu_spawn_timer = 0.5 + randf() * 0.4  # PORT: web/src/tilt-to-live/TiltGame.ts:1675

	# 3. Autopilot steer vector. PORT: web/src/tilt-to-live/TiltGame.ts:1679-1712
	var nearest_orb: Types.WeaponOrb = null
	var min_dist: float = INF
	for orb: Types.WeaponOrb in menu_weapons.orbs:
		var odx: float = orb.x - menu_player.x
		var ody: float = orb.y - menu_player.y
		var odist: float = sqrt(odx * odx + ody * ody)
		if odist < min_dist:
			min_dist = odist
			nearest_orb = orb

	var steer_x: float = 0.0
	var steer_y: float = 0.0
	if nearest_orb != null:
		var sdx: float = nearest_orb.x - menu_player.x
		var sdy: float = nearest_orb.y - menu_player.y
		var sdist: float = maxf(1.0, min_dist)
		steer_x = (sdx / sdist) * 290.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1699
		steer_y = (sdy / sdist) * 290.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1700
	else:
		# DIVERGENCE(M11a R1): the figure-8 wanders around cx = 0.62w (:1703),
		# mirrored to w - 0.62w with its x phase negated.
		var cx: float = bounds.x - bounds.x * 0.62
		var cy: float = bounds.y * 0.5  # PORT: web/src/tilt-to-live/TiltGame.ts:1704
		var angle: float = elapsed * 0.8  # PORT: web/src/tilt-to-live/TiltGame.ts:1705
		var wander_x: float = cx - cos(angle) * (bounds.x * 0.22)  # PORT: :1706
		var wander_y: float = cy + sin(angle * 2.0) * (bounds.y * 0.18)  # PORT: :1707
		var wdx: float = wander_x - menu_player.x
		var wdy: float = wander_y - menu_player.y
		var wdist: float = maxf(1.0, sqrt(wdx * wdx + wdy * wdy))
		steer_x = (wdx / wdist) * 160.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1711
		steer_y = (wdy / wdist) * 160.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1712

	# 4. Repulsion from nearby enemies. PORT: web/src/tilt-to-live/TiltGame.ts:1716-1727
	var danger_radius: float = 145.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1716
	for e: PerilEnemy in menu_swarm.enemies:
		var ex: float = menu_player.x - e.x
		var ey: float = menu_player.y - e.y
		var edist: float = sqrt(ex * ex + ey * ey)
		if edist < danger_radius and edist > 0.1:  # PORT: :1721
			# PORT: web/src/tilt-to-live/TiltGame.ts:1722
			var repulsion: float = pow((danger_radius - edist) / danger_radius, 1.8) * 520.0
			steer_x += (ex / edist) * repulsion
			steer_y += (ey / edist) * repulsion

	# 5. Boundary repulsion. PORT: web/src/tilt-to-live/TiltGame.ts:1730-1743
	# DIVERGENCE(M11a R1): the wide margin min(0.38w, 420) guarded the TS's left
	# sidebar; mirrored, it guards the right-hand panel and the 60 px one moves left.
	var panel_margin: float = minf(bounds.x * 0.38, 420.0)
	var edge_margin: float = 60.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1732
	var top_margin: float = 60.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1733
	var bot_margin: float = 60.0  # PORT: web/src/tilt-to-live/TiltGame.ts:1734
	if menu_player.x > bounds.x - panel_margin:
		steer_x -= ((menu_player.x - (bounds.x - panel_margin)) / panel_margin) * 450.0
	elif menu_player.x < edge_margin:
		steer_x += ((edge_margin - menu_player.x) / edge_margin) * 450.0
	if menu_player.y < top_margin:
		steer_y += ((top_margin - menu_player.y) / top_margin) * 380.0  # PORT: :1740
	elif menu_player.y > bounds.y - bot_margin:
		steer_y -= ((menu_player.y - (bounds.y - bot_margin)) / bot_margin) * 380.0  # PORT: :1742

	var target_pos: Vector2 = Vector2(menu_player.x + steer_x, menu_player.y + steer_y)

	# PORT: web/src/tilt-to-live/TiltGame.ts:1751-1760 — 'mouse', no move vector,
	# {sensitivity 1.0, deadzone 2}, no skin (hitbox/turn 1.0, PlayerShip.ts:107-108).
	menu_player.update(
		dt,
		target_pos,
		bounds,
		particles,
		Types.ControlMode.MOUSE,
		Vector2.ZERO,
		1.0,
		2.0,
		1.0,
		1.0,
		THRUSTER_COLOR,
		Vector2.ZERO
	)

	# PORT: web/src/tilt-to-live/TiltGame.ts:1763-1770
	menu_swarm.update(
		dt, Vector2(menu_player.x, menu_player.y), bounds, particles, 0, Types.GameMode.CLASSIC
	)

	# Defensive shield on a close call. PORT: web/src/tilt-to-live/TiltGame.ts:1773-1783
	for e: PerilEnemy in menu_swarm.enemies:
		var cdx: float = e.x - menu_player.x
		var cdy: float = e.y - menu_player.y
		var reach: float = e.radius + menu_player.radius + 6.0  # PORT: :1776
		if cdx * cdx + cdy * cdy <= reach * reach:
			if not menu_player.has_shield():
				menu_player.activate_shield(3.0)  # PORT: web/src/tilt-to-live/TiltGame.ts:1778
				# PORT: web/src/tilt-to-live/TiltGame.ts:1779
				particles.emit_explosion(menu_player.x, menu_player.y, SHIELD_BURST_COLOR, 14)
				grid.apply_explosion(menu_player.x, menu_player.y, 8.0, 80.0)  # PORT: :1780

	# PORT: web/src/tilt-to-live/TiltGame.ts:1808-1819
	menu_weapons.update(
		dt, menu_player, menu_swarm.enemies, bounds, particles, grid, _silent_audio, _on_killed
	)


# PORT: web/src/tilt-to-live/TiltGame.ts:1816-1818
func _on_killed(dead: PerilEnemy, _weapon_type: Types.WeaponType) -> void:
	menu_swarm.on_enemy_killed(dead, _particles)
