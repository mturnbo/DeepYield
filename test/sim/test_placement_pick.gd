extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")

var state: GameState


func before_each() -> void:
	state = Helpers.new_state()


func _place_command() -> void:
	assert_eq(state.place_first("command", Vector2.ZERO), "")


func test_check_place_first_ok_and_changes_nothing() -> void:
	assert_eq(state.check_place_first("command", Vector2.ZERO), "")
	assert_eq(state.layout.nodes.size(), 0)
	assert_eq(state.kits["command"], 1)


func test_check_place_first_too_far() -> void:
	assert_eq(state.check_place_first("command", Vector2(5000, 0)), "Too far from the arrival ship")


func test_check_place_first_without_kit() -> void:
	assert_eq(state.check_place_first("habitat", Vector2.ZERO), "No habitat to place")


func test_check_place_matches_place_and_changes_nothing() -> void:
	_place_command()
	assert_eq(state.check_place(0, 0, 2, "fusion_generator"), "")
	assert_eq(state.check_place(0, 0, 9, "fusion_generator"), "The frame can only run 1 to 3 pieces")
	assert_eq(state.check_place(0, 0, 2, "habitat"), "No habitat to place")
	assert_eq(state.layout.nodes.size(), 1)
	assert_eq(state.kits["fusion_generator"], 1)
	assert_eq(state.stock.amount("frame_piece"), 32.0)


func test_check_place_without_frame_pieces() -> void:
	_place_command()
	state.stock.items["frame_piece"] = 1.0
	assert_eq(state.check_place(0, 0, 2, "fusion_generator"), "Not enough frame pieces")


func test_pick_first_follows_cursor() -> void:
	var picked := PlacementTool.pick(state, Vector2(-250, 10), 2, "command")
	assert_true(picked["first"])
	assert_eq(picked["center"], Vector2(-250, 10))
	assert_eq(picked["reason"], "")


func test_pick_first_too_far() -> void:
	var picked := PlacementTool.pick(state, Vector2(5000, 0), 2, "command")
	assert_true(picked["first"])
	assert_eq(picked["reason"], "Too far from the arrival ship")


func test_pick_port_follows_cursor_direction() -> void:
	_place_command()
	assert_eq(PlacementTool.pick(state, Vector2(40, 5), 2, "fusion_generator")["port"], 0)
	assert_eq(PlacementTool.pick(state, Vector2(5, 40), 2, "fusion_generator")["port"], 1)
	assert_eq(PlacementTool.pick(state, Vector2(-40, 5), 2, "fusion_generator")["port"], 2)
	assert_eq(PlacementTool.pick(state, Vector2(5, -40), 2, "fusion_generator")["port"], 3)


func test_pick_returns_center_and_ok_reason() -> void:
	_place_command()
	var picked := PlacementTool.pick(state, Vector2(40, 0), 2, "fusion_generator")
	assert_false(picked["first"])
	assert_eq(picked["from_id"], 0)
	assert_eq(picked["run"], 2)
	assert_eq(picked["center"], state.layout.new_center(0, 0, 2, "fusion_generator"))
	assert_eq(picked["reason"], "")


func test_pick_nearest_node() -> void:
	_place_command()
	assert_eq(state.place(0, 0, 2, "fusion_generator"), "")
	var far_east := state.layout.node(1).center + Vector2(0, 30)
	assert_eq(PlacementTool.pick(state, far_east, 2, "refinery")["from_id"], 1)
	assert_eq(PlacementTool.pick(state, Vector2(0, 30), 2, "refinery")["from_id"], 0)


func test_pick_out_of_range() -> void:
	_place_command()
	var picked := PlacementTool.pick(state, Vector2(0, 200), 2, "fusion_generator")
	assert_eq(picked["from_id"], -1)
	assert_eq(picked["reason"], "Point at a module or junction")


func test_pick_range_edge() -> void:
	_place_command()
	assert_eq(PlacementTool.pick(state, Vector2(0, 54), 2, "fusion_generator")["from_id"], 0)
	assert_eq(PlacementTool.pick(state, Vector2(0, 56), 2, "fusion_generator")["from_id"], -1)


func test_pick_used_port() -> void:
	_place_command()
	assert_eq(state.place(0, 0, 2, "fusion_generator"), "")
	var picked := PlacementTool.pick(state, Vector2(20, 0), 2, "refinery")
	assert_eq(picked["from_id"], 0)
	assert_eq(picked["port"], 0)
	assert_eq(picked["reason"], "That port is already used")


func test_pick_dock_run_3_ok_run_2_too_close() -> void:
	_place_command()
	assert_eq(PlacementTool.pick(state, Vector2(-40, 0), 3, "ship_dock")["reason"], "")
	assert_eq(PlacementTool.pick(state, Vector2(-40, 0), 2, "ship_dock")["reason"], "Too close to the command")


func test_pick_without_kit() -> void:
	_place_command()
	var picked := PlacementTool.pick(state, Vector2(40, 0), 2, "habitat")
	assert_eq(picked["reason"], "No habitat to place")
