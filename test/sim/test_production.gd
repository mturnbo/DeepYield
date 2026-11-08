extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")

var state: GameState
var ids: Dictionary


func before_each() -> void:
	state = Helpers.new_state()
	ids = Helpers.place_starter(state)
	Helpers.finish_construction(state)


func _steps(count: int) -> void:
	for i in count:
		state.step()


func test_refines_most_stored_metal() -> void:
	state.storage.add("iron", 10.0)
	state.storage.add("nickel", 4.0)
	var before := state.stock.amount("iron")
	state.production.refine(1.0, state.storage, state.stock)
	assert_eq(state.stock.amount("iron") - before, 2.0)
	assert_eq(state.storage.amount("iron"), 8.0)


func test_argon_needed_for_aluminum() -> void:
	state.storage.add("aluminum", 10.0)
	state.storage.add("iron", 2.0)
	state.production.refine(1.0, state.storage, state.stock)
	assert_eq(state.stock.amount("iron"), 2.0)
	assert_eq(state.stock.amount("aluminum"), 0.0)
	state.stock.add("argon", 1.0)
	state.production.refine(1.0, state.storage, state.stock)
	assert_eq(state.stock.amount("aluminum"), 2.0)
	assert_almost_eq(state.stock.amount("argon"), 0.8, 0.0001)


func test_argon_limits_amount_refined() -> void:
	state.storage.add("aluminum", 10.0)
	state.stock.add("argon", 0.05)
	state.production.refine(1.0, state.storage, state.stock)
	assert_almost_eq(state.stock.amount("aluminum"), 0.5, 0.0001)
	assert_almost_eq(state.stock.amount("argon"), 0.0, 0.0001)


func test_refinery_off_without_operator() -> void:
	state.storage.add("iron", 10.0)
	state.production.refine(0.0, state.storage, state.stock)
	assert_eq(state.storage.amount("iron"), 10.0)
	assert_eq(state.stock.amount("iron"), 0.0)


func test_refinery_stops_when_storage_empty() -> void:
	state.production.refine(1.0, state.storage, state.stock)
	assert_eq(state.stock.amount("iron"), 0.0)


func test_refine_takes_only_what_is_left() -> void:
	state.storage.add("iron", 1.0)
	state.production.refine(1.0, state.storage, state.stock)
	assert_eq(state.stock.amount("iron"), 1.0)
	assert_eq(state.storage.amount("iron"), 0.0)


func test_factory_makes_module_part() -> void:
	state.stock.add("iron", 3.0)
	state.stock.add("aluminum", 1.0)
	state.stock.add("silicon", 1.0)
	assert_eq(state.queue_item("factory", "module_part"), "")
	_steps(3)
	assert_eq(state.stock.amount("module_part"), 0.0)
	_steps(1)
	assert_eq(state.stock.amount("module_part"), 1.0)


func test_job_waits_for_all_inputs() -> void:
	state.stock.add("iron", 3.0)
	state.stock.add("silicon", 1.0)
	state.stock.add("module_part", 2.0)
	state.queue_item("factory", "module_part")
	state.queue_item("assembly", "junction")
	_steps(10)
	assert_eq(state.stock.amount("iron"), 3.0)
	assert_eq(state.stock.amount("silicon"), 1.0)
	assert_eq(state.assembled.get("junction", 0), 1)
	assert_eq(state.production.queues["factory"].size(), 1)


func test_assembly_builds_module_for_placing() -> void:
	state.stock.add("module_part", 12.0)
	state.stock.add("platinum", 2.0)
	state.queue_item("assembly", "electrolysis_plant")
	_steps(50)
	assert_eq(state.assembled["electrolysis_plant"], 1)
	assert_true(state.can_place("electrolysis_plant"))


func test_battery_halves_speed() -> void:
	state.stock.add("iron", 3.0)
	state.stock.add("aluminum", 1.0)
	state.stock.add("silicon", 1.0)
	state.queue_item("factory", "module_part")
	for i in 7:
		var job := state.production.work("factory", 0.5, state.stock)
		assert_true(job.is_empty())
	assert_eq(state.production.work("factory", 0.5, state.stock)["item"], "module_part")


func test_zero_speed_does_not_start_job() -> void:
	state.stock.add("iron", 3.0)
	state.stock.add("aluminum", 1.0)
	state.stock.add("silicon", 1.0)
	state.queue_item("factory", "module_part")
	state.production.work("factory", 0.0, state.stock)
	assert_eq(state.stock.amount("iron"), 3.0)


func test_new_ship_and_robot_join() -> void:
	state.stock.add("module_part", 8.0)
	state.stock.add("magnesium", 4.0)
	state.stock.add("silicon", 4.0)
	state.queue_item("assembly", "mining_ship")
	state.queue_item("assembly", "robot")
	_steps(40)
	assert_eq(state.fleet.ships.size(), 5)
	assert_eq(state.robots, 20)
	_steps(16)
	assert_eq(state.robots, 21)


func test_repair_jumps_queue() -> void:
	state.stock.add("module_part", 7.0)
	state.queue_item("assembly", "habitat")
	state.queue_item("assembly", "gas_storage")
	_steps(5)
	var docked: MiningShip = null
	for each_ship in state.fleet.ships:
		if each_ship.state == "docked":
			docked = each_ship
	assert_not_null(docked)
	docked.condition = 0.5
	state.request_repair(docked.id)
	state.step()
	assert_eq(state.production.current["assembly"]["item"], "ship_repair")
	assert_eq(state.production.queues["assembly"], ["habitat", "gas_storage"])
	_steps(10)
	assert_eq(docked.condition, 1.0)
	assert_false(docked.repair_requested)


func test_repair_not_queued_twice() -> void:
	state.stock.items.erase("module_part")
	var docked: MiningShip = state.fleet.ships[0]
	docked.state = "docked"
	docked.bay = 0
	docked.repair_requested = true
	_steps(3)
	var repairs := 0
	for entry in state.production.queues["assembly"]:
		if entry.begins_with("ship_repair:"):
			repairs += 1
	assert_eq(repairs, 1)


func test_repairs_stay_in_order_requested() -> void:
	state.production.queues["assembly"].append("habitat")
	state.production.add_repair(2)
	state.production.add_repair(1)
	assert_eq(state.production.queues["assembly"], ["ship_repair:2", "ship_repair:1", "habitat"])


func test_queue_refusals() -> void:
	assert_eq(state.queue_item("factory", "habitat"), "Factory can't make that")
	assert_eq(state.queue_item("assembly", "module_part"), "Assembly can't make that")
	assert_eq(state.queue_item("assembly", "ship_repair"), "Assembly can't make that")
	assert_eq(state.queue_item("refinery", "iron"), "No such building")


func test_remove_queued() -> void:
	state.queue_item("factory", "frame_piece")
	state.queue_item("factory", "module_part")
	state.remove_queued("factory", 0)
	assert_eq(state.production.queues["factory"], ["module_part"])
	state.remove_queued("factory", 5)
	state.remove_queued("factory", -1)
	assert_eq(state.production.queues["factory"].size(), 1)


func test_repair_entry_cannot_be_removed() -> void:
	state.production.add_repair(0)
	state.remove_queued("assembly", 0)
	assert_eq(state.production.queues["assembly"].size(), 1)


func test_blocked_first_item_is_not_skipped() -> void:
	state.stock.add("iron", 7.0)
	state.stock.add("nickel", 1.0)
	state.stock.add("silicon", 1.0)
	state.queue_item("factory", "module_part")
	state.queue_item("factory", "frame_piece")
	var frames_before := state.stock.amount("frame_piece")
	_steps(10)
	assert_eq(state.stock.amount("iron"), 7.0)
	assert_eq(state.stock.amount("nickel"), 1.0)
	assert_eq(state.stock.amount("silicon"), 1.0)
	assert_true(state.production.current["factory"].is_empty())
	assert_eq(state.production.queues["factory"], ["module_part", "frame_piece"])
	assert_eq(state.stock.amount("frame_piece"), frames_before)
