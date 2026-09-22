## test_handling_preview.gd
## PORTS: nothing — new file, covers src/ui/handling_preview.gd
extends GutTest
## Proves the live steering preview's physics: deadzone rest, chase toward the
## pointer at the tuned top speed, clamping to the box, and start/stop.

var _progression: ProgressionManager = null
var _preview: HandlingPreview = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_progression = ProgressionManager.new()
	_preview = HandlingPreview.new()
	_preview.size = Vector2(400.0, 300.0)
	add_child_autofree(_preview)
	await get_tree().process_frame


func after_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)


func test_start_places_the_ship_and_pointer_once() -> void:
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:961-971 (w/2+45, h/2-25; mouse w/2+70, h/2-35)
	_preview.start(_progression)
	assert_true(_preview.is_running())
	assert_eq(_preview.ship_x, 200.0 + 45.0)
	assert_eq(_preview.ship_y, 150.0 - 25.0)
	assert_almost_eq(_preview.angle, -PI / 4.0, 0.0001)
	assert_eq(_preview.mouse_pos, Vector2(200.0 + 70.0, 150.0 - 35.0))
	_preview.ship_x = 10.0
	_preview.stop()
	_preview.start(_progression)
	assert_eq(_preview.ship_x, 10.0, "previewInitialized guards re-placement (:961)")


func test_ship_at_rest_inside_the_deadzone_decays() -> void:
	_preview.start(_progression)
	_preview.mouse_pos = Vector2(_preview.ship_x + 1.0, _preview.ship_y)
	_preview.vx = 100.0
	_preview.step()
	# PORT: web/src/tilt-to-live/ArmoryUI.ts:1053-1056 — vx *= 0.84
	assert_almost_eq(_preview.vx, 84.0, 0.0001)


func test_ship_accelerates_toward_a_far_pointer() -> void:
	_preview.start(_progression)
	_preview.mouse_pos = Vector2(_preview.ship_x + 300.0, _preview.ship_y)
	_preview.step()
	# PORT: :1046-1052 — speedFrac 1 at dist ≥ topSpeedRadius; target 240*1.0; vx += 240*0.14
	assert_almost_eq(_preview.vx, 240.0 * 0.14, 0.0001)
	assert_almost_eq(_preview.vy, 0.0, 0.0001)
	assert_gt(_preview.ship_x, 245.0, "moved by vx/60 (:1059)")


func test_top_speed_scales_with_sensitivity() -> void:
	_progression.set_sensitivity(2.0)
	_preview.start(_progression)
	_preview.mouse_pos = Vector2(_preview.ship_x + 300.0, _preview.ship_y)
	_preview.step()
	assert_almost_eq(_preview.vx, 480.0 * 0.14, 0.0001, "maxSpeed = 240 * sensitivity (:1047)")


func test_ship_is_clamped_inside_the_box() -> void:
	_preview.start(_progression)
	_preview.ship_x = 2.0
	_preview.vx = -6000.0
	_preview.mouse_pos = Vector2(_preview.ship_x, _preview.ship_y)
	_preview.step()
	assert_eq(_preview.ship_x, 16.0, "clamped to 16 px (:1063)")


func test_angle_turns_toward_velocity_at_the_tuned_rate() -> void:
	_preview.start(_progression)
	_preview.angle = 0.0
	_preview.vx = 0.0
	_preview.vy = 100.0
	_preview.mouse_pos = Vector2(_preview.ship_x, _preview.ship_y)
	_preview.step()
	# PORT: :1067-1078 — speed>8 → target atan2(vy, vx) after drag = PI/2; diff * min(1, (1/60)*16*1.0)
	var expected: float = (PI / 2.0) * minf(1.0, (1.0 / 60.0) * 16.0)
	assert_almost_eq(_preview.angle, expected, 0.0001)


func test_pointer_follows_gui_input() -> void:
	_preview.start(_progression)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(33.0, 44.0)
	_preview._gui_input(motion)
	assert_eq(_preview.mouse_pos, Vector2(33.0, 44.0))
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.position = Vector2(55.0, 66.0)
	_preview._gui_input(drag)
	assert_eq(_preview.mouse_pos, Vector2(55.0, 66.0))


func test_stop_halts_processing() -> void:
	_preview.start(_progression)
	assert_true(_preview.is_processing())
	_preview.stop()
	assert_false(_preview.is_running())
	assert_false(_preview.is_processing())
