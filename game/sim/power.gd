class_name Power
extends RefCounted

var fuel_core_mwh: float
var battery_hours_left: float
var supply_mw := 0.0
var demand_mw := 0.0
var short := false
var on_battery := false
var operated: Dictionary = {}
var powered: Dictionary = {}
var _modules: Dictionary
var _power: Dictionary
var _arrival_ship_mw: float


func _init(balance: Dictionary) -> void:
	_modules = balance["modules"]
	_power = balance["power"]
	_arrival_ship_mw = float(balance["arrival_ship"]["power_mw"])
	fuel_core_mwh = float(_power["fuel_core_mwh"])
	battery_hours_left = float(_power["battery_hours"])


func step(layout: PlatformLayout, storage: Storage, crew: int) -> String:
	short = false
	on_battery = false
	_assign_operators(layout, crew)
	var candidates := _candidates(layout)
	demand_mw = _demand_of(candidates, layout)
	var generators := layout.built_nodes("fusion_generator").size()
	supply_mw = _supply(generators, storage)
	powered.clear()
	if generators > 0 and supply_mw == 0.0:
		return _run_on_battery(candidates)
	battery_hours_left = float(_power["battery_hours"])
	if supply_mw >= demand_mw:
		_power_all(candidates)
		if generators > 0:
			_burn_fuel(storage, demand_mw)
	else:
		var reduced_demand := _shut_down_until_fits(candidates)
		if generators > 0:
			_burn_fuel(storage, reduced_demand)
	return ""


func fuel_hours_left(storage: Storage) -> float:
	if demand_mw <= 0.0:
		return INF
	var hydrogen_mwh := storage.amount("hydrogen") * float(_power["mwh_per_hydrogen"])
	return (fuel_core_mwh + hydrogen_mwh) / demand_mw


func _assign_operators(layout: PlatformLayout, crew: int) -> void:
	operated.clear()
	var crewed: Array[PlatformNode] = []
	for built in layout.built_nodes():
		if _modules[built.kind]["crewed"]:
			crewed.append(built)
	crewed.sort_custom(_before_in_priority)
	for index in crewed.size():
		operated[crewed[index].id] = index < crew


func _before_in_priority(a: PlatformNode, b: PlatformNode) -> bool:
	var priority: Array = _power["operator_priority"]
	var rank_a := priority.find(a.kind)
	var rank_b := priority.find(b.kind)
	if rank_a != rank_b:
		return rank_a < rank_b
	return a.id < b.id


func _candidates(layout: PlatformLayout) -> Array[PlatformNode]:
	var result: Array[PlatformNode] = []
	for built in layout.built_nodes():
		if not _modules[built.kind]["crewed"] or operated[built.id]:
			result.append(built)
	return result


func _demand_of(candidates: Array[PlatformNode], layout: PlatformLayout) -> float:
	var total := float(_power["frame_piece_mw"]) * layout.frame_piece_count(true)
	for candidate in candidates:
		total += float(_modules[candidate.kind]["power_mw"])
	return total


func _supply(generators: int, storage: Storage) -> float:
	if generators == 0:
		return _arrival_ship_mw
	if fuel_core_mwh > 0.0 or storage.amount("hydrogen") > 0.0:
		return float(_power["generator_mw"]) * generators
	return 0.0


func _power_all(candidates: Array[PlatformNode]) -> void:
	for candidate in candidates:
		powered[candidate.id] = true


func _burn_fuel(storage: Storage, energy_mwh: float) -> void:
	var from_core := minf(energy_mwh, fuel_core_mwh)
	fuel_core_mwh -= from_core
	var remainder := energy_mwh - from_core
	storage.take("hydrogen", remainder / float(_power["mwh_per_hydrogen"]))


func _shut_down_until_fits(candidates: Array[PlatformNode]) -> float:
	short = true
	_power_all(candidates)
	var remaining := demand_mw
	for kind in _power["shutdown_order"]:
		for candidate in candidates:
			if remaining <= supply_mw:
				return remaining
			if candidate.kind == kind and powered[candidate.id]:
				powered[candidate.id] = false
				remaining -= float(_modules[kind]["power_mw"])
	return remaining


func _run_on_battery(candidates: Array[PlatformNode]) -> String:
	on_battery = true
	_power_all(candidates)
	battery_hours_left -= 1.0
	if battery_hours_left <= 0.0:
		return "energy"
	return ""
