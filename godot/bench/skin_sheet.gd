## skin_sheet.gd — SKIN R1: bakes every enemy skin's default dot (with its pattern) at
## two sizes into build/shots/skin_sheet.png, to eyeball. Not part of the suite:
##   "$GODOT" --headless --path godot -s addons/gut/gut_cmdln.gd \
##     -gtest=res://bench/skin_sheet.gd -gexit
extends GutTest


func test_skin_sheet() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	var cell: int = 140
	var sheet: Image = Image.create_empty(cell * 6, cell * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#0D1016"))
	for i: int in range(pm.enemy_skin_catalog.size()):
		var skin: ProgressionManager.EnemySkinConfig = pm.enemy_skin_catalog[i]
		for row: int in range(2):
			var r: float = 60.0 if row == 0 else 22.0
			var size: int = ceili(r * 2.0 + r * 0.14 + 6.0)
			var dot: Image = EnemyTextures.dot_image(
				size,
				r,
				PackedColorArray(
					[
						skin.body_gradient[1],
						skin.body_gradient[0],
						skin.border_color,
						skin.pupil_color
					]
				),
				1.2 * r / 9.0,
				skin.id
			)
			var at: Vector2i = Vector2i(
				i * cell + (cell - size) / 2, row * cell + (cell - size) / 2
			)
			sheet.blend_rect(dot, Rect2i(0, 0, size, size), at)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	sheet.save_png(ProjectSettings.globalize_path("res://build/shots/skin_sheet.png"))
	pass_test("sheet")
