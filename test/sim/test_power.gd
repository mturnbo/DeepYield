extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")


func _built_starter() -> Array:
	var state := Helpers.new_state()
	var ids := Helpers.place_starter(state)
	Helpers.finish_construction(state)
	return [state, ids]


func test_operators_follow_priority() -> void:
	var state := Helpers.new_state()
	var ids := {}
	assert_eq(state.place_first("command", Vector2.ZERO), "")
	ids["command"] = 0
	assert_eq(state.place(0, 3, 2, "metal_storage"), "")
	assert_eq(state.place(1, 0, 2, "refinery"), "")
	assert_eq(state.place(0, 1, 2, "gas_storage"), "")
	assert_eq(state.place(3, 0, 2, "factory"), "")
	Helpers.finish_construction(state)
	state.crew = 2
	state.step()
	assert_true(state.power.operated[2])
	assert_true(state.power.operated[4])
	assert_false(state.power.operated[0])


func test_arrival_ship_powers_before_generator() -> void:
	var state := Helpers.new_state()
	assert_eq(state.place_first("command", Vector2.ZERO), "")
	assert_eq(state.place(0, 2, 3, "ship_dock"), "")
	assert_eq(state.place(0, 1, 2, "gas_storage"), "")
	Helpers.finish_construction(state)
	state.step()
	assert_eq(state.power.supply_mw, 20.0)
	assert_false(state.power.short)
	for node in state.layout.nodes:
		assert_true(state.is_running(node.id))


func test_short_power_shuts_down_in_order() -> void:
	var state := Helpers.new_state()
	assert_eq(state.place_first("command", Vector2.ZERO), "")
	assert_eq(state.place(0, 2, 3, "ship_dock"), "")
	assert_eq(state.place(0, 0, 2, "refinery"), "")
	assert_eq(state.place(0, 1, 2, "factory"), "")
	Helpers.finish_construction(state)
	state.step()
	assert_true(state.power.short)
	assert_almost_eq(state.power.demand_mw, 21.7, 0.001)
	assert_false(state.is_running(0))
	assert_true(state.is_running(1))
	assert_true(state.is_running(2))
	assert_true(state.is_running(3))


func test_generator_burns_core_then_hydrogen() -> void:
	var built := _built_starter()
	var state: GameState = built[0]
	state.storage.add("hydrogen", 10.0)
	state.power.fuel_core_mwh = 10.0
	state.step()
	assert_eq(state.power.fuel_core_mwh, 0.0)
	assert_almost_eq(state.storage.amount("hydrogen"), 10.0 - (state.power.demand_mw - 10.0) / 150.0, 0.0001)


func test_generator_with_core_does_not_touch_hydrogen() -> void:
	var built := _built_starter()
	var state: GameState = built[0]
	state.storage.add("hydrogen", 10.0)
	var core_before := state.power.fuel_core_mwh
	state.step()
	assert_eq(state.storage.amount("hydrogen"), 10.0)
	assert_almost_eq(state.power.fuel_core_mwh, core_before - state.power.demand_mw, 0.001)


func test_arrival_ship_burns_no_fuel() -> void:
	var state := Helpers.new_state()
	assert_eq(state.place_first("command", Vector2.ZERO), "")
	Helpers.finish_construction(state)
	state.step()
	assert_eq(state.power.fuel_core_mwh, 86400.0)


func test_battery_then_collapse() -> void:
	var built := _built_starter()
	var state: GameState = built[0]
	var ids: Dictionary = built[1]
	state.power.fuel_core_mwh = 0.0
	state.step()
	assert_true(state.power.on_battery)
	assert_eq(state.speed_of(ids["refinery"]), 0.5)
	assert_eq(state.outcome, "")
	for i in 10:
		state.step()
	assert_eq(state.outcome, "")
	state.step()
	assert_eq(state.outcome, "collapsed")
	assert_eq(state.collapse_reason, "energy")


func test_short_supply_burns_only_the_reduced_demand_and_clears_when_covered() -> void:
	var weak_balance := Balance.load_default().duplicate(true)
	weak_balance["power"]["generator_mw"] = 20
	var state := GameState.new(weak_balance, 1)
	Helpers.place_starter(state)
	Helpers.finish_construction(state)
	state.power.fuel_core_mwh = 1000.0
	state.step()
	assert_true(state.power.short)
	assert_false(state.is_running(0))
	var running_demand := 0.0
	for built in state.layout.built_nodes():
		if state.power.powered.get(built.id, false):
			running_demand += float(weak_balance["modules"][built.kind]["power_mw"])
	running_demand += 0.1 * state.layout.frame_piece_count(true)
	assert_true(running_demand <= 20.0)
	assert_almost_eq(state.power.fuel_core_mwh, 1000.0 - running_demand, 0.001)
	state.balance["power"]["generator_mw"] = 60
	state.step()
	assert_false(state.power.short)
	assert_true(state.is_running(0))


func test_battery_refills_when_fuel_returns() -> void:
	var built := _built_starter()
	var state: GameState = built[0]
	state.power.fuel_core_mwh = 0.0
	for i in 5:
		state.step()
	assert_eq(state.power.battery_hours_left, 7.0)
	state.storage.add("hydrogen", 10.0)
	state.step()
	assert_eq(state.power.battery_hours_left, 12.0)
	assert_false(state.power.on_battery)


func test_speed_is_full_when_running_normally() -> void:
	var built := _built_starter()
	var state: GameState = built[0]
	var ids: Dictionary = built[1]
	state.step()
	assert_eq(state.speed_of(ids["refinery"]), 1.0)


func test_unbuilt_node_does_not_run() -> void:
	var state := Helpers.new_state()
	assert_eq(state.place_first("command", Vector2.ZERO), "")
	state.step()
	assert_false(state.is_running(0))
	assert_eq(state.speed_of(0), 0.0)


func test_fuel_hours_left() -> void:
	var state := Helpers.new_state()
	state.power.demand_mw = 30.0
	assert_almost_eq(state.power.fuel_hours_left(state.storage), 2880.0, 0.01)


func test_fuel_hours_left_counts_hydrogen() -> void:
	var built := _built_starter()
	var state: GameState = built[0]
	state.power.fuel_core_mwh = 0.0
	state.power.demand_mw = 30.0
	state.storage.add("hydrogen", 10.0)
	assert_almost_eq(state.power.fuel_hours_left(state.storage), 50.0, 0.01)


func test_fuel_hours_left_with_no_demand_is_infinite() -> void:
	var state := Helpers.new_state()
	assert_eq(state.power.fuel_hours_left(state.storage), INF)
