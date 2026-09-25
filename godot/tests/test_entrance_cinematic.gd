## test_entrance_cinematic.gd
## PORTS: nothing — new file, covers ui/entrance_cinematic.gd
extends GutTest
## The 600 ms cold open (TiltEntranceCinematic.ts) on the ColdOpen board (M11b R1).

const BOUNDS: Vector2 = Vector2(844.0, 390.0)

var _audio: SpyAudioBank = null
var _player: PlayerShip = null
var _swarm: EnemySwarm = null
var _grid: VectorGrid = null
var _particles: ParticleEngine = null
var _weapons: WeaponSystem = null
var _finished: int = 0


func _cinematic() -> EntranceCinematic:
	_audio = SpyAudioBank.new()
	_player = PlayerShip.new(0.0, 0.0)
	_swarm = EnemySwarm.new()
	_grid = VectorGrid.new(BOUNDS.x, BOUNDS.y)
	_particles = ParticleEngine.new()
	_weapons = WeaponSystem.new()
	_finished = 0
	var c: EntranceCinematic = EntranceCinematic.new()
	c.theme = UiTheme.build(1.0)
	c.size = BOUNDS
	add_child_autofree(c)
	c.bind(_audio, _player, _swarm, _grid, _particles, _weapons, func() -> void: _finished += 1)
	return c


func test_start_clears_the_arena_centres_the_ship_and_warps_in() -> void:
	var c: EntranceCinematic = _cinematic()
	_swarm.spawn_seeker(BOUNDS, 10.0, 10.0)
	_weapons.spawn_orb(BOUNDS, Types.WeaponType.NUKE, 100.0, 100.0)
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	assert_true(c.is_playing, ":56")
	assert_true(c.visible, ":94")
	assert_eq(c.elapsed, 0.0, ":57")
	assert_eq(_swarm.enemies.size(), 0, ":60")
	assert_eq(_weapons.orbs.size(), 0, ":61")
	assert_eq(Vector2(_player.x, _player.y), BOUNDS / 2.0, ":64-66")
	assert_almost_eq(_player.angle, -PI / 2.0, 0.0001, ":67")
	assert_eq(
		_particles.particles.size(),
		25,
		":71 — 24 sparks + the shockwave ring (ParticleEngine.ts:70-87)"
	)
	assert_eq(_audio.requested, ["warp_in"] as Array[String], ":74 (M5 R8)")
	assert_eq(_finished, 0)


func test_update_holds_the_ship_and_fills_the_bar() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	_player.x = 5.0
	_player.angle = 0.0
	assert_false(c.update(0.3, BOUNDS.x, BOUNDS.y), ":128")
	assert_almost_eq(c.progress(), 0.5, 0.0001, ":110")
	assert_eq(Vector2(_player.x, _player.y), BOUNDS / 2.0, ":119-120")
	assert_almost_eq(_player.angle, -PI / 2.0, 0.0001, ":121")
	var fill: Control = c.find_child("BarFill", true, false) as Control
	assert_almost_eq(fill.size.x, 80.0, 0.001, "160 × 50% (R4)")


func test_it_finishes_on_the_tick_that_reaches_600_ms() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	assert_false(c.update(0.59, BOUNDS.x, BOUNDS.y))
	assert_eq(_finished, 0)
	assert_true(c.update(0.02, BOUNDS.x, BOUNDS.y), ":123-126")
	assert_false(c.is_playing, ":180")
	assert_false(c.visible, ":184")
	assert_eq(_finished, 1, ":219")
	assert_false(c.update(0.1, BOUNDS.x, BOUNDS.y), ":107 — idle update is a no-op")
	assert_eq(_finished, 1)


func test_classic_hands_over_eight_ringed_seekers_a_nuke_and_a_shield() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	c.skip(BOUNDS.x, BOUNDS.y)
	assert_eq(_swarm.enemies.size(), 8, ":204")
	# i = 0: x = min(844-40, 422+260) = 682, y = 195 (:207-209)
	assert_almost_eq(_swarm.enemies[0].x, 682.0, 0.001)
	assert_almost_eq(_swarm.enemies[0].y, 195.0, 0.001)
	# i = 2 (90°): y = min(390-40, 195+260) = 350 (:209 clamp)
	assert_almost_eq(_swarm.enemies[2].y, 350.0, 0.001)
	assert_eq(_weapons.orbs.size(), 1)
	assert_eq(_weapons.orbs[0].type, Types.WeaponType.NUKE, ":212")
	assert_almost_eq(_weapons.orbs[0].x, 422.0, 0.001)
	assert_almost_eq(_weapons.orbs[0].y, 175.5, 0.001, "height × 0.45")
	assert_almost_eq(_player.shield_timer, 2.5, 0.0001, ":216")
	assert_eq(_finished, 1)


func test_code_red_hands_over_its_armada_a_vortex_and_a_nuke() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CODE_RED)
	c.skip(BOUNDS.x, BOUNDS.y)
	assert_eq(_swarm.enemies.size(), 24, ":196 → EnemySwarm.ts:784")
	assert_eq(_weapons.orbs.size(), 2)
	assert_eq(_weapons.orbs[0].type, Types.WeaponType.VORTEX, ":197")
	assert_almost_eq(_weapons.orbs[0].x, 342.0, 0.001, "w/2 - 80")
	assert_eq(_weapons.orbs[1].type, Types.WeaponType.NUKE, ":198")
	assert_almost_eq(_weapons.orbs[1].x, 502.0, 0.001, "w/2 + 80")


func test_gauntlet_hands_over_its_armada_and_a_nuke() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.GAUNTLET)
	c.skip(BOUNDS.x, BOUNDS.y)
	assert_eq(_swarm.enemies.size(), 8, ":200 → EnemySwarm.ts:794")
	assert_eq(_weapons.orbs.size(), 1)
	assert_eq(_weapons.orbs[0].type, Types.WeaponType.NUKE, ":201")


func test_skip_is_idempotent_and_ignored_when_idle() -> void:
	var c: EntranceCinematic = _cinematic()
	c.skip(BOUNDS.x, BOUNDS.y)
	assert_eq(_finished, 0, ":174 — nothing playing")
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	c.skip(BOUNDS.x, BOUNDS.y)
	c.skip(BOUNDS.x, BOUNDS.y)
	assert_false(c.update(0.0, BOUNDS.x, BOUNDS.y), "idle after the skip")
	assert_eq(_finished, 1, "Review Focus 1: one handover")
	assert_eq(_swarm.enemies.size(), 8, "no second armada")


func test_a_tap_or_click_asks_to_skip_only_while_playing() -> void:
	var c: EntranceCinematic = _cinematic()
	watch_signals(c)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	c._gui_input(touch)
	assert_signal_not_emitted(c, "skip_requested", "idle overlay")
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	c._gui_input(touch)
	assert_signal_emit_count(c, "skip_requested", 1, ":102 touchstart")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	c._gui_input(click)
	assert_signal_emit_count(c, "skip_requested", 2, ":101 click")
	assert_eq(c.mouse_filter, Control.MOUSE_FILTER_STOP, "the overlay eats the tap")


func test_only_a_left_click_asks_to_skip() -> void:
	var c: EntranceCinematic = _cinematic()
	watch_signals(c)
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	c._gui_input(wheel)
	assert_signal_not_emitted(c, "skip_requested", "wheel is not the primary button")
	var right_click: InputEventMouseButton = InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	c._gui_input(right_click)
	assert_signal_not_emitted(c, "skip_requested", "right-click is not the primary button")
	var left_click: InputEventMouseButton = InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	c._gui_input(left_click)
	assert_signal_emit_count(c, "skip_requested", 1, ":101 click (primary button)")


func test_the_board_is_built_as_drawn() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	await get_tree().process_frame
	for node_name: String in ["Void", "Glow", "Stack", "Ship", "Title", "BarTrack", "BarFill"]:
		assert_not_null(c.find_child(node_name, true, false), node_name)
	var title: Label = c.find_child("Title", true, false) as Label
	assert_eq(title.text, "PERIL POINT", "R1: app identity")
	assert_eq(title.get_theme_font_size("font_size"), 58, "ColdOpen.dc.html h1")
	var track: Control = c.find_child("BarTrack", true, false) as Control
	assert_eq(track.size, Vector2(160.0, 2.0), "ColdOpen.dc.html bar")
	assert_almost_eq(track.position.y + track.size.y, BOUNDS.y - 44.0, 0.5, "bottom 44")
	assert_almost_eq(track.position.x + track.size.x / 2.0, BOUNDS.x / 2.0, 0.5, "centred")
	var ship: TextureRect = c.find_child("Ship", true, false) as TextureRect
	assert_eq(ship.texture.get_size(), Vector2(52.0, 52.0), "ColdOpen.dc.html svg 52")


func test_a_resize_mid_cinematic_keeps_it_showing_and_filled() -> void:
	var c: EntranceCinematic = _cinematic()
	c.start(BOUNDS.x, BOUNDS.y, Types.GameMode.CLASSIC)
	c.update(0.3, BOUNDS.x, BOUNDS.y)
	c.set_ui_scale(2.0)
	assert_true(c.visible, "Review Focus 2")
	var track: Control = c.find_child("BarTrack", true, false) as Control
	var fill: Control = c.find_child("BarFill", true, false) as Control
	assert_eq(track.size, Vector2(320.0, 4.0))
	assert_almost_eq(fill.size.x, 160.0, 0.001, "still half full after the rebuild")
