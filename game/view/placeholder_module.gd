extends "res://design/modules/module_base.gd"
## Stand-in look for the factory and the assembly: a module base with a colored band
## and a simple shape on the deck. Distances are in meters.

@export var top_style := "factory":
	set(value):
		top_style = value
		band_color = Color("5b8def") if value == "factory" else Color("9b6bd6")
		_rebuild()

const BUILDING_COLOR := Color("aab2bd")

var _top_instance: MeshInstance3D


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck_top := hull_height / 2.0 + band_height + deck_height
	if top_style == "factory":
		_add_factory(st, deck_top)
	else:
		_add_gantry(st, deck_top)
	var mesh := st.commit()
	mesh.surface_set_material(0, MeshBuilder.make_material(BUILDING_COLOR))
	if _top_instance == null:
		_top_instance = MeshInstance3D.new()
		add_child(_top_instance)
	_top_instance.mesh = mesh



func _add_factory(st: SurfaceTool, deck_top: float) -> void:
	MeshBuilder.add_box(st, Vector3(20, 6, 14), Transform3D(Basis(), Vector3(0, deck_top + 3, 0)))
	for i in 3:
		var x := -6.0 + i * 6.0
		var slant := Basis(Vector3.BACK, -0.5)
		MeshBuilder.add_box(st, Vector3(6, 0.6, 14), Transform3D(slant, Vector3(x, deck_top + 7, 0)))


func _add_gantry(st: SurfaceTool, deck_top: float) -> void:
	for z in [-7.5, 7.5]:
		MeshBuilder.add_box(st, Vector3(18, 10, 3), Transform3D(Basis(), Vector3(0, deck_top + 5, z)))
	MeshBuilder.add_box(st, Vector3(20, 2, 3), Transform3D(Basis(), Vector3(0, deck_top + 11, 0)))
