extends GutTest

const FleetView = preload("res://game/view/fleet_view.gd")


func _ship(id: int, state: String, bay := -1, hours_left := 0, hours_total := 0, docked_hours := 0) -> MiningShip:
	var ship := MiningShip.new(id)
	ship.state = state
	ship.bay = bay
	ship.hours_left = hours_left
	ship.hours_total = hours_total
	ship.docked_hours = docked_hours
	return ship


func test_leg_progress_counts_the_departure_hour() -> void:
	assert_almost_eq(FleetView.leg_progress(10, 9, 0.0), 0.1, 0.0001)
	assert_almost_eq(FleetView.leg_progress(10, 5, 0.5), 0.55, 0.0001)


func test_leg_progress_clamps_to_zero_and_one() -> void:
	assert_eq(FleetView.leg_progress(10, 0, 0.5), 1.0)
	assert_eq(FleetView.leg_progress(10, 10, 0.0), 0.0)
	assert_eq(FleetView.leg_progress(0, 0, 0.0), 1.0)


func test_leg_fade_is_clear_at_the_ends_and_hidden_in_the_middle() -> void:
	assert_eq(FleetView.leg_fade(0.0), 0.0)
	assert_eq(FleetView.leg_fade(0.2), 0.0)
	assert_eq(FleetView.leg_fade(0.5), 1.0)
	assert_eq(FleetView.leg_fade(0.8), 0.0)
	assert_eq(FleetView.leg_fade(1.0), 0.0)
	assert_between(FleetView.leg_fade(0.25), 0.01, 0.99)


func test_free_bay_is_the_lowest_not_docked() -> void:
	var ships: Array[MiningShip] = [_ship(0, "docked", 0), _ship(1, "docked", 2), _ship(2, "outbound", 1)]
	assert_eq(FleetView.free_bay(ships), 1)


func test_free_bay_is_minus_one_when_all_four_taken() -> void:
	var ships: Array[MiningShip] = []
	for i in 4:
		ships.append(_ship(i, "docked", i))
	assert_eq(FleetView.free_bay(ships), -1)


func test_door_opens_for_a_ship_that_just_arrived() -> void:
	var ships: Array[MiningShip] = [_ship(0, "docked", 2, 0, 0, 1)]
	assert_true(FleetView.door_wanted(ships, {}, 0.0, 2))
	assert_false(FleetView.door_wanted(ships, {}, 0.0, 0))


func test_door_closed_for_a_ship_settled_in_its_bay() -> void:
	var ships: Array[MiningShip] = [_ship(0, "docked", 2, 0, 0, 2)]
	assert_false(FleetView.door_wanted(ships, {}, 0.0, 2))


func test_door_open_while_a_ship_is_leaving_then_closes() -> void:
	var ships: Array[MiningShip] = [_ship(0, "outbound", -1, 9, 10)]
	assert_true(FleetView.door_wanted(ships, {0: 3}, 0.0, 3))
	assert_false(FleetView.door_wanted(ships, {0: 3}, 0.9, 3))
	assert_false(FleetView.door_wanted(ships, {0: 3}, 0.0, 1))


func test_door_opens_for_the_bay_an_inbound_ship_will_take() -> void:
	var ships: Array[MiningShip] = [_ship(0, "docked", 0, 0, 0, 5), _ship(1, "inbound", -1, 1, 6)]
	assert_true(FleetView.door_wanted(ships, {}, 0.0, 1))
	assert_false(FleetView.door_wanted(ships, {}, 0.0, 0))


func test_door_stays_closed_for_an_inbound_ship_still_far_away() -> void:
	var ships: Array[MiningShip] = [_ship(0, "inbound", -1, 3, 6)]
	assert_false(FleetView.door_wanted(ships, {}, 0.0, 0))
