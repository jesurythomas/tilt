## shot_armory.gd — ITEM R2: the Armory at the A55's aspect, for layout review. Funds the save,
## buys a dash rank and three items (two equipped), opens a tab and screenshots the window.
## Windowed; not in the suite:
##   APPDATA="$(cygpath -w "$(mktemp -d)")" ARMORY_TAB=abilities "$GODOT" --path godot \
##       --render-thread safe --resolution 1560x720 -s res://bench/shot_armory.gd
## Writes godot/build/shots/armory_$ARMORY_TAB.png. SCROLL=end scrolls the tab to its end.
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
	var progression: Object = _root.get("progression")
	var data: Object = progression.get("data")
	data.set("points", 60000)
	progression.call("buy_dash_cooldown")
	progression.call("buy_dash_shield")
	progression.call("buy_dash_shield")
	progression.call("buy_item", "blackhole")
	progression.call("buy_item", "nuke")
	progression.call("buy_item", "shield")
	data.set(
		"points", int(OS.get_environment("POINTS")) if OS.get_environment("POINTS") != "" else 9800
	)
	var tab: String = OS.get_environment("ARMORY_TAB")
	if tab.is_empty():
		tab = "abilities"
	_root.call("open_armory", tab)
	for i: int in range(5):
		await process_frame
	if OS.get_environment("SCROLL") == "end":
		var armory: Node = _root.get("_armory")
		for node: Node in armory.find_children("*", "ScrollContainer", true, false):
			var scroll: ScrollContainer = node as ScrollContainer
			scroll.scroll_vertical = 100000
		for i: int in range(5):
			await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	var suffix: String = "_end" if OS.get_environment("SCROLL") == "end" else ""
	var img: Image = get_root().get_texture().get_image()
	img.save_png(
		ProjectSettings.globalize_path("res://build/shots/armory_%s%s.png" % [tab, suffix])
	)
	quit()
