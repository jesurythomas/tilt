## shot_how_to_play.gd — HTP R3: one How to play page at the A55's aspect, for review.
## Windowed; not in the suite:
##   APPDATA="$(cygpath -w "$(mktemp -d)")" HTP_PAGE=2 "$GODOT" --path godot \
##       --render-thread safe --resolution 1560x720 -s res://bench/shot_how_to_play.gd
## Writes godot/build/shots/how_to_play_$HTP_PAGE.png, a second into the page's clip.
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
	var page: int = int(OS.get_environment("HTP_PAGE"))
	var guide: Object = _root.get("_how_to_play")
	guide.call("open", page)
	await create_timer(1.0).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	var img: Image = get_root().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://build/shots/how_to_play_%d.png" % page))
	quit()
