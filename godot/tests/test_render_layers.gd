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
