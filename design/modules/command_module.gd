@tool
extends "res://design/modules/module_base.gd"
## The command module: a module base with a gold band and the bridge on top.
## The bridge nearly fills the deck. It has a lower tier, a band of windows, an upper
## tier and a gold cap, with a mast holding a tilted communication dish.
## Distances are in meters.

@export var bridge_across_flats := 26.0:
	set(value):
		bridge_across_flats = value
		_rebuild()
@export var lower_tier_height := 6.0:
	set(value):
		lower_tier_height = value
		_rebuild()
@export var window_band_height := 4.0:
	set(value):
		window_band_height = value
		_rebuild()
@export var upper_tier_height := 3.0:
	set(value):
		upper_tier_height = value
		_rebuild()
@export var mast_height := 10.0:
	set(value):
		mast_height = value
		_rebuild()
@export var dish_radius := 6.0:
	set(value):
		dish_radius = value
		_rebuild()
@export_range(0.0, 90.0) var dish_tilt_deg := 35.0:
	set(value):
		dish_tilt_deg = value
		_rebuild()
## Which way the dish leans, in degrees around the vertical axis. 0 leans it east (+X).
@export var dish_heading_deg := 0.0:
	set(value):
		dish_heading_deg = value
		_rebuild()
@export var cap_color := Color("e8b04a"):
	set(value):
		cap_color = value
		_rebuild()
@export var window_frame_color := Color("2b3550"):
	set(value):
		window_frame_color = value
		_rebuild()
@export var window_color := Color("6fb7e8"):
	set(value):
		window_color = value
		_rebuild()
@export var dish_color := Color("e9edf2"):
	set(value):
		dish_color = value
		_rebuild()

var _bridge: MeshInstance3D
var _dish: MeshInstance3D


func _init() -> void:
	band_color = Color("e8b04a")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _bridge == null:
		_bridge = MeshInstance3D.new()
		add_child(_bridge)
		_dish = MeshInstance3D.new()
		add_child(_dish)

	var walls := SurfaceTool.new()
	var roof := SurfaceTool.new()
	var frame := SurfaceTool.new()
	var glass := SurfaceTool.new()
	var cap := SurfaceTool.new()
	for st in [walls, roof, frame, glass, cap]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var deck_top := hull_height / 2.0 + band_height + deck_height
	var windows_bottom := deck_top + lower_tier_height
	var windows_top := windows_bottom + window_band_height
	var upper_top := windows_top + upper_tier_height
	var upper_flats := bridge_across_flats - 3.0
	var cap_flats := bridge_across_flats * 0.58
	var cap_top := upper_top + 0.4 + 1.2
	var mast_top := cap_top + mast_height

	_add_octagon(walls, bridge_across_flats, deck_top, windows_bottom)
	_add_octagon(frame, bridge_across_flats + 0.4, windows_bottom, windows_top)
	_add_octagon(walls, upper_flats, windows_top, upper_top)
	_add_octagon(roof, upper_flats - 0.8, upper_top, upper_top + 0.4)
	_add_octagon(cap, cap_flats, upper_top + 0.4, cap_top)
	MeshBuilder.add_box(walls, Vector3(1.4, mast_height, 1.4), Transform3D(Basis(), Vector3(0, cap_top + mast_height / 2.0, 0)))

	_add_windows(glass, windows_bottom, windows_top)

	var mesh := ArrayMesh.new()
	for pair in [[walls, hull_color], [roof, deck_color], [frame, window_frame_color], [cap, cap_color]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	glass.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _window_material())
	_bridge.mesh = mesh

	_dish.mesh = _make_dish_mesh()
	_dish.position = Vector3(0, mast_top, 0)
	_dish.basis = Basis(Vector3.UP, deg_to_rad(dish_heading_deg)) * Basis(Vector3.BACK, -deg_to_rad(dish_tilt_deg))


# One lit pane on each of the eight sides of the window band.
func _add_windows(st: SurfaceTool, bottom: float, top: float) -> void:
	var side_length := bridge_across_flats * tan(PI / 8.0)
	var size := Vector3(0.2, (top - bottom) * 0.6, side_length * 0.8)
	var face := (bridge_across_flats + 0.4) / 2.0
	for i in 8:
		var facing := Basis(Vector3.UP, i * PI / 4.0)
		MeshBuilder.add_box(st, size, Transform3D(facing, facing * Vector3(face, (bottom + top) / 2.0, 0)))


# A shallow bowl on a short mount, with the feed standing out of its middle.
# It is built pointing straight up; the node's basis gives it the tilt.
func _make_dish_mesh() -> ArrayMesh:
	var back := SurfaceTool.new()
	var face := SurfaceTool.new()
	for st in [back, face]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	MeshBuilder.add_box(back, Vector3(1.8, 1.2, 1.8), Transform3D(Basis(), Vector3(0, 0.6, 0)))
	MeshBuilder.add_prism(back, 16, dish_radius * 0.35, dish_radius, 1.2, 2.2, 0.0)
	MeshBuilder.add_prism(face, 16, dish_radius - 0.3, dish_radius - 0.3, 2.2, 2.3, 0.0)
	MeshBuilder.add_box(back, Vector3(0.3, dish_radius * 0.6, 0.3), Transform3D(Basis(), Vector3(0, 2.3 + dish_radius * 0.3, 0)))
	MeshBuilder.add_box(back, Vector3(0.8, 0.8, 0.8), Transform3D(Basis(), Vector3(0, 2.3 + dish_radius * 0.6, 0)))

	var mesh := ArrayMesh.new()
	back.commit(mesh)
	mesh.surface_set_material(0, MeshBuilder.make_material(hull_color.lightened(0.15)))
	face.commit(mesh)
	mesh.surface_set_material(1, MeshBuilder.make_material(dish_color))
	return mesh


func _add_octagon(st: SurfaceTool, flats: float, bottom: float, top: float) -> void:
	MeshBuilder.add_prism(st, 8, _corner_radius(flats), _corner_radius(flats), bottom, top, PI / 8.0)


func _window_material() -> StandardMaterial3D:
	var material := MeshBuilder.make_material(window_color)
	material.emission_enabled = true
	material.emission = window_color * 0.6
	return material
