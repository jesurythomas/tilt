## test_main_scene.gd
## PORTS: nothing — new file, covers scenes/main.tscn
extends GutTest
## Verifies scenes/main.tscn exposes every node hud_controller.gd and
## control_picker.gd look up, per M2.5 spec §4.3, §4.4, §7.1, §7.4.


func test_main_scene_exposes_required_hud_nodes() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var root: Node = scene.instantiate()
	add_child_autofree(root)

	var labels: Array[String] = [
		"ScoreLabel",
		"BestLabel",
		"MultiplierLabel",
		"FinalScoreLabel",
		"FinalKillsLabel",
		"FinalTimeLabel",
		"NewBestLabel",
	]
	for label_name: String in labels:
		var node: Node = root.find_child(label_name, true, false)
		assert_true(node is Label, "%s must exist and be a Label" % label_name)

	var controls: Array[String] = ["GameOverPanel", "PausePanel"]
	for control_name: String in controls:
		var node: Node = root.find_child(control_name, true, false)
		assert_true(node is Control, "%s must exist and be a Control" % control_name)

	var buttons: Array[String] = ["RestartButton", "PauseButton", "ResumeButton"]
	for button_name: String in buttons:
		var node: Node = root.find_child(button_name, true, false)
		assert_true(node is Button, "%s must exist and be a Button" % button_name)

	var layers: Array[String] = ["GridLayer", "EntityLayer", "EffectLayer", "JoystickLayer"]
	for layer_name: String in layers:
		var node: Node = root.find_child(layer_name, true, false)
		assert_true(node is Node2D, "%s must exist and be a Node2D" % layer_name)

	var pickers: Array[Node] = root.find_children("*", "ControlPicker", true, false)
	assert_eq(pickers.size(), 2, "one picker on the pause overlay, one on the death screen")
