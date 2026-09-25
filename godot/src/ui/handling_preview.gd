## handling_preview.gd
## PORTS: web/src/tilt-to-live/ArmoryUI.ts:83-94 (preview state) and :943-1113
##        (initHandlingPreview / stopHandlingPreview), relocated to a _draw()
##        Control per spec §4.2/D4 — the render-body relocation M3/M4/M7 made
class_name HandlingPreview
extends Control
## Live steering preview (Board 11): a ship chasing the pointer with the real
## turn-rate and deadzone maths over a 40 px grid. Runs only while the
## handling tab is shown.
##
## PORT-NOTE: the TS steps in requestAnimationFrame with a fixed 1/60 dt
## (:1059) regardless of display rate; here _process at max_fps 60 with the
## same fixed dt. This is UI, not sim — never _physics_process.
##
## PORT-NOTE: ctx.shadowBlur = 14 (:1086) is a glow; spec §4.5 defers every
## glow decision to M11's device measurement. TODO(M11c): the ship's tint glow.

## Canvas minimums. PORT: web/src/tilt-to-live/ArmoryUI.ts:954-955
const MIN_WIDTH: float = 280.0
const MIN_HEIGHT: float = 260.0
## Background grid. DIVERGENCE(UI-SYSTEM): ArmoryHandling.dc.html — 34 px, ion at
## 5% (the TS's 40 px / rgba(38,44,56,0.4) at ArmoryUI.ts:995-1002 is superseded,
## interface spec §6.4).
const GRID_COLOR: Color = Color(UiTheme.COLOR_ION, 0.05)
const GRID_STEP: float = 34.0
## Rings. PORT: web/src/tilt-to-live/ArmoryUI.ts:1009-1010, :1014-1016, :1024-1025
const TOP_SPEED_RADIUS: float = 110.0
const DEADZONE_MIN_RADIUS: float = 4.0
const DEADZONE_SCALE: float = 3.5
const TOP_SPEED_COLOR: Color = Color(91.0 / 255.0, 140.0 / 255.0, 1.0, 0.32)
const RING_WIDTH: float = 1.2
const TOP_SPEED_DASH: float = 4.0
const TOP_SPEED_GAP: float = 4.0
const DEADZONE_COLOR: Color = Color(1.0, 177.0 / 255.0, 77.0 / 255.0, 0.75)
## Origin dot. PORT: web/src/tilt-to-live/ArmoryUI.ts:1032-1034
const ORIGIN_COLOR: Color = Color("#FFB14D")
const ORIGIN_RADIUS: float = 2.5
## Steering. PORT: web/src/tilt-to-live/ArmoryUI.ts:1046-1047, :1051, :1055, :1059,
## :1063, :1069, :1078
const SPEED_FRAC_MIN_SPAN: float = 20.0
const MAX_SPEED: float = 240.0
const VELOCITY_LERP: float = 0.14
const REST_DRAG: float = 0.84
const STEP_DT: float = 1.0 / 60.0
const CLAMP_MARGIN: float = 16.0
const TURN_SPEED_THRESHOLD: float = 8.0
const ANGLE_LERP_RATE: float = 16.0
## Ship silhouette. PORT: web/src/tilt-to-live/ArmoryUI.ts:1087, :1091-1092
const SHIP_HALF: float = 24.0
const SHIP_STROKE: Color = Color("#ffffff")
const SHIP_STROKE_WIDTH: float = 1.4
## Pointer reticle. PORT: web/src/tilt-to-live/ArmoryUI.ts:1097, :1099
const RETICLE_COLOR: Color = Color(91.0 / 255.0, 140.0 / 255.0, 1.0, 0.6)
const RETICLE_RADIUS: float = 3.0
## Initial placement. PORT: web/src/tilt-to-live/ArmoryUI.ts:963-969
const INITIAL_SHIP_OFFSET: Vector2 = Vector2(45.0, -25.0)
const INITIAL_ANGLE: float = -PI / 4.0
const INITIAL_MOUSE_OFFSET: Vector2 = Vector2(70.0, -35.0)
## Raster density of the ship silhouette. PORT-NOTE: as ArmoryUI.SVG_OVERSAMPLE.
const SHIP_OVERSAMPLE: float = 2.0
## Box background: the arena token (interface spec §4.1 — no private token hexes).
const BOX_COLOR: Color = UiTheme.COLOR_ARENA

## The tuning source. PORT: web/src/tilt-to-live/ArmoryUI.ts:1008
var progression: ProgressionManager = null
## previewShip. PORT: web/src/tilt-to-live/ArmoryUI.ts:87-93
var ship_x: float = 0.0
var ship_y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var angle: float = -PI / 2.0
## previewMousePos. PORT: web/src/tilt-to-live/ArmoryUI.ts:86
var mouse_pos: Vector2 = Vector2.ZERO
## previewInitialized. PORT: web/src/tilt-to-live/ArmoryUI.ts:94
var _initialized: bool = false
## previewRafId !== null. PORT: web/src/tilt-to-live/ArmoryUI.ts:85
var _running: bool = false
var _ship_texture: ImageTexture = null


func _ready() -> void:
	custom_minimum_size = Vector2(MIN_WIDTH, MIN_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


## onMove. PORT: web/src/tilt-to-live/ArmoryUI.ts:973-982
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_pos = (event as InputEventMouseMotion).position
	elif event is InputEventScreenDrag:
		mouse_pos = (event as InputEventScreenDrag).position
	elif event is InputEventScreenTouch:
		mouse_pos = (event as InputEventScreenTouch).position


func _process(_delta: float) -> void:
	if not _running:
		return
	step()
	queue_redraw()


## initHandlingPreview. PORT: web/src/tilt-to-live/ArmoryUI.ts:943-971, :1105
func start(p: ProgressionManager) -> void:
	progression = p
	var w: float = maxf(MIN_WIDTH, size.x)
	var h: float = maxf(MIN_HEIGHT, size.y)
	if not _initialized:
		ship_x = w / 2.0 + INITIAL_SHIP_OFFSET.x
		ship_y = h / 2.0 + INITIAL_SHIP_OFFSET.y
		vx = 0.0
		vy = 0.0
		angle = INITIAL_ANGLE
		mouse_pos = Vector2(w / 2.0, h / 2.0) + INITIAL_MOUSE_OFFSET
		_initialized = true
	# Path2D(equippedShip.svgPath) filled with tint, stroked white (:1088-1093),
	# as one rasterised 48x48 SVG (the path's own coordinate space, :1087).
	var ship: ProgressionManager.ShipSkinConfig = progression.get_equipped_ship()
	_ship_texture = UiTheme.svg_texture(
		(
			"<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'>"
			+ (
				"<path d='%s' fill='%s' stroke='%s' stroke-width='%s'/></svg>"
				% [
					ship.svg_path,
					ship.tint.to_html(false),
					SHIP_STROKE.to_html(false),
					SHIP_STROKE_WIDTH
				]
			)
		),
		SHIP_OVERSAMPLE
	)
	_running = true
	set_process(true)
	queue_redraw()


## stopHandlingPreview. PORT: web/src/tilt-to-live/ArmoryUI.ts:1108-1113
func stop() -> void:
	_running = false
	set_process(false)


func is_running() -> bool:
	return _running


## One rAF step's physics. PORT: web/src/tilt-to-live/ArmoryUI.ts:1037-1078
func step() -> void:
	var current_w: float = maxf(MIN_WIDTH, size.x)
	var current_h: float = maxf(MIN_HEIGHT, size.y)
	var tuning: ProgressionManager.SteeringTuning = progression.data.tuning
	var deadzone_radius: float = maxf(DEADZONE_MIN_RADIUS, tuning.deadzone * DEADZONE_SCALE)  # :1010

	# 4. Steer ship toward cursor with real turn rate & deadzone physics
	var dx: float = mouse_pos.x - ship_x
	var dy: float = mouse_pos.y - ship_y
	var dist: float = sqrt(dx * dx + dy * dy)

	if dist > deadzone_radius:
		var dir_x: float = dx / dist
		var dir_y: float = dy / dist
		var speed_frac: float = minf(
			1.0,
			(dist - deadzone_radius) / maxf(SPEED_FRAC_MIN_SPAN, TOP_SPEED_RADIUS - deadzone_radius)
		)
		var max_speed: float = MAX_SPEED * tuning.sensitivity
		var target_vx: float = dir_x * max_speed * speed_frac
		var target_vy: float = dir_y * max_speed * speed_frac
		vx += (target_vx - vx) * VELOCITY_LERP
		vy += (target_vy - vy) * VELOCITY_LERP
	else:
		# Natural resting drag inside deadzone - eliminates drift
		vx *= REST_DRAG
		vy *= REST_DRAG

	ship_x += vx * STEP_DT
	ship_y += vy * STEP_DT

	# Clamping within box
	ship_x = maxf(CLAMP_MARGIN, minf(current_w - CLAMP_MARGIN, ship_x))
	ship_y = maxf(CLAMP_MARGIN, minf(current_h - CLAMP_MARGIN, ship_y))

	# Angular lerp tuned by turn rate
	var current_speed: float = sqrt(vx * vx + vy * vy)
	var target_angle: float = angle
	if current_speed > TURN_SPEED_THRESHOLD:
		target_angle = atan2(vy, vx)
	elif dist > deadzone_radius:
		target_angle = atan2(dy, dx)

	var diff: float = target_angle - angle
	while diff < -PI:
		diff += TAU
	while diff > PI:
		diff -= TAU
	angle += diff * minf(1.0, STEP_DT * ANGLE_LERP_RATE * tuning.sensitivity)


## The canvas body. PORT: web/src/tilt-to-live/ArmoryUI.ts:992-1035, :1080-1100
func _draw() -> void:
	var current_w: float = maxf(MIN_WIDTH, size.x)
	var current_h: float = maxf(MIN_HEIGHT, size.y)
	var cx: float = current_w / 2.0
	var cy: float = current_h / 2.0
	draw_rect(Rect2(Vector2.ZERO, Vector2(current_w, current_h)), BOX_COLOR)

	# Subtle background grid (:994-1006)
	var x: float = 0.0
	while x < current_w:
		draw_line(Vector2(x, 0.0), Vector2(x, current_h), GRID_COLOR, 1.0)
		x += GRID_STEP
	var y: float = 0.0
	while y < current_h:
		draw_line(Vector2(0.0, y), Vector2(current_w, y), GRID_COLOR, 1.0)
		y += GRID_STEP

	if progression == null:
		return
	var deadzone_radius: float = maxf(
		DEADZONE_MIN_RADIUS, progression.data.tuning.deadzone * DEADZONE_SCALE
	)

	# 1. Top speed dashed circle (:1012-1020)
	_draw_dashed_circle(
		Vector2(cx, cy), TOP_SPEED_RADIUS, TOP_SPEED_DASH, TOP_SPEED_GAP, TOP_SPEED_COLOR
	)
	# 2. Deadzone solid circle (:1022-1029)
	# PORT-NOTE: 64 segments is a rasterisation choice; the canvas arc()
	# ArmoryUI.ts:1024 draws a mathematically smooth circle.
	draw_arc(Vector2(cx, cy), deadzone_radius, 0.0, TAU, 64, DEADZONE_COLOR, RING_WIDTH)
	# 3. Center origin dot (:1031-1035)
	draw_circle(Vector2(cx, cy), ORIGIN_RADIUS, ORIGIN_COLOR)

	# 5. Player ship silhouette matching the equipped ship (:1080-1094)
	if _ship_texture != null:
		draw_set_transform(
			Vector2(ship_x, ship_y), angle, Vector2(1.0 / SHIP_OVERSAMPLE, 1.0 / SHIP_OVERSAMPLE)
		)
		draw_texture(_ship_texture, Vector2(-SHIP_HALF, -SHIP_HALF) * SHIP_OVERSAMPLE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 6. Subtle mouse reticle dot (:1096-1100)
	draw_circle(mouse_pos, RETICLE_RADIUS, RETICLE_COLOR)


## setLineDash([4, 4]) on an arc. Same walk as EntityLayer._draw_dashed_arc.
func _draw_dashed_circle(
	center: Vector2, radius: float, dash: float, gap: float, color: Color
) -> void:
	var length: float = TAU * radius
	var period: float = dash + gap
	var s: float = 0.0
	while s < length:
		var s1: float = minf(s + dash, length)
		draw_arc(center, radius, s / radius, s1 / radius, 6, color, RING_WIDTH)
		s += period
