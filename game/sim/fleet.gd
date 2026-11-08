class_name Fleet
extends RefCounted

var ships: Array[MiningShip] = []
var _mining: Dictionary
var _dock_has_run := false


func _init(balance: Dictionary, count: int) -> void:
	_mining = balance["mining"]
	for index in count:
		add_ship()


func add_ship() -> MiningShip:
	var new_ship := MiningShip.new(ships.size())
	ships.append(new_ship)
	if _dock_has_run:
		_dock_or_hold(new_ship)
	return new_ship


func ship(id: int) -> MiningShip:
	if id < 0 or id >= ships.size():
		return null
	return ships[id]


func waiting_count() -> int:
	var count := 0
	for each_ship in ships:
		if each_ship.state == "docked" and each_ship.waiting_for_room:
			count += 1
	return count


func step(dock_running: bool, storage: Storage, stock: Stock) -> void:
	if dock_running and not _dock_has_run:
		_dock_has_run = true
		for each_ship in ships:
			if each_ship.state == "in_cargo":
				_dock_or_hold(each_ship)
				each_ship.docked_hours = int(_mining["dock_hours"])
	for each_ship in ships:
		_step_ship(each_ship, dock_running, storage, stock)


func _step_ship(ship_now: MiningShip, dock_running: bool, storage: Storage, stock: Stock) -> void:
	match ship_now.state:
		"docked":
			_step_docked(ship_now, storage, stock)
		"holding":
			if dock_running:
				_dock_or_hold(ship_now)
		"outbound", "working", "inbound":
			_step_trip(ship_now, dock_running)


func _step_docked(ship_now: MiningShip, storage: Storage, stock: Stock) -> void:
	ship_now.docked_hours += 1
	_unload(ship_now, storage, stock)
	if not ship_now.cargo.is_empty() or ship_now.repair_requested:
		return
	if ship_now.docked_hours < int(_mining["dock_hours"]):
		return
	if ship_now.assignment.is_empty() and ship_now.next_assignment.is_empty():
		return
	_depart(ship_now)


func _unload(ship_now: MiningShip, storage: Storage, stock: Stock) -> void:
	for material in ship_now.cargo.keys():
		var units: float = ship_now.cargo[material]
		var stored := units
		if material == "argon":
			stock.add(material, units)
		else:
			stored = storage.add(material, units)
		if stored >= units:
			ship_now.cargo.erase(material)
		else:
			ship_now.cargo[material] = units - stored
	ship_now.waiting_for_room = not ship_now.cargo.is_empty()


func _depart(ship_now: MiningShip) -> void:
	if not ship_now.next_assignment.is_empty():
		ship_now.assignment = ship_now.next_assignment
		ship_now.next_assignment = {}
	ship_now.trip_materials = ship_now.assignment["materials"].duplicate()
	ship_now.destination = ship_now.assignment["site"]
	ship_now.bay = -1
	ship_now.waiting_for_room = false
	_start_phase(ship_now, "outbound", ship_now.travel_hours(int(_site_balance(ship_now)["out"]), _mining))
	ship_now.hours_left -= 1


func _step_trip(ship_now: MiningShip, dock_running: bool) -> void:
	ship_now.hours_left -= 1
	if ship_now.hours_left > 0:
		return
	var site := _site_balance(ship_now)
	match ship_now.state:
		"outbound":
			_start_phase(ship_now, "working", int(site["work"]))
		"working":
			ship_now.cargo = ship_now.load_for(ship_now.trip_materials, _mining)
			_start_phase(ship_now, "inbound", ship_now.travel_hours(int(site["back"]), _mining))
		"inbound":
			ship_now.condition = maxf(ship_now.condition - float(site["wear"]), 0.0)
			ship_now.state = "holding"
			if dock_running:
				_dock_or_hold(ship_now)


func _start_phase(ship_now: MiningShip, phase: String, hours: int) -> void:
	ship_now.state = phase
	ship_now.hours_total = hours
	ship_now.hours_left = hours


func _site_balance(ship_now: MiningShip) -> Dictionary:
	return _mining[ship_now.destination]


func _dock_or_hold(ship_now: MiningShip) -> void:
	var free_bay := _free_bay()
	if free_bay == -1:
		ship_now.state = "holding"
		return
	ship_now.state = "docked"
	ship_now.bay = free_bay
	ship_now.docked_hours = 1


func _free_bay() -> int:
	for bay in int(_mining["bays"]):
		if not _bay_taken(bay):
			return bay
	return -1


func _bay_taken(bay: int) -> bool:
	for each_ship in ships:
		if each_ship.state == "docked" and each_ship.bay == bay:
			return true
	return false
