extends Node3D
## Turns a left click on the platform into a picked node. Clicks that land on the UI
## never arrive here, and clicks while the placement tool is placing are ignored.

signal node_clicked(id: int)
signal ship_clicked(id: int)

const CLICK_SLOP := 6.0
const SHIP_PICK_RADIUS := 12.0

var _game: Node
var _pressed := false
var _press_position := Vector2.ZERO


static func nearest_node(state: GameState, ground: Vector2) -> PlatformNode:
	var nearest: PlatformNode = null
	var nearest_distance := INF
	for candidate in state.layout.nodes:
		var distance := candidate.center.distance_to(ground)
		if distance <= candidate.size / 2.0 and distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


static func nearest_ship(positions: Dictionary, ground: Vector2) -> int:
	var nearest := -1
	var nearest_distance := SHIP_PICK_RADIUS
	for id in positions:
		var distance: float = positions[id].distance_to(ground)
		if distance <= nearest_distance:
			nearest = id
			nearest_distance = distance
	return nearest


static func is_click(press: Vector2, release: Vector2) -> bool:
	return press.distance_to(release) <= CLICK_SLOP


func _ready() -> void:
	_game = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _game.get_node("PlacementTool").placing:
		return
	if event.pressed:
		_pressed = true
		_press_position = event.position
	elif _pressed:
		_pressed = false
		if is_click(_press_position, event.position):
			_pick(event.position)


func _pick(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
	if hit == null:
		return
	var ground := Vector2(hit.x, hit.z)
	var ship_id := nearest_ship(_game.get_node("FleetView").ground_positions(), ground)
	if ship_id != -1:
		ship_clicked.emit(ship_id)
		return
	var picked := nearest_node(_game.state, ground)
	if picked != null:
		node_clicked.emit(picked.id)
