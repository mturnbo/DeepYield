extends GutTest

var game: Node
var menu: Node


func before_each() -> void:
	game = add_child_autofree(load("res://game/main.tscn").instantiate())
	menu = game.get_node("UI/BuildMenu")
	menu.refresh()


func test_kit_button_enabled_with_kit() -> void:
	assert_false(menu._buttons["kit:command"].disabled)
	assert_eq(menu._buttons["kit:command"].text, "Command (kit)")


func test_kit_button_disabled_after_placing() -> void:
	assert_eq(game.state.place_first("command", Vector2.ZERO), "")
	menu.refresh()
	assert_true(menu._buttons["kit:command"].disabled)
	assert_false(menu._buttons["kit:ship_dock"].disabled)


func test_assembled_entry_appears_with_count() -> void:
	assert_false(menu._buttons.has("assembled:habitat"))
	game.state.assembled["habitat"] = 2
	menu.refresh()
	assert_eq(menu._buttons["assembled:habitat"].text, "Habitat ×2")
	assert_false(menu._buttons["assembled:habitat"].disabled)


func test_pressing_button_emits_item_chosen() -> void:
	watch_signals(menu)
	menu._buttons["kit:refinery"].pressed.emit()
	assert_signal_emitted_with_parameters(menu, "item_chosen", ["refinery"])
