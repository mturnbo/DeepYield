@tool
extends "res://design/modules/module_base.gd"
## The refinery: a module base with an orange band, a long low works building and
## two tall stacks with glowing tops behind it to the north. The building's two
## south corners, the ones away from the stacks, are cut at 45 degrees. Three
## glowing vents line its east wall. Distances are in meters.

@export var building_width := 18.0:
	set(value):
		building_width = value
		_rebuild()
@export var building_depth := 14.0:
	set(value):
		building_depth = value
		_rebuild()
@export var building_height := 9.0:
	set(value):
		building_height = value
		_rebuild()
## How far the 45 degree cut runs along each side at the two south corners.
@export var corner_cut := 4.0:
	set(value):
		corner_cut = value
		_rebuild()
@export var stack_radius := 2.8:
	set(value):
		stack_radius = value
		_rebuild()
@export var stack_height := 16.0:
	set(value):
		stack_height = value
		_rebuild()
@export var wall_color := Color("9a9ea5"):
	set(value):
		wall_color = value
		_rebuild()
@export var roof_color := Color("7b8290"):
	set(value):
		roof_color = value
		_rebuild()
@export var stack_color := Color("4d535d"):
	set(value):
		stack_color = value
		_rebuild()
@export var collar_color := Color("944b23"):
	set(value):
		collar_color = value
		_rebuild()
@export var glow_color := Color("f07a3a"):
	set(value):
		glow_color = value
		_rebuild()

const STACK_SIDES := 12
# The building's back wall sits this far south of the module's center; it is
# shifted south to leave room for the stacks.
const BUILDING_BACK_Z := -5.0
const STACK_SPOTS := [Vector3(-3.0, 0, -10.0), Vector3(4.5, 0, -10.0)]
const VENT_COUNT := 3

var _refinery: MeshInstance3D


func _init() -> void:
	band_color = Color("f07a3a")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _refinery == null:
		_refinery = MeshInstance3D.new()
		add_child(_refinery)

	var walls := SurfaceTool.new()
	var roof := SurfaceTool.new()
	var stacks := SurfaceTool.new()
	var collars := SurfaceTool.new()
	var trim := SurfaceTool.new()
	var glow := SurfaceTool.new()
	for st in [walls, roof, stacks, collars, trim, glow]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var deck_top := hull_height / 2.0 + band_height + deck_height
	var roof_bottom := deck_top + building_height
	MeshBuilder.add_extrusion(walls, _footprint(0.0), deck_top, roof_bottom)
	MeshBuilder.add_extrusion(roof, _footprint(0.8), roof_bottom, roof_bottom + 0.5)

	var east := building_width / 2.0
	var vent_span := building_depth - corner_cut - 2.0
	for i in VENT_COUNT:
		var z := BUILDING_BACK_Z + 1.0 + vent_span * (i + 0.5) / VENT_COUNT
		var spot := Vector3(east, deck_top + building_height * 0.55, z)
		MeshBuilder.add_box(trim, Vector3(0.3, 3.0, 2.0), Transform3D(Basis(), spot))
		MeshBuilder.add_box(glow, Vector3(0.4, 2.4, 1.4), Transform3D(Basis(), spot))

	for spot in STACK_SPOTS:
		var top := deck_top + stack_height
		_add_round(stacks, spot, stack_radius, deck_top, top)
		_add_round(collars, spot, stack_radius + 0.25, top - 0.9, top)
		_add_round(glow, spot, stack_radius - 0.2, top, top + 0.15)

	var mesh := ArrayMesh.new()
	for pair in [[walls, wall_color], [roof, roof_color], [stacks, stack_color], [collars, collar_color], [trim, Color("3a3e45")]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	glow.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _glow_material())
	_refinery.mesh = mesh


# The building's outline seen from above, as (x, z) points going around it, pulled
# in by inset on every side. The two south corners are cut at 45 degrees; pulling
# a 45 degree cut in by inset shortens it by inset * (2 - sqrt 2) along each side.
func _footprint(inset: float) -> Array:
	var west := -building_width / 2.0 + inset
	var east := building_width / 2.0 - inset
	var north := BUILDING_BACK_Z + inset
	var south := BUILDING_BACK_Z + building_depth - inset
	var cut := corner_cut - inset * (2.0 - sqrt(2.0))
	return [
		Vector2(west, north), Vector2(east, north),
		Vector2(east, south - cut), Vector2(east - cut, south),
		Vector2(west + cut, south), Vector2(west, south - cut),
	]


func _add_round(st: SurfaceTool, center: Vector3, radius: float, bottom: float, top: float) -> void:
	var piece := SurfaceTool.new()
	piece.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_prism(piece, STACK_SIDES, radius, radius, bottom, top, PI / STACK_SIDES)
	st.append_from(piece.commit(), 0, Transform3D(Basis(), center))


func _glow_material() -> StandardMaterial3D:
	var material := MeshBuilder.make_material(glow_color)
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = 1.0
	return material
