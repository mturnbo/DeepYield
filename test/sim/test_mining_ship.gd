extends GutTest

var _mining: Dictionary = Balance.load_default()["mining"]


func _load(materials: Array, condition := 1.0) -> Dictionary:
	var ship := MiningShip.new(0)
	ship.condition = condition
	return ship.load_for(materials, _mining)


func test_even_split_three_gases() -> void:
	var cargo := _load(["hydrogen", "helium", "nitrogen"])
	assert_eq(cargo["hydrogen"], 7)
	assert_eq(cargo["helium"], 7)
	assert_eq(cargo["nitrogen"], 6)


func test_cap_fills_with_rest() -> void:
	var cargo := _load(["iron", "platinum"])
	assert_eq(cargo["iron"], 18)
	assert_eq(cargo["platinum"], 2)


func test_argon_alone() -> void:
	assert_eq(_load(["argon"]), {"argon": 1})


func test_argon_with_gases_leaves_rest_to_gases() -> void:
	var cargo := _load(["hydrogen", "helium", "argon"])
	assert_eq(cargo["hydrogen"], 10)
	assert_eq(cargo["helium"], 9)
	assert_eq(cargo["argon"], 1)


func test_all_capped_carries_only_caps() -> void:
	var cargo := _load(["platinum", "palladium"])
	assert_eq(cargo, {"platinum": 2, "palladium": 3})


func test_worn_ship_carries_less() -> void:
	var cargo := _load(["hydrogen"], 0.5)
	assert_eq(cargo["hydrogen"], 10)


func test_worn_ship_is_slower() -> void:
	var ship := MiningShip.new(0)
	ship.condition = 0.0
	assert_eq(ship.travel_hours(18, _mining), 27)


func test_new_ship_travels_base_time() -> void:
	assert_eq(MiningShip.new(0).travel_hours(18, _mining), 18)
