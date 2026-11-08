class_name Stock
extends RefCounted

const TOLERANCE := 0.0001

var items: Dictionary = {}


func amount(key: String) -> float:
	return items.get(key, 0.0)


func add(key: String, units: float) -> void:
	items[key] = amount(key) + units


func has_all(needs: Dictionary) -> bool:
	for key in needs:
		if amount(key) < needs[key] - TOLERANCE:
			return false
	return true


func take_all(needs: Dictionary) -> bool:
	if not has_all(needs):
		return false
	for key in needs:
		items[key] = maxf(amount(key) - needs[key], 0.0)
	return true
