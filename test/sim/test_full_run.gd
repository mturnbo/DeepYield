extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")
const MAX_HOURS := 4000
const ICE_SHIP := 2
const WORN := 0.6

var state: GameState
var ids: Dictionary
var plant_placed := false
var habitat_placed := false
var ice_pass_served := -1
var hydrogen_reassigned := false


func test_scripted_run_reaches_goal() -> void:
	state = Helpers.new_state()
	ids = Helpers.place_starter(state)
	_assign_ships()
	_queue_production()
	while state.outcome == "" and state.hour < MAX_HOURS:
		_react()
		state.step()
	assert_eq(state.outcome, "won", "collapse: %s at hour %d" % [state.collapse_reason, state.hour])
	assert_gte(state.hour, int(state.comets.passes[1]["leaves"]))
	assert_gte(state.first_all_on_platform_hour, 0)


func _assign_ships() -> void:
	assert_eq(state.assign_ship(0, "asteroids", ["iron", "aluminum"]), "")
	assert_eq(state.assign_ship(1, "asteroids", ["iron", "aluminum"]), "")
	assert_eq(state.assign_ship(2, "asteroids", ["silicon", "platinum"]), "")
	assert_eq(state.assign_ship(3, "nebula", ["nitrogen", "argon"]), "")


func _queue_production() -> void:
	for i in 22:
		assert_eq(state.queue_item("factory", "module_part"), "")
	assert_eq(state.queue_item("assembly", "electrolysis_plant"), "")
	assert_eq(state.queue_item("assembly", "habitat"), "")


func _react() -> void:
	_place_assembled_modules()
	_fetch_ice_when_in_reach()
	_switch_to_hydrogen_when_core_runs_low()
	_repair_worn_ships()


func _place_assembled_modules() -> void:
	if not plant_placed and state.assembled.get("electrolysis_plant", 0) > 0:
		assert_eq(state.place(ids["metal_storage"], 3, 3, "electrolysis_plant"), "")
		plant_placed = true
	if not habitat_placed and state.assembled.get("habitat", 0) > 0:
		assert_eq(state.place(ids["gas_storage"], 1, 2, "habitat"), "")
		habitat_placed = true


func _fetch_ice_when_in_reach() -> void:
	var pass_index := state.comets.current(state.hour)
	if pass_index == -1 or pass_index == ice_pass_served:
		return
	if state.fetch_ice(ICE_SHIP, 3000) == "":
		ice_pass_served = pass_index


func _switch_to_hydrogen_when_core_runs_low() -> void:
	if hydrogen_reassigned or state.power.fuel_core_mwh > 20000.0:
		return
	assert_eq(state.assign_ship(2, "nebula", ["hydrogen"]), "")
	hydrogen_reassigned = true


func _repair_worn_ships() -> void:
	for each_ship in state.fleet.ships:
		if each_ship.condition < WORN and not each_ship.repair_requested:
			assert_eq(state.request_repair(each_ship.id), "")
			_keep_a_module_part_coming()


func _keep_a_module_part_coming() -> void:
	var on_the_way: int = state.production.queues["factory"].size()
	if state.stock.amount("module_part") + on_the_way < 2.0:
		assert_eq(state.queue_item("factory", "module_part"), "")
