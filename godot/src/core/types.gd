## types.gd
## PORTS: web/src/tilt-to-live/Types.ts (139 lines, source commit 7be9614)
class_name Types
extends RefCounted
## Enumerations and plain-data records shared across the simulation.
##
## PORT-NOTE: Types.ts's `Point2D` and `Velocity2D` (Types.ts:33-41) have no
## port. Godot's built-in Vector2 is their exact equivalent and every call site
## in the TypeScript treats them as one; a one-field-per-axis class would be
## slower and would not interoperate with the engine.
##
## PORT-NOTE: TypeScript optional fields (`targetAngle?`, `state?`, …) have no
## GDScript equivalent — a declared field always holds a value. Two sentinels
## are used, because no single one is safe for every field:
##   - Identifier and enum-state optionals take `Types.ABSENT`. A record id and
##     an enum ordinal are never negative, so -1 cannot collide with real data.
##   - Float optionals take `NAN`, tested with `is_nan()` as the `=== undefined`
##     check. `-1` and `0.0` are both legal angles, timers and scales, so
##     neither can stand in for "unset" without colliding with real data —
##     `EnemySwarm.ts` branches on `=== undefined` for exactly these fields
##     (`targetAngle` at EnemySwarm.ts:300, `aimTimer` at :339, `fireCooldown`
##     at :394, `orbitRadius` at :463, `pulseTimer` at :486, and
##     `stealthOpacity` at :1517 via `?? 0.65`) and NAN is never a legal
##     reading, so it cannot collide the way `-1` and `0.0` do.
## Booleans and `orbit_center` keep their natural default (`false`,
## `Vector2.ZERO`) because `undefined` is falsy in the TypeScript, so those are
## already exact.

## PORT: web/src/tilt-to-live/Types.ts:5
enum GamePhase { MENU, CINEMATIC, PLAYING, PAUSED, GAME_OVER }

## PORT: web/src/tilt-to-live/Types.ts:7
enum GameMode { CLASSIC, CODE_RED, GAUNTLET }

## PORT: web/src/tilt-to-live/Types.ts:9-16
enum WeaponType { NUKE, MISSILES, LIGHTNING, LASER, VORTEX, FREEZE, SHIELD }

## PORT: web/src/tilt-to-live/Types.ts:18-31
enum EnemyType {
	SEEKER,
	ARROW_DRONE,
	WALL_DOT,
	CIRCLE_DOT,
	TURRET_DOT,
	SPIKE_MINE,
	SNAKE_SEGMENT,
	CHARGER,
	ARTILLERY,
	CARRIER,
	BULLET,
	PULSAR,
	SPECTER,
}

## PORT: web/src/tilt-to-live/Types.ts:108
enum EnemyState { AIMING, CHARGING, COOLING, PATROL }

# PORT-NOTE: the next three enums are declared as inline string unions outside
# Types.ts, not inside it. GDScript needs named types and Types.ts is this
# port's enum home (Law 3 keeps one .gd per TS *module*, and these unions are
# not modules). Each carries its true source line.

## PORT: web/src/tilt-to-live/PlayerShip.ts:99
# DIVERGENCE(M2.5 §8.3, D3): GYRO also carries the floating joystick's output.
# The joystick emits a normalised direction-with-magnitude vector, structurally
# identical to the gyro's, so it reuses this mode rather than adding a value to
# an enum that is a cited port. While a thumb is driving the ship the mode reads
# GYRO. See game_root.gd::_update() for the call site.
enum ControlMode { MOUSE, KEYBOARD, GYRO }

## PORT: web/src/tilt-to-live/GameOptions.ts:21
enum ControlScheme { HYBRID, MOUSE, KEYBOARD, GYRO }

## PORT: web/src/tilt-to-live/TiltGame.ts:80
enum MoveDirection { UP, DOWN, LEFT, RIGHT }

## Sentinel for a TypeScript optional field that is currently undefined.
# PORT-NOTE: declared after the enums, not before them as the M1 plan drafted
# it. CONVENTIONS §2 orders constants after enums and gdlint enforces it
# (class-definitions-order). Nothing references ABSENT before this point.
const ABSENT: int = -1


## PORT: web/src/tilt-to-live/Types.ts:43-52
class WeaponOrb:
	extends RefCounted
	var id: int = 0
	var type: WeaponType = WeaponType.NUKE
	var x: float = 0.0
	var y: float = 0.0
	var radius: float = 0.0
	var spawn_time: float = 0.0
	var lifetime: float = 0.0
	var pulse_offset: float = 0.0
	## DIVERGENCE(ORB R1): false for the orbs a run opens with (the cold open's and the
	## ship's starting orb), which sit inside the magnet's reach by design — the player
	## picks when to take them. Every orb spawned in play is magnetic.
	var magnetic: bool = true


## PORT: web/src/tilt-to-live/Types.ts:54-65
class ActiveWeapon:
	extends RefCounted
	var id: int = 0
	var type: WeaponType = WeaponType.NUKE
	var x: float = 0.0
	var y: float = 0.0
	var duration: float = 0.0
	var max_duration: float = 0.0
	var radius: float = 0.0
	## `undefined` in Types.ts:62. NAN until a module sets it; see is_nan().
	var max_radius: float = NAN
	## `undefined` in Types.ts:63. NAN until a module sets it; see is_nan().
	var angle: float = NAN
	# PORT-NOTE: Types.ts:64 types this `any`. Variant is the honest port and
	# CONVENTIONS §4 permits it where the data is genuinely dynamic.
	var data: Variant = null


## PORT: web/src/tilt-to-live/Types.ts:67-76
class HomingMissile:
	extends RefCounted
	var id: int = 0
	var x: float = 0.0
	var y: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	## `null` in Types.ts:73 becomes Types.ABSENT.
	var target_id: int = Types.ABSENT
	var lifetime: float = 0.0
	var smoke_timer: float = 0.0
	## DIVERGENCE(KEY R1): 1 for a Cluster Split child (it does not split again).
	var generation: int = 0
	## DIVERGENCE(KEY R1): homing speed and turn gain — the TS's 440 and 9
	## (WeaponSystem.ts:314-317) unless Hyper Thrusters raised them.
	var cruise: float = 440.0
	var agility: float = 9.0


## PORT: web/src/tilt-to-live/Types.ts:78-85
class LightningArc:
	extends RefCounted
	var x1: float = 0.0
	var y1: float = 0.0
	var x2: float = 0.0
	var y2: float = 0.0
	var intensity: float = 0.0
	var branches: Array[Vector2] = []


# DIVERGENCE(M11c N3a): the Enemy record (Types.ts:87-116) is the native class
# PerilEnemy (native/src/peril_enemy.h), same fields and defaults, so the C++ swarm
# loop reads it directly. `type` is a plain int holding an EnemyType value.


## PORT: web/src/tilt-to-live/Types.ts:118-128
class FloatingText:
	extends RefCounted
	var id: int = 0
	var text: String = ""
	var x: float = 0.0
	var y: float = 0.0
	var vy: float = 0.0
	# PORT-NOTE: Types.ts:124 types this as a CSS colour string. Godot's Color
	# is the equivalent; conversion happens where the record is constructed.
	var color: Color = Color.WHITE
	var size: float = 0.0
	var alpha: float = 0.0
	var lifetime: float = 0.0


## PORT: web/src/tilt-to-live/Types.ts:130-139
class GameStats:
	extends RefCounted
	var score: int = 0
	var best_score: int = 0
	var multiplier: float = 1.0
	var max_multiplier: float = 1.0
	var kills: int = 0
	var survival_time: float = 0.0
	var best_combo: int = 0
	var close_calls: int = 0
