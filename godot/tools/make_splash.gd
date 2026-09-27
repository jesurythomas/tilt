## make_splash.gd — renders the boot splash from the cold-open board (M11c review).
## The splash is what Android shows while the engine loads; drawing it from the
## ColdOpen board (void, ion glow, ship, "PERIL POINT", empty bar) makes the hand-over
## to the real cold open seamless. A GUT script so the project's autoloads exist; it
## renders into a 2340x1080 SubViewport (the A55's screen), whatever the window size.
## Run WINDOWED (the dummy renderer draws nothing), with the single-thread renderer:
##   "$GODOT" --path godot --render-thread safe -s addons/gut/gut_cmdln.gd \
##       -gtest=res://tools/make_splash.gd -gexit
extends GutTest

const OUT_PATH: String = "res://assets/splash/boot_splash.png"
const SPLASH_SIZE: Vector2i = Vector2i(2340, 1080)
const WARMUP_FRAMES: int = 8


func test_render_splash() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = SPLASH_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(vp)
	var board: EntranceCinematic = EntranceCinematic.new()
	vp.add_child(board)
	board.position = Vector2.ZERO
	board.size = Vector2(SPLASH_SIZE)
	board.set_ui_scale(HudController.ui_scale_for(Vector2(SPLASH_SIZE)))
	board.visible = true
	for i: int in range(WARMUP_FRAMES):
		await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	var err: Error = img.save_png(ProjectSettings.globalize_path(OUT_PATH))
	print("make_splash: %s %s -> %d" % [OUT_PATH, img.get_size(), err])
	assert_eq(err, OK)
