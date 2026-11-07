@tool
extends "res://design/modules/module_base.gd"
## Gas storage: a module base with a violet band and three pressurized tanks, one
## each for hydrogen, helium and nitrogen, colored by the gas they hold. Each tank
## has a dark ring low on its side and a rounded top with a valve cap.
## Distances are in meters.

@export var tank_radius := 5.2:
	set(value):
		tank_radius = value
		_rebuild()
@export var tank_height := 13.0:
	set(value):
		tank_height = value
		_rebuild()
@export var hydrogen_color := Color("e36fa8"):
	set(value):
		hydrogen_color = value
		_rebuild()
@export var helium_color := Color("f4e3a1"):
	set(value):
		helium_color = value
		_rebuild()
@export var nitrogen_color := Color("8c9bf2"):
	set(value):
		nitrogen_color = value
		_rebuild()
@export var ring_color := Color("3a3e45"):
	set(value):
		ring_color = value
		_rebuild()
@export var cap_color := Color("7d8696"):
	set(value):
		cap_color = value
		_rebuild()

const TANK_SIDES := 16
# Hydrogen at the back, nitrogen front left and helium front right, as seen from the default camera.
const HYDROGEN_SPOT := Vector3(-5.3, 0, -5.3)
const HELIUM_SPOT := Vector3(7.5, 0, 0)
const NITROGEN_SPOT := Vector3(0, 0, 7.5)

var _tanks: MeshInstance3D


func _init() -> void:
	band_color = Color("c58be0")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _tanks == null:
		_tanks = MeshInstance3D.new()
		add_child(_tanks)

	var rings := SurfaceTool.new()
	var caps := SurfaceTool.new()
	rings.begin(Mesh.PRIMITIVE_TRIANGLES)
	caps.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mesh := ArrayMesh.new()
	var deck_top := hull_height / 2.0 + band_height + deck_height
	for pair in [[HYDROGEN_SPOT, hydrogen_color], [HELIUM_SPOT, helium_color], [NITROGEN_SPOT, nitrogen_color]]:
		var body := SurfaceTool.new()
		body.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_tank(body, rings, caps, pair[0], deck_top)
		body.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	for pair in [[rings, ring_color], [caps, cap_color]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	_tanks.mesh = mesh


# A round tank with a ring around it near the bottom, a narrower shoulder on top
# and a small valve cap.
func _add_tank(body: SurfaceTool, rings: SurfaceTool, caps: SurfaceTool, spot: Vector3, deck_top: float) -> void:
	var top := deck_top + tank_height
	_add_round(body, spot, tank_radius, deck_top, top)
	_add_round(rings, spot, tank_radius + 0.15, deck_top + tank_height * 0.22, deck_top + tank_height * 0.22 + 0.6)
	_add_round(body, spot, tank_radius * 0.82, top, top + 1.2)
	_add_round(caps, spot, tank_radius * 0.42, top + 1.2, top + 2.0)


func _add_round(st: SurfaceTool, center: Vector3, radius: float, bottom: float, top: float) -> void:
	var piece := SurfaceTool.new()
	piece.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_prism(piece, TANK_SIDES, radius, radius, bottom, top, PI / TANK_SIDES)
	st.append_from(piece.commit(), 0, Transform3D(Basis(), center))
