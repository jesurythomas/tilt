## test_ability_bar.gd
## PORTS: nothing — new file, covers src/ui/ability_bar.gd and its HUD placement (rulings
## HUD R1, HUD R2)
extends GutTest
## Proves the item buttons follow the loadout and dim once used, the gauge redraws only when
## what it shows changes, the bar mirrors for a right-anchored stick, and the score block left
## the top centre.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _bar: AbilityBar = null
var _abilities: AbilitySystem = null


func before_each() -> void:
	_bar = AbilityBar.new()
	add_child_autofree(_bar)
	_abilities = AbilitySystem.new()
	_abilities.reset(20.0, 2.0, ["blackhole", "nuke"])


func test_one_button_per_equipped_item_in_slot_order() -> void:
	_bar.show_abilities(_abilities)
	assert_not_null(_bar.item_button(0))
	assert_not_null(_bar.item_button(1))
	assert_null(_bar.item_button(2))
	assert_eq(_bar.item_button(0).tooltip_text, "blackhole")
	assert_eq(_bar.item_button(1).tooltip_text, "nuke")
	assert_eq(_bar.item_button(0).focus_mode, Control.FOCUS_NONE)


func test_no_items_no_buttons_but_the_gauge_stays() -> void:
	_abilities.reset(20.0, 2.0, [])
	_bar.show_abilities(_abilities)
	assert_null(_bar.item_button(0))
	assert_not_null(_bar.gauge())
	assert_eq(_bar.get_child_count(), 1)


func test_a_used_item_dims_and_stops_taking_taps() -> void:
	_bar.show_abilities(_abilities)
	_abilities.request_item(1)
	_abilities.take_item_requests()
	_bar.show_abilities(_abilities)
	assert_true(_bar.item_button(1).disabled)
	assert_almost_eq(_bar.item_button(1).modulate.a, AbilityBar.USED_ALPHA, 0.0001)
	assert_false(_bar.item_button(0).disabled)


func test_pressing_a_button_names_its_slot() -> void:
	_bar.show_abilities(_abilities)
	watch_signals(_bar)
	_bar.item_button(1).pressed.emit()
	assert_signal_emitted_with_parameters(_bar, "item_pressed", [1])


func test_the_gauge_follows_the_dash() -> void:
	_bar.show_abilities(_abilities)
	var gauge: AbilityBar.DashGauge = _bar.gauge()
	assert_eq(gauge.state, AbilitySystem.DashState.READY)
	assert_eq(gauge.steps, AbilityBar.FRACTION_STEPS)
	_abilities.dash_cooldown_left = 12.3
	_bar.show_abilities(_abilities)
	assert_eq(gauge.state, AbilitySystem.DashState.COOLDOWN)
	assert_eq(gauge.seconds, 13, "whole seconds, rounded up")
	assert_eq(gauge.steps, floori((1.0 - 12.3 / 20.0) * AbilityBar.FRACTION_STEPS))
	_abilities.dash_cooldown_left = 0.0
	_abilities.dash_shield_left = 1.0
	_bar.show_abilities(_abilities)
	assert_eq(gauge.state, AbilitySystem.DashState.SHIELD)
	assert_eq(gauge.steps, AbilityBar.FRACTION_STEPS / 2)


func test_the_gauge_sits_on_the_inside_edge() -> void:
	_bar.show_abilities(_abilities)
	assert_eq(_bar.get_child(0), _bar.gauge(), "right corner: gauge first, items at the edge")
	_bar.set_left(true)
	assert_eq(_bar.get_child(_bar.get_child_count() - 1), _bar.gauge())
	_abilities.reset(20.0, 2.0, ["laser"])
	_bar.show_abilities(_abilities)
	assert_eq(_bar.get_child(_bar.get_child_count() - 1), _bar.gauge(), "kept after a rebuild")


func test_the_hud_places_the_bar_and_the_score() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var hud: HudController = root._hud
	var bar: AbilityBar = hud.ability_bar()
	assert_not_null(bar)
	assert_eq(bar.anchor_left, 1.0, "bottom right by default")
	hud.set_ability_side(true)
	assert_eq(bar.anchor_left, 0.0, "bottom left beside a right stick")
	assert_true(bar.is_on_left())
	hud.set_ability_side(false)
	assert_eq(bar.anchor_left, 1.0)
	var score_block: Control = hud.find_child("ScoreBlock", true, false) as Control
	assert_eq(str(score_block.get_parent().name), "LeftColumn", "HUD R1: off the top centre")


func test_the_bar_shows_in_a_run_not_on_the_menu() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var bar: AbilityBar = root._hud.ability_bar()
	root.launch_run(root.options.settings.mode)
	root.skip_cinematic()
	assert_true(bar.visible)
	root.return_to_menu()
	assert_false(bar.visible)


## HUD R4 (user: "it should also be on the right when tilt is selected. on touch, when the
## joystick is stickied to the right show it on the left, else right").
func test_only_a_right_anchored_touch_stick_moves_the_bar_left() -> void:
	var touch: Types.ControlScheme = Types.ControlScheme.MOUSE
	var tilt: Types.ControlScheme = Types.ControlScheme.GYRO
	var right: ControlSettings.StickAnchor = ControlSettings.StickAnchor.RIGHT
	assert_true(GameRoot.is_ability_bar_left(touch, right, true), "touch, stick right: left")
	assert_false(GameRoot.is_ability_bar_left(tilt, right, true), "tilt: right, whatever the stick")
	for anchor: ControlSettings.StickAnchor in [
		ControlSettings.StickAnchor.LEFT, ControlSettings.StickAnchor.DYNAMIC
	]:
		assert_false(GameRoot.is_ability_bar_left(touch, anchor, true), "touch, %d: right" % anchor)
	assert_false(GameRoot.is_ability_bar_left(touch, right, false), "no stick off a phone")


func test_switching_to_tilt_puts_the_bar_back_on_the_right() -> void:
	var root: GameRoot = MAIN_SCENE.instantiate() as GameRoot
	add_child_autofree(root)
	await get_tree().process_frame
	var bar: AbilityBar = root._hud.ability_bar()
	root.settings.stick_anchor = ControlSettings.StickAnchor.RIGHT
	root._hud.set_ability_side(true)
	root.set_control_scheme(Types.ControlScheme.GYRO)
	assert_false(bar.is_on_left(), "tilt: right")


func test_pad_badges_hidden_until_the_controller_is_used() -> void:
	_bar.show_abilities(_abilities)
	var dash_badge: AbilityBar.PadBadge = AbilityBar.badge_of(_bar.gauge())
	assert_not_null(dash_badge, "the gauge carries a badge")
	assert_eq(dash_badge.text, "A")
	assert_false(dash_badge.visible, "hidden for touch players")
	assert_eq(AbilityBar.badge_of(_bar.item_button(0)).text, "LB")
	assert_eq(AbilityBar.badge_of(_bar.item_button(1)).text, "RB")


func test_pad_badges_show_and_hide_together() -> void:
	_bar.show_abilities(_abilities)
	_bar.set_pad_hints(true)
	assert_true(AbilityBar.badge_of(_bar.gauge()).visible)
	assert_true(AbilityBar.badge_of(_bar.item_button(1)).visible)
	_bar.set_pad_hints(false)
	assert_false(AbilityBar.badge_of(_bar.gauge()).visible)
	assert_false(AbilityBar.badge_of(_bar.item_button(0)).visible)


func test_a_rebuilt_loadout_keeps_the_badges_shown() -> void:
	_bar.set_pad_hints(true)
	_bar.show_abilities(_abilities)
	assert_true(AbilityBar.badge_of(_bar.item_button(0)).visible, "new buttons follow the mode")


func test_badges_relabel_for_a_playstation_pad() -> void:
	_bar.show_abilities(_abilities)
	_bar.set_pad_hints(true, GamepadInput.Family.PLAYSTATION)
	assert_eq(AbilityBar.badge_of(_bar.gauge()).text, "×")
	assert_eq(AbilityBar.badge_of(_bar.item_button(1)).text, "R1")
