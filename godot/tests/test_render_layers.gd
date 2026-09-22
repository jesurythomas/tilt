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
	var charging: Types.Enemy = swarm.spawn_charger(bounds, player_pos)
	charging.state = Types.EnemyState.CHARGING
	charging.vx = 100.0
	var artillery: Types.Enemy = swarm.spawn_artillery(bounds, player_pos)
	artillery.fire_cooldown = 0.3
	swarm.spawn_bullet(100.0, 100.0, player_pos)
	swarm.spawn_carrier(bounds, player_pos)
	swarm.spawn_pulsar(bounds, player_pos)
	swarm.spawn_specter(bounds, player_pos)
	var mine: Types.Enemy = Types.Enemy.new()
	mine.type = Types.EnemyType.SPIKE_MINE
	mine.radius = 8.0
	swarm.enemies.append(mine)
	var frozen: Types.Enemy = swarm.spawn_seeker(bounds)
	frozen.frozen = true
	var turret: Types.Enemy = Types.Enemy.new()
	turret.type = Types.EnemyType.TURRET_DOT
	turret.radius = 12.0
	turret.target_angle = 1.0
	swarm.enemies.append(turret)

	add_child_autofree(layer)
	layer.queue_redraw()
	await wait_frames(2)
	assert_eq(swarm.enemies.size(), 1 + 7 + 38 + 12 + 1 + 6 + 8 + 2 + 1 + 1 + 5 + 1 + 1 + 1 + 1 + 1)


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
	var no_kill: Callable = func(_e: Types.Enemy, _w: Types.WeaponType) -> void: pass

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
	var victim: Types.Enemy = Types.Enemy.new()
	victim.id = 1
	victim.x = 600.0
	victim.y = 100.0
	victim.radius = 8.0
	var enemies: Array[Types.Enemy] = [victim]
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


func test_grid_layer_rebuilds_the_background_on_theme_change() -> void:
	_remove_save()
	var progression: ProgressionManager = ProgressionManager.new()
	var layer: GridLayer = GridLayer.new()
	add_child_autofree(layer)
	await get_tree().process_frame
	var before: GradientTexture2D = layer.background_texture()
	layer.set_arena_theme(progression.arena_theme_catalog[2])
	var after: GradientTexture2D = layer.background_texture()
	assert_ne(after, before, "a new gradient is baked for the theme")
	assert_eq(after.gradient.colors[0], progression.arena_theme_catalog[2].bg_gradient[0])
	_remove_save()


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
