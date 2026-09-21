## coin_system.gd
## PORTS: web/src/tilt-to-live/CoinSystem.ts (176 lines, source commit 7be9614)
class_name CoinSystem
extends RefCounted
## Points coin pickups: a currency-drop system independent of
## WeaponSystem's orb spawner, on its own cadence, so points income no
## longer depends solely on milestone rewards. Collecting a coin credits the
## run's single currency ("Points") via ProgressionManager.add_points_credited,
## which already applies the player's purchased points multiplier — the value
## passed to the callback must stay unmultiplied or that multiplier
## double-applies. PORT: web/src/tilt-to-live/CoinSystem.ts:4-9
##
## PORT-NOTE: render() (CoinSystem.ts:126-175) relocates to
## render/entity_layer.gd::_draw_coins (spec §4.2/D4, §5.5), the relocation M3
## and M4 made for their render() bodies. COIN_COLOR and FADE_WARNING_TIME
## stay here (LAW 3) and the layer reads them.

## --flare (#FFB14D) is the design system's reserved points/currency colour.
## Never reuse hazard red (#FF4757, enemies-only) here.
## PORT: web/src/tilt-to-live/CoinSystem.ts:25-27
const COIN_COLOR: Color = Color("#FFB14D")

const MAX_COINS_ON_SCREEN: int = 6  # PORT: web/src/tilt-to-live/CoinSystem.ts:29
const COIN_LIFETIME: float = 12.0  # PORT: web/src/tilt-to-live/CoinSystem.ts:30
const COIN_RADIUS: float = 9.0  # PORT: web/src/tilt-to-live/CoinSystem.ts:31
const COIN_BASE_VALUE: int = 25  # PORT: web/src/tilt-to-live/CoinSystem.ts:32
## Seconds remaining at which the coin starts fading out.
const FADE_WARNING_TIME: float = 3.0  # PORT: web/src/tilt-to-live/CoinSystem.ts:33
const MIN_DISTANCE_FROM_PLAYER: float = 110.0  # PORT: web/src/tilt-to-live/CoinSystem.ts:34
const SPAWN_INTERVAL_MIN: float = 2.5  # PORT: web/src/tilt-to-live/CoinSystem.ts:35
const SPAWN_INTERVAL_MAX: float = 4.0  # PORT: web/src/tilt-to-live/CoinSystem.ts:36

## Live coins. PORT: web/src/tilt-to-live/CoinSystem.ts:39
var coins: Array[CoinPickup] = []
## Coins picked up this run. PORT: web/src/tilt-to-live/CoinSystem.ts:40
var coins_collected: int = 0
## Points actually credited from coins this run. PORT: web/src/tilt-to-live/CoinSystem.ts:41
var points_from_coins: int = 0

var _next_coin_id: int = 1  # PORT: web/src/tilt-to-live/CoinSystem.ts:43
# PORT: web/src/tilt-to-live/CoinSystem.ts:44
var _spawn_timer: float = SPAWN_INTERVAL_MIN + randf() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN)


## PORT: web/src/tilt-to-live/CoinSystem.ts:46-52
func reset() -> void:
	coins = []
	coins_collected = 0
	points_from_coins = 0
	_next_coin_id = 1
	_spawn_timer = SPAWN_INTERVAL_MIN + randf() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN)


## Spawns on its own timer, ages every coin, and banks pickups through
## `on_collected` (func(value: int) -> int, returning what was actually
## credited). PORT: web/src/tilt-to-live/CoinSystem.ts:54-99
# PORT-NOTE: `bounds: {width, height}` (:57) becomes Vector2 (x = width,
# y = height), the rule in types.gd; the audio parameter is AudioBank (M2's
# TiltAudio surface).
func update(
	dt: float,
	player: PlayerShip,
	bounds: Vector2,
	particles: ParticleEngine,
	audio: AudioBank,
	mode_multiplier: float,
	on_collected: Callable
) -> void:
	# 1. Coin spawning - runs entirely on its own timer, independent of
	# WeaponSystem's orb cooldown.
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		if coins.size() < MAX_COINS_ON_SCREEN:
			_spawn_coin(bounds, player)
		_spawn_timer = SPAWN_INTERVAL_MIN + randf() * (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN)

	# 2. Lifetime + pickup collision
	for i: int in range(coins.size() - 1, -1, -1):
		var coin: CoinPickup = coins[i]
		coin.lifetime -= dt

		if coin.lifetime <= 0.0:
			coins.remove_at(i)
			continue

		var dx: float = player.x - coin.x
		var dy: float = player.y - coin.y
		var dist: float = sqrt(dx * dx + dy * dy)

		if dist < player.radius + coin.radius:
			var value: int = roundi(float(COIN_BASE_VALUE) * mode_multiplier)  # PORT: :88
			coins_collected += 1
			audio.play_coin_pickup()
			particles.emit_sparks(coin.x, coin.y, 16, COIN_COLOR, 160.0)  # PORT: :91
			# onCollected banks the coin and returns what was ACTUALLY credited, which
			# differs from `value` once the player owns the Points Multiplier upgrade.
			# Track the credited figure so the run summary cannot under-report earnings.
			# PORT-NOTE: the Callable's return is untyped by construction.
			var result: Variant = on_collected.call(value)
			if result is int:
				points_from_coins += result
			coins.remove_at(i)


## PORT: web/src/tilt-to-live/CoinSystem.ts:101-124
func _spawn_coin(bounds: Vector2, player: PlayerShip) -> void:
	var pad: float = 50.0  # PORT: :102
	var min_dist2: float = MIN_DISTANCE_FROM_PLAYER * MIN_DISTANCE_FROM_PLAYER

	var x: float = 0.0
	var y: float = 0.0
	for _attempt: int in range(10):  # PORT: :107
		x = pad + randf() * (bounds.x - pad * 2.0)
		y = pad + randf() * (bounds.y - pad * 2.0)
		var dx: float = x - player.x
		var dy: float = y - player.y
		if dx * dx + dy * dy >= min_dist2:
			break

	var coin: CoinPickup = CoinPickup.new()
	coin.id = _next_coin_id
	_next_coin_id += 1
	coin.x = x
	coin.y = y
	coin.radius = COIN_RADIUS
	coin.lifetime = COIN_LIFETIME
	coin.max_lifetime = COIN_LIFETIME
	coin.pulse_offset = randf() * TAU  # PORT: :122
	coins.append(coin)


## PORT: web/src/tilt-to-live/CoinSystem.ts:15-23
class CoinPickup:
	extends RefCounted
	var id: int = 0
	var x: float = 0.0
	var y: float = 0.0
	var radius: float = 0.0
	var lifetime: float = 0.0
	var max_lifetime: float = 0.0
	var pulse_offset: float = 0.0
