extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")


func _everyone_on_platform(state: GameState) -> void:
	var ids := Helpers.place_starter(state)
	Helpers.finish_construction(state)
	state.assembled["electrolysis_plant"] = 1
	assert(state.place(ids["metal_storage"], 3, 3, "electrolysis_plant") == "")
	state.assembled["habitat"] = 1
	assert(state.place(ids["gas_storage"], 1, 2, "habitat") == "")
	Helpers.finish_construction(state)
	state.cradle_ice = 3000.0
	state.storage.add("nitrogen", 60.0)


func test_win_at_second_comet() -> void:
	var state := Helpers.new_state()
	_everyone_on_platform(state)
	state.comets.passes[1]["leaves"] = state.hour + 1
	state.step()
	assert_eq(state.outcome, "won")


func test_no_win_at_first_comet() -> void:
	var state := Helpers.new_state()
	_everyone_on_platform(state)
	state.comets.passes[0]["leaves"] = state.hour + 1
	state.step()
	assert_eq(state.outcome, "")


func test_no_win_at_second_comet_while_dependent() -> void:
	var state := Helpers.new_state()
	state.comets.passes[1]["leaves"] = state.hour + 1
	state.step()
	assert_eq(state.outcome, "")


func test_later_comet_can_still_win() -> void:
	var state := Helpers.new_state()
	_everyone_on_platform(state)
	state.cradle_ice = 0.0
	state.comets.passes[1]["leaves"] = state.hour + 1
	state.step()
	assert_eq(state.outcome, "")
	state.cradle_ice = 3000.0
	state.comets.passes[2]["leaves"] = state.hour + 1
	state.step()
	assert_eq(state.outcome, "won")


func test_first_all_on_platform_hour_is_recorded_once() -> void:
	var state := Helpers.new_state()
	_everyone_on_platform(state)
	var first_hour := state.hour
	state.step()
	state.step()
	assert_eq(state.first_all_on_platform_hour, first_hour)


func test_summary_fields() -> void:
	var state := Helpers.new_state()
	_everyone_on_platform(state)
	var first_hour := state.hour
	state.step()
	state.end_run()
	var summary := state.summary()
	assert_eq(summary["outcome"], "ended")
	assert_eq(summary["reason"], "")
	assert_eq(summary["hours"], state.hour)
	assert_almost_eq(summary["reserve_hours_left"], state.life.reserve / 12.0, 0.001)
	assert_eq(summary["first_all_on_platform_hour"], first_hour)
