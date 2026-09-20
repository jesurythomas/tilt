## test_arena_inset.gd
## PORTS: nothing — new file, covers M2.5 spec §6.2.
extends GutTest
## The inset keeps the playfield clear of the device bezel and cutout without
## letterboxing the game.

## Vector2 stores float32 while clampf computes in float64, so a value clamped
## to an exact ceiling can round up by ~1e-5 px when stored. MAX_INSET_RATIO is
## a design intent, not an exact boundary, so these compare sub-pixel.
const FLOAT32_TOLERANCE: float = 0.001


func test_a_device_reporting_no_safe_area_still_gets_the_floor_inset() -> void:
	var viewport: Vector2 = Vector2(2340.0, 1080.0)
	var safe: Rect2 = Rect2(Vector2.ZERO, viewport)
	var inset: Vector2 = GameRoot.arena_inset(viewport, safe)
	assert_almost_eq(inset.x, GameRoot.MIN_INSET_X, 0.0001, "the floor applies with no cutout")
	assert_almost_eq(inset.y, GameRoot.MIN_INSET_Y, 0.0001, "the floor applies with no cutout")


func test_a_reported_cutout_widens_the_inset() -> void:
	var viewport: Vector2 = Vector2(2340.0, 1080.0)
	# A 40px cutout on the left, as a landscape phone reports it.
	var safe: Rect2 = Rect2(Vector2(40.0, 0.0), Vector2(2300.0, 1080.0))
	var inset: Vector2 = GameRoot.arena_inset(viewport, safe)
	assert_almost_eq(inset.x, 40.0, 0.0001, "the inset clears the reported cutout")


func test_the_inset_is_symmetric_when_the_cutout_is_not() -> void:
	var viewport: Vector2 = Vector2(2340.0, 1080.0)
	var safe: Rect2 = Rect2(Vector2(40.0, 0.0), Vector2(2300.0, 1080.0))
	var inset: Vector2 = GameRoot.arena_inset(viewport, safe)
	# Applied on both sides, the playfield stays centred.
	var playfield_width: float = viewport.x - inset.x * 2.0
	assert_almost_eq(
		playfield_width, 2340.0 - 80.0, 0.0001, "the arena stays centred, not lopsided"
	)


func test_an_aggressive_safe_area_cannot_letterbox_the_game() -> void:
	var viewport: Vector2 = Vector2(2340.0, 1080.0)
	# A device reporting an absurd safe area must not shrink the playfield.
	var safe: Rect2 = Rect2(Vector2(400.0, 300.0), Vector2(1540.0, 480.0))
	var inset: Vector2 = GameRoot.arena_inset(viewport, safe)
	assert_lte(
		inset.x,
		viewport.x * GameRoot.MAX_INSET_RATIO + FLOAT32_TOLERANCE,
		"the ceiling caps the horizontal inset"
	)
	assert_lte(
		inset.y,
		viewport.y * GameRoot.MAX_INSET_RATIO + FLOAT32_TOLERANCE,
		"the ceiling caps the vertical inset"
	)


func test_a_degenerate_safe_area_falls_back_to_the_floor() -> void:
	var viewport: Vector2 = Vector2(2340.0, 1080.0)
	# DisplayServer can report an empty rect on platforms with no notion of one.
	var safe: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)
	var inset: Vector2 = GameRoot.arena_inset(viewport, safe)
	assert_almost_eq(inset.x, GameRoot.MIN_INSET_X, 0.0001, "an empty safe area is not trusted")
	assert_almost_eq(inset.y, GameRoot.MIN_INSET_Y, 0.0001, "an empty safe area is not trusted")


func test_the_playfield_is_always_smaller_than_the_viewport() -> void:
	var viewport: Vector2 = Vector2(2340.0, 1080.0)
	var safe: Rect2 = Rect2(Vector2.ZERO, viewport)
	var inset: Vector2 = GameRoot.arena_inset(viewport, safe)
	assert_gt(inset.x, 0.0, "there is always some inset")
	assert_gt(inset.y, 0.0, "there is always some inset")
