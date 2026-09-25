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
