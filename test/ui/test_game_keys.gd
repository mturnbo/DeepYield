extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")

var game: Node


func before_each() -> void:
	game = add_child_autofree(load("res://game/main.tscn").instantiate())


func after_each() -> void:
	await get_tree().process_frame


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	game._unhandled_input(event)


func _all_buttons(root: Node) -> Array[BaseButton]:
	var found: Array[BaseButton] = []
	for child in root.get_children():
		if child is BaseButton:
			found.append(child)
		found.append_array(_all_buttons(child))
	return found


func test_space_toggles_pause_and_remembers_fast() -> void:
	game.set_speed("fast")
	_press(KEY_SPACE)
	assert_eq(game.clock.speed, "paused")
	_press(KEY_SPACE)
	assert_eq(game.clock.speed, "fast")


func test_p_toggles_pause_back_to_normal() -> void:
	game.set_speed("normal")
	_press(KEY_P)
	assert_eq(game.clock.speed, "paused")
	_press(KEY_P)
	assert_eq(game.clock.speed, "normal")


func test_one_and_two_set_normal_and_fast() -> void:
	_press(KEY_2)
	assert_eq(game.clock.speed, "fast")
	_press(KEY_1)
	assert_eq(game.clock.speed, "normal")


func test_locked_keys_block_speed_but_not_pause() -> void:
	game.keys_locked = true
	_press(KEY_2)
	assert_eq(game.clock.speed, "paused")
	game.set_speed("normal")
	_press(KEY_SPACE)
	assert_eq(game.clock.speed, "paused")


func test_space_still_pauses_after_pressing_a_speed_button() -> void:
	var fast_button: Button = game.get_node("UI/Hud")._speed_buttons["fast"]
	fast_button.pressed.emit()
	assert_eq(game.clock.speed, "fast")
	assert_null(get_viewport().gui_get_focus_owner())
	_press(KEY_SPACE)
	assert_eq(game.clock.speed, "paused")


func test_keys_are_ignored_once_the_run_has_ended() -> void:
	game.set_speed("normal")
	game.state.outcome = "won"
	_press(KEY_SPACE)
	_press(KEY_2)
	assert_eq(game.clock.speed, "normal")


func test_escape_does_not_close_panels_under_the_end_screen() -> void:
	var ids := Helpers.place_starter(game.state)
	var panel: Node = game.get_node("UI/ModulePanel")
	panel.open(ids["assembly"])
	game.state.outcome = "won"
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	panel._unhandled_input(event)
	assert_true(panel.visible)


func test_every_ui_button_refuses_focus() -> void:
	var ids := Helpers.place_starter(game.state)
	game.state.queue_item("assembly", "habitat")
	game.state.fleet.ships[0].state = "docked"
	game.get_node("UI/Hud").refresh()
	game.get_node("UI/ModulePanel").open(ids["assembly"])
	game.get_node("UI/ShipPopup").open(0)
	var buttons := _all_buttons(game.get_node("UI"))
	assert_gt(buttons.size(), 20)
	for button in buttons:
		assert_eq(button.focus_mode, Control.FOCUS_NONE, "focusable: " + str(button.get_path()) + " " + str(button.text))
