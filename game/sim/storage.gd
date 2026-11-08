class_name Storage
extends RefCounted

var _balance: Dictionary
var _gas_count := 0
var _metal_count := 0
var _amounts: Dictionary = {}


func _init(storage_balance: Dictionary) -> void:
	_balance = storage_balance


func set_modules(gas_count: int, metal_count: int) -> void:
	_gas_count = gas_count
	_metal_count = metal_count


func amount(material: String) -> float:
	return _amounts.get(material, 0.0)


func capacity(material: String) -> float:
	if _balance["gas_storage"].has(material):
		return float(_balance["gas_storage"][material]) * _gas_count
	if _balance["metal_storage"].has(material):
		return float(_balance["metal_storage"][material]) * _metal_count
	return 0.0


func room(material: String) -> float:
	return maxf(capacity(material) - amount(material), 0.0)


func add(material: String, units: float) -> float:
	var stored := minf(units, room(material))
	_amounts[material] = amount(material) + stored
	return stored


func take(material: String, units: float) -> float:
	var taken := minf(units, amount(material))
	_amounts[material] = amount(material) - taken
	return taken


func is_full(material: String) -> bool:
	return room(material) <= 0.0


func most_stored(materials: Array) -> String:
	var best := ""
	var best_amount := 0.0
	for material in materials:
		if amount(material) > best_amount:
			best = material
			best_amount = amount(material)
	return best
