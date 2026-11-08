extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")
const Hud = preload("res://game/ui/hud.gd")

var game: Node
var hud: Node


func before_each() -> void:
	game = add_child_autofree(load("res://game/main.tscn").instantiate())
	hud = game.get_node("UI/Hud")


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
