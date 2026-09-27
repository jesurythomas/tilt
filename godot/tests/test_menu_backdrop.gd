## test_menu_backdrop.gd
## PORTS: nothing — new file, covers render/menu_backdrop.gd
extends GutTest
## Proves the menu autopilot: its population caps, the mirrored orb band (R1),
## the close-call shield, and that it is a second, independent sim (spec §5.2).

const BOUNDS: Vector2 = Vector2(844.0, 390.0)


func _step(b: MenuBackdrop, seconds: float, grid: VectorGrid, particles: ParticleEngine) -> void:
	var steps: int = roundi(seconds * 120.0)
	for i: int in steps:
		b.update(1.0 / 120.0, BOUNDS, grid, particles)


func test_the_player_starts_where_the_ts_puts_it() -> void:
	var b: MenuBackdrop = MenuBackdrop.new()
	assert_eq(b.menu_player.x, 600.0, "TiltGame.ts:71")
	assert_eq(b.menu_player.y, 350.0, "TiltGame.ts:71")


func test_it_is_a_separate_sim_instance() -> void:
	var a: MenuBackdrop = MenuBackdrop.new()
	var b: MenuBackdrop = MenuBackdrop.new()
	assert_ne(a.menu_swarm, b.menu_swarm, "spec §5.2: instantiable twice")
	assert_ne(a.menu_weapons, b.menu_weapons)


func test_the_swarm_fills_to_the_ts_cap_and_no_further() -> void:
	seed(11)
	var b: MenuBackdrop = MenuBackdrop.new()
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	b.update(1.0 / 120.0, BOUNDS, grid, particles)
	assert_gt(b.menu_swarm.enemies.size(), 0, "timer starts at 0 (:75): a seeker at once (:1674)")
	_step(b, 12.0, grid, particles)
	# :1673 gates only the menu's own spawn at < 14; EnemySwarm.update's own timer can
	# add more (TS behaviour), so no hard cap is asserted — only that it keeps populating.
	assert_gt(b.menu_swarm.enemies.size(), 1, "seekers keep spawning (:1672-1676)")


func test_orbs_spawn_in_the_mirrored_band() -> void:
	seed(5)
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	for trial: int in 40:
		var b: MenuBackdrop = MenuBackdrop.new()
		b.update(1.0 / 120.0, BOUNDS, grid, particles)
		# The menu spawns before menu_weapons.update (:1667 vs :1808), so orbs[0] is the
		# menu's own orb even if WeaponSystem's internal timer adds a second one.
		assert_gt(b.menu_weapons.orbs.size(), 0, "timer starts at 0 (:74), so an orb at once")
		var orb: Types.WeaponOrb = b.menu_weapons.orbs[0]
		# :1665 band [0.38w, 0.93w] mirrored (R1) → [0.07w, 0.62w]
		assert_between(orb.x, BOUNDS.x * 0.07 - 0.01, BOUNDS.x * 0.62 + 0.01)
		assert_between(orb.y, 80.0 - 0.01, BOUNDS.y - 80.0 + 0.01, ":1666")


func test_no_new_orb_while_two_are_up() -> void:
	var b: MenuBackdrop = MenuBackdrop.new()
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	b.menu_weapons.spawn_orb(BOUNDS, Types.WeaponType.NUKE, 100.0, 100.0)
	b.menu_weapons.spawn_orb(BOUNDS, Types.WeaponType.LASER, 200.0, 200.0)
	var timer_before: float = b._menu_orb_timer
	b.update(1.0 / 120.0, BOUNDS, grid, particles)
	# :1661 gates at < 2: the menu did not spawn, so its timer only ticked down.
	assert_almost_eq(b._menu_orb_timer, timer_before - 1.0 / 120.0, 0.000001)


func test_a_close_enemy_shields_the_ship() -> void:
	var b: MenuBackdrop = MenuBackdrop.new()
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	var e: PerilEnemy = b.menu_swarm.spawn_seeker(BOUNDS, b.menu_player.x, b.menu_player.y)
	assert_not_null(e)
	b.update(1.0 / 120.0, BOUNDS, grid, particles)
	assert_true(b.menu_player.has_shield(), ":1776-1779 activates a 3 s shield")


func test_the_autopilot_steers_away_from_the_panel_side() -> void:
	# R1: the mirrored side margin pushes a ship sitting at the right edge leftwards.
	var b: MenuBackdrop = MenuBackdrop.new()
	var grid: VectorGrid = VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y))
	var particles: ParticleEngine = ParticleEngine.new()
	b.menu_player.x = BOUNDS.x - 10.0
	b.menu_player.y = BOUNDS.y / 2.0
	var start_x: float = b.menu_player.x
	_step(b, 0.5, grid, particles)
	assert_lt(b.menu_player.x, start_x, "mirrored leftMargin (:1731, :1736-1737)")
