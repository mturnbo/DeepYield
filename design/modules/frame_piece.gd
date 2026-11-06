@tool
extends Node3D
## One piece of the platform frame: an open square truss with the rail inside.
## It runs along +X from its origin, which sits on the frame's center line.
## Distances are in meters.

@export var length := 15.0:
	set(value):
		length = value
		_rebuild()
@export var width := 4.0:
	set(value):
		width = value
		_rebuild()
@export var height := 4.0:
	set(value):
		height = value
		_rebuild()
@export_range(1, 12) var bays := 5:
	set(value):
		bays = value
		_rebuild()
@export var chord_thickness := 0.35:
	set(value):
		chord_thickness = value
		_rebuild()
@export var brace_thickness := 0.22:
	set(value):
		brace_thickness = value
		_rebuild()
@export var truss_color := Color("9a9ea5"):
	set(value):
		truss_color = value
		_rebuild()
@export var rail_color := Color("f2d45c"):
	set(value):
		rail_color = value
		_rebuild()

var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)

	var truss := SurfaceTool.new()
	var rail := SurfaceTool.new()
	truss.begin(Mesh.PRIMITIVE_TRIANGLES)
	rail.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hy := height / 2.0
	var hz := width / 2.0
	var bay := length / bays

	# Four chords along the corners.
	for y in [-hy, hy]:
		for z in [-hz, hz]:
			_box(truss, Vector3(length, chord_thickness, chord_thickness), Vector3(length / 2.0, y, z))

	# A square ring at each end and between bays.
	for i in bays + 1:
		var x := i * bay
		for z in [-hz, hz]:
			_box(truss, Vector3(brace_thickness, height, brace_thickness), Vector3(x, 0, z))
		for y in [-hy, hy]:
			_box(truss, Vector3(brace_thickness, brace_thickness, width), Vector3(x, y, 0))

	# One diagonal brace per bay on the two sides and the top, alternating direction.
	for i in bays:
		var x0 := i * bay
		var x1 := x0 + bay
		var flip := 1.0 if i % 2 == 0 else -1.0
		for z in [-hz, hz]:
			_strut(truss, Vector3(x0, -hy * flip, z), Vector3(x1, hy * flip, z))
		_strut(truss, Vector3(x0, hy, -hz * flip), Vector3(x1, hy, hz * flip))

	# The rail runs along the floor of the truss.
	_box(rail, Vector3(length, 0.3, 1.4), Vector3(length / 2.0, -hy + chord_thickness / 2.0 + 0.15, 0))

	var mesh := ArrayMesh.new()
	truss.commit(mesh)
	mesh.surface_set_material(0, MeshBuilder.make_material(truss_color))
	rail.commit(mesh)
	mesh.surface_set_material(1, MeshBuilder.make_material(rail_color))
	_mesh_instance.mesh = mesh


func _box(st: SurfaceTool, size: Vector3, center: Vector3) -> void:
	MeshBuilder.add_box(st, size, Transform3D(Basis(), center))


# A thin box from one point to another.
func _strut(st: SurfaceTool, from: Vector3, to: Vector3) -> void:
	var along := to - from
	var x_axis := along.normalized()
	var helper := Vector3.UP if absf(x_axis.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	var z_axis := x_axis.cross(helper).normalized()
	var y_axis := z_axis.cross(x_axis)
	var strut_basis := Basis(x_axis, y_axis, z_axis)
	MeshBuilder.add_box(st, Vector3(along.length(), brace_thickness, brace_thickness), Transform3D(strut_basis, (from + to) / 2.0))
