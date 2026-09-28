## pixel_native_particles.gd — M11c N7c render check: the native particle loop
## (PerilParticleDrawer) must draw exactly what EffectLayer's GDScript loop draws.
## Windowed (the headless dummy renderer draws nothing); not in the suite:
##   "$GODOT" --path godot --render-thread safe -s addons/gut/gut_cmdln.gd -gtest=res://bench/pixel_native_particles.gd -gexit
extends GutTest

const BOUNDS: Vector2 = Vector2(1280.0, 720.0)
const DT: float = 1.0 / 120.0


func after_each() -> void:
	EffectLayer.use_native_draw = true


## Every shape: explosion sparks (circles, streaks) and rings of many ages (textured and
## draw_arc), ice and kinetic shards, snow, smoke and thruster streaks, fading.
func _engine() -> ParticleEngine:
	seed(11)
	var pe: ParticleEngine = ParticleEngine.new()
	for i: int in range(30):
		var x: float = 60.0 + randf() * (BOUNDS.x - 120.0)
		var y: float = 60.0 + randf() * (BOUNDS.y - 120.0)
		match i % 6:
			0, 1:
				pe.emit_explosion(x, y, Color(1.0, 0.3 + 0.02 * i, 0.2), 14)
			2:
				pe.emit_ice_shatter(x, y, 8)
			3:
				pe.emit_kinetic_ice_shards(x, y, 6)
			4:
				pe.emit_smoke(x, y)
				pe.emit_blizzard_snow(BOUNDS, 3)
			5:
				pe.emit_thruster_sparks(x, y, randf() * TAU)
		pe.step(DT)
		pe.flush()
	return pe


func _render(native: bool) -> Image:
	EffectLayer.use_native_draw = native
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(BOUNDS)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(vp)
	var layer: EffectLayer = EffectLayer.new()
	vp.add_child(layer)
	layer.bind(_engine(), null, null)
	layer.set_arena_origin(Vector2(7.0, 5.0))
	for f: int in range(3):
		layer.queue_redraw()
		await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


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
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			if a.get_pixel(x, y) != bg:
				n += 1
	return n


func test_native_particles_draw_the_same_pixels() -> void:
	var ref: Image = await _render(false)
	var nat: Image = await _render(true)
	var diff: int = _differing(ref, nat)
	var lit: int = _lit(ref)
	print(
		(
			"PIXEL particles: %d of %d px differ (%d lit)"
			% [diff, ref.get_width() * ref.get_height(), lit]
		)
	)
	assert_gt(lit, 5000, "the reference drew the particles")
	assert_eq(diff, 0, "particles")
