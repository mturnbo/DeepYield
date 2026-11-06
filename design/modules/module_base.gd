@tool
extends Node3D
## The octagonal base every module stands on: a hull, a color band around the rim,
## a top deck and a frame port on four of its sides. Distances are in meters.
## The origin sits on the frame's center line, so frame pieces line up with the ports.
## Change any setting in the Inspector and the base rebuilds in the editor right away.

@export var across_flats := 30.0:
	set(value):
		across_flats = value
		_rebuild()
@export var hull_height := 6.0:
	set(value):
		hull_height = value
		_rebuild()
@export var band_height := 1.6:
	set(value):
		band_height = value
		_rebuild()
@export var deck_height := 0.8:
	set(value):
		deck_height = value
		_rebuild()
@export var keel_height := 1.2:
	set(value):
		keel_height = value
		_rebuild()
@export var port_width := 6.0:
	set(value):
		port_width = value
		_rebuild()
@export var port_height := 4.6:
	set(value):
		port_height = value
		_rebuild()
@export var hull_color := Color("7b7f84"):
	set(value):
		hull_color = value
		_rebuild()
@export var band_color := Color("8fa3b8"):
	set(value):
		band_color = value
		_rebuild()
@export var deck_color := Color("c7cdd6"):
	set(value):
		deck_color = value
		_rebuild()
@export var port_color := Color("2c3038"):
	set(value):
		port_color = value
		_rebuild()

# Ports face east, south, west and north: the flat sides on the X and Z axes.
const PORT_DIRECTIONS := [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
const RIM := 0.6

var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)

	var hull := SurfaceTool.new()
	var band := SurfaceTool.new()
	var deck := SurfaceTool.new()
	var port := SurfaceTool.new()
	for st in [hull, band, deck, port]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := hull_height / 2.0
	var band_top := half + band_height
	MeshBuilder.add_prism(hull, 8, _corner_radius(across_flats - 6.0), _corner_radius(across_flats), -half - keel_height, -half, PI / 8.0)
	MeshBuilder.add_prism(hull, 8, _corner_radius(across_flats), _corner_radius(across_flats), -half, half, PI / 8.0)
	MeshBuilder.add_prism(band, 8, _corner_radius(across_flats + 0.6), _corner_radius(across_flats + 0.6), half, band_top, PI / 8.0)
	MeshBuilder.add_prism(deck, 8, _corner_radius(across_flats - 1.2), _corner_radius(across_flats - 1.2), band_top, band_top + deck_height, PI / 8.0)

	for direction in PORT_DIRECTIONS:
		_add_port(port, deck, direction)

	var mesh := ArrayMesh.new()
	for pair in [[hull, hull_color], [band, band_color], [deck, deck_color], [port, port_color]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	_mesh_instance.mesh = mesh


# A dark socket in the hull side with a light rim around it.
func _add_port(socket: SurfaceTool, rim: SurfaceTool, direction: Vector3) -> void:
	var facing := Transform3D(Basis(Vector3.UP, atan2(-direction.z, direction.x)), Vector3.ZERO)
	var face := across_flats / 2.0
	MeshBuilder.add_box(socket, Vector3(0.4, port_height, port_width), facing * Transform3D(Basis(), Vector3(face - 0.1, 0, 0)))

	var rim_x := face + RIM / 2.0 - 0.1
	var rim_y := port_height / 2.0 + RIM / 2.0
	var rim_z := port_width / 2.0 + RIM / 2.0
	var across := Vector3(RIM, RIM, port_width + RIM * 2.0)
	var upright := Vector3(RIM, port_height, RIM)
	MeshBuilder.add_box(rim, across, facing * Transform3D(Basis(), Vector3(rim_x, rim_y, 0)))
	MeshBuilder.add_box(rim, across, facing * Transform3D(Basis(), Vector3(rim_x, -rim_y, 0)))
	MeshBuilder.add_box(rim, upright, facing * Transform3D(Basis(), Vector3(rim_x, 0, rim_z)))
	MeshBuilder.add_box(rim, upright, facing * Transform3D(Basis(), Vector3(rim_x, 0, -rim_z)))


func _corner_radius(flats: float) -> float:
	return flats / 2.0 / cos(PI / 8.0)
