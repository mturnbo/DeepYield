class_name Production
extends RefCounted

const METALS := ["iron", "nickel", "magnesium", "silicon", "aluminum", "platinum", "palladium"]

var queues: Dictionary = {}
var current: Dictionary = {"factory": {}, "assembly": {}}
var _refinery: Dictionary
var _recipes: Dictionary


func _init(balance: Dictionary) -> void:
	_refinery = balance["refinery"]
	_recipes = balance["recipes"]
	var factory_queue: Array[String] = []
	var assembly_queue: Array[String] = []
	queues = {"factory": factory_queue, "assembly": assembly_queue}


func refine(speed: float, storage: Storage, stock: Stock) -> void:
	if speed <= 0.0:
		return
	var metal := storage.most_stored(_refinable_metals(stock))
	if metal == "":
		return
	var units := minf(float(_refinery["rate"]) * speed, storage.amount(metal))
	var argon_every := float(_refinery["argon_every"])
	if _refinery["argon_metals"].has(metal):
		units = minf(units, stock.amount("argon") * argon_every)
		stock.take_all({"argon": units / argon_every})
	stock.add(metal, storage.take(metal, units))


func work(building: String, speed: float, stock: Stock) -> Dictionary:
	if speed <= 0.0:
		return {}
	if current[building].is_empty():
		_try_start(building, stock)
	if current[building].is_empty():
		return {}
	current[building]["hours_left"] -= speed
	if current[building]["hours_left"] > 0.0001:
		return {}
	var finished: Dictionary = current[building]
	current[building] = {}
	return {"item": finished["item"], "ship_id": finished["ship_id"]}


func add_repair(ship_id: int) -> void:
	var index := 0
	while index < queues["assembly"].size() and queues["assembly"][index].begins_with("ship_repair:"):
		index += 1
	queues["assembly"].insert(index, "ship_repair:" + str(ship_id))


func has_repair_for(ship_id: int) -> bool:
	return queues["assembly"].has("ship_repair:" + str(ship_id)) or repair_started(ship_id)


func repair_started(ship_id: int) -> bool:
	return current["assembly"].get("ship_id", -1) == ship_id and current["assembly"].get("item", "") == "ship_repair"


func _refinable_metals(stock: Stock) -> Array:
	if stock.amount("argon") > 0.0:
		return METALS
	var candidates: Array = []
	for metal in METALS:
		if not _refinery["argon_metals"].has(metal):
			candidates.append(metal)
	return candidates


func _try_start(building: String, stock: Stock) -> void:
	if queues[building].is_empty():
		return
	var entry: String = queues[building][0]
	var item := entry.get_slice(":", 0)
	var recipe: Dictionary = _recipes[building][item]
	if not stock.take_all(recipe["takes"]):
		return
	queues[building].pop_front()
	var ship_id := int(entry.get_slice(":", 1)) if entry.contains(":") else -1
	current[building] = {"item": item, "hours_left": float(recipe["hours"]), "ship_id": ship_id}
