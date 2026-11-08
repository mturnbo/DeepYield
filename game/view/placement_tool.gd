class_name PlacementTool
extends Node3D
## Lets the player place a kit or module: a preview follows the cursor, green when
## the placement is allowed and red with the reason when it is refused.

signal placed

const PlatformViewScript = preload("res://game/view/platform_view.gd")
const OK_COLOR := Color(0.3, 0.9, 0.5, 0.5)
const REFUSED_COLOR := Color(0.95, 0.3, 0.3, 0.5)
const PICK_MARGIN := 40.0
const MIN_RUN := 1
const MAX_RUN := 3

var placing := false
var kind := ""
var run := 2

var _game: Node
var _view: Node3D
var _run_chosen := false
var _picked := {}
var _preview: Node3D
var _preview_key := []
var _disc_material: StandardMaterial3D
var _label: Label3D


static func pick(state: GameState, ground: Vector2, pick_run: int, pick_kind: String) -> Dictionary:
	var picked := {"first": false, "from_id": -1, "port": -1, "run": pick_run, "kind": pick_kind, "center": ground, "reason": ""}
	if state.layout.nodes.is_empty():
		picked["first"] = true
		picked["reason"] = state.check_place_first(pick_kind, ground)
		return picked
	var from_node := nearest_node(state, ground)
	if from_node == null:
		picked["reason"] = "Point at a module or junction"
		return picked
	picked["from_id"] = from_node.id
	picked["port"] = _closest_port(ground - from_node.center)
	picked["center"] = state.layout.new_center(from_node.id, picked["port"], pick_run, pick_kind)
	picked["reason"] = state.check_place(from_node.id, picked["port"], pick_run, pick_kind)
	return picked


static func nearest_node(state: GameState, ground: Vector2) -> PlatformNode:
	var nearest: PlatformNode = null
	var nearest_distance := INF
	for candidate in state.layout.nodes:
		var distance := candidate.center.distance_to(ground)
		if distance <= candidate.size / 2.0 + PICK_MARGIN and distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


static func _closest_port(offset: Vector2) -> int:
	var best_port := 0
	var best_dot := -INF
	for port in PlatformLayout.DIRECTIONS.size():
		var dot := offset.dot(PlatformLayout.DIRECTIONS[port])
		if dot > best_dot:
			best_port = port
			best_dot = dot
	return best_port


func _ready() -> void:
	_game = get_parent()
	_view = _game.get_node("PlatformView")
	_game.run_started.connect(_on_run_started)


func _on_run_started() -> void:
	cancel()


func start(new_kind: String) -> void:
	_clear_preview()
	_picked = {}
	kind = new_kind
	placing = true
	_run_chosen = false
	_game.keys_locked = true


func cancel() -> void:
	placing = false
	_clear_preview()
	_picked = {}
	_game.keys_locked = false


func _process(_delta: float) -> void:
	if not placing:
		return
	var ground = _ground_under_mouse()
	if ground != null:
		_update_preview(ground)


func _input(event: InputEvent) -> void:
	if not placing:
		return
	if event is InputEventMouseButton and event.pressed:
		_handle_mouse_button(event.button_index)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)


func _unhandled_input(event: InputEvent) -> void:
	if not placing or _picked.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_place_here()


func _handle_mouse_button(button: int) -> void:
	if button == MOUSE_BUTTON_WHEEL_UP:
		_choose_run(run + 1)
	elif button == MOUSE_BUTTON_WHEEL_DOWN:
		_choose_run(run - 1)
	elif button == MOUSE_BUTTON_RIGHT:
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()


func _handle_key(keycode: int) -> void:
	if keycode == KEY_ESCAPE:
		cancel()
	elif keycode == KEY_1 or keycode == KEY_2 or keycode == KEY_3:
		_choose_run(keycode - KEY_0)
	else:
		return
	get_viewport().set_input_as_handled()


func _choose_run(new_run: int) -> void:
	run = clampi(new_run, MIN_RUN, MAX_RUN)
	_run_chosen = true


func _ground_under_mouse() -> Variant:
	var camera := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit == null:
		return null
	return Vector2(hit.x, hit.z)


func _place_here() -> void:
	var state: GameState = _game.state
	var result := ""
	if _picked["first"]:
		result = state.place_first(kind, _picked["center"])
	else:
		result = state.place(_picked["from_id"], _picked["port"], _picked["run"], kind)
	if result != "":
		return
	_view.sync()
	cancel()
	placed.emit()


func _update_preview(ground: Vector2) -> void:
	var state: GameState = _game.state
	if not _run_chosen:
		run = _default_run(state, ground)
	_picked = pick(state, ground, run, kind)
	var key := [_picked["first"], _picked["from_id"], _picked["port"], run, kind]
	if key != _preview_key:
		_rebuild_preview(state)
		_preview_key = key
	_preview.position = _view.world_position(_picked["center"])
	_show_reason(_picked["reason"])


func _default_run(state: GameState, ground: Vector2) -> int:
	var wide_kinds: Array = state.balance["layout"]["wide_kinds"]
	if wide_kinds.has(kind):
		return MAX_RUN
	var from_node := nearest_node(state, ground)
	if from_node != null and wide_kinds.has(from_node.kind):
		return MAX_RUN
	return 2


func _rebuild_preview(state: GameState) -> void:
	_clear_preview()
	_preview = Node3D.new()
	add_child(_preview)
	_preview.add_child(_view.make_model(kind))
	if not _picked["first"] and _picked["from_id"] != -1:
		_add_frame_pieces(state)
	_view.set_transparency(_preview, PlatformViewScript.GHOST_TRANSPARENCY)
	_add_disc(state)
	_add_label()


func _add_frame_pieces(state: GameState) -> void:
	var from_node := state.layout.node(_picked["from_id"])
	var port: int = _picked["port"]
	var direction: Vector2 = PlatformViewScript.DIRECTIONS[port]
	for i in run:
		var start := from_node.center + direction * (from_node.size / 2.0 + PlatformViewScript.PIECE_LENGTH * i)
		var piece := Node3D.new()
		piece.set_script(load(PlatformViewScript.FRAME_SCRIPT))
		piece.position = _view.world_position(start - _picked["center"])
		piece.rotation.y = PlatformViewScript.FRAME_ROTATIONS[port]
		_preview.add_child(piece)


func _add_disc(state: GameState) -> void:
	var mesh := CylinderMesh.new()
	var size_key := "junction_size" if kind == "junction" else "module_size"
	mesh.top_radius = float(state.balance["layout"][size_key]) * 0.7
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.5
	_disc_material = StandardMaterial3D.new()
	_disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = _disc_material
	var disc := MeshInstance3D.new()
	disc.mesh = mesh
	disc.position.y = -3.0
	_preview.add_child(disc)


func _add_label() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.06
	_label.font_size = 100
	_label.outline_size = 16
	_label.no_depth_test = true
	_label.position.y = 30.0
	_preview.add_child(_label)


func _show_reason(reason: String) -> void:
	_disc_material.albedo_color = OK_COLOR if reason == "" else REFUSED_COLOR
	_label.text = reason
	_label.visible = reason != ""


func _clear_preview() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null
	_preview_key = []
