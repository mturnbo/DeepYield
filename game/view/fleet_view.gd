extends Node3D
## Shows the mining ships: parked on their bay pads, flying between the dock door and
## their destination, circling the dock when no bay is free. Also opens and closes the
## dock doors and shows the comet only while a pass is in reach.

const SHIP_SCRIPT := "res://design/ships/robot_ship.gd"
const ICE_SCRIPT := "res://design/modules/ice_chunk.gd"
const NEBULA_POINT := Vector3(900, 40, 500)
const FLIGHT_HEIGHT := 6.0
const SHIP_LIFT := 1.5
const PLANT_OFFSET := Vector3(0, 6, 40)
const HOLD_RADIUS := 80.0
const HOLD_HEIGHT := 20.0
const HOLD_LAP_SECONDS := 20.0
const TOW_DISTANCE := 30.0
const CHUNK_FULL_SIZE := 3000.0
const BAY_COUNT := 4
const DOOR_OPEN_PROGRESS := 0.15
const FADE_START := 0.2
const FADE_END := 0.3

var _game: Node
var _platform: Node
var _ships := {}
var _chunks := {}
var _fades := {}
var _last_bay := {}
var _time := 0.0


static func leg_progress(hours_total: int, hours_left: int, sub_hour: float) -> float:
	if hours_total <= 0:
		return 1.0
	return clampf((hours_total - hours_left + sub_hour) / hours_total, 0.0, 1.0)


static func leg_fade(progress: float) -> float:
	var edge := minf(progress, 1.0 - progress)
	return smoothstep(FADE_START, FADE_END, edge)


static func free_bay(ships: Array[MiningShip]) -> int:
	for bay in BAY_COUNT:
		if not _bay_taken(ships, bay):
			return bay
	return -1


static func door_wanted(ships: Array[MiningShip], last_bay: Dictionary, sub_hour: float, bay: int) -> bool:
	var next_bay := free_bay(ships)
	for ship in ships:
		match ship.state:
			"docked":
				if ship.bay == bay and ship.docked_hours <= 1:
					return true
			"outbound", "ice_outbound":
				var progress := leg_progress(ship.hours_total, ship.hours_left, sub_hour)
				if last_bay.get(ship.id, 0) == bay and progress < DOOR_OPEN_PROGRESS:
					return true
			"inbound":
				if next_bay == bay and ship.hours_left <= 1:
					return true
	return false


static func _bay_taken(ships: Array[MiningShip], bay: int) -> bool:
	for ship in ships:
		if ship.state == "docked" and ship.bay == bay:
			return true
	return false


func _ready() -> void:
	_game = get_parent()
	_platform = _game.get_node("PlatformView")


func _process(delta: float) -> void:
	_time += delta
	var state: GameState = _game.state
	_game.get_node("Comet").visible = state.comets.current(state.hour) >= 0
	var dock := _first_model("ship_dock")
	for ship in state.fleet.ships:
		if ship.state == "docked":
			_last_bay[ship.id] = ship.bay
		_update_ship(state, dock, ship)
	if dock != null:
		for bay in BAY_COUNT:
			if door_wanted(state.fleet.ships, _last_bay, _game.sub_hour, bay):
				dock.open_door(bay)
			else:
				dock.close_door(bay)


func _first_model(kind: String) -> Node3D:
	var state: GameState = _game.state
	var built := state.layout.built_nodes(kind)
	if built.is_empty():
		return null
	return _platform.model_of(built[0].id)


func _update_ship(state: GameState, dock: Node3D, ship: MiningShip) -> void:
	var node := _ship_node(ship.id)
	if dock == null:
		node.visible = false
		_hide_chunk(ship.id)
		return
	var progress := leg_progress(ship.hours_total, ship.hours_left, _game.sub_hour)
	var fade := 0.0
	match ship.state:
		"docked":
			_place_docked(node, dock, ship.bay)
		"outbound", "ice_outbound":
			var door := _door_world(dock, _last_bay.get(ship.id, 0))
			fade = _fly(node, door, _destination_point(ship.destination), progress)
		"inbound":
			var door := _door_world(dock, maxi(free_bay(state.fleet.ships), 0))
			fade = _fly(node, _inbound_start(dock, ship), door, progress)
		"towing":
			fade = _fly(node, _destination_point("comet"), _plant_point(dock), progress)
		"at_plant":
			_place_at_plant(node, _plant_point(dock))
		"holding":
			_place_holding(node, dock, ship.id)
		_:
			node.visible = false
	_set_fade(ship.id, node, fade)
	_update_chunk(ship, node, progress)


func _ship_node(id: int) -> Node3D:
	if not _ships.has(id):
		var node := Node3D.new()
		node.set_script(load(SHIP_SCRIPT))
		add_child(node)
		_ships[id] = node
	return _ships[id]


func _door_world(dock: Node3D, bay: int) -> Vector3:
	return dock.to_global(dock.door_position(bay)) + Vector3(0, SHIP_LIFT, 0)


func _destination_point(destination: String) -> Vector3:
	match destination:
		"nebula":
			return NEBULA_POINT
		"asteroids":
			return _game.get_node("AsteroidField").global_position
		"comet":
			return _game.get_node("Comet").global_position
	return Vector3.ZERO


func _plant_point(dock: Node3D) -> Vector3:
	var plant := _first_model("electrolysis_plant")
	if plant == null:
		return dock.global_position + Vector3(0, FLIGHT_HEIGHT, 0)
	return plant.global_position + PLANT_OFFSET


func _inbound_start(dock: Node3D, ship: MiningShip) -> Vector3:
	if ship.destination == "dock":
		return _plant_point(dock)
	return _destination_point(ship.destination)


func _place_docked(node: Node3D, dock: Node3D, bay: int) -> void:
	node.visible = true
	node.position = dock.to_global(dock.bay_position(bay)) + Vector3(0, SHIP_LIFT, 0)
	node.look_at(node.position + dock.PORT_DIRECTIONS[bay])


func _fly(node: Node3D, from: Vector3, to: Vector3, progress: float) -> float:
	var fade := leg_fade(progress)
	node.visible = fade < 1.0
	if from.is_equal_approx(to):
		return fade
	node.position = from.lerp(to, progress)
	node.look_at(node.position + (to - from))
	return fade


func _place_at_plant(node: Node3D, point: Vector3) -> void:
	node.visible = true
	node.position = point
	var plant := _first_model("electrolysis_plant")
	if plant != null:
		node.look_at(plant.global_position + Vector3(0, PLANT_OFFSET.y, 0))


func _place_holding(node: Node3D, dock: Node3D, id: int) -> void:
	node.visible = true
	var angle := TAU * _time / HOLD_LAP_SECONDS + id * PI / 2.0
	var around := Vector3(cos(angle), 0, sin(angle)) * HOLD_RADIUS
	node.position = dock.global_position + around + Vector3(0, HOLD_HEIGHT, 0)
	node.look_at(node.position + Vector3(-sin(angle), 0, cos(angle)))


func _set_fade(id: int, node: Node3D, fade: float) -> void:
	if is_equal_approx(_fades.get(id, 0.0), fade):
		return
	_fades[id] = fade
	_platform.set_transparency(node, fade)


func _update_chunk(ship: MiningShip, node: Node3D, progress: float) -> void:
	var towing_visible := ship.state == "towing" and progress >= 1.0 - FADE_START and node.visible
	if not towing_visible and ship.state != "at_plant":
		_hide_chunk(ship.id)
		return
	var chunk := _chunk_node(ship.id)
	chunk.visible = true
	var scale_factor := pow(ship.chunk / CHUNK_FULL_SIZE, 1.0 / 3.0)
	chunk.scale = Vector3.ONE * scale_factor
	var behind := node.global_transform.basis.z * TOW_DISTANCE
	chunk.position = node.position + behind + Vector3(0, -2, 0)


func _chunk_node(id: int) -> Node3D:
	if not _chunks.has(id):
		var chunk := Node3D.new()
		chunk.set_script(load(ICE_SCRIPT))
		add_child(chunk)
		_chunks[id] = chunk
	return _chunks[id]


func _hide_chunk(id: int) -> void:
	if _chunks.has(id):
		_chunks[id].visible = false
