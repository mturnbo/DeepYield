@tool
extends Node3D
## The white monorail car that runs on the frame's rail. It straddles the rail on two
## bogies. Its origin sits on the rail's top surface at the middle of the car, and it
## runs along X. In a frame piece the rail top is 1.525 m below the frame's center line.
## Distances are in meters.

@export var length := 7.0:
	set(value):
		length = value
		_rebuild()
@export var width := 2.8:
	set(value):
		width = value
		_rebuild()
@export var height := 2.3:
	set(value):
		height = value
		_rebuild()
@export var body_color := Color("e9edf0"):
	set(value):
		body_color = value
		_rebuild()
@export var window_color := Color("2a3442"):
	set(value):
		window_color = value
		_rebuild()

const RAIL_WIDTH := 1.4
const RAIL_DEPTH := 0.3
const BODY_LIFT := 0.3
const NOSE_LENGTH := 0.6
const NOSE_WIDTH_SCALE := 0.78
const NOSE_HEIGHT_SCALE := 0.82
const BOGIE_LENGTH := 1.6
const BOGIE_COLOR := Color("5a5f66")
const DOOR_COLOR := Color("c9cfd6")
const LIGHT_COLOR := Color("ffb347")

var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)

	var body := SurfaceTool.new()
	var glass := SurfaceTool.new()
	var bogies := SurfaceTool.new()
	var doors := SurfaceTool.new()
	var lights := SurfaceTool.new()
	for st in [body, glass, bogies, doors, lights]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_body(body)
	_add_windows(glass)
	_add_doors(doors, glass)
	_add_bogies(bogies)
	_add_lights(lights)

	var mesh := ArrayMesh.new()
	var surfaces := [[body, body_color], [glass, window_color], [bogies, BOGIE_COLOR], [doors, DOOR_COLOR], [lights, LIGHT_COLOR]]
	for i in surfaces.size():
		surfaces[i][0].commit(mesh)
		mesh.surface_set_material(i, MeshBuilder.make_material(surfaces[i][1]))
	var light_material: StandardMaterial3D = mesh.surface_get_material(4)
	light_material.emission_enabled = true
	light_material.emission = LIGHT_COLOR
	_mesh_instance.mesh = mesh


# The body's cross-section as (z, y) points, going around the car.
func _body_outline() -> Array:
	var hz := width / 2.0
	var bottom := BODY_LIFT
	var top := BODY_LIFT + height
	var low_chamfer := 0.35
	var high_chamfer := 0.5
	return [
		Vector2(-hz + low_chamfer, bottom), Vector2(hz - low_chamfer, bottom),
		Vector2(hz, bottom + low_chamfer), Vector2(hz, top - high_chamfer),
		Vector2(hz - high_chamfer, top), Vector2(-hz + high_chamfer, top),
		Vector2(-hz, top - high_chamfer), Vector2(-hz, bottom + low_chamfer),
	]


# The flat end face: the body outline pulled in toward its lower middle.
func _nose_outline() -> Array:
	var pivot_y := BODY_LIFT + height * 0.26
	var outline := []
	for point in _body_outline():
		outline.append(Vector2(point.x * NOSE_WIDTH_SCALE, pivot_y + (point.y - pivot_y) * NOSE_HEIGHT_SCALE))
	return outline


func _add_body(st: SurfaceTool) -> void:
	var full := _body_outline()
	var nose := _nose_outline()
	var half := length / 2.0
	var shoulder := half - NOSE_LENGTH
	_add_loft(st, full, -shoulder, full, shoulder)
	_add_loft(st, full, shoulder, nose, half)
	_add_loft(st, nose, -half, full, -shoulder)
	_add_cap(st, nose, half, Vector3.RIGHT)
	_add_cap(st, nose, -half, Vector3.LEFT)


# Walls joining two cross-sections at two points along X.
func _add_loft(st: SurfaceTool, outline_a: Array, x_a: float, outline_b: Array, x_b: float) -> void:
	var middle_y := BODY_LIFT + height / 2.0
	for i in outline_a.size():
		var j := (i + 1) % outline_a.size()
		var a0 := Vector3(x_a, outline_a[i].y, outline_a[i].x)
		var a1 := Vector3(x_a, outline_a[j].y, outline_a[j].x)
		var b0 := Vector3(x_b, outline_b[i].y, outline_b[i].x)
		var b1 := Vector3(x_b, outline_b[j].y, outline_b[j].x)
		var edge_middle: Vector2 = (outline_a[i] + outline_a[j]) / 2.0
		var outward := Vector3(0, edge_middle.y - middle_y, edge_middle.x)
		MeshBuilder.add_quad(st, a0, a1, b1, b0, outward)


func _add_cap(st: SurfaceTool, outline: Array, x: float, outward: Vector3) -> void:
	var first := Vector3(x, outline[0].y, outline[0].x)
	for i in range(1, outline.size() - 1):
		var b := Vector3(x, outline[i].y, outline[i].x)
		var c := Vector3(x, outline[i + 1].y, outline[i + 1].x)
		MeshBuilder.add_triangle(st, first, b, c, outward)


func _window_band() -> Vector2:
	var top := BODY_LIFT + height
	return Vector2(top - 1.15, top - 0.6)


func _add_windows(st: SurfaceTool) -> void:
	var band := _window_band()
	var band_height := band.y - band.x
	var band_middle := (band.x + band.y) / 2.0
	var side_z := width / 2.0 + 0.02
	var strip_start := 0.85
	var strip_end := length / 2.0 - NOSE_LENGTH - 0.25
	var strip_length := strip_end - strip_start
	for side in [-1.0, 1.0]:
		for direction in [-1.0, 1.0]:
			var center := Vector3(direction * (strip_start + strip_length / 2.0), band_middle, side * side_z)
			_box(st, Vector3(strip_length, band_height, 0.04), center)

	var nose := _nose_outline()
	var nose_top: float = nose[4].y
	var nose_window_z: float = nose[4].x - 0.1
	for direction in [-1.0, 1.0]:
		var center := Vector3(direction * (length / 2.0 + 0.02), nose_top - 0.45, 0)
		_box(st, Vector3(0.04, 0.5, nose_window_z * 2.0), center)


func _add_doors(st: SurfaceTool, glass: SurfaceTool) -> void:
	var band := _window_band()
	var door_bottom := BODY_LIFT + 0.15
	var door_top := band.y + 0.15
	var door_height := door_top - door_bottom
	var side_z := width / 2.0 + 0.02
	for side in [-1.0, 1.0]:
		_box(st, Vector3(1.2, door_height, 0.04), Vector3(0, door_bottom + door_height / 2.0, side * side_z))
		_box(glass, Vector3(0.75, band.y - band.x, 0.04), Vector3(0, (band.x + band.y) / 2.0, side * (side_z + 0.02)))


# Each bogie is a plate under the body with a skirt hanging down each side of the rail.
func _add_bogies(st: SurfaceTool) -> void:
	var bogie_x := length / 2.0 - NOSE_LENGTH - BOGIE_LENGTH / 2.0 - 0.2
	var skirt_thickness := 0.18
	var skirt_z := RAIL_WIDTH / 2.0 + 0.06 + skirt_thickness / 2.0
	var skirt_bottom := -RAIL_DEPTH - 0.05
	var skirt_top := BODY_LIFT
	var plate_width := RAIL_WIDTH + 0.4
	for direction in [-1.0, 1.0]:
		var x: float = direction * bogie_x
		_box(st, Vector3(BOGIE_LENGTH, BODY_LIFT - 0.05, plate_width), Vector3(x, 0.05 + (BODY_LIFT - 0.05) / 2.0, 0))
		for side in [-1.0, 1.0]:
			var skirt_center := Vector3(x, (skirt_bottom + skirt_top) / 2.0, side * skirt_z)
			_box(st, Vector3(BOGIE_LENGTH, skirt_top - skirt_bottom, skirt_thickness), skirt_center)


func _add_lights(st: SurfaceTool) -> void:
	var nose := _nose_outline()
	var light_y: float = nose[0].y + 0.3
	var light_z: float = nose[2].x - 0.25
	for direction in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			_box(st, Vector3(0.06, 0.18, 0.3), Vector3(direction * (length / 2.0 + 0.03), light_y, side * light_z))


func _box(st: SurfaceTool, size: Vector3, center: Vector3) -> void:
	MeshBuilder.add_box(st, size, Transform3D(Basis(), center))
