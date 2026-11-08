extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")


func test_checklist_order_run_steps_without_errors() -> void:
	var state := Helpers.new_state()
	assert_eq(state.place_first("ship_dock", Vector2(-200, 0)), "")
	assert_eq(state.place(0, 0, 3, "metal_storage"), "")
	assert_eq(state.place(1, 0, 2, "gas_storage"), "")
	assert_eq(state.place(1, 1, 2, "fusion_generator"), "")
	assert_eq(state.place(1, 3, 2, "command"), "")
	assert_eq(state.place(3, 0, 2, "refinery"), "")
	assert_eq(state.place(2, 0, 2, "factory"), "")
	assert_eq(state.place(3, 1, 2, "assembly"), "")
	assert_eq(state.assign_ship(0, "asteroids", ["iron", "aluminum"]), "")
	assert_eq(state.assign_ship(1, "asteroids", ["silicon", "platinum"]), "")
	assert_eq(state.assign_ship(2, "nebula", ["hydrogen"]), "")
	assert_eq(state.assign_ship(3, "nebula", ["nitrogen", "argon"]), "")
	assert_eq(state.queue_item("factory", "module_part"), "")
	assert_eq(state.queue_item("assembly", "electrolysis_plant"), "")
	for i in 400:
		state.step()
	assert_eq(state.outcome, "")
	assert_eq(state.layout.built_nodes().size(), 8)
