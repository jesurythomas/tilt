## pixel_native_draw.gd — M11c N4 render check: the native enemy loop
## (PerilEnemyDrawer) must draw exactly what EntityLayer's GDScript loop draws.
## Windowed (the headless dummy renderer draws nothing); not in the suite:
##   "$GODOT" --path godot --render-thread safe -s addons/gut/gut_cmdln.gd -gtest=res://bench/pixel_native_draw.gd -gexit
extends GutTest

const BOUNDS: Vector2 = Vector2(1280.0, 720.0)


func after_each() -> void:
	EntityLayer.use_native_draw = true


## Every _draw_enemies branch: seekers (plain, chilled, hazard), frozen dots, turret
## dots with and without an indicator, a wall, carriers + satellites, artillery with a
## muzzle flash, pulsars, specters, bullets, aiming and charging chargers.
func _swarm() -> EnemySwarm:
	seed(99)
	var sw: EnemySwarm = EnemySwarm.new()
	sw.scale = 1.25
	var c: Vector2 = BOUNDS * 0.5
	for i: int in range(60):
		var e: PerilEnemy = sw.spawn_seeker(BOUNDS, randf() * BOUNDS.x, randf() * BOUNDS.y)
		e.chilled = i % 7 == 0
		e.is_hazard = i % 5 == 0
		e.frozen = i % 9 == 0
		e.radius += float(i % 3) * 0.37
	sw.spawn_wall_formation(BOUNDS)
	for i: int in range(6):
		sw.spawn_turret(BOUNDS)
	for i: int in range(sw.enemies.size()):
		var e: PerilEnemy = sw.enemies[i]
		if e.type == Types.EnemyType.TURRET_DOT and i % 2 == 0:
			e.target_angle = float(i) * 0.7
	for i: int in range(2):
		sw.spawn_carrier(BOUNDS, c)
		sw.spawn_artillery(BOUNDS, c)
		sw.spawn_pulsar(BOUNDS, c)
		sw.spawn_specter(BOUNDS, c)
		sw.spawn_bullet(c.x + 100.0 * i, c.y, c + Vector2(300.0, 40.0))
		var ch: PerilEnemy = sw.spawn_charger(BOUNDS, c)
		ch.state = Types.EnemyState.AIMING if i == 0 else Types.EnemyState.CHARGING
		ch.vx = 30.0
		ch.vy = -12.0
	for e: PerilEnemy in sw.enemies:
		if e.type == Types.EnemyType.ARTILLERY:
			e.fire_cooldown = 0.3
		e.x = clampf(e.x, 30.0, BOUNDS.x - 30.0)
		e.y = clampf(e.y, 30.0, BOUNDS.y - 30.0)
	return sw


func _alt_skin() -> ProgressionManager.EnemySkinConfig:
	var skin: ProgressionManager.EnemySkinConfig = ProgressionManager.EnemySkinConfig.new()
	skin.id = "pixel_check"
	skin.glow_color = Color(0.2, 1.0, 0.4, 0.5)
	skin.body_gradient = [Color("#aaffcc"), Color("#22aa66"), Color("#103020")]
	skin.pupil_color = Color("#001100")
	skin.border_color = Color("#66ffaa")
	return skin


func _render(native: bool, skin: ProgressionManager.EnemySkinConfig, halo: bool) -> Image:
	EntityLayer.use_native_draw = native
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(BOUNDS)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(vp)
	var layer: EntityLayer = EntityLayer.new()
	vp.add_child(layer)
	layer.bind_entities(null, _swarm(), null, null)
	layer.set_model_scale(1.5)
	layer.set_arena_origin(Vector2(7.0, 5.0))
	layer.set_enemy_skin(skin)
	layer.set_high_contrast_halo(halo)
	layer.set_elapsed(3.217)
	var img: Image = null
	for f: int in range(3):
		seed(4242)  # the charging plume draws randf()
		layer.queue_redraw()
		await RenderingServer.frame_post_draw
	img = vp.get_texture().get_image()
	return img


func _differing(a: Image, b: Image) -> int:
	var n: int = 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func _lit(a: Image) -> int:
	var bg: Color = a.get_pixel(0, 0)
	var n: int = 0
	for y: int in range(0, a.get_height(), 2):
		for x: int in range(0, a.get_width(), 2):
			if a.get_pixel(x, y) != bg:
				n += 1
	return n


func _check(skin: ProgressionManager.EnemySkinConfig, halo: bool, label: String) -> void:
	var ref: Image = await _render(false, skin, halo)
	var nat: Image = await _render(true, skin, halo)
	var diff: int = _differing(ref, nat)
	var lit: int = _lit(ref)
	print(
		(
			"PIXEL %s: %d of %d px differ (%d lit samples)"
			% [label, diff, ref.get_width() * ref.get_height(), lit]
		)
	)
	assert_gt(lit, 5000, "the reference drew the swarm")
	assert_eq(diff, 0, label)


func test_no_skin_halo_on() -> void:
	await _check(null, true, "no skin, halo on")


func test_alt_skin_halo_off() -> void:
	await _check(_alt_skin(), false, "alt skin, halo off")
