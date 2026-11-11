@tool
extends "res://design/modules/module_base.gd"
## The factory: a module base with a blue band and a long works building with a
## sawtooth roof. Each roof tooth slopes up toward the east and ends in a tall
## blue window facing east. A wide loading door sits in the east wall.
## Distances are in meters.

@export var building_width := 18.0:
	set(value):
		building_width = value
		_rebuild()
@export var building_depth := 14.0:
	set(value):
		building_depth = value
		_rebuild()
@export var building_height := 6.0:
	set(value):
		building_height = value
		_rebuild()
@export_range(1, 6) var teeth := 3:
	set(value):
		teeth = value
		_rebuild()
@export var tooth_height := 3.6:
	set(value):
		tooth_height = value
		_rebuild()
@export var wall_color := Color("9a9ea5"):
	set(value):
		wall_color = value
		_rebuild()
@export var roof_color := Color("c7cdd6"):
	set(value):
		roof_color = value
		_rebuild()
@export var glass_color := Color("5b8def"):
	set(value):
		glass_color = value
		_rebuild()

const ROOF_THICKNESS := 0.5
const ROOF_OVERHANG := 0.3
const TOOTH_INSET := 0.5
const DOOR_WIDTH := 8.0
const DOOR_HEIGHT := 3.6
const DOOR_COLOR := Color("2b3550")
const TRIM_COLOR := Color("3a3e45")

var _factory: MeshInstance3D


func _init() -> void:
	band_color = Color("5b8def")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _factory == null:
		_factory = MeshInstance3D.new()
		add_child(_factory)

	var walls := SurfaceTool.new()
	var roof := SurfaceTool.new()
	var glass := SurfaceTool.new()
	var door := SurfaceTool.new()
	var trim := SurfaceTool.new()
	for st in [walls, roof, glass, door, trim]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var deck_top := hull_height / 2.0 + band_height + deck_height
	var roof_bottom := deck_top + building_height
	var roof_top := roof_bottom + ROOF_THICKNESS
	var hx := building_width / 2.0
	var hz := building_depth / 2.0
	_box(walls, Vector3(building_width, building_height, building_depth), Vector3(0, deck_top + building_height / 2.0, 0))
	var overhang := ROOF_OVERHANG * 2.0
	_box(roof, Vector3(building_width + overhang, ROOF_THICKNESS, building_depth + overhang), Vector3(0, roof_bottom + ROOF_THICKNESS / 2.0, 0))

	var tooth_length := building_width / teeth
	var tooth_hz := hz - TOOTH_INSET
	for i in teeth:
		var west := -hx + i * tooth_length
		_add_tooth(walls, roof, glass, west, west + tooth_length, roof_top, tooth_hz)

	var door_center := Vector3(hx + 0.05, deck_top + DOOR_HEIGHT / 2.0, 0)
	_box(door, Vector3(0.2, DOOR_HEIGHT, DOOR_WIDTH), door_center)
	_box(trim, Vector3(0.3, 0.5, DOOR_WIDTH + 1.0), door_center + Vector3(0, DOOR_HEIGHT / 2.0 + 0.25, 0))
	for side in [-1.0, 1.0]:
		_box(trim, Vector3(0.3, DOOR_HEIGHT, 0.5), door_center + Vector3(0, 0, side * (DOOR_WIDTH / 2.0 + 0.25)))

	var mesh := ArrayMesh.new()
	for pair in [[walls, wall_color], [roof, roof_color], [glass, glass_color], [door, DOOR_COLOR], [trim, TRIM_COLOR]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	_factory.mesh = mesh


# One roof tooth: a wedge running north to south, low at its west edge and
# tooth_height tall at its east edge, where the window is.
func _add_tooth(ends: SurfaceTool, slope: SurfaceTool, window: SurfaceTool, west: float, east: float, base: float, hz: float) -> void:
	var top := base + tooth_height
	var low_n := Vector3(west, base, -hz)
	var low_s := Vector3(west, base, hz)
	var foot_n := Vector3(east, base, -hz)
	var foot_s := Vector3(east, base, hz)
	var peak_n := Vector3(east, top, -hz)
	var peak_s := Vector3(east, top, hz)
	var slope_normal := Vector3(-tooth_height, east - west, 0)
	MeshBuilder.add_quad(slope, low_n, peak_n, peak_s, low_s, slope_normal)
	MeshBuilder.add_quad(window, foot_n, foot_s, peak_s, peak_n, Vector3.RIGHT)
	MeshBuilder.add_triangle(ends, low_n, foot_n, peak_n, Vector3.FORWARD)
	MeshBuilder.add_triangle(ends, low_s, foot_s, peak_s, Vector3.BACK)


func _box(st: SurfaceTool, size: Vector3, center: Vector3) -> void:
	MeshBuilder.add_box(st, size, Transform3D(Basis(), center))
