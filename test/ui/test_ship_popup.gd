extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")
const ShipPopup = preload("res://game/ui/ship_popup.gd")
const WorldPicker = preload("res://game/view/world_picker.gd")

var game: Node
var popup: Node
var hud: Node


func before_each() -> void:
	game = add_child_autofree(load("res://game/main.tscn").instantiate())
	popup = game.get_node("UI/ShipPopup")
	hud = game.get_node("UI/Hud")
	game.state.fleet.add_ship()
	game.state.fleet.ships[0].state = "docked"
	game.state.fleet.ships[0].bay = 0


func after_each() -> void:
	await get_tree().process_frame


func _ship() -> MiningShip:
	return game.state.fleet.ships[0]


func _find(root: Node, type: String, text: String) -> Node:
	for child in root.find_children("*", type, true, false):
		if child.text == text:
			return child
	return null


func _fetch_button(text: String) -> Button:
	return _find(popup, "Button", text)


func test_where_text_covers_every_state() -> void:
	var ship := MiningShip.new(0)
	var cases := {
		"in_cargo": "In cargo bay", "docked": "Docked", "ice_outbound": "To the comet",
		"working": "Mining", "carving": "Carving ice", "towing": "Towing ice",
		"at_plant": "Waiting at the plant", "inbound": "Coming home", "holding": "Holding",
	}
	for state in cases:
		ship.state = state
		assert_eq(ShipPopup.where_text(ship), cases[state], state)


func test_where_text_outbound_names_the_site() -> void:
	var ship := MiningShip.new(0)
	ship.state = "outbound"
	ship.destination = "nebula"
	assert_eq(ShipPopup.where_text(ship), "To the nebula")
	ship.destination = "asteroids"
	assert_eq(ShipPopup.where_text(ship), "To the asteroids")


func test_where_text_docked_waiting_for_room() -> void:
	var ship := MiningShip.new(0)
	ship.state = "docked"
	ship.waiting_for_room = true
	assert_eq(ShipPopup.where_text(ship), "Waiting to unload")


func test_cargo_text() -> void:
	var ship := MiningShip.new(0)
	assert_eq(ShipPopup.cargo_text(ship), "Cargo: empty")
	ship.cargo = {"hydrogen": 7, "helium": 7, "nitrogen": 6}
	assert_eq(ShipPopup.cargo_text(ship), "Cargo: 7 hydrogen, 7 helium, 6 nitrogen")


func test_nearest_ship_picks_closest_within_twelve_metres() -> void:
	var positions := {0: Vector2(100, 0), 1: Vector2(105, 0)}
	assert_eq(WorldPicker.nearest_ship(positions, Vector2(104, 0)), 1)
	assert_eq(WorldPicker.nearest_ship(positions, Vector2(88, 0)), 0)


func test_nearest_ship_misses_beyond_twelve_metres() -> void:
	assert_eq(WorldPicker.nearest_ship({0: Vector2(100, 0)}, Vector2(112.5, 0)), -1)
	assert_eq(WorldPicker.nearest_ship({}, Vector2.ZERO), -1)


func test_popup_shows_ship_details() -> void:
	_ship().cargo = {"iron": 10}
	_ship().condition = 0.78
	popup.open(0)
	assert_true(popup.visible)
	assert_not_null(_find(popup, "Label", "Ship 1"))
	assert_not_null(_find(popup, "Label", "Docked"))
	assert_not_null(_find(popup, "Label", "Condition 78%"))
	assert_not_null(_find(popup, "Label", "Cargo: 10 iron"))
	assert_not_null(_find(popup, "Label", "Assignment: none"))


func test_popup_shows_hours_left_on_a_leg() -> void:
	_ship().state = "outbound"
	_ship().destination = "nebula"
	_ship().hours_left = 7
	popup.open(0)
	assert_not_null(_find(popup, "Label", "7 h left on this leg"))
	assert_true(_find(popup, "Label", "7 h left on this leg").visible)


func test_apply_assigns_ship() -> void:
	popup.open(0)
	popup._checks["hydrogen"].button_pressed = true
	popup._checks["helium"].button_pressed = true
	popup._on_apply()
	assert_eq(_ship().assignment, {"site": "nebula", "materials": ["hydrogen", "helium"]})
	assert_eq(popup._apply_label.text, "Assigned")
	assert_eq(popup._apply_label.get_theme_color("font_color"), ShipPopup.MINT)
	assert_not_null(_find(popup, "Label", "Assignment: Nebula, hydrogen, helium"))


func test_apply_with_nothing_picked_shows_refusal_in_red() -> void:
	popup.open(0)
	popup._on_apply()
	assert_eq(popup._apply_label.text, "Pick at least one material")
	assert_eq(popup._apply_label.get_theme_color("font_color"), ShipPopup.RED)
	assert_eq(_ship().assignment, {})


func test_three_metals_cannot_be_checked() -> void:
	popup.open(0)
	popup._site_buttons["asteroids"].pressed.emit()
	popup._checks["iron"].button_pressed = true
	popup._checks["nickel"].button_pressed = true
	assert_true(popup._checks["silicon"].disabled)
	assert_false(popup._checks["iron"].disabled)
	popup._checks["nickel"].button_pressed = false
	assert_false(popup._checks["silicon"].disabled)


func test_apply_three_metals_is_refused_by_the_sim() -> void:
	popup.open(0)
	popup._site_buttons["asteroids"].pressed.emit()
	for material in ["iron", "nickel", "silicon"]:
		popup._checks[material].disabled = false
		popup._checks[material].button_pressed = true
	popup._on_apply()
	assert_eq(popup._apply_label.text, "Pick up to 2 metals")
	assert_eq(_ship().assignment, {})


func test_open_prefills_current_assignment() -> void:
	game.state.assign_ship(0, "asteroids", ["iron", "nickel"])
	popup.open(0)
	assert_true(popup._site_buttons["asteroids"].button_pressed)
	assert_true(popup._checks["iron"].button_pressed)
	assert_false(popup._checks["silicon"].button_pressed)


func test_next_assignment_shown_while_ship_is_away() -> void:
	_ship().state = "outbound"
	game.state.assign_ship(0, "nebula", ["argon"])
	popup.open(0)
	assert_not_null(_find(popup, "Label", "Next: Nebula, argon"))
	assert_true(_find(popup, "Label", "Next: Nebula, argon").visible)


func test_fetch_buttons_disabled_without_comet() -> void:
	popup.open(0)
	assert_eq(game.state.comets.current(game.state.hour), -1)
	for button in popup._fetch_buttons.values():
		assert_true(button.disabled)


func test_fetch_buttons_enabled_with_comet_in_reach() -> void:
	game.state.comets.passes[0]["arrives"] = game.state.hour
	game.state.comets.passes[0]["leaves"] = game.state.hour + 100
	popup.open(0)
	assert_eq(popup._fetch_buttons.size(), 3)
	for button in popup._fetch_buttons.values():
		assert_false(button.disabled)
	assert_not_null(_fetch_button("2,000 u"))


func test_fetch_without_plant_shows_refusal() -> void:
	game.state.comets.passes[0]["arrives"] = game.state.hour
	game.state.comets.passes[0]["leaves"] = game.state.hour + 100
	popup.open(0)
	popup._fetch_buttons[1000].pressed.emit()
	assert_eq(popup._fetch_label.text, "Build an electrolysis plant first")
	assert_true(popup._fetch_label.visible)
	assert_eq(_ship().ice_order, 0)


func test_fetch_with_plant_places_order() -> void:
	var ids := Helpers.place_starter(game.state)
	game.state.assembled["electrolysis_plant"] = 1
	assert_eq(game.state.place(ids["metal_storage"], 3, 3, "electrolysis_plant"), "")
	Helpers.finish_construction(game.state)
	game.state.comets.passes[0]["arrives"] = game.state.hour
	game.state.comets.passes[0]["leaves"] = game.state.hour + 100
	game.state.fleet.ships[0].state = "docked"
	popup.open(0)
	popup._fetch_buttons[3000].pressed.emit()
	assert_eq(_ship().ice_order, 3000)
	assert_false(popup._fetch_label.visible)


func test_repair_button_flow() -> void:
	popup.open(0)
	assert_eq(popup._repair_button.text, "Repair")
	assert_false(popup._repair_button.disabled)
	popup._repair_button.pressed.emit()
	assert_true(_ship().repair_requested)
	assert_eq(popup._repair_button.text, "Repair requested")
	assert_true(popup._repair_button.disabled)


func test_close_button_and_escape() -> void:
	popup.open(0)
	popup.close()
	assert_false(popup.visible)
	popup.open(0)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	popup._unhandled_input(escape)
	assert_false(popup.visible)


func test_step_updates_in_place_and_keeps_editor_state() -> void:
	popup.open(0)
	popup._checks["hydrogen"].button_pressed = true
	var apply_label: Label = popup._apply_label
	var checkbox: CheckBox = popup._checks["hydrogen"]
	_ship().condition = 0.5
	game.stepped.emit()
	assert_not_null(_find(popup, "Label", "Condition 50%"))
	assert_same(popup._checks["hydrogen"], checkbox)
	assert_true(checkbox.button_pressed)
	assert_same(popup._apply_label, apply_label)


func test_fleet_list_rows_show_ship_state() -> void:
	game.stepped.emit()
	var rows: Array = hud._fleet_buttons
	assert_eq(rows.size(), game.state.fleet.ships.size())
	assert_eq(rows[0].text, "Ship 1 · Docked · 100%")


func test_fleet_list_grows_with_the_fleet_and_survives_steps() -> void:
	game.stepped.emit()
	var first: Button = hud._fleet_buttons[0]
	_ship().condition = 0.78
	game.stepped.emit()
	assert_same(hud._fleet_buttons[0], first)
	assert_eq(first.text, "Ship 1 · Docked · 78%")
	var before: int = hud._fleet_buttons.size()
	game.state.fleet.add_ship()
	game.stepped.emit()
	assert_eq(hud._fleet_buttons.size(), before + 1)


func test_clicking_fleet_row_opens_popup() -> void:
	game.stepped.emit()
	hud._fleet_buttons[0].pressed.emit()
	assert_true(popup.visible)
	assert_not_null(_find(popup, "Label", "Ship 1"))


func test_fleet_list_stays_inside_the_window_with_ten_ships() -> void:
	while game.state.fleet.ships.size() < 10:
		game.state.fleet.add_ship()
	get_tree().root.size = Vector2i(1152, 648)
	game.stepped.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll: ScrollContainer = hud.get_node("SidePanel/Margin/List/FleetScroll")
	var viewport_height := get_viewport().get_visible_rect().size.y
	assert_lte(scroll.get_global_rect().end.y, viewport_height)
	assert_gt(scroll.get_global_rect().size.y, 0.0)
	assert_eq(scroll.get_child(0).get_child_count(), 10)
	assert_gt(scroll.get_child(0).get_combined_minimum_size().y, scroll.size.y)


func test_popup_stays_inside_the_window_with_scrolling_body() -> void:
	get_tree().root.size = Vector2i(1152, 400)
	popup.open(0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lte(popup.get_global_rect().end.y, get_viewport().get_visible_rect().size.y)


func test_popup_and_module_panel_exclude_each_other() -> void:
	var panel: Node = game.get_node("UI/ModulePanel")
	Helpers.place_starter(game.state)
	panel.open(0)
	assert_true(panel.visible)
	popup.open(0)
	assert_true(popup.visible)
	assert_false(panel.visible)
	panel.open(0)
	assert_true(panel.visible)
	assert_false(popup.visible)
