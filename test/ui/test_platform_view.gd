extends GutTest

const PlatformView = preload("res://game/view/platform_view.gd")
const Helpers = preload("res://test/sim/helpers.gd")


func test_all_bases_and_bundles_present_at_the_start() -> void:
	var state := Helpers.new_state()
	assert_eq(PlatformView.bases_present(state), [true, true, true, true])
	assert_eq(PlatformView.frame_bundles_present(state), 8)


func test_a_base_is_gone_once_its_kit_is_placed() -> void:
	var state := Helpers.new_state()
	assert_eq(state.place_first("command", Vector2.ZERO), "")
	assert_eq(PlatformView.bases_present(state), [false, true, true, true])
	assert_eq(state.place(0, 1, 2, "gas_storage"), "")
	assert_eq(state.place(0, 0, 2, "fusion_generator"), "")
	assert_eq(state.place(0, 3, 2, "metal_storage"), "")
	assert_eq(PlatformView.bases_present(state), [false, false, false, false])


func test_other_kits_do_not_remove_bases() -> void:
	var state := Helpers.new_state()
	state.place_first("command", Vector2.ZERO)
	state.place(0, 2, 3, "ship_dock")
	assert_eq(PlatformView.bases_present(state), [false, true, true, true])


func test_bundles_round_up_while_a_bundle_is_partly_used() -> void:
	var state := Helpers.new_state()
	state.place_first("command", Vector2.ZERO)
	assert_eq(state.place(0, 0, 2, "fusion_generator"), "")
	assert_eq(PlatformView.frame_bundles_present(state), 8)
	assert_eq(state.place(0, 1, 3, "gas_storage"), "")
	assert_eq(PlatformView.frame_bundles_present(state), 7)


func test_bundles_follow_the_frame_pieces_used_by_the_starter_layout() -> void:
	var state := Helpers.new_state()
	Helpers.place_starter(state)
	assert_eq(state.layout.frame_piece_count(false), 15)
	assert_eq(PlatformView.frame_bundles_present(state), 5)


func test_no_bundles_are_left_once_the_ships_pieces_are_all_used() -> void:
	var state := Helpers.new_state()
	state.balance["start"]["frame_pieces"] = 10
	Helpers.place_starter(state)
	assert_eq(PlatformView.frame_bundles_present(state), 0)
