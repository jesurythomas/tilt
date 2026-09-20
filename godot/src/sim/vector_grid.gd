## vector_grid.gd
## PORTS: web/src/tilt-to-live/VectorGrid.ts (118 lines, source commit 7be9614)
class_name VectorGrid
extends RefCounted
## Spring-mass reactive mesh behind the arena.
##
## Instantiated twice concurrently once MenuBackdrop lands (spec §5.2), so it
## must never become an autoload.
##
## PORT-NOTE: VectorGrid.ts:86-117 defines render(); per spec §4.2/D4 that body
## relocates to render/grid_layer.gd, which is why cols/rows/points are public
## here and private in the TypeScript (VectorGrid.ts:16-18).
##
## PORT-NOTE: update() ignores its dt (VectorGrid.ts:45 names the parameter
## `_dt`). The spring integrates once per *call*, not per second, so the settle
## rate is tied to how often the caller ticks. Preserved deliberately — it is
## part of the tuned feel. See the physics-tick decision recorded in HANDOFF.md.

const SPACING: float = 36.0  # PORT: web/src/tilt-to-live/VectorGrid.ts:15
const STIFFNESS: float = 0.08  # PORT: web/src/tilt-to-live/VectorGrid.ts:46
const DAMPING: float = 0.90  # PORT: web/src/tilt-to-live/VectorGrid.ts:47

## Lattice width in points.
var cols: int = 0
## Lattice height in points.
var rows: int = 0
## Row-major lattice: index = row * cols + col.
var points: Array[GridPoint] = []


func _init(width: float, height: float) -> void:
	resize(width, height)


## Rebuilds the lattice for a new viewport size. PORT: web/src/tilt-to-live/VectorGrid.ts:24-43
func resize(width: float, height: float) -> void:
	# PORT-NOTE: ceil() returns Variant; unsafe argument warning suppressed for port fidelity
	@warning_ignore("unsafe_call_argument")
	cols = int(ceil(width / SPACING)) + 1  # PORT: web/src/tilt-to-live/VectorGrid.ts:25
	# PORT-NOTE: ceil() returns Variant; unsafe argument warning suppressed for port fidelity
	@warning_ignore("unsafe_call_argument")
	rows = int(ceil(height / SPACING)) + 1  # PORT: web/src/tilt-to-live/VectorGrid.ts:26
	points = []

	for r: int in range(rows):
		for c: int in range(cols):
			var point: GridPoint = GridPoint.new()
			point.x = c * SPACING
			point.y = r * SPACING
			point.orig_x = point.x
			point.orig_y = point.y
			points.append(point)


## Advances the spring one step. PORT: web/src/tilt-to-live/VectorGrid.ts:45-63
func update(_dt: float) -> void:
	for point: GridPoint in points:
		var dx: float = point.orig_x - point.x
		var dy: float = point.orig_y - point.y

		point.vx += dx * STIFFNESS
		point.vy += dy * STIFFNESS

		point.vx *= DAMPING
		point.vy *= DAMPING

		point.x += point.vx
		point.y += point.vy


## Pushes points away from (cx, cy). PORT: web/src/tilt-to-live/VectorGrid.ts:65-80
func apply_explosion(cx: float, cy: float, force: float, radius: float) -> void:
	var r2: float = radius * radius
	for point: GridPoint in points:
		var dx: float = point.x - cx
		var dy: float = point.y - cy
		var dist2: float = dx * dx + dy * dy

		if dist2 < r2 and dist2 > 0.001:  # PORT: web/src/tilt-to-live/VectorGrid.ts:73
			var dist: float = sqrt(dist2)
			var factor: float = (1.0 - dist / radius) * force
			point.vx += (dx / dist) * factor
			point.vy += (dy / dist) * factor


## Explosion with a negated force. PORT: web/src/tilt-to-live/VectorGrid.ts:82-84
func apply_implosion(cx: float, cy: float, force: float, radius: float) -> void:
	apply_explosion(cx, cy, -force, radius)


## PORT: web/src/tilt-to-live/VectorGrid.ts:5-12
class GridPoint:
	extends RefCounted
	var x: float = 0.0
	var y: float = 0.0
	var orig_x: float = 0.0
	var orig_y: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
