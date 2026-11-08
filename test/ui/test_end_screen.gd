extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")
const EndScreen = preload("res://game/ui/end_screen.gd")

var game: Node
var end_screen: Node


func before_each() -> void:
	game = add_child_autofree(load("res://game/main.tscn").instantiate())
	end_screen = game.get_node("UI/EndScreen")


func after_each() -> void:
	await get_tree().process_frame


func _id_of(popup: PopupMenu, text: String) -> int:
	for index in popup.item_count:
		if popup.get_item_text(index) == text:
			return popup.get_item_id(index)
	return -1


func _choose_from_menu(text: String) -> void:
	var popup: PopupMenu = game.get_node("UI/Hud").menu_button.get_popup()
	popup.id_pressed.emit(_id_of(popup, text))


func test_hidden_while_the_run_is_going() -> void:
	end_screen.refresh()
	assert_false(end_screen.visible)


func test_won_title() -> void:
	game.state.outcome = "won"
	end_screen.refresh()
	assert_true(end_screen.visible)
	assert_eq(end_screen._title_label.text, "Platform held")
	assert_eq(end_screen._title_label.get_theme_color("font_color"), EndScreen.MINT)


func test_energy_collapse_title() -> void:
	game.state.outcome = "collapsed"
	game.state.collapse_reason = "energy"
	end_screen.refresh()
	assert_eq(end_screen._title_label.text, "Collapse: energy ran out")
	assert_eq(end_screen._title_label.get_theme_color("font_color"), EndScreen.RED)


func test_air_water_collapse_title() -> void:
	game.state.outcome = "collapsed"
	game.state.collapse_reason = "air_water"
	end_screen.refresh()
	assert_eq(end_screen._title_label.text, "Collapse: oxygen and water ran out")


func test_ended_title() -> void:
	game.state.outcome = "ended"
	end_screen.refresh()
	assert_eq(end_screen._title_label.text, "Run ended")


func test_hours_operated_counts_the_collapsing_hour() -> void:
	assert_eq(EndScreen.hours_operated({"outcome": "collapsed", "hours": 100}), 101)
	assert_eq(EndScreen.hours_operated({"outcome": "won", "hours": 100}), 100)
	assert_eq(EndScreen.hours_operated({"outcome": "ended", "hours": 0}), 0)


func test_crew_line_is_never_or_the_hour() -> void:
	assert_eq(EndScreen.crew_text(-1), "Whole crew on the platform: never")
	assert_eq(EndScreen.crew_text(42), "Whole crew on the platform: hour 42")


func test_lines_show_hours_reserve_and_crew_hour() -> void:
	game.state.hour = 300
	game.state.first_all_on_platform_hour = 120
	game.state.outcome = "collapsed"
	game.state.collapse_reason = "energy"
	end_screen.refresh()
	var expected_reserve := int(floor(game.state.life.reserve_hours(game.state.crew)))
	assert_eq(end_screen._hours_label.text, "Hours operated: 301")
	assert_eq(end_screen._reserve_label.text, "Ship reserve left: %d h" % expected_reserve)
	assert_eq(end_screen._crew_label.text, "Whole crew on the platform: hour 120")


func test_end_run_from_the_menu_shows_run_ended() -> void:
	_choose_from_menu("End run")
	assert_true(end_screen.visible)
	assert_eq(end_screen._title_label.text, "Run ended")
	assert_eq(game.clock.speed, "paused")


func test_outcome_during_play_shows_the_screen_and_pauses() -> void:
	game.set_speed("normal")
	game.state.outcome = "won"
	game.stepped.emit()
	assert_true(end_screen.visible)
	assert_eq(game.clock.speed, "paused")


func test_new_run_resets_state_and_clears_views() -> void:
	Helpers.place_starter(game.state)
	game.get_node("PlatformView").sync()
	game.state.fleet.add_ship()
	game.state.fleet.ships[0].state = "docked"
	game.state.fleet.ships[0].bay = 0
	await get_tree().process_frame
	assert_gt(game.get_node("PlatformView").visuals.size(), 0)
	assert_gt(game.get_node("FleetView")._ships.size(), 0)
	var old_seed: int = game.run_seed
	game.state.end_run()
	end_screen.refresh()
	end_screen._new_run_button.pressed.emit()
	assert_eq(game.state.hour, 0)
	assert_eq(game.state.outcome, "")
	assert_eq(game.run_seed, old_seed + 1)
	assert_eq(game.state.layout.nodes.size(), 0)
	assert_false(end_screen.visible)
	assert_eq(game.clock.speed, "paused")
	assert_eq(game.get_node("PlatformView").visuals.size(), 0)
	assert_eq(game.get_node("FleetView")._ships.size(), 0)
	assert_eq(game.get_node("FleetView")._chunks.size(), 0)


func test_new_run_from_the_menu_closes_panels_and_cancels_placing() -> void:
	var ids := Helpers.place_starter(game.state)
	game.get_node("UI/ModulePanel").open(ids["command"])
	game.get_node("PlacementTool").start("habitat")
	_choose_from_menu("New run")
	assert_false(game.get_node("UI/ModulePanel").visible)
	assert_false(game.get_node("UI/ShipPopup").visible)
	assert_false(game.get_node("PlacementTool").placing)
	assert_false(game.keys_locked)
	assert_eq(game.state.layout.nodes.size(), 0)


func test_new_run_refreshes_the_build_menu_kits() -> void:
	var menu = game.get_node("UI/BuildMenu")
	menu.refresh()
	var before: int = menu._buttons.size()
	assert_gt(before, 0)
	game.new_run(5)
	assert_eq(menu._buttons.size(), before)
	assert_eq(game.run_seed, 5)
