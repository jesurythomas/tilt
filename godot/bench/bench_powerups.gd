## bench_powerups.gd — desktop cost of each power-up over its active time (M11c,
## user 2026-09-27: "any power up used currently drops frames"). Not part of the suite.
## Run: "$GODOT" --headless --path godot -s addons/gut/gut_cmdln.gd -gtest=res://bench/bench_powerups.gd -gexit
## 200 seekers around the ship (held still: speed_scale 0, so the swarm loop's work is
## unchanged but nothing reaches the ship), then the power-up fires at the ship and
## RunController.update runs 2 s of ticks; the particle flush runs once per 2 ticks
## (60 fps). Prints µs per tick for each probe section and the worst tick.
extends GutTest

const BOUNDS: Vector2 = Vector2(2162.0, 1056.0)
const ENEMIES: int = 200
const TICKS: int = 240
const DT: float = 1.0 / 120.0
const SECTIONS: Array[String] = [
	"s_swarm", "s_weapons", "s_grid", "s_particles", "s_collide", "s_goals", "s_hud_signal"
]

var _rc: RunController = null
## Every perk rank 5 and every keystone on (the perf test mode's maxed upgrades).
var _maxed: bool = false


func _setup() -> void:
	seed(4321)
	var player: PlayerShip = PlayerShip.new(BOUNDS.x * 0.5, BOUNDS.y * 0.5)
	var progression: ProgressionManager = ProgressionManager.new()
	_rc = RunController.new(
		player,
		EnemySwarm.new(),
		WeaponSystem.new(),
		ParticleEngine.new(),
		VectorGrid.new(int(BOUNDS.x), int(BOUNDS.y)),
		ScoreManager.new(),
		AudioBank.new(),
		progression,
		GameOptionsManager.new(),
		CoinSystem.new()
	)
	if _maxed:
		var all: Dictionary = progression.data.perks.to_dict()
		for weapon: String in all:
			var record: Dictionary = all[weapon]
			for key: String in record:
				record[key] = true if record[key] is bool else 5
		progression.data.perks.from_dict(all)
	_rc.goals = GoalManager.new(progression)
	_rc.maze = GauntletMaze.new()
	_rc.reset_run(BOUNDS)
	_rc.swarm.scale = 1.25
	_rc.weapons.set_scale(1.25)
	_rc.swarm.set_speed_scale(0.0)
	var c: Vector2 = BOUNDS * 0.5
	for i: int in range(ENEMIES):
		var a: float = randf() * TAU
		var r: float = 120.0 + randf() * 480.0
		_rc.swarm.spawn_seeker(BOUNDS, c.x + cos(a) * r, c.y + sin(a) * r * 0.8)


func _run(label: String, weapon: int) -> void:
	_setup()
	# Settle one tick so spawn-time work is not charged to the power-up.
	_rc.update(DT, Types.ControlMode.KEYBOARD, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	if weapon >= 0:
		_rc.weapons.trigger_weapon(
			weapon as Types.WeaponType,
			_rc.player.x,
			_rc.player.y,
			_rc.player,
			_rc.swarm.enemies,
			_rc.particles,
			_rc.grid,
			_rc.audio,
			Callable(_rc, "handle_enemy_killed"),
			_rc.progression.data.perks
		)
	PerfProbe.enabled = true
	PerfProbe.reset()
	var worst: int = 0
	var flush_us: int = 0
	var t_all: int = Time.get_ticks_usec()
	for i: int in range(TICKS):
		_rc.swarm._spawn_timer = 1.0e9
		_rc.swarm._wave_timer = 1.0e9
		_rc.weapons._orb_spawn_timer = 1.0e9
		var t0: int = Time.get_ticks_usec()
		_rc.update(DT, Types.ControlMode.KEYBOARD, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		if i % 2 == 1:
			var f0: int = Time.get_ticks_usec()
			_rc.particles.flush()
			flush_us += Time.get_ticks_usec() - f0
		worst = maxi(worst, Time.get_ticks_usec() - t0)
	var total: float = float(Time.get_ticks_usec() - t_all) / TICKS
	var parts: PackedStringArray = PackedStringArray()
	for s: String in SECTIONS:
		parts.append("%s %.0f" % [s.trim_prefix("s_"), float(PerfProbe.accumulated(s)) / TICKS])
	parts.append("flush %.0f" % (float(flush_us) / TICKS))
	print(
		(
			"BENCH %-10s total %6.0f us/tick  worst %6d  | %s  (left %d)"
			% [label, total, worst, "  ".join(parts), _rc.swarm.enemies.size()]
		)
	)


func test_bench_powerups() -> void:
	_run("none", -1)
	for w: Types.WeaponType in [
		Types.WeaponType.NUKE,
		Types.WeaponType.MISSILES,
		Types.WeaponType.LIGHTNING,
		Types.WeaponType.LASER,
		Types.WeaponType.VORTEX,
		Types.WeaponType.FREEZE,
		Types.WeaponType.SHIELD,
	]:
		var label: String = Types.WeaponType.keys()[w]
		_run(label, w)
	pass_test("bench")


func test_bench_powerups_maxed() -> void:
	# Every rank 5 and every keystone on (KEY R1's 21 included).
	_maxed = true
	test_bench_powerups()
	_maxed = false
