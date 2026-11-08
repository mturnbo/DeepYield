class_name GameState
extends RefCounted

var hour := 0
var balance: Dictionary
var rng := RandomNumberGenerator.new()
var layout: PlatformLayout
var storage: Storage
var stock := Stock.new()
var kits: Dictionary = {}
var assembled: Dictionary = {}
var crew := 12
var robots := 20
var construction: Construction
var power: Power
var outcome := ""
var collapse_reason := ""
var _arrival_ship: Vector2


func _init(game_balance: Dictionary, seed: int) -> void:
	balance = game_balance
	rng.seed = seed
	layout = PlatformLayout.new(balance["layout"])
	storage = Storage.new(balance["storage"])
	construction = Construction.new(balance["work"])
	power = Power.new(balance)
	crew = int(balance["start"]["crew"])
	robots = int(balance["start"]["robots"])
	stock.add("frame_piece", float(balance["start"]["frame_pieces"]))
	for kind in balance["start"]["kits"]:
		kits[kind] = kits.get(kind, 0) + 1
	var ship_position: Array = balance["arrival_ship"]["position"]
	_arrival_ship = Vector2(float(ship_position[0]), float(ship_position[1]))


func step() -> void:
	if outcome != "":
		return
	_step_construction()
	if power.step(layout, storage, crew) == "energy":
		outcome = "collapsed"
		collapse_reason = "energy"
	hour += 1


func can_place(kind: String) -> bool:
	return kits.get(kind, 0) > 0 or assembled.get(kind, 0) > 0


func place_first(kind: String, center: Vector2) -> String:
	var reason := layout.check_first(kind, center, _arrival_ship)
	if reason != "":
		return reason
	if not can_place(kind):
		return _missing_reason(kind)
	var site_work := _take_module(kind)
	var new_node := layout.add_first(kind, center)
	construction.add_site(new_node.id, site_work)
	return ""


func place(from_id: int, port: int, run: int, kind: String) -> String:
	var reason := layout.check_placement(from_id, port, run, kind)
	if reason != "":
		return reason
	if not can_place(kind):
		return _missing_reason(kind)
	var frame_cost := {"frame_piece": float(run)}
	if not stock.has_all(frame_cost):
		return "Not enough frame pieces"
	stock.take_all(frame_cost)
	var site_work := _take_module(kind) + run * float(balance["work"]["frame_piece"])
	var new_node := layout.add(from_id, port, run, kind)
	construction.add_site(new_node.id, site_work)
	return ""


func is_running(node_id: int) -> bool:
	if not layout.node(node_id).built:
		return false
	var crewed: bool = balance["modules"][layout.node(node_id).kind]["crewed"]
	if crewed and not power.operated.get(node_id, false):
		return false
	return power.powered.get(node_id, false)


func speed_of(node_id: int) -> float:
	if not is_running(node_id):
		return 0.0
	if power.on_battery:
		return float(balance["power"]["battery_speed"])
	return 1.0


func end_run() -> void:
	outcome = "ended"


func _missing_reason(kind: String) -> String:
	return "No " + kind.replace("_", " ") + " to place"


func _take_module(kind: String) -> float:
	if kits.get(kind, 0) > 0:
		kits[kind] -= 1
		return float(balance["work"]["kit"])
	assembled[kind] -= 1
	if kind == "junction":
		return float(balance["work"]["junction"])
	return float(balance["work"]["assembled_module"])


func _step_construction() -> void:
	for node_id in construction.step(robots):
		layout.node(node_id).built = true
	storage.set_modules(layout.built_nodes("gas_storage").size(), layout.built_nodes("metal_storage").size())
