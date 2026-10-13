## shot_hud.gd — DASH R4: the live HUD over a run, at the A55's aspect, for layout review.
## Plays the real game (main.tscn, a Survival run), packs dots under the top centre, sets a
## big score and multiplier, and screenshots the window. Windowed; not in the suite:
##   APPDATA="$(cygpath -w "$(mktemp -d)")" "$GODOT" --path godot --render-thread safe \
##       --resolution 1560x720 -s res://bench/shot_hud.gd
## Writes godot/build/shots/hud_$SHOT_NAME.png (default hud_now.png).
## Untyped on purpose: a -s script compiles before the autoloads the game's classes use.
extends SceneTree

var _root: Node = null


func _initialize() -> void:
	_root = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(_root)
	_run.call_deferred()


func _run() -> void:
	for i: int in range(10):
		await process_frame
	var guide: Object = _root.get("_how_to_play")
	if guide.call("is_open"):
		guide.call("close")
	_root.call("launch_run", Types.GameMode.CLASSIC)
	for i: int in range(5):
		await process_frame
	_root.call("skip_cinematic")
	await create_timer(1.0).timeout
	_prepare()
	await create_timer(0.5).timeout
	_prepare()
	for i: int in range(3):
		await process_frame
	var shot_name: String = OS.get_environment("SHOT_NAME")
	if shot_name.is_empty():
		shot_name = "now"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	var img: Image = get_root().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://build/shots/hud_%s.png" % shot_name))
	quit()


## Keeps the ship safe at the bottom left and packs dots across the top centre.
func _prepare() -> void:
	var rc: Object = _root.get("_run_controller")
	var bounds: Vector2 = _root.get("_bounds")
	var player: Object = rc.get("player")
	player.call("activate_shield", 5.0)
	player.set("x", bounds.x * 0.2)
	player.set("y", bounds.y * 0.8)
	var swarm: Object = rc.get("swarm")
	var enemies: Array = swarm.get("enemies")
	enemies.clear()
	for k: int in range(60):
		var x: float = bounds.x * (0.3 + 0.4 * float(k % 12) / 11.0)
		var y: float = bounds.y * (0.05 + 0.25 * float(k / 12) / 4.0)
		swarm.call("spawn_seeker", bounds, x, y)
	var scores: Object = rc.get("scores")
	var stats: Object = scores.get("stats")
	stats.set("score", 184200)
	stats.set("multiplier", 12)
	get_root().get_node("GameEvents").emit_signal("score_changed", 184200, 12, 96500)
