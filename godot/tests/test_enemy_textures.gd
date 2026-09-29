## test_enemy_textures.gd
## PORTS: nothing — new file, covers render/enemy_textures.gd (SKIN R1).
extends GutTest

const COLORS: PackedColorArray = [
	Color("#ee1133"), Color("#ff6677"), Color("#ff8899"), Color("#110005")
]


func test_every_unlockable_skin_has_a_pattern_and_classic_has_none() -> void:
	var pm: ProgressionManager = ProgressionManager.new()
	for skin: ProgressionManager.EnemySkinConfig in pm.enemy_skin_catalog:
		var textured: bool = EnemyTextures.has_texture(skin.id)
		assert_eq(textured, skin.id != "classic", skin.id)
		assert_eq(EnemyTextures.svg(skin.id, 52, 23.5) != "", textured, skin.id)


func test_a_pattern_changes_the_body_but_not_the_outside() -> void:
	var plain: Image = EnemyTextures.dot_image(52, 23.5, COLORS, 3.3, "classic")
	for id: String in EnemyTextures.TEXTURED:
		var dot: Image = EnemyTextures.dot_image(52, 23.5, COLORS, 3.3, id)
		assert_ne(dot.get_data(), plain.get_data(), "%s paints the body" % id)
		assert_eq(dot.get_pixel(0, 0).a, 0.0, "%s: nothing outside the dot (masked)" % id)
		assert_eq(dot.get_pixel(51, 26).a, 0.0, "%s: right edge clear" % id)


func test_the_skinned_dot_sprite_carries_the_pattern() -> void:
	var layer: EntityLayer = EntityLayer.new()
	add_child_autofree(layer)
	var pm: ProgressionManager = ProgressionManager.new()
	layer.set_enemy_skin(pm.enemy_skin_catalog[0])  # classic
	var classic: Image = layer._dot_sprites(8.5, false, false).atlas.get_image()
	layer.set_enemy_skin(pm.enemy_skin_catalog[1])  # toxic
	var toxic: Image = layer._dot_sprites(8.5, false, false).atlas.get_image()
	layer.set_enemy_skin(null)
	var menu: Image = layer._dot_sprites(8.5, false, false).atlas.get_image()
	assert_eq(toxic.get_size(), classic.get_size(), "same layout")
	assert_ne(toxic.get_data(), classic.get_data())
	assert_ne(menu.get_data(), toxic.get_data(), "the menu (no skin) stays plain")


func test_every_new_skin_paints_a_pattern_that_rasterises() -> void:
	for id: String in ["arctic", "ember", "neon", "ocean", "desert", "ph", "jp", "br", "us", "de"]:
		assert_true(EnemyTextures.has_texture(id), id)
		assert_not_null(EnemyTextures.image(id, 52, 23.5), "%s rasterises" % id)
