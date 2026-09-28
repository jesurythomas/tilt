## test_coin_system.gd
## PORTS: nothing — new file, covers src/sim/coin_system.gd
extends GutTest
## Proves coin spawning cadence and placement, the on-screen cap, expiry,
## pickup crediting through the callback, and the mode multiplier.

const BOUNDS: Vector2 = Vector2(1000.0, 600.0)

var _cs: CoinSystem = null
var _player: PlayerShip = null
var _particles: ParticleEngine = null
var _audio: AudioBank = null
var _credited: Array[int] = []


func before_each() -> void:
	seed(20260921)
	_cs = CoinSystem.new()
	# The TS rules below predate the magnet (M11c P10); the magnet has its own tests.
	_cs.magnet_radius = 0.0
	_player = PlayerShip.new(500.0, 300.0)
	_particles = ParticleEngine.new()
	_audio = AudioBank.new()
	_credited = []


func _bank() -> Callable:
	# Stands in for ProgressionManager.add_points_credited: returns the credited
	# amount, here doubled so the test can tell the two figures apart.
	return func(value: int) -> int:
		_credited.append(value)
		return value * 2


func _step(seconds: float, mode_multiplier: float = 1.0) -> void:
	var t: float = 0.0
	while t < seconds:
		_cs.update(0.05, _player, BOUNDS, _particles, _audio, mode_multiplier, _bank())
		t += 0.05


func test_constants_match_the_typescript() -> void:
	assert_eq(CoinSystem.MAX_COINS_ON_SCREEN, 6, "CoinSystem.ts:29")
	assert_almost_eq(CoinSystem.COIN_LIFETIME, 12.0, 0.0001, ":30")
	assert_almost_eq(CoinSystem.COIN_RADIUS, 9.0, 0.0001, ":31")
	assert_eq(CoinSystem.COIN_BASE_VALUE, 10, "DIVERGENCE(ECON R1); TS 25 (:32)")
	assert_almost_eq(CoinSystem.FADE_WARNING_TIME, 3.0, 0.0001, ":33")
	assert_almost_eq(CoinSystem.MIN_DISTANCE_FROM_PLAYER, 110.0, 0.0001, ":34")
	assert_almost_eq(CoinSystem.SPAWN_INTERVAL_MIN, 2.5, 0.0001, ":35")
	assert_almost_eq(CoinSystem.SPAWN_INTERVAL_MAX, 4.0, 0.0001, ":36")
	assert_eq(CoinSystem.COIN_COLOR, Color("#FFB14D"), ":27")


func test_no_coin_before_the_first_interval_then_one() -> void:
	_step(2.4)
	assert_eq(_cs.coins.size(), 0, "spawnTimer starts at >= 2.5 s (:44)")
	_step(1.7)
	assert_eq(_cs.coins.size(), 1, "and at most 4.0 s")
	var coin: CoinSystem.CoinPickup = _cs.coins[0]
	assert_eq(coin.id, 1, "ids start at 1 (:43)")
	assert_almost_eq(coin.radius, 9.0, 0.0001)
	assert_almost_eq(coin.max_lifetime, 12.0, 0.0001)
	assert_true(coin.lifetime <= 12.0 and coin.lifetime > 11.0)
	assert_true(coin.pulse_offset >= 0.0 and coin.pulse_offset < TAU, ":122")


func test_coins_spawn_inside_the_padded_arena_away_from_the_player() -> void:
	_step(60.0)
	assert_gt(_cs.coins.size(), 0)
	for coin: CoinSystem.CoinPickup in _cs.coins:
		assert_true(coin.x >= 50.0 and coin.x <= BOUNDS.x - 50.0, "pad 50 (:102)")
		assert_true(coin.y >= 50.0 and coin.y <= BOUNDS.y - 50.0)
		var d: float = Vector2(coin.x, coin.y).distance_to(Vector2(_player.x, _player.y))
		assert_gt(d, 110.0, "MIN_DISTANCE_FROM_PLAYER (:103, :112)")


func test_never_more_than_six_on_screen() -> void:
	# One spawn per 2.5-4 s against a 12 s lifetime settles at three or four
	# coins, so the cap is exercised by pre-filling it with long-lived coins.
	for i: int in range(6):
		var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
		coin.id = 100 + i
		coin.x = 100.0 + 50.0 * float(i)
		coin.y = 100.0
		coin.radius = CoinSystem.COIN_RADIUS
		coin.lifetime = 100.0
		coin.max_lifetime = 100.0
		_cs.coins.append(coin)
	_step(20.0)
	assert_eq(_cs.coins.size(), 6, "no spawn while six are live (:67)")
	_cs.coins[0].lifetime = 0.01
	_step(4.1)
	assert_eq(_cs.coins.size(), 6, "one expired, one spawned into the freed slot")
	assert_true(_cs.coins[5].id < 100 or _cs.coins[5].id > 105, "the newest coin has a fresh id")


func test_coins_expire_after_their_lifetime() -> void:
	_step(4.0)
	assert_eq(_cs.coins.size(), 1)
	_cs.coins[0].lifetime = 0.04
	_cs.update(0.05, _player, BOUNDS, _particles, _audio, 1.0, _bank())
	assert_eq(_cs.coins.size(), 0, ":78-80")
	assert_eq(_cs.coins_collected, 0, "expiry is not a pickup")


func test_pickup_credits_through_the_callback_and_tracks_the_credited_figure() -> void:
	_step(4.0)
	assert_eq(_cs.coins.size(), 1)
	var coin: CoinSystem.CoinPickup = _cs.coins[0]
	_player.x = coin.x
	_player.y = coin.y
	var particles_before: int = _particles.particles.size()
	_cs.update(0.01, _player, BOUNDS, _particles, _audio, 1.0, _bank())
	assert_eq(_cs.coins.size(), 0, "collected coins are removed (:96)")
	assert_eq(_cs.coins_collected, 1)
	assert_eq(_credited, [10], "COIN_BASE_VALUE * 1.0, unmultiplied (:88)")
	assert_eq(_cs.points_from_coins, 20, "what the callback says was credited (:95)")
	assert_gt(_particles.particles.size(), particles_before, "16 sparks (:91)")


func test_mode_multiplier_rounds_the_coin_value() -> void:
	_step(4.0)
	var coin: CoinSystem.CoinPickup = _cs.coins[0]
	_player.x = coin.x
	_player.y = coin.y
	_cs.update(0.01, _player, BOUNDS, _particles, _audio, 1.25, _bank())
	assert_eq(_credited, [13], "Math.round(10 * 1.25) = 13 (:88)")
	_credited = []
	_step(4.0)
	coin = _cs.coins[0]
	_player.x = coin.x
	_player.y = coin.y
	_cs.update(0.01, _player, BOUNDS, _particles, _audio, 1.5, _bank())
	assert_eq(_credited, [15], "Math.round(15.0) = 15")


func test_reset_clears_everything_and_restarts_the_timer() -> void:
	_step(30.0)
	var coin: CoinSystem.CoinPickup = _cs.coins[0]
	_player.x = coin.x
	_player.y = coin.y
	_cs.update(0.01, _player, BOUNDS, _particles, _audio, 1.0, _bank())
	assert_gt(_cs.coins_collected, 0)
	_cs.reset()
	assert_eq(_cs.coins.size(), 0)
	assert_eq(_cs.coins_collected, 0)
	assert_eq(_cs.points_from_coins, 0)
	_player.x = 500.0
	_player.y = 300.0
	_step(2.4)
	assert_eq(_cs.coins.size(), 0, "the timer restarts at >= 2.5 s (:51)")
	_step(1.7)
	assert_eq(_cs.coins.size(), 1)
	assert_eq(_cs.coins[0].id, 1, "ids restart at 1 (:50)")


func _magnet_coin(offset: Vector2) -> CoinSystem.CoinPickup:
	_cs.magnet_radius = CoinSystem.MAGNET_RADIUS
	_cs.coins.clear()
	var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	coin.x = _player.x + offset.x
	coin.y = _player.y + offset.y
	coin.radius = CoinSystem.COIN_RADIUS
	coin.lifetime = CoinSystem.COIN_LIFETIME
	coin.max_lifetime = CoinSystem.COIN_LIFETIME
	_cs.coins.append(coin)
	return coin


func test_magnet_pulls_a_nearby_coin_toward_the_ship() -> void:
	# DIVERGENCE(M11c P10): user ruling 2026-09-26 — nearby coins fly to the ship.
	var coin: CoinSystem.CoinPickup = _magnet_coin(Vector2(170.0, 0.0))
	_cs.update(0.01, _player, BOUNDS, _particles, _audio, 1.0, _bank())
	assert_lt(coin.x, _player.x + 170.0, "moved toward the ship")
	assert_almost_eq(coin.y, _player.y, 0.0001, "straight at it")
	assert_eq(_cs.coins.size(), 1, "not collected in one tick")


func test_magnet_collects_a_nearby_coin_without_the_ship_moving() -> void:
	_magnet_coin(Vector2(0.0, -170.0))
	for i: int in range(60):  # 0.6 s of sim time
		_cs.update(0.01, _player, BOUNDS, _particles, _audio, 1.0, _bank())
	assert_eq(_cs.coins_collected, 1)


func test_magnet_ignores_coins_beyond_its_radius() -> void:
	var coin: CoinSystem.CoinPickup = _magnet_coin(Vector2(CoinSystem.MAGNET_RADIUS + 5.0, 0.0))
	var x0: float = coin.x
	_cs.update(0.05, _player, BOUNDS, _particles, _audio, 1.0, _bank())
	assert_eq(coin.x, x0)
