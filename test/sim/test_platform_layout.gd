extends GutTest

var layout: PlatformLayout


func before_each() -> void:
	layout = PlatformLayout.new(Balance.load_default()["layout"])
	layout.add_first("command", Vector2(0, 0))


func test_new_center_module_to_module() -> void:
	assert_eq(layout.new_center(0, 0, 2, "fusion_generator"), Vector2(60, 0))
	assert_eq(layout.new_center(0, 1, 3, "ship_dock"), Vector2(0, 75))
	assert_eq(layout.new_center(0, 2, 1, "junction"), Vector2(-35, 0))


func test_run_limits() -> void:
	assert_eq(layout.check_placement(0, 0, 0, "junction"), "The frame can only run 1 to 3 pieces")
	assert_eq(layout.check_placement(0, 0, 4, "junction"), "The frame can only run 1 to 3 pieces")


func test_modules_need_two_pieces() -> void:
	assert_eq(layout.check_placement(0, 0, 1, "fusion_generator"), "Too close to the command")
	assert_eq(layout.check_placement(0, 0, 2, "fusion_generator"), "")


func test_dock_needs_three_pieces() -> void:
	assert_eq(layout.check_placement(0, 0, 2, "ship_dock"), "Too close to the command")
	assert_eq(layout.check_placement(0, 0, 3, "ship_dock"), "")


func test_spacing_checks_every_module_not_just_neighbor() -> void:
	layout.add(0, 1, 2, "gas_storage")
	var junction := layout.add(0, 0, 1, "junction")
	assert_eq(junction.center, Vector2(35, 0))
	assert_eq(layout.new_center(junction.id, 1, 2, "metal_storage"), Vector2(35, 50))
	assert_eq(layout.check_placement(junction.id, 1, 2, "metal_storage"), "Too close to the gas storage")


func test_dock_joins_only_one_module() -> void:
	assert_eq(layout.check_placement(0, 0, 3, "ship_dock"), "")
	var dock := layout.add(0, 0, 3, "ship_dock")
	assert_eq(layout.check_placement(dock.id, 0, 3, "refinery"), "The dock can only join one module")
	assert_eq(layout.check_placement(dock.id, 1, 1, "junction"), "The dock can only join one module")


func test_unlinked_dock_can_start_the_platform() -> void:
	var first := PlatformLayout.new(Balance.load_default()["layout"])
	var dock := first.add_first("ship_dock", Vector2(-200, 0))
	assert_eq(first.check_placement(dock.id, 0, 3, "metal_storage"), "")
	first.add(dock.id, 0, 3, "metal_storage")
	assert_eq(first.check_placement(dock.id, 1, 3, "refinery"), "The dock can only join one module")


func test_used_port_refused() -> void:
	layout.add(0, 0, 2, "fusion_generator")
	assert_eq(layout.check_placement(0, 0, 3, "refinery"), "That port is already used")


func test_add_links_both_ways() -> void:
	var generator := layout.add(0, 0, 2, "fusion_generator")
	assert_eq(layout.node(0).links[0], generator.id)
	assert_eq(generator.links[2], 0)
	assert_eq(generator.run, 2)
	assert_false(generator.built)


func test_overlap_with_existing_module_refused() -> void:
	layout.add(0, 0, 3, "junction")
	layout.add(1, 3, 3, "junction")
	var north := layout.add(0, 3, 3, "junction")
	assert_eq(north.center, Vector2(0, -65))
	assert_eq(layout.new_center(north.id, 0, 3, "refinery"), Vector2(65, -65))
	assert_eq(layout.check_placement(north.id, 0, 3, "refinery"), "Overlaps the frame or a module")


func test_overlap_with_existing_run_refused() -> void:
	layout.add(0, 0, 3, "junction")
	layout.add(1, 3, 3, "junction")
	var near := layout.add(0, 3, 1, "junction")
	assert_eq(near.center, Vector2(0, -35))
	assert_eq(layout.new_center(near.id, 0, 3, "refinery"), Vector2(65, -35))
	assert_eq(layout.check_placement(near.id, 0, 3, "refinery"), "Overlaps the frame or a module")


func test_outside_build_area() -> void:
	var last := 0
	var placed := 0
	while layout.check_placement(last, 0, 3, "junction") == "" and placed < 30:
		last = layout.add(last, 0, 3, "junction").id
		placed += 1
	assert_eq(layout.check_placement(last, 0, 3, "junction"), "Outside the build area")
	assert_lt(layout.node(last).center.x + 5.0, 600.0001)
	assert_gt(placed, 5)


func test_first_node_too_far() -> void:
	var ship := Vector2(-260, 0)
	assert_eq(layout.check_first("command", Vector2(100, 0), ship), "Too far from the arrival ship")
	assert_eq(layout.check_first("command", Vector2(0, 0), ship), "")


func test_frame_piece_count() -> void:
	var first := layout.add(0, 0, 2, "fusion_generator")
	layout.add(0, 1, 3, "ship_dock")
	assert_eq(layout.frame_piece_count(false), 5)
	assert_eq(layout.frame_piece_count(true), 0)
	first.built = true
	assert_eq(layout.frame_piece_count(true), 2)


func test_built_nodes_filters_by_kind() -> void:
	var generator := layout.add(0, 0, 2, "fusion_generator")
	assert_eq(layout.built_nodes().size(), 0)
	layout.node(0).built = true
	generator.built = true
	assert_eq(layout.built_nodes().size(), 2)
	assert_eq(layout.built_nodes("command").size(), 1)
