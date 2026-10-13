## ability_system.gd
## PORTS: nothing — new file per rulings DASH R1-R4 and ITEM R1 (user 2026-10-14; plan
## docs/superpowers/plans/2026-10-14-dash-and-abilities.md)
class_name AbilitySystem
extends RefCounted
## The run's dash and its item slots.
##
## The dash is a short burst a quarter of the arena long in the ship's direction that raises
## the ship's shield; its cooldown starts when that shield window ends, and it is ready at the
## start of every run. The items are up to ProgressionManager.ITEM_SLOTS power-ups the player
## fires on demand, once each a run.
##
## Requests (a double tap, an item button) arrive between ticks and are taken at the next tick,
## so the sim keeps its frame order (spec §5.4). RunController owns one; the menu backdrop has
## none.

## What the dash gauge shows.
enum DashState { READY, SHIELD, COOLDOWN }

## DIVERGENCE(DASH R2): the burst's length in seconds, and the share of the arena it covers
## along its direction (user: "dashes the user 1/4 of the screen").
const DASH_SECONDS: float = 0.12
const DASH_REACH: float = 0.25
## DIVERGENCE(DASH R2): below this speed (px/s) the ship dashes where it faces — PlayerShip's
## own turning threshold. PORT: web/src/tilt-to-live/PlayerShip.ts:197
const MOVING_SPEED: float = 20.0
## The ship's wall padding beyond its radius. PORT: web/src/tilt-to-live/PlayerShip.ts:211
const WALL_PAD: float = 6.0
## DIVERGENCE(DASH R2): the streak (sparks per tick, their speed), the launch burst, the grid
## ripple (force, radius at arena scale 1) and their colour (the shielded flame,
## PlayerShip.ts:247).
const STREAK_SPARKS: int = 3
const STREAK_SPEED: float = 90.0
const LAUNCH_SPARKS: int = 14
const LAUNCH_SPEED: float = 160.0
const RIPPLE_FORCE: float = 8.0
const RIPPLE_RADIUS: float = 140.0
const DASH_COLOR: Color = Color("#00ffee")
## DIVERGENCE(ITEM R1): an item's burst, the orb pickup's.
## PORT: web/src/tilt-to-live/WeaponSystem.ts:96
const ITEM_SPARKS: int = 20
const ITEM_SPARK_SPEED: float = 140.0

## The dash cooldown and shield this run was reset with (the save's upgrades, DASH R4).
var dash_cooldown: float = ProgressionManager.DASH_BASE_COOLDOWN
var dash_shield: float = ProgressionManager.DASH_BASE_SHIELD
## Seconds the dash's shield window has left; the cooldown waits for it (DASH R3).
var dash_shield_left: float = 0.0
## Seconds of cooldown left.
var dash_cooldown_left: float = 0.0
## Seconds of burst left.
var dash_motion_left: float = 0.0
## Dashes this run.
var dashes: int = 0
## The equipped items' power-ups, in slot order.
var item_types: Array[Types.WeaponType] = []
## True for each slot already fired this run.
var item_used: Array[bool] = []

var _dash_dir: Vector2 = Vector2.ZERO
var _dash_speed: float = 0.0
var _is_dash_requested: bool = false
var _item_requests: Array[int] = []


## Readies the dash and every item for a new run: `cooldown` and `shield` in seconds,
## `items` the loadout's Armory ids (ProgressionData.equipped_items).
func reset(cooldown: float, shield: float, items: Array[String]) -> void:
	dash_cooldown = cooldown
	dash_shield = shield
	dash_shield_left = 0.0
	dash_cooldown_left = 0.0
	dash_motion_left = 0.0
	dashes = 0
	_dash_dir = Vector2.ZERO
	_dash_speed = 0.0
	_is_dash_requested = false
	_item_requests = []
	item_types = []
	item_used = []
	for id: String in items:
		var type: int = WeaponIcons.weapon_type(id)
		if type != Types.ABSENT and item_types.size() < ProgressionManager.ITEM_SLOTS:
			item_types.append(type as Types.WeaponType)
			item_used.append(false)


## Asks for a dash at the next tick; dropped there if the dash is not ready (DASH R1).
func request_dash() -> void:
	_is_dash_requested = true


## Asks to fire item `slot` at the next tick.
func request_item(slot: int) -> void:
	if not _item_requests.has(slot):
		_item_requests.append(slot)


## True when a dash would fire now.
func is_dash_ready() -> bool:
	return dash_motion_left <= 0.0 and dash_shield_left <= 0.0 and dash_cooldown_left <= 0.0


## What the gauge shows: ready, the dash shield draining, or the cooldown.
func dash_state() -> DashState:
	if dash_shield_left > 0.0 or dash_motion_left > 0.0:
		return DashState.SHIELD
	if dash_cooldown_left > 0.0:
		return DashState.COOLDOWN
	return DashState.READY


## The gauge's fill, 0..1: the shield left while shielded, the cooldown's progress while
## cooling, full when ready.
func dash_fraction() -> float:
	match dash_state():
		DashState.SHIELD:
			return clampf(dash_shield_left / maxf(dash_shield, 0.001), 0.0, 1.0)
		DashState.COOLDOWN:
			return clampf(1.0 - dash_cooldown_left / maxf(dash_cooldown, 0.001), 0.0, 1.0)
	return 1.0


## True while slot `slot` holds an item not yet fired this run.
func is_item_ready(slot: int) -> bool:
	return slot >= 0 and slot < item_types.size() and not item_used[slot]


## One tick of the dash: counts the shield window and cooldown down, starts a requested dash
## when ready, and moves the ship through the burst. `maze` is the Gauntlet's walls, or null.
## Returns true on the tick a dash starts.
func update_dash(
	dt: float,
	player: PlayerShip,
	bounds: Vector2,
	maze: GauntletMaze,
	particles: ParticleEngine,
	grid: VectorGrid,
	audio: AudioBank
) -> bool:
	if dash_shield_left > 0.0:
		dash_shield_left -= dt
		if dash_shield_left <= 0.0:
			dash_shield_left = 0.0
			dash_cooldown_left = dash_cooldown  # DASH R3: the cooldown starts as the shield ends
	elif dash_cooldown_left > 0.0:
		dash_cooldown_left = maxf(0.0, dash_cooldown_left - dt)

	var started: bool = false
	if _is_dash_requested and is_dash_ready() and not player.is_dead:
		_start_dash(player, bounds, particles, grid, audio)
		started = true
	_is_dash_requested = false

	if dash_motion_left > 0.0:
		var step_time: float = minf(dt, dash_motion_left)
		dash_motion_left -= step_time
		_move(player, _dash_dir * _dash_speed * step_time, bounds, maze)
		player.vx = _dash_dir.x * player.max_speed
		player.vy = _dash_dir.y * player.max_speed
		player.angle = _dash_dir.angle()
		particles.emit_sparks(player.x, player.y, STREAK_SPARKS, DASH_COLOR, STREAK_SPEED)
	return started


## Marks every requested, ready slot as used and returns their power-ups, slot order; the
## caller fires them (RunController, before the weapon step).
func take_item_requests() -> Array[Types.WeaponType]:
	var fired: Array[Types.WeaponType] = []
	_item_requests.sort()
	for slot: int in _item_requests:
		if is_item_ready(slot):
			item_used[slot] = true
			fired.append(item_types[slot])
	_item_requests = []
	return fired


## The unit direction of a dash from `player`: its velocity when moving, else its facing.
static func dash_direction(player: PlayerShip) -> Vector2:
	var velocity: Vector2 = Vector2(player.vx, player.vy)
	if velocity.length() > MOVING_SPEED:
		return velocity.normalized()
	return Vector2.from_angle(player.angle)


## A quarter of the arena along unit direction `dir`: a quarter of the width sideways, of the
## height up or down (DASH R2).
static func dash_distance(dir: Vector2, bounds: Vector2) -> float:
	return DASH_REACH * Vector2(bounds.x * dir.x, bounds.y * dir.y).length()


func _start_dash(
	player: PlayerShip,
	bounds: Vector2,
	particles: ParticleEngine,
	grid: VectorGrid,
	audio: AudioBank
) -> void:
	_dash_dir = dash_direction(player)
	_dash_speed = dash_distance(_dash_dir, bounds) / DASH_SECONDS
	dash_motion_left = DASH_SECONDS
	dash_shield_left = dash_shield
	dashes += 1
	player.activate_shield(dash_shield)
	particles.emit_sparks(player.x, player.y, LAUNCH_SPARKS, DASH_COLOR, LAUNCH_SPEED)
	grid.apply_explosion(player.x, player.y, RIPPLE_FORCE, RIPPLE_RADIUS * player.scale)
	audio.play_warp_in()
	GameEvents.dash_activated.emit()


# Moves the ship by `delta` in steps no longer than its radius, kept inside the arena's padding,
# and ends the burst before a step that would enter a maze wall (DASH R2: no tunnelling).
func _move(player: PlayerShip, delta: Vector2, bounds: Vector2, maze: GauntletMaze) -> void:
	var r: float = player.radius
	var pad: float = r + WALL_PAD
	var steps: int = maxi(1, ceili(delta.length() / maxf(r, 1.0)))
	var step: Vector2 = delta / float(steps)
	for i: int in range(steps):
		var nx: float = clampf(player.x + step.x, pad, bounds.x - pad)
		var ny: float = clampf(player.y + step.y, pad, bounds.y - pad)
		if maze != null and maze.blocks(nx, ny, r):
			dash_motion_left = 0.0
			return
		player.x = nx
		player.y = ny
