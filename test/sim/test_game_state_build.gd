extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")

var state: GameState


func before_each() -> void:
	state = Helpers.new_state()


func test_starts_with_kits_and_frame() -> void:
	var kit_total := 0
	for kind in state.kits:
		kit_total += state.kits[kind]
	assert_eq(kit_total, 8)
	assert_eq(state.stock.amount("frame_piece"), 32.0)
	assert_eq(state.crew, 12)
	assert_eq(state.robots, 20)
	assert_eq(state.hour, 0)
	assert_eq(state.outcome, "")


func test_place_takes_kit_and_frame_pieces() -> void:
	assert_eq(state.place_first("command", Vector2.ZERO), "")
	assert_eq(state.place(0, 0, 2, "fusion_generator"), "")
	assert_eq(state.kits["fusion_generator"], 0)
	assert_eq(state.stock.amount("frame_piece"), 30.0)
	assert_eq(state.construction.sites.size(), 2)


func test_place_refused_without_kit() -> void:
	state.place_first("command", Vector2.ZERO)
	assert_eq(state.place(0, 0, 2, "habitat"), "No habitat to place")
	assert_eq(state.stock.amount("frame_piece"), 32.0)


func test_place_refused_without_frame_pieces() -> void:
	state.place_first("command", Vector2.ZERO)
	state.stock.items["frame_piece"] = 1.0
	assert_eq(state.place(0, 0, 2, "fusion_generator"), "Not enough frame pieces")
	assert_eq(state.kits["fusion_generator"], 1)
	assert_eq(state.stock.amount("frame_piece"), 1.0)
	assert_eq(state.layout.nodes.size(), 1)


func test_layout_reason_comes_first() -> void:
	state.place_first("command", Vector2.ZERO)
	assert_eq(state.place(0, 0, 9, "habitat"), "The frame can only run 1 to 3 pieces")


func test_place_first_refused_far_from_ship() -> void:
	assert_ne(state.place_first("command", Vector2(5000, 0)), "")
	assert_eq(state.kits["command"], 1)
	assert_eq(state.layout.nodes.size(), 0)


func test_place_first_refused_without_kit() -> void:
	assert_eq(state.place_first("habitat", Vector2.ZERO), "No habitat to place")
	assert_eq(state.layout.nodes.size(), 0)


func test_assembled_module_used_when_no_kit() -> void:
	state.place_first("command", Vector2.ZERO)
	state.kits["fusion_generator"] = 0
	state.assembled["fusion_generator"] = 1
	assert_true(state.can_place("fusion_generator"))
	assert_eq(state.place(0, 0, 2, "fusion_generator"), "")
	assert_eq(state.assembled["fusion_generator"], 0)
	assert_eq(state.construction.progress(1), 0.0)
	state.construction.step(20)
	assert_eq(state.construction.progress(1), 4.0 / 96.0)


func test_kit_used_before_assembled() -> void:
	state.place_first("command", Vector2.ZERO)
	state.assembled["fusion_generator"] = 1
	state.place(0, 0, 2, "fusion_generator")
	assert_eq(state.kits["fusion_generator"], 0)
	assert_eq(state.assembled["fusion_generator"], 1)


func test_junction_needs_assembled_junction() -> void:
	state.place_first("command", Vector2.ZERO)
	assert_false(state.can_place("junction"))
	assert_eq(state.place(0, 0, 2, "junction"), "No junction to place")
	state.assembled["junction"] = 1
	assert_true(state.can_place("junction"))
	assert_eq(state.place(0, 0, 2, "junction"), "")
	state.construction.step(20)
	assert_eq(state.construction.progress(1), 4.0 / 32.0)


func test_starter_platform_builds() -> void:
	Helpers.place_starter(state)
	Helpers.finish_construction(state)
	assert_eq(state.layout.built_nodes().size(), 8)
	assert_eq(state.storage.capacity("hydrogen"), 60.0)
	assert_eq(state.storage.capacity("iron"), 30.0)
	assert_eq(state.stock.amount("frame_piece"), 17.0)


func test_kit_work_includes_frame() -> void:
	state.place_first("command", Vector2.ZERO)
	state.place(0, 0, 2, "fusion_generator")
	state.construction.step(20)
	assert_eq(state.construction.progress(1), 4.0 / 136.0)


func test_is_running_is_built_for_now() -> void:
	state.place_first("command", Vector2.ZERO)
	assert_false(state.is_running(0))
	Helpers.finish_construction(state)
	assert_true(state.is_running(0))


func test_step_advances_hour() -> void:
	state.step()
	assert_eq(state.hour, 1)


func test_no_steps_after_outcome() -> void:
	state.end_run()
	state.step()
	assert_eq(state.hour, 0)
	assert_eq(state.outcome, "ended")


func test_dock_first_then_one_module_from_it() -> void:
	state.hour = 3
	assert_eq(state.place_first("ship_dock", Vector2(-200, 0)), "")
	assert_eq(state.place(0, 0, 3, "metal_storage"), "")
	assert_eq(state.place(0, 1, 3, "gas_storage"), "The dock can only join one module")


func test_dock_placed_from_a_module_is_still_refused() -> void:
	state.place_first("command", Vector2.ZERO)
	state.place(0, 0, 3, "ship_dock")
	var dock_id := state.layout.nodes.size() - 1
	assert_eq(state.place(dock_id, 0, 3, "refinery"), "The dock can only join one module")
