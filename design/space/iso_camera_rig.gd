@tool
extends Node3D
## Isometric orthographic camera that orbits a focus point.
## Drag with the left mouse button to rotate, scroll to zoom, WASD or the arrow
## keys to pan, and R to reset the view.

@export var yaw_deg := 45.0:
	set(value):
		yaw_deg = value
		_place_camera()
@export var pitch_deg := 35.264:
	set(value):
		pitch_deg = value
		_place_camera()
@export var zoom := 70.0:
	set(value):
		zoom = clampf(value, min_zoom, max_zoom)
		_place_camera()
@export var min_zoom := 10.0
@export var max_zoom := 240.0
@export var distance := 300.0
@export var rotate_speed := 0.3
@export var pan_speed := 40.0

var _start_position := Vector3.ZERO
var _start_yaw := 0.0
var _start_zoom := 0.0


func _ready() -> void:
	_start_position = position
	_start_yaw = yaw_deg
	_start_zoom = zoom
	_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom /= 0.9
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw_deg -= event.relative.x * rotate_speed
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		position = _start_position
		yaw_deg = _start_yaw
		zoom = _start_zoom


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if move != Vector3.ZERO:
		position += basis * move.normalized() * pan_speed * delta * (zoom / 70.0)


func _place_camera() -> void:
	if not is_inside_tree():
		return
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	var pitch := deg_to_rad(pitch_deg)
	camera.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation_degrees = Vector3(-pitch_deg, 0.0, 0.0)
	camera.size = zoom
