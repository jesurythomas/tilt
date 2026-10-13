## record_htp_clips.gd — records the How to play guide's own clips (HTP R2) from the game.
## dodge:  a Survival run flown by the attract-mode autopilot, orbs held off, UI hidden.
## armory: a tour of the Armory tabs (Weapons, Ships, Arena, Handling, Boosts).
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
]
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
	if OS.get_environment("HTP_CLIP") == "armory":
		await _armory()
	else:
		await _dodge()
	quit()


## A Survival run steered by the attract mode's own rule (TiltGame.ts:1679-1743, as
## MenuBackdrop.update): wander a figure-8, pushed off nearby dots and the walls. Orbs are
## cleared each frame so the clip is pure dodging; the HUD and menu are hidden.
func _dodge() -> void:
	(_root.get_node("CanvasLayer") as CanvasLayer).visible = false
	# Untyped: a -s script compiles before the autoloads these classes use exist.
	var options: Object = _root.get("options")
	var settings: Object = options.get("settings")
	settings.set("first_run_done", true)
	_root.call("set_control_scheme", Types.ControlScheme.MOUSE)
	_root.call("launch_run", Types.GameMode.CLASSIC)
	_root.call("skip_cinematic")
	var player: Object = _root.get("_player")
	var swarm: Object = _root.get("_swarm")
	var weapons: Object = _root.get("_weapons")
	var router: Object = _root.get("_router")
	var state: Object = _root.get("_state")
	var bounds: Vector2 = _root.get("_bounds")
	for i: int in range(WARMUP_FRAMES + CLIP_FRAMES):
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
			return
		await process_frame


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
