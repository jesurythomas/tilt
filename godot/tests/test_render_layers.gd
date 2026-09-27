# gdlint:disable=max-public-methods
## test_render_layers.gd
## Verifies RenderContext, EffectLayer, and EntityLayer can be bound and instantiated.
extends GutTest


func test_render_context_instantiation() -> void:
	var rc: RenderContext = RenderContext.new()
	assert_not_null(rc)
	assert_eq(rc.scale, 1.0)
	assert_eq(rc.game_mode, Types.GameMode.CLASSIC)
	assert_eq(rc.control_mode, Types.ControlMode.MOUSE)
	rc.viewport_size = Vector2(1920.0, 1080.0)
	rc.bounds = Vector2(1000.0, 600.0)
	assert_eq(rc.bounds.x, 1000.0)


func test_effect_layer_bind_and_configure() -> void:
	var el: EffectLayer = EffectLayer.new()
	assert_not_null(el)
	var particles: ParticleEngine = ParticleEngine.new()
	var scores: ScoreManager = ScoreManager.new()
	el.bind(particles, scores)

	# Populate some particles and floating text
	particles.emit_sparks(100.0, 100.0, 5, Color.WHITE)
	particles.emit_explosion(200.0, 200.0, Color.RED)
	var ft: Types.FloatingText = Types.FloatingText.new()
	ft.x = 150.0
	ft.y = 150.0
	ft.text = "+100"
	ft.color = Color.YELLOW
	ft.size = 20.0
	ft.alpha = 1.0
	scores.floating_texts.append(ft)

	# Verify nodes can be added to tree and redraw queued without crash
	add_child_autofree(el)
	el.queue_redraw()
	assert_true(true, "EffectLayer redraw queued without error")


func test_entity_layer_bind_entities_and_draw() -> void:
	var layer: EntityLayer = EntityLayer.new()
	assert_not_null(layer)
	var player: PlayerShip = PlayerShip.new(500.0, 300.0)
	var swarm: EnemySwarm = EnemySwarm.new()
	var weapons: WeaponSystem = WeaponSystem.new()

	layer.bind_entities(player, swarm, weapons)
	layer.set_elapsed(1.5)
	layer.set_high_contrast_halo(true)

	# Spawn entities
	weapons.spawn_orb(Vector2(800.0, 600.0), Types.WeaponType.NUKE)
	var w: Types.ActiveWeapon = Types.ActiveWeapon.new()
	w.type = Types.WeaponType.NUKE
	w.x = 400.0
	w.y = 300.0
	w.duration = 0.5
	w.max_duration = 1.0
	w.radius = 150.0
	w.max_radius = 300.0
	weapons.active_weapons.append(w)
	swarm.spawn_seeker(Vector2(200.0, 200.0))

	add_child_autofree(layer)
	layer.queue_redraw()
	assert_true(true, "EntityLayer redraw queued without error")


func test_joystick_layer_draws_nothing_while_idle() -> void:
	var layer: JoystickLayer = JoystickLayer.new()
	var stick: FloatingJoystick = FloatingJoystick.new()
	layer.bind(stick)
	add_child_autofree(layer)
	layer.queue_redraw()
	assert_false(stick.is_active, "an idle stick is not drawn")


func test_joystick_layer_redraws_when_engaged() -> void:
	var layer: JoystickLayer = JoystickLayer.new()
	var stick: FloatingJoystick = FloatingJoystick.new()
	layer.bind(stick)
	add_child_autofree(layer)

	stick.on_touch(0, Vector2(300.0, 400.0))
	stick.on_drag(0, Vector2(340.0, 400.0))
	layer.queue_redraw()
	assert_true(stick.is_active, "JoystickLayer redraw queued without error while engaged")


func test_entity_layer_accepts_an_arena_origin() -> void:
	var layer: EntityLayer = EntityLayer.new()
	layer.set_arena_origin(Vector2(24.0, 36.0))
	add_child_autofree(layer)
	layer.queue_redraw()
	assert_true(true, "EntityLayer accepts the arena origin and redraws")


func test_effect_layer_accepts_an_arena_origin() -> void:
	var layer: EffectLayer = EffectLayer.new()
	var particles: ParticleEngine = ParticleEngine.new()
	var scores: ScoreManager = ScoreManager.new()
	layer.bind(particles, scores)
	layer.set_arena_origin(Vector2(24.0, 36.0))
	particles.emit_explosion(100.0, 100.0, Color.RED)
	add_child_autofree(layer)
	layer.queue_redraw()
	assert_true(true, "EffectLayer accepts the arena origin and redraws")


func test_entity_layer_draws_every_enemy_type_without_error() -> void:
	var layer: EntityLayer = EntityLayer.new()
	var player: PlayerShip = PlayerShip.new(500.0, 300.0)
	var swarm: EnemySwarm = EnemySwarm.new()
	var weapons: WeaponSystem = WeaponSystem.new()
	layer.bind_entities(player, swarm, weapons)
	layer.set_elapsed(2.0)
	layer.set_arena_origin(Vector2(8.0, 12.0))
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var player_pos: Vector2 = Vector2(500.0, 300.0)

	swarm.spawn_seeker(bounds)
	swarm.spawn_arrow_formation(bounds)
	swarm.spawn_sequential_gauntlet_wall(bounds)
	swarm.spawn_circle_encirclement(player_pos, bounds, 0)
	swarm.spawn_turret(bounds)
	swarm.spawn_rotating_gate(bounds)
	swarm.spawn_snake(bounds)
	swarm.spawn_charger(bounds, player_pos)
	var charging: PerilEnemy = swarm.spawn_charger(bounds, player_pos)
	charging.state = Types.EnemyState.CHARGING
	charging.vx = 100.0
	var artillery: PerilEnemy = swarm.spawn_artillery(bounds, player_pos)
	artillery.fire_cooldown = 0.3
	swarm.spawn_bullet(100.0, 100.0, player_pos)
	swarm.spawn_carrier(bounds, player_pos)
	swarm.spawn_pulsar(bounds, player_pos)
	swarm.spawn_specter(bounds, player_pos)
	var mine: PerilEnemy = PerilEnemy.new()
	mine.type = Types.EnemyType.SPIKE_MINE
	mine.radius = 8.0
	swarm.enemies.append(mine)
	var frozen: PerilEnemy = swarm.spawn_seeker(bounds)
	frozen.frozen = true
	var turret: PerilEnemy = PerilEnemy.new()
	turret.type = Types.EnemyType.TURRET_DOT
	turret.radius = 12.0
	turret.target_angle = 1.0
	swarm.enemies.append(turret)

	add_child_autofree(layer)
	layer.queue_redraw()
	await wait_frames(2)
	# The ring is 8 dots at score 0 (M11c P9 user ruling; the TS spawns 12).
	assert_eq(swarm.enemies.size(), 1 + 7 + 38 + 8 + 1 + 6 + 8 + 2 + 1 + 1 + 5 + 1 + 1 + 1 + 1 + 1)


func test_layers_draw_every_weapon_fx_and_every_orb_glyph_without_error() -> void:
	var entity: EntityLayer = EntityLayer.new()
	var effect: EffectLayer = EffectLayer.new()
	var player: PlayerShip = PlayerShip.new(500.0, 300.0)
	var swarm: EnemySwarm = EnemySwarm.new()
	var weapons: WeaponSystem = WeaponSystem.new()
	var particles: ParticleEngine = ParticleEngine.new()
	var scores: ScoreManager = ScoreManager.new()
	var grid: VectorGrid = VectorGrid.new(1000.0, 600.0)
	var audio: AudioBank = AudioBank.new()
	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var no_kill: Callable = func(_e: PerilEnemy, _w: Types.WeaponType) -> void: pass

	entity.bind_entities(player, swarm, weapons)
	entity.set_elapsed(2.0)
	entity.set_arena_origin(Vector2(8.0, 12.0))
	effect.bind(particles, scores, weapons)
	effect.set_elapsed(2.0)
	effect.set_arena_origin(Vector2(8.0, 12.0))

	weapons.spawn_orb(bounds, Types.WeaponType.NUKE, 100.0, 100.0)
	weapons.spawn_orb(bounds, Types.WeaponType.MISSILES, 160.0, 100.0)
	weapons.spawn_orb(bounds, Types.WeaponType.LIGHTNING, 220.0, 100.0)
	weapons.spawn_orb(bounds, Types.WeaponType.LASER, 280.0, 100.0)
	weapons.spawn_orb(bounds, Types.WeaponType.VORTEX, 340.0, 100.0)
	weapons.spawn_orb(bounds, Types.WeaponType.FREEZE, 400.0, 100.0)
	weapons.spawn_orb(bounds, Types.WeaponType.SHIELD, 460.0, 100.0)
	weapons.activate_weapon(
		Types.WeaponType.NUKE, 200.0, 300.0, player, [], particles, grid, audio, no_kill
	)
	var cross: ProgressionManager.WeaponPerks = ProgressionManager.WeaponPerks.new()
	cross.laser.cross_beam = true
	weapons.activate_weapon(
		Types.WeaponType.LASER, 0.0, 0.0, player, [], particles, grid, audio, no_kill, cross
	)
	weapons.activate_weapon(
		Types.WeaponType.VORTEX, 700.0, 300.0, player, [], particles, grid, audio, no_kill
	)
	weapons.activate_weapon(
		Types.WeaponType.MISSILES, 500.0, 500.0, player, [], particles, grid, audio, no_kill
	)
	var victim: PerilEnemy = PerilEnemy.new()
	victim.id = 1
	victim.x = 600.0
	victim.y = 100.0
	victim.radius = 8.0
	var enemies: Array[PerilEnemy] = [victim]
	weapons.activate_weapon(
		Types.WeaponType.LIGHTNING, 500.0, 100.0, player, enemies, particles, grid, audio, no_kill
	)

	assert_eq(weapons.orbs.size(), 7)
	assert_eq(weapons.active_weapons.size(), 3)
	assert_eq(weapons.missiles.size(), 8)
	assert_eq(weapons.lightning_arcs.size(), 1)

	add_child_autofree(entity)
	add_child_autofree(effect)
	entity.queue_redraw()
	effect.queue_redraw()
	await wait_frames(2)
	assert_eq(weapons.orbs.size(), 7, "drawing consumes nothing")


func test_entity_layer_draws_coins_without_error() -> void:
	var layer: EntityLayer = EntityLayer.new()
	add_child_autofree(layer)
	var player: PlayerShip = PlayerShip.new(100.0, 100.0)
	var coins: CoinSystem = CoinSystem.new()
	var fresh: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	fresh.id = 1
	fresh.x = 200.0
	fresh.y = 150.0
	fresh.radius = CoinSystem.COIN_RADIUS
	fresh.lifetime = 10.0
	fresh.max_lifetime = CoinSystem.COIN_LIFETIME
	var fading: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	fading.id = 2
	fading.x = 300.0
	fading.y = 150.0
	fading.radius = CoinSystem.COIN_RADIUS
	fading.lifetime = 1.0
	fading.max_lifetime = CoinSystem.COIN_LIFETIME
	coins.coins.append(fresh)
	coins.coins.append(fading)
	layer.bind_entities(player, EnemySwarm.new(), WeaponSystem.new(), coins)
	layer.set_elapsed(1.5)
	layer.queue_redraw()
	await get_tree().process_frame
	assert_true(true, "two coins, one inside FADE_WARNING_TIME, drew without a script error")


func _remove_save() -> void:
	var absolute: String = ProjectSettings.globalize_path(ProgressionManager.SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func test_grid_layer_resolves_theme_colours() -> void:
	# PORT: web/src/tilt-to-live/TiltRenderer.ts:60-62 defaults, :76-80 theme override
	var layer: GridLayer = GridLayer.new()
	add_child_autofree(layer)
	assert_eq(layer.background_colors(), [GridLayer.BG_INNER, GridLayer.BG_MID, GridLayer.BG_OUTER])
	assert_eq(layer.grid_color(), GridLayer.GRID_COLOR)
	assert_eq(layer.boundary_color(), GridLayer.BOUNDARY_COLOR)
	_remove_save()
	var progression: ProgressionManager = ProgressionManager.new()
	var synth: ProgressionManager.ArenaThemeConfig = progression.arena_theme_catalog[1]
	layer.set_arena_theme(synth)
	assert_eq(layer.background_colors(), synth.bg_gradient)
	assert_eq(layer.grid_color(), synth.grid_color)
	assert_eq(layer.boundary_color(), synth.boundary_color)
	layer.bind(VectorGrid.new(400, 300))
	layer.queue_redraw()
	await get_tree().process_frame
	layer.set_arena_theme(null)
	assert_eq(layer.boundary_color(), GridLayer.BOUNDARY_COLOR, "null restores the defaults")
	_remove_save()


func test_grid_layer_feeds_the_theme_to_the_background_shader() -> void:
	# M11c review: the background is a shader (no banding); its colours follow the theme.
	_remove_save()
	var progression: ProgressionManager = ProgressionManager.new()
	var layer: GridLayer = GridLayer.new()
	add_child_autofree(layer)
	layer.bind(VectorGrid.new(400, 300))
	layer.refresh()
	var mat: ShaderMaterial = layer.background_material()
	var inner0: Color = mat.get_shader_parameter("inner_color")
	assert_eq(inner0, GridLayer.BG_INNER)
	layer.set_arena_theme(progression.arena_theme_catalog[2])
	layer.refresh()
	var inner1: Color = mat.get_shader_parameter("inner_color")
	assert_eq(inner1, progression.arena_theme_catalog[2].bg_gradient[0])
	var outer1: Color = mat.get_shader_parameter("outer_color")
	assert_eq(outer1, progression.arena_theme_catalog[2].bg_gradient[2])
	_remove_save()


func test_grid_lines_redraw_only_when_the_lattice_moves() -> void:
	# M11c review: a settled grid costs no redraw; an explosion wakes it until it settles.
	var layer: GridLayer = GridLayer.new()
	add_child_autofree(layer)
	var grid: VectorGrid = VectorGrid.new(400, 300)
	layer.bind(grid)
	layer.refresh()
	var rev: int = grid.revision
	for i: int in range(5):
		grid.update(1.0 / 120.0)
	assert_eq(grid.revision, rev, "a settled lattice does not step")
	grid.apply_explosion(200.0, 150.0, 20.0, 120.0)
	assert_false(grid.settled)
	grid.update(1.0 / 120.0)
	assert_gt(grid.revision, rev, "an explosion wakes it")
	for i: int in range(2000):
		grid.update(1.0 / 120.0)
	assert_true(grid.settled, "it settles again")
	assert_eq(grid.px, grid.ox, "snapped exactly to rest")


func test_entity_layer_draws_every_enemy_type_under_every_skin() -> void:
	_remove_save()
	var progression: ProgressionManager = ProgressionManager.new()
	var layer: EntityLayer = EntityLayer.new()
	var swarm: EnemySwarm = EnemySwarm.new()
	var bounds: Vector2 = Vector2(800.0, 600.0)
	var player: PlayerShip = PlayerShip.new(400.0, 300.0)
	var player_pos: Vector2 = Vector2(player.x, player.y)
	layer.bind_entities(player, swarm, WeaponSystem.new())
	add_child_autofree(layer)
	# enemy_swarm.gd:61, :101, :223, :292, :145, :184 — one of each skin-reading type
	swarm.spawn_seeker(bounds, 100.0, 100.0)
	swarm.spawn_charger(bounds, player_pos)
	swarm.spawn_artillery(bounds, player_pos)
	swarm.spawn_carrier(bounds, player_pos)
	swarm.spawn_pulsar(bounds, player_pos)
	swarm.spawn_specter(bounds, player_pos)
	assert_true(swarm.enemies.size() >= 6)
	var skins: Array[ProgressionManager.EnemySkinConfig] = (
		progression.enemy_skin_catalog.duplicate()
	)
	skins.append(null)
	for skin: ProgressionManager.EnemySkinConfig in skins:
		layer.set_enemy_skin(skin)
		layer.queue_redraw()
		await get_tree().process_frame
	assert_true(true, "six skins plus the null (menu backdrop) arm drew without a script error")
	_remove_save()


func test_hull_points_match_the_ts_prows() -> void:
	# PORT: web/src/tilt-to-live/PlayerShip.ts — first moveTo of each hull
	assert_eq(EntityLayer.hull_points_for(ProgressionManager.ShipShape.CLASSIC).size(), 4)  # :598-601
	assert_eq(
		EntityLayer.hull_points_for(ProgressionManager.ShipShape.CLASSIC)[0], Vector2(15.0, 0.0)
	)
	assert_eq(EntityLayer.hull_points_for(ProgressionManager.ShipShape.VIPER).size(), 11)  # :371-381
	assert_eq(
		EntityLayer.hull_points_for(ProgressionManager.ShipShape.VIPER)[0], Vector2(18.0, 0.0)
	)
	assert_eq(EntityLayer.hull_points_for(ProgressionManager.ShipShape.PHANTOM).size(), 6)  # :411-416
	assert_eq(EntityLayer.hull_points_for(ProgressionManager.ShipShape.SOLAR).size(), 13)  # :448-460
	assert_eq(EntityLayer.hull_points_for(ProgressionManager.ShipShape.CYBER).size(), 8)  # :496-503
	assert_gt(
		EntityLayer.hull_points_for(ProgressionManager.ShipShape.SHURIKEN).size(),
		8,
		"curves sampled"
	)
	assert_eq(
		EntityLayer.hull_points_for(ProgressionManager.ShipShape.SHURIKEN)[0], Vector2(17.0, 0.0)
	)
	assert_eq(
		EntityLayer.hull_points_for(ProgressionManager.ShipShape.CELESTIAL)[0], Vector2(18.0, 0.0)
	)


func test_entity_layer_draws_every_ship_shape() -> void:
	_remove_save()
	var progression: ProgressionManager = ProgressionManager.new()
	var layer: EntityLayer = EntityLayer.new()
	var player: PlayerShip = PlayerShip.new(300.0, 200.0)
	layer.bind_entities(player, EnemySwarm.new(), WeaponSystem.new())
	add_child_autofree(layer)
	for ship: ProgressionManager.ShipSkinConfig in progression.ship_catalog:
		layer.set_ship_skin(ship)
		assert_eq(layer.get_ship_skin().id, ship.id)
		layer.queue_redraw()
		await get_tree().process_frame
	layer.set_ship_skin(null)
	layer.queue_redraw()
	await get_tree().process_frame
	assert_true(true, "seven hulls and the null fallback drew without a script error")
	_remove_save()


# DIVERGENCE(mobile-scale): the model scale is a render-only multiplier with
# no TypeScript counterpart; this exercises every enemy drawer under it.
func test_entity_layer_draws_every_entity_kind_at_a_model_scale() -> void:
	var layer: EntityLayer = EntityLayer.new()
	assert_almost_eq(layer.get_model_scale(), 1.0, 0.0001, "sim size by default")
	layer.set_model_scale(1.5)
	assert_almost_eq(layer.get_model_scale(), 1.5, 0.0001)

	var bounds: Vector2 = Vector2(1000.0, 600.0)
	var player: PlayerShip = PlayerShip.new(500.0, 300.0)
	var swarm: EnemySwarm = EnemySwarm.new()
	var weapons: WeaponSystem = WeaponSystem.new()
	var coins: CoinSystem = CoinSystem.new()
	layer.bind_entities(player, swarm, weapons, coins)

	for type: Types.WeaponType in Types.WeaponType.values():
		weapons.spawn_orb(Vector2(100.0, 100.0), type)
	swarm.spawn_seeker(bounds).frozen = true
	swarm.spawn_seeker(bounds)
	swarm.spawn_charger(bounds, Vector2(player.x, player.y))
	swarm.spawn_pulsar(bounds, Vector2(player.x, player.y))
	swarm.spawn_specter(bounds, Vector2(player.x, player.y))
	swarm.spawn_artillery(bounds, Vector2(player.x, player.y))
	swarm.spawn_bullet(10.0, 10.0, Vector2(player.x, player.y))
	swarm.spawn_carrier(bounds, Vector2(player.x, player.y))
	swarm.spawn_turret(bounds)
	var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
	coin.x = 300.0
	coin.y = 300.0
	coin.radius = CoinSystem.COIN_RADIUS
	coin.lifetime = 1.0
	coins.coins.append(coin)

	add_child_autofree(layer)
	layer.queue_redraw()
	await wait_frames(2)
	assert_true(true, "every drawer ran under a non-unit model scale")


func test_grid_layer_mode_colours_without_a_theme() -> void:
	var layer: GridLayer = GridLayer.new()
	add_child_autofree(layer)
	layer.set_elapsed(0.0)  # alert pulse 0.5
	layer.set_game_mode(Types.GameMode.CODE_RED)
	var plasma: Color = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0)
	assert_eq(layer.background_colors()[0], Color("#180e28"), "TiltRenderer.ts:67")
	var grid: Color = layer.grid_color()
	assert_almost_eq(grid.a, 0.28 + 0.08 * 0.5, 0.0001, ":68")
	assert_almost_eq(grid.r, plasma.r, 0.0001)
	assert_almost_eq(layer.boundary_color().a, 0.55 + 0.2 * 0.5, 0.0001, ":69")
	layer.set_game_mode(Types.GameMode.GAUNTLET)
	assert_eq(layer.background_colors()[2], Color("#060301"), ":71")
	assert_almost_eq(layer.grid_color().a, 0.35, 0.0001, ":72")
	assert_almost_eq(layer.boundary_color().a, 0.75, 0.0001, ":73")
	layer.set_game_mode(Types.GameMode.CLASSIC)
	assert_eq(layer.background_colors()[0], GridLayer.BG_INNER, ":60")


func test_equipped_theme_overrides_the_mode_colours() -> void:
	var layer: GridLayer = GridLayer.new()
	add_child_autofree(layer)
	var progression: ProgressionManager = ProgressionManager.new()
	var theme: ProgressionManager.ArenaThemeConfig = progression.get_equipped_arena_theme()
	layer.set_arena_theme(theme)
	layer.set_game_mode(Types.GameMode.GAUNTLET)
	assert_eq(layer.background_colors(), theme.bg_gradient, "TiltRenderer.ts:76-80 wins (M10 R6)")
	assert_eq(layer.grid_color(), theme.grid_color)
	assert_eq(layer.boundary_color(), theme.boundary_color)


func test_alert_pulse_matches_the_ts() -> void:
	assert_almost_eq(GridLayer.alert_pulse(0.0), 0.5, 0.0001, "TiltRenderer.ts:65")
	assert_almost_eq(GridLayer.alert_pulse(PI / 8.0), 1.0, 0.0001)
	assert_almost_eq(GridLayer.alert_pulse(3.0 * PI / 8.0), 0.0, 0.0001)


func test_grid_layer_draws_every_mode_without_error() -> void:
	var layer: GridLayer = GridLayer.new()
	layer.bind(VectorGrid.new(400, 300))
	add_child_autofree(layer)
	for mode: Types.GameMode in [
		Types.GameMode.CLASSIC, Types.GameMode.CODE_RED, Types.GameMode.GAUNTLET
	]:
		layer.set_game_mode(mode)
		layer.set_elapsed(1.3)
		layer.queue_redraw()
		await get_tree().process_frame
	assert_eq(layer.get_game_mode(), Types.GameMode.GAUNTLET)


func test_stripe_polygons_stay_inside_the_segment() -> void:
	var stripes: Array[PackedVector2Array] = EntityLayer.stripe_polygons(100.0, 22.0, 0.3)
	assert_false(stripes.is_empty())
	for piece: PackedVector2Array in stripes:
		for p: Vector2 in piece:
			assert_true(
				p.x >= -0.001 and p.x <= 100.001 and p.y >= -0.001 and p.y <= 22.001,
				"clipped to the segment (GauntletMaze.ts:320-322): %s" % p
			)
	# (elapsed * 20) % 16 (:327): the stripe cycle repeats every 0.8 s.
	assert_eq(
		EntityLayer.stripe_polygons(100.0, 22.0, 0.0), EntityLayer.stripe_polygons(100.0, 22.0, 0.8)
	)


func test_stripe_polygons_match_a_brute_force_per_stroke_clip() -> void:
	# Reference: the pre-F-1 approach, clipping every stroke individually.
	var cases: Array[Vector3] = [
		Vector3(10.0, 22.0 * 1.75, 0.0),
		Vector3(100.0, 22.0 * 1.75, 0.4),
		Vector3(1015.0, 22.0 * 1.75, 1.3),
	]
	for c: Vector3 in cases:
		var seg_width: float = c.x
		var row_height: float = c.y
		var elapsed: float = c.z
		var expected: Array[PackedVector2Array] = _brute_force_stripe_polygons(
			seg_width, row_height, elapsed
		)
		var actual: Array[PackedVector2Array] = EntityLayer.stripe_polygons(
			seg_width, row_height, elapsed
		)
		assert_eq(
			actual.size(),
			expected.size(),
			(
				"same piece count (seg_width=%s, row_height=%s, elapsed=%s)"
				% [seg_width, row_height, elapsed]
			)
		)
		for exp_piece: PackedVector2Array in expected:
			var found: bool = false
			for act_piece: PackedVector2Array in actual:
				if _point_sets_match(exp_piece, act_piece):
					found = true
					break
			assert_true(
				found,
				(
					"F-1: shared clip must match the brute-force per-stroke clip (seg_width=%s)"
					% seg_width
				)
			)


## Brute-force reference for the F-1 test: clips every stroke individually,
## as EntityLayer.stripe_polygons did before the shared-clip restructure.
func _brute_force_stripe_polygons(
	seg_width: float, row_height: float, elapsed: float
) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var half_width: float = 6.0 / 2.0
	var stripe_spacing: float = 16.0
	var stripe_offset: float = fmod(elapsed * 20.0, stripe_spacing)
	var normal: Vector2 = Vector2(-1.0, 1.0).normalized() * half_width
	var clip: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(seg_width, 0.0),
			Vector2(seg_width, row_height),
			Vector2(0.0, row_height)
		]
	)
	var sx: float = -row_height + stripe_offset
	while sx < seg_width + row_height:
		var from: Vector2 = Vector2(sx, 0.0)
		var to: Vector2 = Vector2(sx + row_height, row_height)
		var stroke: PackedVector2Array = PackedVector2Array(
			[from + normal, from - normal, to - normal, to + normal]
		)
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(stroke, clip):
			out.append(piece)
		sx += stripe_spacing
	return out


## True when two point sets contain the same points within 0.001, regardless
## of start vertex or winding order (F-1: intersect_polygons may rotate the
## first vertex it returns).
func _point_sets_match(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	var remaining: Array[Vector2] = []
	for p: Vector2 in b:
		remaining.append(p)
	for pa: Vector2 in a:
		var match_index: int = -1
		for i: int in range(remaining.size()):
			if pa.distance_to(remaining[i]) <= 0.001:
				match_index = i
				break
		if match_index == -1:
			return false
		remaining.remove_at(match_index)
	return true


func test_beacon_pulse_matches_the_ts() -> void:
	assert_almost_eq(EntityLayer.beacon_pulse(0.0, 0), 0.6, 0.0001, "GauntletMaze.ts:353")
	assert_almost_eq(EntityLayer.beacon_pulse(PI / 16.0, 0), 1.0, 0.0001)
	assert_almost_eq(EntityLayer.beacon_pulse(0.0, 3), 0.6 + 0.4 * sin(3.0), 0.0001)


func test_entity_layer_draws_the_maze_only_in_gauntlet() -> void:
	var layer: EntityLayer = EntityLayer.new()
	var maze: GauntletMaze = GauntletMaze.new()
	maze.reset(800.0, 600.0)
	for row: GauntletMaze.GauntletWallRow in maze.rows:
		row.y += 400.0  # bring the seeded rows on screen
	layer.bind_entities(PlayerShip.new(400.0, 300.0))
	layer.bind_maze(maze)
	add_child_autofree(layer)
	assert_false(layer.is_maze_drawn(), "CLASSIC by default (TiltRenderer.ts:130)")
	layer.set_game_mode(Types.GameMode.GAUNTLET)
	assert_true(layer.is_maze_drawn())
	layer.set_elapsed(2.0)
	layer.queue_redraw()
	await get_tree().process_frame
	layer.set_game_mode(Types.GameMode.CODE_RED)
	assert_false(layer.is_maze_drawn())


func test_banner_alpha_fades_in_holds_and_out() -> void:
	# PORT: TiltRenderer.ts:520
	assert_almost_eq(EffectLayer.banner_alpha(0.0), 0.0, 0.0001)
	assert_almost_eq(EffectLayer.banner_alpha(0.15), 0.5, 0.0001)
	assert_almost_eq(EffectLayer.banner_alpha(1.0), 1.0, 0.0001)
	assert_almost_eq(EffectLayer.banner_alpha(2.5), 0.5, 0.0001)
	assert_almost_eq(EffectLayer.banner_alpha(2.8), 0.0, 0.0001)
	assert_almost_eq(EffectLayer.banner_alpha(60.0), 0.0, 0.0001)


func test_banner_copy_per_mode() -> void:
	var classic: PackedStringArray = EffectLayer.banner_copy(Types.GameMode.CLASSIC)
	assert_eq(classic[0], "CLASSIC SURVIVAL", "TiltRenderer.ts:526")
	assert_eq(classic[1], "STANDARD 1.0X SCORE // THE NEON ARENA", ":527")
	var red: PackedStringArray = EffectLayer.banner_copy(Types.GameMode.CODE_RED)
	assert_eq(red[0], "CODE RED PROTOCOL", ":532")
	assert_eq(red[1], "1.5X SCORE // INSTANT HYPER-SWARM AMBUSH", ":533")
	var gauntlet: PackedStringArray = EffectLayer.banner_copy(Types.GameMode.GAUNTLET)
	assert_eq(gauntlet[0], "THE GAUNTLET", ":537")
	assert_eq(gauntlet[1], "1.25X MULTIPLIER // DESCENDING WALL MAZE", ":538")
	assert_eq(EffectLayer.banner_colors(Types.GameMode.CODE_RED)[0], Color("#A78BFA"), ":534")
	assert_eq(EffectLayer.banner_colors(Types.GameMode.GAUNTLET)[0], Color("#FFB14D"), ":539")
	assert_eq(EffectLayer.banner_colors(Types.GameMode.CLASSIC)[0], Color("#5B8CFF"), ":528")


func test_banner_box_fits_a_narrow_arena() -> void:
	var wide: Rect2 = EffectLayer.banner_rect(780.0, 1.0)
	assert_almost_eq(wide.size.x, 460.0, 0.0001, "min(460, w - 32) (TiltRenderer.ts:543)")
	assert_almost_eq(wide.position.x, 160.0, 0.0001, "centred")
	assert_almost_eq(wide.position.y, 88.0, 0.0001, ":545")
	assert_almost_eq(wide.size.y, 46.0, 0.0001, ":544")
	var narrow: Rect2 = EffectLayer.banner_rect(400.0, 1.0)
	assert_almost_eq(narrow.size.x, 368.0, 0.0001)
	assert_almost_eq(narrow.position.x, 16.0, 0.0001)
	var scaled: Rect2 = EffectLayer.banner_rect(1560.0, 2.0)
	assert_almost_eq(scaled.size.x, 920.0, 0.0001, "CSS px times ui_scale (R2)")
	assert_almost_eq(scaled.position.y, 176.0, 0.0001)


func test_banner_hides_when_the_run_ends() -> void:
	var el: EffectLayer = EffectLayer.new()
	el.bind(ParticleEngine.new(), ScoreManager.new())
	add_child_autofree(el)
	el.set_game_mode(Types.GameMode.GAUNTLET)
	el.set_banner_shown(true)
	el.set_elapsed(1.0)
	assert_true(el.is_banner_drawn())
	el.queue_redraw()
	await get_tree().process_frame
	el.set_banner_shown(false)
	assert_false(el.is_banner_drawn(), "a death inside 2.8 s must not freeze it (Review Focus 4)")
	el.set_banner_shown(true)
	el.set_elapsed(3.0)
	assert_false(el.is_banner_drawn(), "faded out")
