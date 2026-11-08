extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")


func _built_starter() -> Array:
	var state := Helpers.new_state()
	var ids := Helpers.place_starter(state)
	Helpers.finish_construction(state)
	state.step()
	return [state, ids]


func _alert_ids(state: GameState) -> Array:
	var ids := []
	for alert in Advisor.alerts(state):
		ids.append(alert["id"])
	return ids


func _alert_text(state: GameState, id: String) -> String:
	for alert in Advisor.alerts(state):
		if alert["id"] == id:
			return alert["text"]
	return ""


func test_no_alerts_on_fresh_starter() -> void:
	var state: GameState = _built_starter()[0]
	state.comets.passes.clear()
	assert_eq(_alert_ids(state), [])


func test_storage_full_raises_and_clears() -> void:
	var state: GameState = _built_starter()[0]
	state.storage.add("hydrogen", 1000.0)
	assert_true(_alert_ids(state).has("storage_full"))
	assert_eq(_alert_text(state, "storage_full"), "Storage is full")
	state.storage.take("hydrogen", 1000.0)
	assert_false(_alert_ids(state).has("storage_full"))


func test_storage_full_ignored_without_storage_module() -> void:
	var state := Helpers.new_state()
	assert_false(_alert_ids(state).has("storage_full"))


func test_ships_waiting_raises_and_clears() -> void:
	var state: GameState = _built_starter()[0]
	state.fleet.ships[0].state = "docked"
	state.fleet.ships[0].waiting_for_room = true
	assert_eq(_alert_text(state, "ships_waiting"), "1 ship waiting to unload")
	state.fleet.ships[1].state = "docked"
	state.fleet.ships[1].waiting_for_room = true
	assert_eq(_alert_text(state, "ships_waiting"), "2 ships waiting to unload")
	state.fleet.ships[0].waiting_for_room = false
	state.fleet.ships[1].waiting_for_room = false
	assert_false(_alert_ids(state).has("ships_waiting"))


func test_power_short_raises_and_clears() -> void:
	var state: GameState = _built_starter()[0]
	state.power.short = true
	assert_eq(_alert_text(state, "power_short"), "Not enough power")
	state.power.short = false
	assert_false(_alert_ids(state).has("power_short"))


func test_comet_forecast_raises_and_clears() -> void:
	var state: GameState = _built_starter()[0]
	state.comets.passes = [{"arrives": state.hour + 100, "leaves": state.hour + 300, "distance": 1.0}]
	assert_eq(_alert_text(state, "comet_forecast"), "Comet arrives in 100 hours")
	assert_false(_alert_ids(state).has("comet_in_reach"))
	state.comets.passes.clear()
	assert_false(_alert_ids(state).has("comet_forecast"))


func test_comet_in_reach_replaces_forecast() -> void:
	var state: GameState = _built_starter()[0]
	state.comets.passes = [{"arrives": state.hour - 10, "leaves": state.hour + 50, "distance": 1.0}]
	assert_eq(_alert_text(state, "comet_in_reach"), "Comet in reach for 50 hours")
	assert_false(_alert_ids(state).has("comet_forecast"))
	state.hour += 50
	assert_false(_alert_ids(state).has("comet_in_reach"))


func test_reserve_low_raises_and_clears() -> void:
	var state: GameState = _built_starter()[0]
	state.crew = 12
	state.life.dependent = 12
	state.life.reserve = 12.0 * 199.5
	assert_eq(_alert_text(state, "reserve_low"), "Ship's reserve: 199 hours left")
	state.life.reserve = 12.0 * 200.0
	assert_false(_alert_ids(state).has("reserve_low"))
	state.life.reserve = 12.0 * 10.0
	state.life.dependent = 0
	assert_false(_alert_ids(state).has("reserve_low"))


func test_fuel_low_raises_and_clears() -> void:
	var state: GameState = _built_starter()[0]
	state.power.fuel_core_mwh = 10.0
	assert_true(state.power.fuel_hours_left(state.storage) < 200.0)
	assert_true(_alert_text(state, "fuel_low").begins_with("Fuel: "))
	assert_true(_alert_text(state, "fuel_low").ends_with(" hours left"))
	state.power.fuel_core_mwh = 1000000.0
	assert_false(_alert_ids(state).has("fuel_low"))


func test_fuel_low_needs_a_generator() -> void:
	var state := Helpers.new_state()
	state.place_first("command", Vector2.ZERO)
	Helpers.finish_construction(state)
	state.step()
	state.power.fuel_core_mwh = 0.0
	assert_false(_alert_ids(state).has("fuel_low"))


func test_no_operator_raises_and_clears() -> void:
	var state: GameState = _built_starter()[0]
	state.crew = 4
	state.step()
	assert_eq(_alert_text(state, "no_operator"), "1 module has no operator")
	state.crew = 3
	state.step()
	assert_eq(_alert_text(state, "no_operator"), "2 modules have no operator")
	state.crew = 12
	state.step()
	assert_false(_alert_ids(state).has("no_operator"))


func test_alert_order() -> void:
	var state: GameState = _built_starter()[0]
	state.storage.add("hydrogen", 1000.0)
	state.power.short = true
	state.comets.passes = [{"arrives": state.hour - 1, "leaves": state.hour + 5, "distance": 1.0}]
	assert_eq(_alert_ids(state), ["storage_full", "power_short", "comet_in_reach"])


func test_checklist_order_and_done() -> void:
	var state := Helpers.new_state()
	Helpers.place_starter(state)
	var items := Advisor.checklist(state)
	var item_ids := []
	for item in items:
		item_ids.append(item["id"])
	assert_eq(item_ids, ["core", "metals", "industry", "plant", "ice", "habitat"])
	assert_eq(items[0]["text"], "Set up the dock, storage and generator")
	assert_eq(items[5]["text"], "Build a habitat")
	for item in items:
		assert_false(item["done"])
	Helpers.finish_construction(state)
	items = Advisor.checklist(state)
	assert_true(items[0]["done"])
	assert_false(items[1]["done"])
	assert_true(items[2]["done"])
	assert_eq(state.assign_ship(0, "asteroids", ["iron"]), "")
	assert_true(Advisor.checklist(state)[1]["done"])
	assert_false(Advisor.checklist(state)[3]["done"])
	state.ice_delivered = true
	assert_true(Advisor.checklist(state)[4]["done"])


func test_metals_done_by_next_assignment_and_not_by_nebula() -> void:
	var state := Helpers.new_state()
	state.assign_ship(0, "nebula", ["hydrogen"])
	assert_false(Advisor.checklist(state)[1]["done"])
	state.fleet.ships[1].state = "outbound"
	state.assign_ship(1, "asteroids", ["iron"])
	assert_false(state.fleet.ships[1].next_assignment.is_empty())
	assert_true(Advisor.checklist(state)[1]["done"])


func test_core_needs_all_four_modules() -> void:
	var state := Helpers.new_state()
	state.place_first("command", Vector2.ZERO)
	state.place(0, 2, 3, "ship_dock")
	Helpers.finish_construction(state)
	assert_false(Advisor.checklist(state)[0]["done"])
