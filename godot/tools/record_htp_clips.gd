## record_htp_clips.gd — records the How to play guide's own clips (HTP R2, R3) from the game.
## dodge:  a Survival run flown by the attract-mode autopilot, orbs held off, UI hidden.
## dash:   the same run with the HUD showing: a dash, then both items fired (HTP R3).
## armory: a tour of the Armory tabs (Weapons, Ships, Arena, Handling, Boosts, Abilities).
## Run WINDOWED with Movie Maker, a throwaway user:// and the single-thread renderer, then
## re-encode to Theora (see docs/superpowers/plans/2026-10-13-add-onboarding.md, HTP R2):
##   APPDATA="$(cygpath -w "$(mktemp -d)")" HTP_CLIP=dodge "$GODOT" --path godot \
##       --render-thread safe --resolution 1280x720 --fixed-fps 30 \
##       --write-movie /tmp/dodge.avi -s res://tools/record_htp_clips.gd
extends SceneTree

## Frames before recording is worth keeping (trimmed off by ffmpeg) and the clip length.
const WARMUP_FRAMES: int = 240
const CLIP_FRAMES: int = 360
## The dodge autopilot's danger radius (TiltGame.ts:1716).
const DANGER_RADIUS: float = 145.0
## The Armory clip's steps: [frame, action, argument].
const ARMORY_STEPS: Array[Array] = [
	[60, "tab", "weapons"],
	[60, "press", "Weapon_laser"],
	[60, "press", "Weapon_freeze"],
	[60, "tab", "ships"],
	[45, "press", "ShipNext"],
	[45, "press", "ShipNext"],
	[60, "tab", "arena"],
	[45, "press", "ThemeNext"],
	[60, "tab", "handling"],
	[75, "tab", "boosts"],
	[90, "tab", "abilities"],  # HTP R3
]
## HTP R3: the dash clip's dash and item frames, counted from the clip's start (30 fps).
const DASH_AT_FRAME: int = 30
const ITEM_FRAMES: Array[int] = [120, 240]
## Points the Armory clip shows (a few runs in), so prices read as reachable.
const ARMORY_POINTS: int = 4200

var _root: Node = null


func _initialize() -> void:
	_root = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(_root)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var guide: Control = _root.get("_how_to_play")
	guide.call("close")
	var clip: String = OS.get_environment("HTP_CLIP")
	if clip == "armory":
		await _armory()
	elif clip == "dash":
		await _dash()
	else:
		await _dodge()
	quit()


## A Survival run steered by the attract mode's own rule (TiltGame.ts:1679-1743, as
## MenuBackdrop.update): wander a figure-8, pushed off nearby dots and the walls. Orbs are
## cleared each frame so the clip is pure dodging; the HUD and menu are hidden.
func _dodge() -> void:
	(_root.get_node("CanvasLayer") as CanvasLayer).visible = false
	_start_run()
	for i: int in range(WARMUP_FRAMES + CLIP_FRAMES):
		if not _autopilot(i):
			return
		await process_frame


## HTP R3: the dodge run with the HUD up and two items equipped; a dash a second into the
## clip, the Blackhole item at 4 s and the Nuke at 8 s, so the gauge and buttons change.
func _dash() -> void:
	var progression: Object = _root.get("progression")
	var data: Object = progression.get("data")
	data.set("points", 100000)
	progression.call("buy_item", "blackhole")
	progression.call("buy_item", "nuke")
	_start_run()
	var player: Object = _root.get("_player")
	for i: int in range(WARMUP_FRAMES + CLIP_FRAMES):
		if not _autopilot(i):
			return
		var t: int = i - WARMUP_FRAMES
		if t == DASH_AT_FRAME:
			# A still ship dashes where it faces: aim it along its course first.
			var vx: float = player.get("vx")
			var vy: float = player.get("vy")
			if Vector2(vx, vy).length() < 40.0:
				player.set("angle", -PI / 2.0)
			_root.call("request_dash")
		elif t == ITEM_FRAMES[0]:
			_root.call("use_item", 0)
		elif t == ITEM_FRAMES[1]:
			_root.call("use_item", 1)
		await process_frame


# Untyped: a -s script compiles before the autoloads these classes use exist.
func _start_run() -> void:
	var options: Object = _root.get("options")
	var settings: Object = options.get("settings")
	settings.set("first_run_done", true)
	_root.call("set_control_scheme", Types.ControlScheme.MOUSE)
	_root.call("launch_run", Types.GameMode.CLASSIC)
	_root.call("skip_cinematic")


## One autopilot frame (frame `i`); false once the ship has died.
func _autopilot(i: int) -> bool:
	var player: Object = _root.get("_player")
	var swarm: Object = _root.get("_swarm")
	var weapons: Object = _root.get("_weapons")
	var router: Object = _root.get("_router")
	var state: Object = _root.get("_state")
	var bounds: Vector2 = _root.get("_bounds")
	var orbs: Array = weapons.get("orbs")
	orbs.clear()
	var px: float = player.get("x")
	var py: float = player.get("y")
	var at: Vector2 = Vector2(px, py)
	var angle: float = i / 30.0 * 0.8
	var wander: Vector2 = Vector2(
		bounds.x * 0.5 - cos(angle) * bounds.x * 0.3,
		bounds.y * 0.5 + sin(angle * 2.0) * bounds.y * 0.25
	)
	var steer: Vector2 = (wander - at).normalized() * 160.0
	var enemies: Array = swarm.get("enemies")
	for e: Object in enemies:
		var ex: float = e.get("x")
		var ey: float = e.get("y")
		var away: Vector2 = at - Vector2(ex, ey)
		var d: float = away.length()
		if d < DANGER_RADIUS and d > 0.1:
			steer += away / d * pow((DANGER_RADIUS - d) / DANGER_RADIUS, 1.8) * 520.0
	var margin: float = 60.0
	steer.x += maxf(0.0, margin - at.x) / margin * 450.0
	steer.x -= maxf(0.0, at.x - (bounds.x - margin)) / margin * 450.0
	steer.y += maxf(0.0, margin - at.y) / margin * 380.0
	steer.y -= maxf(0.0, at.y - (bounds.y - margin)) / margin * 380.0
	router.set("mouse_pos", at + steer)
	if state.get("phase") == Types.GamePhase.GAME_OVER:
		print("record_htp_clips: the ship died at frame %d" % i)
		return false
	return true


func _armory() -> void:
	var progression: Object = _root.get("progression")
	var data: Object = progression.get("data")
	data.set("points", ARMORY_POINTS)
	_root.call("open_armory", "weapons")
	var armory: Control = _root.get("_armory")
	for i: int in range(WARMUP_FRAMES):
		await process_frame
	for step: Array in ARMORY_STEPS:
		var target: String = str(step[2])
		var button_name: String = "Tab_" + target if step[1] == "tab" else target
		var button: Button = armory.find_child(button_name, true, false) as Button
		if button != null:
			button.pressed.emit()
		else:
			push_warning("record_htp_clips: no %s" % button_name)
		var hold: int = step[0]
		for f: int in range(hold):
			await process_frame
