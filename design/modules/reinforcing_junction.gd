@tool
extends Node3D
## The reinforcing junction: a small, solid block where up to four frame trusses
## meet, so the rail passes straight through it from one truss to the next. It is
## sturdier than the frame, which is why one is needed at least every 3 frame
## pieces. Seen from above it is a square with its corners cut at 45 degrees, with
## a slate band near the top. Each of its four sides has a dark socket that one
## truss plugs into, with the rail running through it. The sockets face east,
## south, west and north, and the origin sits on the frame's center line, like a
## module's. Distances are in meters.

@export var across := 10.0:
	set(value):
		across = value
		_rebuild()
## How far the 45 degree cut runs along each side at the corners. The flat sides
## must stay wider than the 4 m truss.
@export var corner_cut := 1.8:
	set(value):
		corner_cut = value
		_rebuild()
@export var body_color := Color("7b7f84"):
	set(value):
		body_color = value
		_rebuild()
@export var band_color := Color("8fa3b8"):
	set(value):
		band_color = value
		_rebuild()
@export var deck_color := Color("c7cdd6"):
	set(value):
		deck_color = value
		_rebuild()
@export var socket_color := Color("2c3038"):
	set(value):
		socket_color = value
		_rebuild()
@export var rail_color := Color("f2d45c"):
	set(value):
		rail_color = value
		_rebuild()

const BODY_BOTTOM := -3.0
const BAND_BOTTOM := 2.4
const BAND_TOP := 3.2
const DECK_TOP := 3.6
const KEEL_BOTTOM := -3.6
# A socket is a little bigger than the 4 m truss that plugs into it.
const SOCKET_SIZE := 4.4
# The rail's height and width match the rail inside a frame piece.
const RAIL_Y := -1.675
const RAIL_WIDTH := 1.4
const SOCKET_DIRECTIONS := [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]

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
	var band := SurfaceTool.new()
	var deck := SurfaceTool.new()
	var socket := SurfaceTool.new()
	var rail := SurfaceTool.new()
	for st in [body, band, deck, socket, rail]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	MeshBuilder.add_extrusion(body, _outline(0.6), KEEL_BOTTOM, BODY_BOTTOM)
	MeshBuilder.add_extrusion(body, _outline(0.0), BODY_BOTTOM, BAND_BOTTOM)
	MeshBuilder.add_extrusion(band, _outline(-0.15), BAND_BOTTOM, BAND_TOP)
	MeshBuilder.add_extrusion(deck, _outline(0.4), BAND_TOP, DECK_TOP)

	var face := across / 2.0
	for direction in SOCKET_DIRECTIONS:
		var facing := Basis(Vector3.UP, atan2(-direction.z, direction.x))
		MeshBuilder.add_box(socket, Vector3(0.4, SOCKET_SIZE, SOCKET_SIZE), Transform3D(facing, facing * Vector3(face - 0.15, 0, 0)))
		MeshBuilder.add_box(rail, Vector3(0.5, 0.3, RAIL_WIDTH), Transform3D(facing, facing * Vector3(face - 0.1, RAIL_Y, 0)))

	var mesh := ArrayMesh.new()
	for pair in [[body, body_color], [band, band_color], [deck, deck_color], [socket, socket_color], [rail, rail_color]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	_mesh_instance.mesh = mesh


# The block's outline seen from above, as (x, z) points going around it, pulled in
# by inset on every side (a negative inset pushes it out). Pulling a 45 degree corner
# cut in by inset shortens it by inset * (2 - sqrt 2) along each side.
func _outline(inset: float) -> Array:
	var half := across / 2.0 - inset
	var cut := corner_cut - inset * (2.0 - sqrt(2.0))
	return [
		Vector2(half - cut, -half), Vector2(half, -half + cut),
		Vector2(half, half - cut), Vector2(half - cut, half),
		Vector2(-half + cut, half), Vector2(-half, half - cut),
		Vector2(-half, -half + cut), Vector2(-half + cut, -half),
	]
