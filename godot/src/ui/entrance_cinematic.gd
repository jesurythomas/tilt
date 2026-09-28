## entrance_cinematic.gd
## PORTS: web/src/tilt-to-live/TiltEntranceCinematic.ts (221 lines, source commit 7be9614)
class_name EntranceCinematic
extends Control
## The 600 ms cold open between Play/Retry and the run. It resets the arena,
## holds the ship at the centre and fills a bar, then hands the run a
## mode-specific armada and a spawn shield. Drawn on ColdOpen.dc.html (M11b R1).
##
## PORT-NOTE: the TS injects its overlay DOM (:78-93); this Control is that
## overlay, built on the board. render() (:131-171) paints the canvas under an
## opaque overlay (game.css:3695, z-index 50 at :1045) that the player never
## sees, so it has no port (M11b R2).
## PORT-NOTE: GameRoot owns this node and ticks it (M11b R5); the TS
## constructor's renderer argument (:38) is never read by the class, so bind()
## omits it.

## A tap or click on the overlay while playing. GameRoot answers with skip().
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:96-102
signal skip_requested

## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:27
const DURATION: float = 0.6
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:70
const RIPPLE_FORCE: float = 260.0
const RIPPLE_RADIUS: float = 60.0
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:71
const BURST_COLOR: Color = Color("#5B8CFF")
const BURST_COUNT: int = 24
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:204-205 (the radius is now the floor)
const SEEKER_COUNT: int = 8
const SEEKER_RADIUS: float = 260.0
## DIVERGENCE(M11c P8): user ruling 2026-09-26, "further away would make it easier for
## players to evade" — the ring scales with the arena's short side, never below 260.
const SEEKER_RADIUS_FRACTION: float = 0.42
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:208-209
const SEEKER_MARGIN: float = 40.0
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:197-198
const ORB_SPREAD: float = 80.0
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:197, :201, :212
const ORB_Y_RATIO: float = 0.45
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:216
const SPAWN_SHIELD: float = 2.5
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:115 (whole-percent width)
const PERCENT: float = 100.0

## DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — radial-gradient(420px 260px at 50% 50%,
## rgba(91,140,255,0.08), rgba(0,0,0,0) 72%)
const GLOW_RADII: Vector2 = Vector2(420.0, 260.0)
const GLOW_ALPHA: float = 0.08
const GLOW_STOP: float = 0.72
## DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — centre stack gap 18
const STACK_GAP: int = 18
## DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — ship svg 52×52 on a 72 viewBox, ion fill.
## TODO(M11c): its drop-shadow(0 0 20px rgba(91,140,255,0.9)) glow (spec §4.5, M11b R3).
const SHIP_SVG: String = (
	'<svg xmlns="http://www.w3.org/2000/svg" width="52" height="52" viewBox="0 0 72 72" '
	+ 'fill="none"><path d="M62 36 L20 13 L28 36 L20 59 Z" fill="#5B8CFF"/></svg>'
)
## DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — h1 58px, letter-spacing -0.015em
const TITLE_SIZE: int = 58
const TITLE_TRACKING_EM: float = -0.015
## DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — bar 160×2, radius 2, bottom 44
const BAR_WIDTH: int = 160
const BAR_HEIGHT: int = 2
const BAR_RADIUS: int = 2
const BAR_BOTTOM: int = 44

## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:25
var is_playing: bool = false
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:26
var elapsed: float = 0.0

## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:24
var _game_mode: Types.GameMode = Types.GameMode.CLASSIC
var _audio: AudioBank = null
var _player: PlayerShip = null
var _swarm: EnemySwarm = null
var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _weapons: WeaponSystem = null
var _on_finish: Callable = Callable()
var _ui_scale: float = 1.0
var _fill: Panel = null


## The TS constructor's systems. PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:32-52
func bind(
	audio: AudioBank,
	player: PlayerShip,
	swarm: EnemySwarm,
	grid: VectorGrid,
	particles: ParticleEngine,
	weapons: WeaponSystem,
	on_finish: Callable
) -> void:
	_audio = audio
	_player = player
	_swarm = swarm
	_grid = grid
	_particles = particles
	_weapons = weapons
	_on_finish = on_finish


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:54-104
func start(width: float, height: float, mode: Types.GameMode) -> void:
	_game_mode = mode
	is_playing = true
	elapsed = 0.0

	_swarm.reset()
	_weapons.reset()

	var cx: float = width / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:64
	var cy: float = height / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:65
	_player.reset(cx, cy)
	_player.angle = -PI / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:67

	_grid.apply_explosion(cx, cy, RIPPLE_FORCE, RIPPLE_RADIUS)
	_particles.emit_explosion(cx, cy, BURST_COLOR, BURST_COUNT)

	_audio.play_warp_in()  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:74

	_set_fill(0.0)
	visible = true  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:94


## Returns true on the tick the cold open ends.
## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:106-129
func update(dt: float, width: float, height: float) -> bool:
	if not is_playing:
		return false

	elapsed += dt
	_set_fill(progress())

	_player.x = width / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:119
	_player.y = height / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:120
	_player.angle = -PI / 2.0  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:121

	if elapsed >= DURATION:
		_finish(width, height)
		return true
	return false


## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:110, :136
func progress() -> float:
	return minf(1.0, elapsed / DURATION)


## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:173-176
func skip(width: float, height: float) -> void:
	if not is_playing:
		return
	_finish(width, height)


## Rebuilds the board at `scale`, keeping its visibility and fill (Review Focus 2).
func set_ui_scale(scale: float) -> void:
	_ui_scale = scale
	theme = UiTheme.build(scale)
	_build()


## The overlay's click/touchstart skip. PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:96-102
# PORT-NOTE: `{ once: true }` (:101-102) is not ported; skip() is idempotent (:174) (M11b R7).
func _gui_input(event: InputEvent) -> void:
	var is_press: bool = false
	if event is InputEventScreenTouch:
		is_press = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		# PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:101 click (primary button)
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		is_press = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if is_press and is_playing:
		accept_event()
		skip_requested.emit()


## PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:178-220
func _finish(width: float, height: float) -> void:
	if not is_playing:
		return
	is_playing = false
	visible = false  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:184

	_swarm.reset()
	var bounds: Vector2 = Vector2(width, height)
	var player_pos: Vector2 = Vector2(_player.x, _player.y)
	var orb_y: float = height * ORB_Y_RATIO

	if _game_mode == Types.GameMode.CODE_RED:
		_swarm.spawn_mode_armada(Types.GameMode.CODE_RED, bounds, player_pos)
		_opening_orb(bounds, Types.WeaponType.VORTEX, width / 2.0 - ORB_SPREAD, orb_y)  # PORT: :197
		_opening_orb(bounds, Types.WeaponType.NUKE, width / 2.0 + ORB_SPREAD, orb_y)  # PORT: :198
	elif _game_mode == Types.GameMode.GAUNTLET:
		_swarm.spawn_mode_armada(Types.GameMode.GAUNTLET, bounds, player_pos)
		_opening_orb(bounds, Types.WeaponType.NUKE, width / 2.0, orb_y)  # PORT: :201
	else:
		var radius: float = maxf(SEEKER_RADIUS, minf(width, height) * SEEKER_RADIUS_FRACTION)
		for i: int in range(SEEKER_COUNT):
			var ang: float = (float(i) / float(SEEKER_COUNT)) * PI * 2.0  # PORT: :207
			var x: float = clampf(
				width / 2.0 + cos(ang) * radius, SEEKER_MARGIN, width - SEEKER_MARGIN
			)  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:208
			var y: float = clampf(
				height / 2.0 + sin(ang) * radius, SEEKER_MARGIN, height - SEEKER_MARGIN
			)  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:209
			_swarm.spawn_seeker(bounds, x, y)
		_opening_orb(bounds, Types.WeaponType.NUKE, width / 2.0, orb_y)  # PORT: :212

	_player.activate_shield(SPAWN_SHIELD)

	if _on_finish.is_valid():
		_on_finish.call()  # PORT: web/src/tilt-to-live/TiltEntranceCinematic.ts:219


## Sets the fill to whole percents, as the TS sets `style.width` (M11b R4).
# PORT-NOTE: the 50 ms `transition: width 0.05s linear` (game.css:3764) is not
# ported — the bar is already set every tick.
func _set_fill(fraction: float) -> void:
	if _fill == null:
		return
	_fill.size.x = UiTheme.px(BAR_WIDTH, _ui_scale) * (roundi(fraction * PERCENT) / PERCENT)


func _build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	var void_rect: ColorRect = ColorRect.new()
	void_rect.name = "Void"
	void_rect.color = UiTheme.COLOR_VOID
	void_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(void_rect)
	void_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	add_child(_glow())
	add_child(_stack())
	add_child(_bar())

	visible = is_playing
	_set_fill(progress())


# DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — the glow ellipse, stretched from a
# radial GradientTexture2D sized to the board's diameters (2 × the 420×260 radii).
func _glow() -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, GLOW_STOP])
	gradient.colors = PackedColorArray(
		[UiTheme.tint(UiTheme.COLOR_ION, GLOW_ALPHA), UiTheme.tint(UiTheme.COLOR_ION, 0.0)]
	)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)  # DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — at 50% 50%
	texture.fill_to = Vector2(1.0, 0.5)  # DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — at 50% 50%
	var diameter: Vector2 = GLOW_RADII * 2.0  # DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — radii → size
	texture.width = roundi(diameter.x)
	texture.height = roundi(diameter.y)

	var glow: TextureRect = TextureRect.new()
	glow.name = "Glow"
	glow.texture = texture
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = Vector2(UiTheme.px(diameter.x, _ui_scale), UiTheme.px(diameter.y, _ui_scale))
	glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	return glow


func _stack() -> VBoxContainer:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "Stack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", UiTheme.px(STACK_GAP, _ui_scale))

	var ship: TextureRect = TextureRect.new()
	ship.name = "Ship"
	ship.texture = UiTheme.svg_texture(SHIP_SVG, _ui_scale)
	ship.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(ship)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "PERIL POINT"  # M11b R1: app identity (the TS :85 "TILT TO LIVE" names the web game)
	var size_px: int = UiTheme.px(TITLE_SIZE, _ui_scale)
	var wordmark: FontVariation = UiTheme.archivo(UiTheme.WORDMARK_WIDTH)
	wordmark.spacing_glyph = roundi(TITLE_TRACKING_EM * size_px)
	title.add_theme_font_override("font", wordmark)
	title.add_theme_font_size_override("font_size", size_px)
	title.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title)

	# The stack's minimum size is only known once its fonts resolve in the tree, so it
	# must grow from its centre anchor both ways; the default (END) grew it right and
	# down, off-centre at phone scale (A55 report, 2026-09-26).
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.grow_vertical = Control.GROW_DIRECTION_BOTH
	return stack


func _bar() -> Panel:
	var width: int = UiTheme.px(BAR_WIDTH, _ui_scale)
	var height: int = UiTheme.px(BAR_HEIGHT, _ui_scale)
	var radius: int = UiTheme.px(BAR_RADIUS, _ui_scale)

	var track: Panel = Panel.new()
	track.name = "BarTrack"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.clip_contents = true  # game.css:3752 overflow: hidden
	track.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_RAISED, UiTheme.COLOR_RAISED, radius, 0)
	)
	# DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — left 50%, translateX(-50%), bottom 44
	track.anchor_left = 0.5
	track.anchor_right = 0.5
	track.anchor_top = 1.0
	track.anchor_bottom = 1.0
	track.offset_left = -width / 2.0
	track.offset_right = width / 2.0
	track.offset_bottom = -UiTheme.px(BAR_BOTTOM, _ui_scale)
	track.offset_top = track.offset_bottom - height

	_fill = Panel.new()
	_fill.name = "BarFill"
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.add_theme_stylebox_override(
		"panel", UiTheme.flat(UiTheme.COLOR_ION, UiTheme.COLOR_ION, radius, 0)
	)
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(0.0, height)
	track.add_child(_fill)
	return track


## DIVERGENCE(ORB R1): an opening orb — spawned as the TS spawns it, but not magnetic, so
## the magnet does not take it before the player chooses to (Types.WeaponOrb.magnetic).
func _opening_orb(bounds: Vector2, type: Types.WeaponType, x: float, y: float) -> void:
	_weapons.spawn_orb(bounds, type, x, y).magnetic = false
