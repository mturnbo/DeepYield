class_name Advisor
extends RefCounted


static func alerts(state: GameState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _storage_full(state):
		result.append({"id": "storage_full", "text": "Storage is full"})
	var waiting := state.fleet.waiting_count()
	if waiting > 0:
		var ships_text := "1 ship waiting to unload" if waiting == 1 else "%d ships waiting to unload" % waiting
		result.append({"id": "ships_waiting", "text": ships_text})
	if state.power.short:
		result.append({"id": "power_short", "text": "Not enough power"})
	_add_comet_alert(state, result)
	var thresholds: Dictionary = state.balance["alerts"]
	if state.life.dependent > 0 and state.life.reserve_hours(state.crew) < float(thresholds["reserve_low_hours"]):
		var reserve_hours := int(floor(state.life.reserve_hours(state.crew)))
		result.append({"id": "reserve_low", "text": "Ship's reserve: %d hours left" % reserve_hours})
	if not state.layout.built_nodes("fusion_generator").is_empty():
		var fuel_hours := state.power.fuel_hours_left(state.storage)
		if fuel_hours < float(thresholds["fuel_low_hours"]):
			result.append({"id": "fuel_low", "text": "Fuel: %d hours left" % int(floor(fuel_hours))})
	var unoperated := _unoperated_count(state)
	if unoperated > 0:
		var modules_text := "1 module has no operator" if unoperated == 1 else "%d modules have no operator" % unoperated
		result.append({"id": "no_operator", "text": modules_text})
	return result


static func checklist(state: GameState) -> Array[Dictionary]:
	var core := _all_built(state, ["ship_dock", "gas_storage", "metal_storage", "fusion_generator"])
	var industry := _all_built(state, ["refinery", "factory", "assembly"])
	var plant := _all_built(state, ["electrolysis_plant"])
	var habitat := _all_built(state, ["habitat"])
	var result: Array[Dictionary] = []
	result.append({"id": "core", "text": "Set up the dock, storage and generator", "done": core})
	result.append({"id": "metals", "text": "Send ships to mine metals", "done": _any_ship_mines_asteroids(state)})
	result.append({"id": "industry", "text": "Set up the refinery, factory and assembly", "done": industry})
	result.append({"id": "plant", "text": "Build an electrolysis plant", "done": plant})
	result.append({"id": "ice", "text": "Fetch comet ice", "done": state.ice_delivered})
	result.append({"id": "habitat", "text": "Build a habitat", "done": habitat})
	return result


static func _storage_full(state: GameState) -> bool:
	var containers: Dictionary = state.balance["storage"]
	for container in containers:
		for material in containers[container]:
			if state.storage.capacity(material) > 0.0 and state.storage.is_full(material):
				return true
	return false


static func _add_comet_alert(state: GameState, result: Array[Dictionary]) -> void:
	var in_reach := state.comets.current(state.hour)
	if in_reach != -1:
		var hours_left := int(floor(state.comets.passes[in_reach]["leaves"] - state.hour))
		result.append({"id": "comet_in_reach", "text": "Comet in reach for %d hours" % hours_left})
		return
	var next := state.comets.next_forecast(state.hour)
	if next != -1:
		var hours_until := int(floor(state.comets.passes[next]["arrives"] - state.hour))
		result.append({"id": "comet_forecast", "text": "Comet arrives in %d hours" % hours_until})


static func _unoperated_count(state: GameState) -> int:
	var count := 0
	for built in state.layout.built_nodes():
		if state.balance["modules"][built.kind]["crewed"] and not state.power.operated.get(built.id, false):
			count += 1
	return count


static func _all_built(state: GameState, kinds: Array) -> bool:
	for kind in kinds:
		if state.layout.built_nodes(kind).is_empty():
			return false
	return true


static func _any_ship_mines_asteroids(state: GameState) -> bool:
	for each_ship in state.fleet.ships:
		if each_ship.assignment.get("site", "") == "asteroids" or each_ship.next_assignment.get("site", "") == "asteroids":
			return true
	return false
