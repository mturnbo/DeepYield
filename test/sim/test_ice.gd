extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")


func _state_with_plant() -> GameState:
	var state := Helpers.new_state()
	var ids := Helpers.place_starter(state)
	state.assembled["electrolysis_plant"] = 1
	assert_eq(state.place(ids["metal_storage"], 3, 3, "electrolysis_plant"), "")
	Helpers.finish_construction(state)
	return state


func _comet_now(state: GameState, distance: float, reach: int) -> void:
	state.comets.passes[0]["arrives"] = state.hour
	state.comets.passes[0]["leaves"] = state.hour + reach
	state.comets.passes[0]["distance"] = distance


func _step(state: GameState, hours: int) -> void:
	for hour in hours:
		state.step()


func test_refusals() -> void:
	var state := Helpers.new_state()
	Helpers.place_starter(state)
	Helpers.finish_construction(state)
	assert_eq(state.fetch_ice(9, 1000), "No such ship")
	assert_eq(state.fetch_ice(0, 1000), "No comet in reach")
	_comet_now(state, 1.0, 200)
	assert_eq(state.fetch_ice(0, 1500), "Chunks are 1,000, 2,000 or 3,000 u")
	assert_eq(state.fetch_ice(0, 1000), "Build an electrolysis plant first")
	state = _state_with_plant()
	_comet_now(state, 1.0, 200)
	state.fleet.ship(1).state = "in_cargo"
	assert_eq(state.fetch_ice(1, 1000), "That ship is still in the cargo bay")
	assert_eq(state.fetch_ice(0, 1000), "")
	assert_eq(state.fetch_ice(0, 2000), "That ship is already fetching ice")
	_step(state, 1)
	assert_eq(state.fetch_ice(0, 2000), "That ship is already fetching ice")


func test_cradle_capacity_counts_built_plants() -> void:
	var state := Helpers.new_state()
	Helpers.place_starter(state)
	assert_eq(state.cradle_capacity(), 0.0)
	state = _state_with_plant()
	assert_eq(state.cradle_capacity(), 3000.0)


func test_ice_trip_timing() -> void:
	var state := _state_with_plant()
	_comet_now(state, 1.0, 200)
	state.fetch_ice(0, 3000)
	var ship := state.fleet.ship(0)
	_step(state, 1)
	assert_eq(ship.state, "ice_outbound")
	assert_eq(ship.chunk, 3000)
	assert_eq(ship.ice_order, 0)
	_step(state, 29)
	assert_eq(ship.state, "carving")
	_step(state, 10)
	assert_eq(ship.state, "towing")
	_step(state, 44)
	assert_eq(ship.state, "towing")
	assert_eq(state.cradle_ice, 0.0)
	assert_false(state.ice_delivered)
	_step(state, 1)
	assert_eq(state.cradle_ice, 3000.0)
	assert_true(state.ice_delivered)
	assert_eq(ship.chunk, 0)
	assert_almost_eq(ship.condition, 0.99, 0.00001)
	assert_eq(ship.state, "inbound")
	_step(state, 1)
	assert_eq(ship.state, "docked")
	assert_almost_eq(ship.condition, 0.99, 0.00001)


func test_far_comet_is_slower() -> void:
	var state := _state_with_plant()
	_comet_now(state, 2.0, 200)
	state.fetch_ice(0, 1000)
	_step(state, 60 + 10 + 69)
	assert_eq(state.cradle_ice, 0.0)
	_step(state, 1)
	assert_eq(state.cradle_ice, 1000.0)


func test_chunk_waits_for_cradle_room() -> void:
	var state := _state_with_plant()
	_comet_now(state, 1.0, 200)
	state.cradle_ice = 2500.0
	state.fetch_ice(0, 1000)
	var ship := state.fleet.ship(0)
	_step(state, 30 + 10 + 35)
	assert_eq(ship.state, "at_plant")
	_step(state, 5)
	assert_eq(ship.state, "at_plant")
	assert_eq(state.cradle_ice, 2500.0)
	state.cradle_ice = 2000.0
	_step(state, 1)
	assert_eq(state.cradle_ice, 3000.0)
	assert_eq(ship.state, "inbound")


func test_away_ship_goes_after_unloading() -> void:
	var state := _state_with_plant()
	state.assign_ship(0, "nebula", ["hydrogen"])
	_step(state, 5)
	assert_eq(state.fleet.ship(0).state, "outbound")
	_comet_now(state, 1.0, 500)
	assert_eq(state.fetch_ice(0, 1000), "")
	var ship := state.fleet.ship(0)
	_step(state, 41)
	assert_eq(ship.state, "docked")
	assert_false(ship.cargo.is_empty())
	_step(state, 1)
	assert_true(ship.cargo.is_empty())
	assert_eq(ship.state, "ice_outbound")


func test_order_cancelled_if_comet_leaves_first() -> void:
	var state := _state_with_plant()
	state.assign_ship(0, "nebula", ["hydrogen"])
	_step(state, 5)
	_comet_now(state, 1.0, 10)
	state.fetch_ice(0, 1000)
	var ship := state.fleet.ship(0)
	_step(state, 41)
	assert_eq(ship.state, "docked")
	assert_eq(ship.ice_order, 1000)
	_step(state, 1)
	assert_eq(ship.ice_order, 0)
	assert_eq(ship.state, "docked")
	_step(state, 5)
	assert_eq(ship.state, "outbound")
	assert_eq(ship.destination, "nebula")


func test_chunk_still_comes_home_after_comet_leaves() -> void:
	var state := _state_with_plant()
	_comet_now(state, 1.0, 20)
	state.fetch_ice(0, 1000)
	var ship := state.fleet.ship(0)
	_step(state, 30 + 5)
	assert_eq(ship.state, "carving")
	assert_eq(state.comets.current(state.hour), -1)
	_step(state, 5 + 35)
	assert_eq(state.cradle_ice, 1000.0)


func test_assignment_resumes_after_ice() -> void:
	var state := _state_with_plant()
	state.assign_ship(0, "nebula", ["hydrogen"])
	_comet_now(state, 1.0, 200)
	state.fetch_ice(0, 1000)
	var ship := state.fleet.ship(0)
	_step(state, 30 + 10 + 35 + 1)
	assert_eq(ship.state, "docked")
	assert_eq(ship.assignment["site"], "nebula")
	_step(state, 5)
	assert_eq(ship.state, "outbound")
	assert_eq(ship.destination, "nebula")
