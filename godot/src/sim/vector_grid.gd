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
## relocates to render/grid_layer.gd, which is why cols/rows and the point arrays are public
## here and private in the TypeScript (VectorGrid.ts:16-18).
##
## PORT-NOTE: update() ignores its dt (VectorGrid.ts:45 names the parameter
## `_dt`). The spring integrates once per *call*, not per second, so the settle
## rate is tied to how often the caller ticks. Preserved deliberately — it is
## part of the tuned feel. See the physics-tick decision recorded in HANDOFF.md.

const SPACING: float = 36.0  # PORT: web/src/tilt-to-live/VectorGrid.ts:15
const STIFFNESS: float = 0.08  # PORT: web/src/tilt-to-live/VectorGrid.ts:46
const DAMPING: float = 0.90  # PORT: web/src/tilt-to-live/VectorGrid.ts:47
## DIVERGENCE(M11c review): below this displacement and speed (px, px per step) every
## point is snapped to rest and the lattice sleeps until the next explosion; the
## springs only decay towards rest from there, far below a pixel.
const SETTLE_EPS: float = 0.02
## DIVERGENCE(M11c P31): explosion windows this large (points) scan in C++.
const NATIVE_BLAST_MIN_POINTS: int = 64

## DIVERGENCE(M11c P31): update() steps in C++ when the PerilNative extension is
## loaded; false forces the GDScript step (the grid tests compare both).
static var use_native: bool = true
static var _native: Object = null

## Lattice width in points.
var cols: int = 0
## Lattice height in points.
var rows: int = 0
## DIVERGENCE(M11c P3): the TS GridPoint objects (VectorGrid.ts:5-12) become six
## row-major packed arrays (index = row * cols + col). 64-bit, so every value is
## what the object grid computed, bit for bit.
var px: PackedFloat64Array = PackedFloat64Array()
var py: PackedFloat64Array = PackedFloat64Array()
var ox: PackedFloat64Array = PackedFloat64Array()
var oy: PackedFloat64Array = PackedFloat64Array()
var vx: PackedFloat64Array = PackedFloat64Array()
var vy: PackedFloat64Array = PackedFloat64Array()
## DIVERGENCE(M11c P3): false while nothing draws the grid (gridlines off); update()
## and apply_explosion() then do nothing. GameRoot.apply_readability sets it.
var awake: bool = true
## DIVERGENCE(M11c review): true while every point is exactly at rest (update() then
## does nothing); cleared by an explosion that moves a point.
var settled: bool = true
## DIVERGENCE(M11c review): bumped whenever a point moves, so a drawer can redraw only
## then.
var revision: int = 0
## Largest |x - ox| or |y - oy| after the last update() — bounds apply_explosion's
## scan window. Positions move only in update(), so it stays valid until the next one.
var _max_displacement: float = 0.0
## DIVERGENCE(M11c review): the points update() steps (see update()), and a flag per
## point for membership.
var _active: PackedInt32Array = PackedInt32Array()
var _is_active: PackedByteArray = PackedByteArray()


func _init(width: float, height: float) -> void:
	resize(width, height)


## Rebuilds the lattice for a new viewport size. PORT: web/src/tilt-to-live/VectorGrid.ts:24-43
func resize(width: float, height: float) -> void:
	cols = ceili(width / SPACING) + 1  # PORT: web/src/tilt-to-live/VectorGrid.ts:25
	rows = ceili(height / SPACING) + 1  # PORT: web/src/tilt-to-live/VectorGrid.ts:26
	var n: int = cols * rows
	px.resize(n)
	py.resize(n)
	ox.resize(n)
	oy.resize(n)
	vx.resize(n)
	vy.resize(n)
	vx.fill(0.0)
	vy.fill(0.0)
	for r: int in range(rows):
		for c: int in range(cols):
			var i: int = r * cols + c
			px[i] = c * SPACING
			py[i] = r * SPACING
			ox[i] = px[i]
			oy[i] = py[i]
	_max_displacement = 0.0
	_is_active.resize(n)
	_is_active.fill(0)
	_active = PackedInt32Array()
	settled = true
	revision += 1


## Advances the spring one step. PORT: web/src/tilt-to-live/VectorGrid.ts:45-63
# DIVERGENCE(M11c review): steps only the active points. Every point springs to its
# own origin alone, and a point exactly at rest with zero velocity is unchanged by a
# step, so skipping it changes nothing; a point joins the list when an explosion
# pushes it and leaves it once within SETTLE_EPS of rest (snapped exactly to rest).
func update(_dt: float) -> void:
	if not awake or settled:
		return
	var native: Object = _native_stepper()
	if native != null:
		# DIVERGENCE(M11c P31): the same step in C++ (native/src/peril_native.cpp),
		# bit-identical (the grid tests run both paths).
		var r: Array = native.call(
			"grid_step", px, py, ox, oy, vx, vy, _active, _is_active, STIFFNESS, DAMPING, SETTLE_EPS
		)
		px = r[0]
		py = r[1]
		vx = r[2]
		vy = r[3]
		_active = r[4]
		_is_active = r[5]
		_max_displacement = r[6]
		revision += 1
		settled = _active.is_empty()
		return
	var max_d: float = 0.0
	var still: PackedInt32Array = PackedInt32Array()
	for i: int in _active:
		var dx: float = ox[i] - px[i]
		var dy: float = oy[i] - py[i]

		vx[i] += dx * STIFFNESS
		vy[i] += dy * STIFFNESS

		vx[i] *= DAMPING
		vy[i] *= DAMPING

		px[i] += vx[i]
		py[i] += vy[i]
		var d: float = maxf(absf(px[i] - ox[i]), absf(py[i] - oy[i]))
		if d < SETTLE_EPS and maxf(absf(vx[i]), absf(vy[i])) < SETTLE_EPS:
			px[i] = ox[i]
			py[i] = oy[i]
			vx[i] = 0.0
			vy[i] = 0.0
			_is_active[i] = 0
			still.append(i)
		else:
			max_d = maxf(max_d, d)
	if not still.is_empty():
		var kept: PackedInt32Array = PackedInt32Array()
		for i: int in _active:
			if _is_active[i] == 1:
				kept.append(i)
		_active = kept
	_max_displacement = max_d
	revision += 1
	settled = _active.is_empty()


## The native stepper, or null when the extension is missing or use_native is off.
static func _native_stepper() -> Object:
	if not use_native:
		return null
	if _native == null and ClassDB.class_exists("PerilNative"):
		_native = ClassDB.instantiate("PerilNative")
	return _native


## Pushes points away from (cx, cy). PORT: web/src/tilt-to-live/VectorGrid.ts:65-80
# DIVERGENCE(M11c P3): scans only the rows/columns whose rest position lies within
# radius + the current largest displacement of the centre; a point outside that
# window is provably farther than radius, so the result is the full scan's.
func apply_explosion(cx: float, cy: float, force: float, radius: float) -> void:
	if not awake or cols == 0 or rows == 0:
		return
	var r2: float = radius * radius
	var reach: float = radius + _max_displacement
	var c0: int = clampi(floori((cx - reach) / SPACING), 0, cols - 1)
	var c1: int = clampi(ceili((cx + reach) / SPACING), 0, cols - 1)
	var r0: int = clampi(floori((cy - reach) / SPACING), 0, rows - 1)
	var r1: int = clampi(ceili((cy + reach) / SPACING), 0, rows - 1)
	if (c1 - c0 + 1) * (r1 - r0 + 1) >= NATIVE_BLAST_MIN_POINTS:
		var native: Object = _native_stepper()
		if native != null:
			# DIVERGENCE(M11c P31): a large window (a nuke ring, a vortex pull) is scanned
			# in C++, bit-identical; a kill's small blast is cheaper than the array copies.
			var res: Array = native.call(
				"grid_explode",
				px,
				py,
				vx,
				vy,
				_active,
				_is_active,
				c0,
				c1,
				r0,
				r1,
				cols,
				cx,
				cy,
				force,
				radius
			)
			vx = res[0]
			vy = res[1]
			_active = res[2]
			_is_active = res[3]
			if res[4]:
				settled = false
			return
	for r: int in range(r0, r1 + 1):
		var row_offset: int = r * cols
		for c: int in range(c0, c1 + 1):
			var i: int = row_offset + c
			var dx: float = px[i] - cx
			var dy: float = py[i] - cy
			var dist2: float = dx * dx + dy * dy

			if dist2 < r2 and dist2 > 0.001:  # PORT: web/src/tilt-to-live/VectorGrid.ts:73
				var dist: float = sqrt(dist2)
				var factor: float = (1.0 - dist / radius) * force
				vx[i] += (dx / dist) * factor
				vy[i] += (dy / dist) * factor
				if _is_active[i] == 0:
					_is_active[i] = 1
					_active.append(i)
				settled = false


## Explosion with a negated force. PORT: web/src/tilt-to-live/VectorGrid.ts:82-84
func apply_implosion(cx: float, cy: float, force: float, radius: float) -> void:
	apply_explosion(cx, cy, -force, radius)


## DIVERGENCE(M11c review): marks point i as moved, for code that sets its position or
## velocity directly (tests); explosions do this themselves.
func touch(i: int) -> void:
	if _is_active[i] == 0:
		_is_active[i] = 1
		_active.append(i)
	settled = false
