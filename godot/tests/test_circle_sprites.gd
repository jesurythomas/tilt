## test_circle_sprites.gd
## Covers the shared disc/ring textures that replace draw_circle/draw_arc on the hot
## paths (M11c P5).
extends GutTest


func _alpha_at(tex: Texture2D, texel: Vector2i) -> float:
	return tex.get_image().get_pixelv(texel).a


func test_disc_is_opaque_inside_and_clear_outside() -> void:
	var tex: Texture2D = CircleSprites.disc()
	var half: int = CircleSprites.TEX_SIZE / 2
	assert_almost_eq(_alpha_at(tex, Vector2i(half, half)), 1.0, 0.01, "centre")
	assert_almost_eq(_alpha_at(tex, Vector2i(0, 0)), 0.0, 0.01, "corner")
	assert_almost_eq(_alpha_at(tex, Vector2i(half, 0)), 0.0, 0.01, "outermost texel row")


func test_disc_rect_maps_the_edge_onto_the_radius() -> void:
	var rect: Rect2 = CircleSprites.disc_rect(Vector2(100.0, 50.0), 10.0)
	assert_almost_eq(rect.get_center().x, 100.0, 0.0001)
	assert_almost_eq(rect.get_center().y, 50.0, 0.0001)
	# The half-alpha edge sits at DISC_EDGE of the texture half-size.
	assert_almost_eq(rect.size.x * 0.5 * CircleSprites.DISC_EDGE, 10.0, 0.0001)


func test_ring_textures_are_shared_per_ratio_step() -> void:
	var a: int = CircleSprites.ring_key(13.0, 1.2)
	var b: int = CircleSprites.ring_key(13.05, 1.2)
	var c: int = CircleSprites.ring_key(6.0, 1.2)
	assert_eq(a, b, "near-equal ratios share a texture")
	assert_ne(a, c, "a different ratio gets its own")
	assert_same(CircleSprites.ring(a), CircleSprites.ring(a), "memoised")


func test_ring_is_opaque_on_its_line_and_clear_at_its_centre() -> void:
	var key: int = CircleSprites.ring_key(10.0, 2.5)
	var tex: Texture2D = CircleSprites.ring(key)
	var half: int = CircleSprites.TEX_SIZE / 2
	var line: int = half + roundi(CircleSprites.ring_centre(key) * half)
	assert_almost_eq(_alpha_at(tex, Vector2i(half, half)), 0.0, 0.01, "hollow centre")
	assert_gt(_alpha_at(tex, Vector2i(line, half)), 0.9, "on the stroke")
	assert_almost_eq(_alpha_at(tex, Vector2i(half * 2 - 1, half)), 0.0, 0.01, "outside")


func test_ring_rect_maps_the_centre_line_onto_the_radius() -> void:
	var key: int = CircleSprites.ring_key(13.0, 1.2)
	var rect: Rect2 = CircleSprites.ring_rect(Vector2.ZERO, 13.0, key)
	assert_almost_eq(rect.size.x * 0.5 * CircleSprites.ring_centre(key), 13.0, 0.0001)


func test_small_rings_are_faithful_as_textures() -> void:
	# Dot halo and border: one texel stays under a screen pixel.
	assert_true(CircleSprites.ring_is_faithful(13.0, 1.2), "dot halo")
	assert_true(CircleSprites.ring_is_faithful(8.75, 1.2), "dot border")


func test_large_thin_rings_are_not_faithful_as_textures() -> void:
	# Final review (Important): the kill shockwave grows to ~85 px at width 1 — one
	# texel would span ~2.9 px and the stroke ratio falls below RATIO_STEP.
	assert_false(CircleSprites.ring_is_faithful(85.0, 1.0), "late shockwave")
	assert_false(CircleSprites.ring_is_faithful(40.0, 2.0), "mid shockwave, texel > 1 px")


func test_bake_layers_composites_in_order() -> void:
	# A 20 px red disc under a 10 px blue disc, 48 px texture (M11c P13).
	var tex: ImageTexture = CircleSprites.bake_layers(
		48,
		PackedFloat32Array([20.0, 10.0]),
		PackedFloat32Array([0.0, 0.0]),
		PackedColorArray([Color.RED, Color.BLUE])
	)
	var img: Image = tex.get_image()
	assert_eq(img.get_size(), Vector2i(48, 48))
	assert_true(img.get_pixel(24, 24).is_equal_approx(Color.BLUE), "later layer on top")
	assert_true(img.get_pixel(24, 24 + 15).is_equal_approx(Color.RED), "earlier layer outside")
	assert_almost_eq(img.get_pixel(0, 0).a, 0.0, 0.01, "clear corner")


func test_bake_layers_ring_is_hollow() -> void:
	var tex: ImageTexture = CircleSprites.bake_layers(
		48, PackedFloat32Array([15.0]), PackedFloat32Array([2.0]), PackedColorArray([Color.WHITE])
	)
	var img: Image = tex.get_image()
	assert_almost_eq(img.get_pixel(24, 24).a, 0.0, 0.01, "hollow centre")
	assert_gt(img.get_pixel(24, 24 + 15).a, 0.9, "on the line")


func test_dot_sprites_are_cached_until_the_look_changes() -> void:
	var layer: EntityLayer = EntityLayer.new()
	autofree(layer)
	layer.set_model_scale(1.5)
	var a: EntityLayer.DotSprites = layer._dot_sprites(10.0, false, false)
	assert_same(layer._dot_sprites(10.0, false, false), a, "same look reuses the bake")
	assert_ne(layer._dot_sprites(10.0, true, false), a, "chilled is its own look")
	layer.set_model_scale(1.0)
	assert_ne(layer._dot_sprites(10.0, false, false), a, "a new model scale rebakes")
	# Sized to the drawn pixels: (radius + 0.6) * scale + 1 each side.
	assert_eq(a.inner_half, ceilf(((10.0 + 0.6) * 1.5 + 1.0) * 2.0) * 0.5)


func test_dot_sprites_survive_a_skin_round_trip() -> void:
	# M11c review fix: menu (no skin) <-> run (equipped skin) must not rebake.
	var layer: EntityLayer = EntityLayer.new()
	autofree(layer)
	layer.set_model_scale(1.5)
	var skin: ProgressionManager.EnemySkinConfig = (
		ProgressionManager.new().get_equipped_enemy_skin()
	)
	layer.set_enemy_skin(skin)
	var in_run: EntityLayer.DotSprites = layer._dot_sprites(10.0, false, false)
	layer.set_enemy_skin(null)
	var in_menu: EntityLayer.DotSprites = layer._dot_sprites(10.0, false, false)
	assert_ne(in_menu, in_run, "a different look bakes its own")
	layer.set_enemy_skin(skin)
	assert_same(layer._dot_sprites(10.0, false, false), in_run, "back in a run: reused")
	layer.set_high_contrast_halo(false)
	assert_ne(layer._dot_sprites(10.0, false, false), in_run, "the halo is part of the look")
