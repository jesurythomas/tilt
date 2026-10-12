## shot_pickups.gd — ENH-301: coins and every orb buried in a dense swarm, at the A55's size
## and model scale, under the classic and ember skins, to judge pickup glance value.
## Windowed; not in the suite:
##   "$GODOT" --path godot --render-thread safe -s addons/gut/gut_cmdln.gd \
##     -gtest=res://bench/shot_pickups.gd -gexit
## Writes godot/build/shots/$SHOT_NAME.png (default pickups.png): classic over ember, half size.
extends GutTest

const SIZE: Vector2i = Vector2i(2340, 1080)


func _render(skin_id: String) -> Image:
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child_autofree(vp)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#0b0d14")
	bg.size = Vector2(SIZE)
	vp.add_child(bg)

	var layer: EntityLayer = EntityLayer.new()
	layer.set_model_scale(GameRoot.MOBILE_MODEL_SCALE)
	var pm: ProgressionManager = ProgressionManager.new()
	for skin: ProgressionManager.EnemySkinConfig in pm.enemy_skin_catalog:
		if skin.id == skin_id:
			layer.set_enemy_skin(skin)
	var bounds: Vector2 = Vector2(SIZE)
	var player: PlayerShip = PlayerShip.new(200.0, 540.0)
	var swarm: EnemySwarm = EnemySwarm.new()
	var weapons: WeaponSystem = WeaponSystem.new()
	var coins: CoinSystem = CoinSystem.new()
	layer.bind_entities(player, swarm, weapons, coins)

	# One cluster per pickup: a pickup at the centre, seekers packed over it.
	var centres: Array[Vector2] = []
	for i: int in range(Types.WeaponType.size() + 3):
		centres.append(Vector2(420.0 + (i % 5) * 400.0, 300.0 + (i / 5) * 480.0))
	var n: int = 0
	for type: Types.WeaponType in Types.WeaponType.values():
		weapons.spawn_orb(bounds, type, centres[n].x, centres[n].y)
		n += 1
	for i: int in range(n, centres.size()):
		var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
		coin.x = centres[i].x
		coin.y = centres[i].y
		coin.radius = CoinSystem.COIN_RADIUS
		coin.lifetime = CoinSystem.COIN_LIFETIME
		coins.coins.append(coin)
	for centre: Vector2 in centres:
		for k: int in range(14):
			var a: float = k * 2.4
			var d: float = 10.0 + 9.0 * sqrt(float(k))
			swarm.spawn_seeker(bounds, centre.x + cos(a) * d, centre.y + sin(a) * d)
	vp.add_child(layer)
	layer.queue_redraw()
	for f: int in range(4):
		await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func test_render() -> void:
	var top: Image = await _render("classic")
	var bottom: Image = await _render("ember")
	var both: Image = Image.create_empty(SIZE.x, SIZE.y * 2, false, top.get_format())
	both.blit_rect(top, Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
	both.blit_rect(bottom, Rect2i(Vector2i.ZERO, SIZE), Vector2i(0, SIZE.y))
	both.resize(SIZE.x / 2, SIZE.y)
	var shot_name: String = OS.get_environment("SHOT_NAME")
	if shot_name.is_empty():
		shot_name = "pickups"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	both.save_png(ProjectSettings.globalize_path("res://build/shots/%s.png" % shot_name))
	pass_test("shot")
