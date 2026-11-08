extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")


func _state_with_plant_and_habitat() -> GameState:
	var state := Helpers.new_state()
	var ids := Helpers.place_starter(state)
	Helpers.finish_construction(state)
	state.assembled["electrolysis_plant"] = 1
	assert(state.place(ids["metal_storage"], 3, 3, "electrolysis_plant") == "")
	state.assembled["habitat"] = 1
	assert(state.place(ids["gas_storage"], 1, 2, "habitat") == "")
	Helpers.finish_construction(state)
	return state


func test_everyone_depends_on_ship_at_start() -> void:
	var state := Helpers.new_state()
	var before := state.life.reserve
	state.step()
	assert_eq(state.life.dependent, 12)
	assert_eq(state.life.on_platform, 0)
	assert_almost_eq(state.life.reserve, before - 12.0, 0.001)


func test_plant_and_habitat_take_everyone() -> void:
	var state := _state_with_plant_and_habitat()
	state.cradle_ice = 3000.0
	state.storage.add("nitrogen", 60.0)
	var reserve_before := state.life.reserve
	var nitrogen_before := state.storage.amount("nitrogen")
	state.step()
	assert_eq(state.life.on_platform, 12)
	assert_eq(state.life.dependent, 0)
	assert_almost_eq(state.life.reserve, reserve_before, 0.001)
	assert_almost_eq(state.cradle_ice, 2999.0, 0.001)
	assert_almost_eq(state.storage.amount("nitrogen"), nitrogen_before - 0.12, 0.001)


func test_beds_limit() -> void:
	var state := _state_with_plant_and_habitat()
	state.layout.node(state.layout.built_nodes("habitat")[0].id).built = false
	state.cradle_ice = 3000.0
	state.storage.add("nitrogen", 60.0)
	state.step()
	assert_eq(state.life.on_platform, 0)


func test_no_ice_no_supply() -> void:
	var state := _state_with_plant_and_habitat()
	state.cradle_ice = 0.0
	state.storage.add("nitrogen", 60.0)
	state.step()
	assert_eq(state.life.dependent, 12)


func test_nitrogen_limits_supply() -> void:
	var state := _state_with_plant_and_habitat()
	state.cradle_ice = 3000.0
	state.storage.take("nitrogen", state.storage.amount("nitrogen"))
	state.storage.add("nitrogen", 0.05)
	state.step()
	assert_eq(state.life.on_platform, 5)
	assert_eq(state.life.dependent, 7)


func test_reserve_runs_out() -> void:
	var state := Helpers.new_state()
	state.life.reserve = 24.0
	state.step()
	assert_eq(state.outcome, "")
	state.step()
	assert_eq(state.outcome, "collapsed")
	assert_eq(state.collapse_reason, "air_water")


func test_reserve_hours_with_no_crew_is_infinite() -> void:
	var state := Helpers.new_state()
	assert_eq(state.life.reserve_hours(0), INF)
	assert_almost_eq(state.life.reserve_hours(12), 1000.0, 0.001)
