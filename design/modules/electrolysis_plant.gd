@tool
extends "res://design/modules/module_base.gd"
## The electrolysis plant: a module base with a white band, a round blue water tank,
## three tall oxygen cylinders along the back and a small pump house. Under the keel
## is the ice cradle: a collar with four clamp arms that grip the top edge of a towed
## ice chunk. A chunk placed at ICE_MOUNT_Y locks into the cradle.
## Distances are in meters.

@export var tank_radius := 7.0:
	set(value):
		tank_radius = value
		_rebuild()
@export var tank_height := 7.0:
	set(value):
		tank_height = value
		_rebuild()
@export var cylinder_radius := 2.25:
	set(value):
		cylinder_radius = value
		_rebuild()
@export var cylinder_height := 20.0:
	set(value):
		cylinder_height = value
		_rebuild()
## How far out the cradle arms reach, to just inside the top edge of a 50 m chunk.
@export var cradle_reach := 24.0:
	set(value):
		cradle_reach = value
		_rebuild()
@export var tank_color := Color("3d7fbf"):
	set(value):
		tank_color = value
		_rebuild()
@export var tank_top_color := Color("62a8e4"):
	set(value):
		tank_top_color = value
		_rebuild()
@export var cylinder_color := Color("b5bac2"):
	set(value):
		cylinder_color = value
		_rebuild()
@export var trim_color := Color("4a4f5a"):
	set(value):
		trim_color = value
		_rebuild()
@export var light_color := Color("e9edf2"):
	set(value):
		light_color = value
		_rebuild()

const ICE_MOUNT_Y := -6.0
const TANK_SIDES := 16
# The tank sits a little forward of center, toward the southeast.
const TANK_CENTER := Vector3(2.5, 0, 2.5)
# The pump house sits in the northeast corner.
const PUMP_HOUSE_CENTER := Vector3(7.5, 0, -7.5)
const BACK := Vector3(-0.7071, 0, -0.7071)
const ALONG_BACK := Vector3(0.7071, 0, -0.7071)

var _plant: MeshInstance3D


func _init() -> void:
	band_color = Color("f2f4f7")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _plant == null:
		_plant = MeshInstance3D.new()
		add_child(_plant)

	var tank := SurfaceTool.new()
	var tank_top := SurfaceTool.new()
	var cylinders := SurfaceTool.new()
	var trim := SurfaceTool.new()
	var light := SurfaceTool.new()
	var walls := SurfaceTool.new()
	for st in [tank, tank_top, cylinders, trim, light, walls]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var deck_top := hull_height / 2.0 + band_height + deck_height
	_add_tank(tank, tank_top, trim, light, deck_top)
	for spot in [BACK * 9.5, BACK * 8.0 + ALONG_BACK * 6.2, BACK * 8.0 - ALONG_BACK * 6.2]:
		_add_cylinder(cylinders, light, trim, spot, deck_top)
	_add_pump_house(walls, tank_top, deck_top)
	_add_cradle(trim, walls)

	var mesh := ArrayMesh.new()
	for pair in [[tank, tank_color], [tank_top, tank_top_color], [cylinders, cylinder_color], [trim, trim_color], [light, light_color], [walls, hull_color]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	_plant.mesh = mesh


# A dark plinth with small lit windows, the blue tank with a seam around its middle,
# then a shoulder and a cap on top.
func _add_tank(tank: SurfaceTool, top: SurfaceTool, trim: SurfaceTool, light: SurfaceTool, deck_top: float) -> void:
	var plinth_top := deck_top + 2.5
	var tank_top := plinth_top + tank_height
	_add_round(trim, TANK_CENTER, tank_radius, deck_top, plinth_top)
	_add_round(tank, TANK_CENTER, tank_radius, plinth_top, tank_top)
	_add_round(trim, TANK_CENTER, tank_radius + 0.15, plinth_top + tank_height * 0.5 - 0.15, plinth_top + tank_height * 0.5 + 0.15)
	_add_round(top, TANK_CENTER, tank_radius * 0.88, tank_top, tank_top + 1.4)
	_add_round(top, TANK_CENTER, tank_radius * 0.5, tank_top + 1.4, tank_top + 2.4)

	var apothem := tank_radius * cos(PI / TANK_SIDES)
	for i in TANK_SIDES:
		var facing := Basis(Vector3.UP, i * TAU / TANK_SIDES)
		var spot := TANK_CENTER + facing * Vector3(apothem, deck_top + 1.25, 0)
		MeshBuilder.add_box(light, Vector3(0.2, 1.1, 0.7), Transform3D(facing, spot))


# A tall oxygen cylinder with a light collar near the top and a darker cap.
func _add_cylinder(body: SurfaceTool, light: SurfaceTool, trim: SurfaceTool, spot: Vector3, deck_top: float) -> void:
	var top := deck_top + cylinder_height
	_add_round(body, spot, cylinder_radius, deck_top, top)
	_add_round(light, spot, cylinder_radius + 0.35, top - 2.4, top - 1.4)
	_add_round(trim, spot, cylinder_radius * 0.75, top, top + 0.8)


# A small block with a blue skylight on its roof.
func _add_pump_house(walls: SurfaceTool, glass: SurfaceTool, deck_top: float) -> void:
	var size := Vector3(5.0, 4.0, 5.0)
	MeshBuilder.add_box(walls, size, Transform3D(Basis(), PUMP_HOUSE_CENTER + Vector3(0, deck_top + size.y / 2.0, 0)))
	MeshBuilder.add_box(glass, Vector3(3.2, 0.3, 3.2), Transform3D(Basis(), PUMP_HOUSE_CENTER + Vector3(0, deck_top + size.y + 0.15, 0)))


# A collar under the keel with four arms reaching out on the diagonals, between the
# frame ports. Each arm ends in a clamp that drops over the edge of the ice.
func _add_cradle(trim: SurfaceTool, walls: SurfaceTool) -> void:
	var keel_bottom := -hull_height / 2.0 - keel_height
	MeshBuilder.add_prism(trim, 8, _corner_radius(18.0), _corner_radius(18.0), ICE_MOUNT_Y + 0.6, keel_bottom, PI / 8.0)
	for i in 4:
		var direction := Basis(Vector3.UP, PI / 4.0 + i * PI / 2.0) * Vector3.RIGHT
		var root := direction * 8.0 + Vector3(0, keel_bottom - 0.6, 0)
		var elbow := direction * cradle_reach + Vector3(0, ICE_MOUNT_Y + 1.0, 0)
		MeshBuilder.add_strut(walls, root, elbow, 1.2)
		MeshBuilder.add_strut(walls, root + Vector3(0, -0.8, 0), elbow + Vector3(0, -0.4, 0), 0.8)
		var clamp_basis := Basis(Vector3.UP, atan2(-direction.z, direction.x))
		MeshBuilder.add_box(trim, Vector3(1.4, 4.0, 3.0), Transform3D(clamp_basis, elbow + direction * 1.4 + Vector3(0, -1.5, 0)))


func _add_round(st: SurfaceTool, center: Vector3, radius: float, bottom: float, top: float) -> void:
	var piece := SurfaceTool.new()
	piece.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_prism(piece, TANK_SIDES, radius, radius, bottom, top, PI / TANK_SIDES)
	st.append_from(piece.commit(), 0, Transform3D(Basis(), center))
