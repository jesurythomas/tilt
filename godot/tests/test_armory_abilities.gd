## test_armory_abilities.gd
## PORTS: nothing — new file, covers the Armory's Abilities tab (rulings DASH R4, ITEM R2)
extends GutTest
## Proves the sixth tab and its aliases, the dash upgrade rows (seconds now → next, pips, cost,
## Max), and the item cards' buy → Equip/Unequip cycle with the two-slot limit.

const ARMORY_SCENE: PackedScene = preload("res://scenes/armory.tscn")

var _armory: ArmoryUI = null
var _progression: ProgressionManager = null


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func before_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)
	_progression = ProgressionManager.new()
	_progression.data.points = 100000
	_armory = ARMORY_SCENE.instantiate() as ArmoryUI
	add_child_autofree(_armory)
	_armory.bind(_progression, null)
	await get_tree().process_frame
	_armory.open("abilities")


func after_each() -> void:
	_remove(ProgressionManager.SAVE_PATH)


func _button(node_name: String) -> Button:
	var b: Button = _armory.find_child(node_name, true, false) as Button
	assert_not_null(b, "%s must exist" % node_name)
	return b


func _label(node_name: String) -> Label:
	var l: Label = _armory.find_child(node_name, true, false) as Label
	assert_not_null(l, "%s must exist" % node_name)
	return l


func _value_text(node_name: String) -> String:
	var row: Node = _armory.find_child(node_name, true, false)
	assert_not_null(row, "%s must exist" % node_name)
	var text: String = ""
	for label: Node in row.get_children():
		text += (label as Label).text
	return text


func test_the_abilities_tab_is_sixth_and_answers_its_aliases() -> void:
	assert_eq(ArmoryUI.TAB_LABELS[ArmoryUI.Tab.ABILITIES], "Abilities")
	assert_true(_button("Tab_abilities").button_pressed)
	for alias: String in ["items", "dash"]:
		_armory.open("weapons")
		_armory.open(alias)
		assert_eq(_armory.active_tab, ArmoryUI.Tab.ABILITIES, alias)


func test_the_dash_rows_show_seconds_now_and_next() -> void:
	assert_eq(_value_text("DashValue_dashCooldown"), "20s → 19s")
	assert_eq(_value_text("DashValue_dashShield"), "2.0s → 2.5s")
	assert_eq(
		_button("Dash_dashCooldown").text, UiTheme.group_digits(_progression.get_perk_cost(0))
	)
	_button("Dash_dashShield").pressed.emit()
	assert_eq(_progression.data.dash.shield, 1)
	assert_eq(_value_text("DashValue_dashShield"), "2.5s → 3.0s")


func test_a_maxed_dash_row_says_max() -> void:
	for i: int in range(ProgressionManager.DASH_COOLDOWN_RANKS):
		_button("Dash_dashCooldown").pressed.emit()
	assert_almost_eq(_progression.get_dash_cooldown(), 15.0, 0.0001)
	assert_eq(_button("Dash_dashCooldown").text, "Max")
	assert_true(_button("Dash_dashCooldown").disabled)
	assert_eq(_value_text("DashValue_dashCooldown"), "15s")


func test_every_item_has_a_card_with_its_price() -> void:
	for id: String in ProgressionManager.ITEM_COSTS:
		assert_eq(_button("Item_" + id).text, UiTheme.group_digits(_progression.get_item_cost(id)))
	assert_eq(_label("ItemSlot_0").text, "Slot 1 · Empty")


func test_buying_equips_then_the_full_slots_lock_equip() -> void:
	_button("Item_blackhole").pressed.emit()
	_button("Item_nuke").pressed.emit()
	_button("Item_shield").pressed.emit()
	assert_eq(_button("Item_blackhole").text, "Unequip")
	assert_eq(_button("Item_nuke").text, "Unequip")
	assert_eq(_button("Item_shield").text, "Equip")
	assert_true(_button("Item_shield").disabled, "2 max")
	assert_eq(_label("ItemSlot_0").text, "Slot 1 · Blackhole")
	assert_eq(_label("ItemSlot_1").text, "Slot 2 · Nuke")
	assert_not_null(_armory.find_child("ItemSlotsFull", true, false))


func test_unequip_then_equip_swaps_a_slot() -> void:
	for id: String in ["blackhole", "nuke", "shield"]:
		_button("Item_" + id).pressed.emit()
	_button("Item_blackhole").pressed.emit()
	assert_eq(_progression.data.equipped_items, ["nuke"] as Array[String])
	assert_false(_button("Item_shield").disabled)
	_button("Item_shield").pressed.emit()
	assert_eq(_progression.data.equipped_items, ["nuke", "shield"] as Array[String])
	assert_eq(_label("ItemSlot_1").text, "Slot 2 · Shield")


func test_an_unaffordable_item_is_locked() -> void:
	_progression.data.points = 10
	_armory.render()
	assert_true(_button("Item_laser").disabled)
	assert_not_null(_button("Item_laser").icon, "the lock")


func test_a_purchase_signals_the_game() -> void:
	watch_signals(_armory)
	_button("Item_freeze").pressed.emit()
	_button("Dash_dashCooldown").pressed.emit()
	assert_signal_emit_count(_armory, "state_changed", 2)


func test_the_header_fits_six_tabs_and_a_seven_digit_balance() -> void:
	var sizes: Array[Vector2] = [Vector2(844, 390), Vector2(2340, 1080)]
	var scales: Array[float] = [1.0, 1080.0 / 390.0]
	for i: int in range(sizes.size()):
		var host: Control = Control.new()
		host.size = sizes[i]
		add_child_autofree(host)
		var armory: ArmoryUI = ARMORY_SCENE.instantiate() as ArmoryUI
		host.add_child(armory)
		_progression.data.points = 1234567
		armory.bind(_progression, null)
		armory.set_ui_scale(scales[i])
		armory.open("abilities")
		await get_tree().process_frame
		await get_tree().process_frame
		var outside: Array[String] = UiChecks.outside(armory, armory.get_global_rect())
		assert_true(outside.is_empty(), "fits %s: %s" % [sizes[i], outside])
		var header: Node = armory.find_child("Header", true, false)
		assert_true(UiChecks.overlapping_siblings(header).is_empty(), "header at %s" % sizes[i])
