extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")
const Hud = preload("res://game/ui/hud.gd")

var game: Node
var hud: Node
var original_size: Vector2i


func before_each() -> void:
	original_size = get_tree().root.size
	game = add_child_autofree(load("res://game/main.tscn").instantiate())
	hud = game.get_node("UI/Hud")


func after_each() -> void:
	get_tree().root.size = original_size
	await get_tree().process_frame


func test_day_hour_text() -> void:
	assert_eq(Hud.day_hour_text(0), "Day 1, 00:00")
	assert_eq(Hud.day_hour_text(38), "Day 2, 14:00")
	assert_eq(Hud.day_hour_text(23), "Day 1, 23:00")
	assert_eq(Hud.day_hour_text(24), "Day 2, 00:00")


func test_top_bar_shows_clock_frames_and_platform_after_stepping() -> void:
	Helpers.place_starter(game.state)
	for i in 3:
		game.state.step()
	hud.refresh()
	assert_eq(hud._clock_label.text, "Day 1, 03:00")
	assert_eq(hud._frame_label.text, "Frame %d" % int(game.state.stock.amount("frame_piece")))
	assert_eq(hud._platform_label.text, "On platform %d / %d" % [game.state.life.on_platform, game.state.crew])
	assert_eq(hud._crew_label.text, "Crew 12")


func test_fuel_is_dash_before_a_generator_exists() -> void:
	hud.refresh()
	assert_eq(hud._fuel_label.text, "Fuel —")


func test_fuel_shows_whole_hours_once_generator_is_built() -> void:
	Helpers.place_starter(game.state)
	Helpers.finish_construction(game.state)
	hud.refresh()
	assert_true(hud._fuel_label.text.begins_with("Fuel "))
	assert_ne(hud._fuel_label.text, "Fuel —")


func test_alerts_and_checklist_are_listed() -> void:
	Helpers.place_starter(game.state)
	for i in 3:
		game.state.step()
	hud.refresh()
	var alerts := Advisor.alerts(game.state)
	assert_gt(alerts.size(), 0)
	assert_not_null(hud._alerts.get_node_or_null(alerts[0]["id"]))
	var first_item: Node = hud._checklist.get_child(0)
	assert_eq(first_item.get_child(0).text, "○")
	assert_eq(first_item.get_child(1).text, Advisor.checklist(game.state)[0]["text"])


func test_done_checklist_item_is_ticked() -> void:
	Helpers.place_starter(game.state)
	Helpers.finish_construction(game.state)
	hud.refresh()
	assert_eq(hud._checklist.get_child(0).get_child(0).text, "✓")


func test_speed_buttons_set_speed_and_highlight() -> void:
	hud._speed_buttons["fast"].pressed.emit()
	assert_eq(game.clock.speed, "fast")
	assert_eq(hud._speed_buttons["fast"].get_theme_color("font_color"), Hud.MINT)
	assert_ne(hud._speed_buttons["normal"].get_theme_color("font_color"), Hud.MINT)


func test_speed_change_from_game_updates_highlight() -> void:
	game.set_speed("normal")
	assert_eq(hud._speed_buttons["normal"].get_theme_color("font_color"), Hud.MINT)
	assert_ne(hud._speed_buttons["paused"].get_theme_color("font_color"), Hud.MINT)


func test_power_label_goes_gold_when_short() -> void:
	Helpers.place_starter(game.state)
	game.state.step()
	hud.refresh()
	var expected := Hud.GOLD if game.state.power.short else Hud.LIGHT
	assert_eq(hud._power_label.get_theme_color("font_color"), expected)


func _built_generator() -> void:
	Helpers.place_starter(game.state)
	Helpers.finish_construction(game.state)
	game.state.power.demand_mw = 10.0


func test_fuel_text_and_colour_below_threshold() -> void:
	_built_generator()
	game.state.power.fuel_core_mwh = 1500.0
	hud.refresh()
	assert_eq(hud._fuel_label.text, "Fuel %d h" % int(floor(game.state.power.fuel_hours_left(game.state.storage))))
	assert_lt(game.state.power.fuel_hours_left(game.state.storage), 200.0)
	assert_eq(hud._fuel_label.get_theme_color("font_color"), Hud.GOLD)


func test_fuel_text_and_colour_above_threshold() -> void:
	_built_generator()
	game.state.power.fuel_core_mwh = 3000.0
	hud.refresh()
	assert_eq(hud._fuel_label.text, "Fuel 300 h")
	assert_eq(hud._fuel_label.get_theme_color("font_color"), Hud.LIGHT)


func test_fuel_exact_text_below_threshold() -> void:
	_built_generator()
	game.state.power.fuel_core_mwh = 1000.0
	hud.refresh()
	assert_eq(hud._fuel_label.text, "Fuel 100 h")


func test_reserve_gold_below_threshold_when_someone_depends_on_the_ship() -> void:
	game.state.life.reserve = 1800.0
	game.state.life.dependent = 3
	hud.refresh()
	assert_eq(hud._reserve_label.text, "Reserve 150 h")
	assert_eq(hud._reserve_label.get_theme_color("font_color"), Hud.GOLD)


func test_reserve_not_gold_when_nobody_depends_on_the_ship() -> void:
	game.state.life.reserve = 1800.0
	game.state.life.dependent = 0
	hud.refresh()
	assert_eq(hud._reserve_label.get_theme_color("font_color"), Hud.LIGHT)


func test_reserve_normal_above_threshold() -> void:
	game.state.life.reserve = 3600.0
	hud.refresh()
	assert_eq(hud._reserve_label.text, "Reserve 300 h")
	assert_eq(hud._reserve_label.get_theme_color("font_color"), Hud.LIGHT)


func test_ice_text() -> void:
	game.state.cradle_ice = 42.7
	hud.refresh()
	assert_eq(hud._ice_label.text, "Ice 42 u")


func test_robots_free_over_total_with_construction_under_way() -> void:
	Helpers.place_starter(game.state)
	game.state.step()
	var busy: int = game.state.construction.robots_busy()
	assert_gt(busy, 0)
	hud.refresh()
	assert_eq(hud._robots_label.text, "Robots %d / %d" % [game.state.robots - busy, game.state.robots])


func test_power_label_gold_when_short() -> void:
	game.state.power.supply_mw = 20.0
	game.state.power.demand_mw = 35.0
	game.state.power.short = true
	hud.refresh()
	assert_eq(hud._power_label.text, "Power 35 of 20 MW")
	assert_eq(hud._power_label.get_theme_color("font_color"), Hud.GOLD)


func test_power_label_normal_when_not_short() -> void:
	game.state.power.supply_mw = 20.0
	game.state.power.demand_mw = 5.0
	game.state.power.short = false
	hud.refresh()
	assert_eq(hud._power_label.text, "Power 5 of 20 MW")
	assert_eq(hud._power_label.get_theme_color("font_color"), Hud.LIGHT)


func test_stepped_signal_refreshes_without_calling_refresh() -> void:
	hud.refresh()
	assert_eq(hud._clock_label.text, "Day 1, 00:00")
	for i in 25:
		game.state.step()
	game.stepped.emit()
	assert_eq(hud._clock_label.text, "Day 2, 01:00")


func test_deferred_ready_refresh_fills_the_top_bar() -> void:
	var fresh: Node = add_child_autofree(load("res://game/main.tscn").instantiate())
	await get_tree().process_frame
	assert_eq(fresh.get_node("UI/Hud")._clock_label.text, "Day 1, 00:00")
	assert_eq(fresh.get_node("UI/Hud")._crew_label.text, "Crew 12")


func test_late_game_top_bar_fits_the_window() -> void:
	get_tree().root.size = Vector2i(1152, 648)
	game.state.hour = 96 * 24 + 10
	game.state.power.demand_mw = 120.0
	game.state.power.supply_mw = 120.0
	game.state.life.on_platform = 12
	game.state.life.reserve = 1000.0 * 12.0
	game.state.cradle_ice = 3000.0
	game.state.robots = 24
	game.state.stock.items["frame_piece"] = 99.0
	hud._refresh_numbers(game.state)
	hud._clock_label.text = Hud.day_hour_text(game.state.hour)
	hud._fuel_label.text = "Fuel 9999 h"
	await get_tree().process_frame
	await get_tree().process_frame
	var bar: Control = hud.get_node("TopBar")
	var window_width: float = get_viewport().get_visible_rect().size.x
	assert_gte(bar.get_global_rect().position.x, 0.0)
	assert_lte(bar.get_global_rect().end.x, window_width)
	assert_lte(hud.menu_button.get_global_rect().end.x, window_width)
	assert_gte(hud._clock_label.get_global_rect().position.x, 0.0)


func test_side_panel_starts_below_the_top_bar() -> void:
	hud.refresh()
	assert_gte(hud.get_node("SidePanel").offset_top, hud.bar_bottom())
