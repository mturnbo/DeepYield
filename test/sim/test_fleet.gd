extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")


func _built_starter() -> GameState:
	var state := Helpers.new_state()
	Helpers.place_starter(state)
	Helpers.finish_construction(state)
	return state


func _step(state: GameState, hours: int) -> void:
	for hour in hours:
		state.step()


func test_ships_wait_in_cargo_until_dock_runs() -> void:
	var state := Helpers.new_state()
	Helpers.place_starter(state)
	state.step()
	for ship in state.fleet.ships:
		assert_eq(ship.state, "in_cargo")
	Helpers.finish_construction(state)
	for ship in state.fleet.ships:
		assert_eq(ship.state, "docked")
		assert_eq(ship.bay, ship.id)
		assert_true(ship.assignment.is_empty())


func test_assign_refusals() -> void:
	var state := _built_starter()
	assert_eq(state.assign_ship(0, "nebula", ["hydrogen", "helium", "nitrogen", "argon"]), "Pick up to 3 gases")
	assert_eq(state.assign_ship(0, "asteroids", ["iron", "nickel", "silicon"]), "Pick up to 2 metals")
	assert_eq(state.assign_ship(0, "nebula", ["iron"]), "iron isn't found there")
	assert_eq(state.assign_ship(0, "nebula", []), "Pick at least one material")
	assert_eq(state.assign_ship(9, "nebula", ["hydrogen"]), "No such ship")
	assert_eq(state.assign_ship(0, "moon", ["hydrogen"]), "No such site")
	assert_true(state.fleet.ship(0).assignment.is_empty())


func test_nebula_round_trip_timing() -> void:
	var state := _built_starter()
	assert_eq(state.assign_ship(0, "nebula", ["hydrogen"]), "")
	var ship := state.fleet.ship(0)
	_step(state, 1)
	assert_eq(ship.state, "outbound")
	_step(state, 44)
	assert_eq(ship.state, "inbound")
	_step(state, 1)
	assert_eq(ship.state, "docked")
	assert_eq(state.storage.amount("hydrogen"), 0.0)
	_step(state, 1)
	assert_eq(state.storage.amount("hydrogen"), 20.0)
	assert_true(ship.cargo.is_empty())


func test_phase_boundaries() -> void:
	var state := _built_starter()
	state.assign_ship(0, "nebula", ["hydrogen"])
	var ship := state.fleet.ship(0)
	_step(state, 18)
	assert_eq(ship.state, "working")
	assert_eq(ship.hours_total, 10)
	_step(state, 10)
	assert_eq(ship.state, "inbound")
	assert_eq(ship.hours_total, 18)


func test_wear_after_trip() -> void:
	var state := _built_starter()
	state.assign_ship(0, "asteroids", ["iron"])
	_step(state, 22 + 12 + 22)
	assert_almost_eq(state.fleet.ship(0).condition, 0.96, 0.0001)


func test_wear_does_not_drift_over_five_trips() -> void:
	var state := _built_starter()
	state.assign_ship(0, "asteroids", ["iron"])
	var ship := state.fleet.ship(0)
	var arrivals := 0
	var last_condition := 1.0
	while arrivals < 5:
		state.storage.take("iron", 100.0)
		state.step()
		if ship.condition != last_condition:
			arrivals += 1
			last_condition = ship.condition
	assert_eq(ship.condition, 0.8)
	var total := 0
	for units in ship.load_for(["iron"], Balance.load_default()["mining"]).values():
		total += units
	assert_eq(total, 16)


func test_holding_when_bays_full() -> void:
	var state := _built_starter()
	var fifth := state.fleet.add_ship()
	assert_eq(fifth.state, "holding")
	assert_eq(fifth.bay, -1)


func test_returning_ship_holds_when_bays_full() -> void:
	var state := _built_starter()
	state.assign_ship(0, "nebula", ["hydrogen"])
	_step(state, 5)
	var fifth := state.fleet.add_ship()
	assert_eq(fifth.state, "docked")
	assert_eq(fifth.bay, 0)
	_step(state, 41)
	assert_eq(state.fleet.ship(0).state, "holding")


func test_full_storage_keeps_ship_docked() -> void:
	var state := _built_starter()
	state.storage.add("hydrogen", 55.0)
	state.assign_ship(0, "nebula", ["hydrogen"])
	var ship := state.fleet.ship(0)
	_step(state, 47)
	assert_eq(state.storage.amount("hydrogen"), 60.0)
	assert_true(ship.waiting_for_room)
	assert_eq(ship.cargo["hydrogen"], 15.0)
	assert_eq(state.fleet.waiting_count(), 1)
	_step(state, 10)
	assert_eq(ship.state, "docked")
	assert_eq(state.fleet.waiting_count(), 1)


func test_missing_storage_keeps_cargo() -> void:
	var state := Helpers.new_state()
	assert_eq(state.place_first("command", Vector2.ZERO), "")
	assert_eq(state.place(0, 2, 3, "ship_dock"), "")
	Helpers.finish_construction(state)
	state.assign_ship(0, "nebula", ["hydrogen"])
	var ship := state.fleet.ship(0)
	_step(state, 60)
	assert_eq(ship.state, "docked")
	assert_true(ship.waiting_for_room)
	assert_eq(ship.cargo["hydrogen"], 20.0)
	assert_eq(state.place(0, 1, 2, "gas_storage"), "")
	Helpers.finish_construction(state)
	_step(state, 1)
	assert_true(ship.cargo.is_empty())
	assert_false(ship.waiting_for_room)
	assert_eq(state.storage.amount("hydrogen"), 20.0)


func test_assignment_change_mid_trip() -> void:
	var state := _built_starter()
	state.assign_ship(0, "asteroids", ["iron", "nickel"])
	_step(state, 5)
	assert_eq(state.assign_ship(0, "asteroids", ["silicon"]), "")
	var ship := state.fleet.ship(0)
	assert_eq(ship.assignment["materials"], ["iron", "nickel"])
	assert_eq(ship.next_assignment["materials"], ["silicon"])
	_step(state, 22 + 12 + 22 - 5 + 1)
	assert_eq(state.storage.amount("iron"), 10.0)
	assert_eq(state.storage.amount("nickel"), 10.0)
	assert_eq(state.storage.amount("silicon"), 0.0)
	assert_eq(ship.state, "docked")
	_step(state, 4)
	assert_eq(ship.state, "outbound")
	assert_eq(ship.trip_materials, ["silicon"])
	assert_true(ship.next_assignment.is_empty())


func test_argon_goes_to_stock() -> void:
	var state := _built_starter()
	state.assign_ship(0, "nebula", ["argon"])
	_step(state, 47)
	assert_eq(state.stock.amount("argon"), 1.0)
	assert_eq(state.storage.amount("argon"), 0.0)


func test_no_dock_running_means_holding() -> void:
	var fleet := Fleet.new(Balance.load_default(), 1)
	var storage := Storage.new(Balance.load_default()["storage"])
	var stock := Stock.new()
	fleet.step(true, storage, stock)
	var ship := fleet.ship(0)
	ship.assignment = {"site": "nebula", "materials": ["hydrogen"]}
	for hour in 46:
		fleet.step(false, storage, stock)
	assert_eq(ship.state, "holding")
	fleet.step(true, storage, stock)
	assert_eq(ship.state, "docked")
