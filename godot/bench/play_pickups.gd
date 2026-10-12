## play_pickups.gd — ENH-301: plays the real game (main.tscn, a Survival run) windowed, packs
## the swarm around fresh orbs and coins away from the ship, keeps the ship shielded, and
## screenshots the live window. Not part of the suite:
##   "$GODOT" --path godot --render-thread safe --resolution 1560x720 \
##     -s addons/gut/gut_cmdln.gd -gtest=res://bench/play_pickups.gd -gexit
## Writes godot/build/shots/play_pickups_<n>.png.
extends GutTest


func _shield(rc: RunController) -> void:
	rc.player.activate_shield(5.0)


func test_play() -> void:
	var root: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameRoot
	add_child_autofree(root)
	await wait_frames(10)
	root.launch_run(Types.GameMode.CLASSIC)
	await wait_frames(5)
	root.skip_cinematic()
	await wait_seconds(1.0)
	var rc: RunController = root._run_controller
	var bounds: Vector2 = root._bounds
	assert_eq(root._state.phase, Types.GamePhase.PLAYING, "the run is live")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	for shot: int in range(3):
		_shield(rc)
		rc.player.x = bounds.x * 0.12
		rc.player.y = bounds.y * 0.5
		var n: int = 0
		for type: Types.WeaponType in Types.WeaponType.values():
			var c: Vector2 = Vector2(
				bounds.x * (0.3 + 0.15 * (n % 5)), bounds.y * (0.3 + 0.4 * (n / 5))
			)
			rc.weapons.spawn_orb(bounds, type, c.x, c.y)
			for k: int in range(10):
				rc.swarm.spawn_seeker(bounds, c.x + cos(k * 2.4) * 24.0, c.y + sin(k * 2.4) * 24.0)
			n += 1
		for i: int in range(3):
			var coin: CoinSystem.CoinPickup = CoinSystem.CoinPickup.new()
			coin.x = bounds.x * (0.6 + 0.15 * i)
			coin.y = bounds.y * 0.7
			coin.radius = CoinSystem.COIN_RADIUS
			coin.lifetime = CoinSystem.COIN_LIFETIME
			rc.coins.coins.append(coin)
			for k: int in range(10):
				rc.swarm.spawn_seeker(
					bounds, coin.x + cos(k * 2.4) * 20.0, coin.y + sin(k * 2.4) * 20.0
				)
		await wait_seconds(0.4 + shot * 0.8)
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://build/shots/play_pickups_%d.png" % shot))
	assert_eq(root._state.phase, Types.GamePhase.PLAYING, "still playing after the shots")
