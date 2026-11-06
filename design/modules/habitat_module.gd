@tool
extends "res://design/modules/module_base.gd"
## The habitat module: a module base with a green band and a round drum on top.
## The drum has a ring of lit windows, and a glass garden dome sits on it with
## a few trees inside. Distances are in meters.

@export var drum_radius := 13.2:
	set(value):
		drum_radius = value
		_rebuild()
@export var drum_height := 9.0:
	set(value):
		drum_height = value
		_rebuild()
@export var dome_radius := 10.7:
	set(value):
		dome_radius = value
		_rebuild()
@export var dome_height := 12.0:
	set(value):
		dome_height = value
		_rebuild()
@export_range(1, 12) var tree_count := 6:
	set(value):
		tree_count = value
		_rebuild()
@export var window_color := Color("ffe061"):
	set(value):
		window_color = value
		_rebuild()
@export var lip_color := Color("7d8696"):
	set(value):
		lip_color = value
		_rebuild()
@export var glass_color := Color(0.5, 0.85, 0.6, 0.35):
	set(value):
		glass_color = value
		_rebuild()
@export var garden_color := Color("3f6b4c"):
	set(value):
		garden_color = value
		_rebuild()
@export var tree_color := Color("5ea072"):
	set(value):
		tree_color = value
		_rebuild()

const DRUM_SIDES := 16
const DOME_RINGS := 6
const LIP_HEIGHT := 0.9

var _drum: MeshInstance3D


func _init() -> void:
	band_color = Color("5dbb7a")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _drum == null:
		_drum = MeshInstance3D.new()
		add_child(_drum)

	var walls := SurfaceTool.new()
	var roof := SurfaceTool.new()
	var lip := SurfaceTool.new()
	var lights := SurfaceTool.new()
	var garden := SurfaceTool.new()
	var trees := SurfaceTool.new()
	var glass := SurfaceTool.new()
	for st in [walls, roof, lip, lights, garden, trees, glass]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var deck_top := hull_height / 2.0 + band_height + deck_height
	var drum_top := deck_top + drum_height
	var dome_base := drum_top + LIP_HEIGHT

	_add_round(walls, drum_radius, deck_top, drum_top)
	_add_round(roof, drum_radius - 0.4, drum_top, drum_top + 0.2)
	_add_round(lip, dome_radius + 1.5, drum_top, dome_base)
	_add_windows(lights, deck_top + drum_height * 0.45)
	_add_round(garden, dome_radius - 0.2, dome_base, dome_base + 0.3)
	_add_trees(trees, dome_base + 0.3)
	_add_dome(glass, dome_base)

	var mesh := ArrayMesh.new()
	for pair in [[walls, hull_color], [roof, deck_color], [lip, lip_color], [garden, garden_color], [trees, tree_color]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	lights.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _window_material())
	glass.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _glass_material())
	_drum.mesh = mesh


# One lit window on each side of the drum.
func _add_windows(st: SurfaceTool, center_y: float) -> void:
	var apothem := drum_radius * cos(PI / DRUM_SIDES)
	var side_length := 2.0 * drum_radius * sin(PI / DRUM_SIDES)
	var size := Vector3(0.2, 2.7, side_length * 0.55)
	for i in DRUM_SIDES:
		var facing := Basis(Vector3.UP, i * TAU / DRUM_SIDES)
		MeshBuilder.add_box(st, size, Transform3D(facing, facing * Vector3(apothem, center_y, 0)))


# Low cone trees in a ring on the garden floor.
func _add_trees(st: SurfaceTool, floor_y: float) -> void:
	var ring := dome_radius * 0.55
	for i in tree_count:
		var angle := i * TAU / tree_count
		var height := 3.5 + 1.2 * sin(i * 2.3)
		var tree := SurfaceTool.new()
		tree.begin(Mesh.PRIMITIVE_TRIANGLES)
		MeshBuilder.add_prism(tree, 6, 1.6, 0.0, floor_y, floor_y + height, angle)
		st.append_from(tree.commit(), 0, Transform3D(Basis(), Vector3(cos(angle) * ring, 0.0, sin(angle) * ring)))
	MeshBuilder.add_prism(st, 6, 2.0, 0.0, floor_y, floor_y + 5.5, 0.0)


# A faceted dome: rings of glass panels following a rounded profile, closed at the top.
func _add_dome(st: SurfaceTool, base_y: float) -> void:
	var rings := []
	for k in DOME_RINGS + 1:
		var t := k * (PI / 2.0) / (DOME_RINGS + 1)
		rings.append(_ring_points(dome_radius * cos(t), base_y + dome_height * sin(t)))
	var center := Vector3(0, base_y, 0)
	for k in DOME_RINGS:
		var lower: Array = rings[k]
		var upper: Array = rings[k + 1]
		for i in DRUM_SIDES:
			var j := (i + 1) % DRUM_SIDES
			var outward: Vector3 = (lower[i] + upper[j]) / 2.0 - center
			MeshBuilder.add_quad(st, lower[i], lower[j], upper[j], upper[i], outward)
	var top := Vector3(0, base_y + dome_height, 0)
	var last: Array = rings[DOME_RINGS]
	for i in DRUM_SIDES:
		var j := (i + 1) % DRUM_SIDES
		MeshBuilder.add_triangle(st, last[i], last[j], top, (last[i] + last[j]) / 2.0 - center)


func _ring_points(radius: float, y: float) -> Array:
	var points := []
	for i in DRUM_SIDES:
		var angle := PI / DRUM_SIDES + i * TAU / DRUM_SIDES
		points.append(Vector3(cos(angle) * radius, y, sin(angle) * radius))
	return points


func _add_round(st: SurfaceTool, radius: float, bottom: float, top: float) -> void:
	MeshBuilder.add_prism(st, DRUM_SIDES, radius, radius, bottom, top, PI / DRUM_SIDES)


func _window_material() -> StandardMaterial3D:
	var material := MeshBuilder.make_material(window_color)
	material.emission_enabled = true
	material.emission = window_color * 0.7
	return material


func _glass_material() -> StandardMaterial3D:
	var material := MeshBuilder.make_material(glass_color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.15
	material.metallic = 0.0
	return material
