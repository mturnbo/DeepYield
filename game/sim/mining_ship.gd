class_name MiningShip
extends RefCounted

var id: int
var state := "in_cargo"
var hours_left := 0
var hours_total := 0
var destination := ""
var bay := -1
var condition := 1.0
var assignment: Dictionary = {}
var next_assignment: Dictionary = {}
var trip_materials: Array = []
var cargo: Dictionary = {}
var repair_requested := false
var waiting_for_room := false
var docked_hours := 0


func _init(ship_id: int) -> void:
	id = ship_id


func load_for(materials: Array, mining_balance: Dictionary) -> Dictionary:
	var total := int(floor(float(mining_balance["load"]) * condition))
	var caps: Dictionary = mining_balance["caps"]
	var share := total / materials.size()
	var result := {}
	var left := total
	var uncapped: Array = []
	for material in materials:
		if caps.has(material):
			result[material] = mini(int(caps[material]), share)
			left -= result[material]
		else:
			uncapped.append(material)
	if uncapped.is_empty():
		return result
	var base := left / uncapped.size()
	var extra := left % uncapped.size()
	for index in uncapped.size():
		result[uncapped[index]] = base + (1 if index < extra else 0)
	return result


func travel_hours(base: int, mining_balance: Dictionary) -> int:
	var slowdown := (1.0 - condition) * float(mining_balance["max_slowdown"])
	return ceili(base * (1.0 + slowdown))
