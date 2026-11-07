@tool
extends "res://design/modules/module_base.gd"
## Helium-3 storage: a module base with a gold band and a single frosted white
## cryogenic sphere held up on four struts, with a gold stripe around it and a
## valve cap on top. Distances are in meters.

@export var sphere_radius := 9.0:
	set(value):
		sphere_radius = value
		_rebuild()
## How high the bottom of the sphere sits above the deck.
@export var clearance := 1.5:
	set(value):
		clearance = value
		_rebuild()
@export var frost_color := Color("e9edf2"):
	set(value):
		frost_color = value
		_rebuild()
@export var stripe_color := Color("ffd36e"):
	set(value):
		stripe_color = value
		_rebuild()
@export var strut_color := Color("606774"):
	set(value):
		strut_color = value
		_rebuild()

const SIDES := 16
const RINGS := 8

var _sphere: MeshInstance3D


func _init() -> void:
	band_color = Color("ffd36e")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _sphere == null:
		_sphere = MeshInstance3D.new()
		add_child(_sphere)

	var frost := SurfaceTool.new()
	var stripe := SurfaceTool.new()
	var struts := SurfaceTool.new()
	for st in [frost, stripe, struts]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var deck_top := hull_height / 2.0 + band_height + deck_height
	var center := Vector3(0, deck_top + clearance + sphere_radius, 0)
	_add_sphere(frost, center)
	MeshBuilder.add_prism(stripe, SIDES, sphere_radius * 1.02, sphere_radius * 1.02, center.y - 2.2, center.y - 0.6, PI / SIDES)
	var cap_bottom := center.y + sphere_radius - 0.4
	MeshBuilder.add_prism(struts, SIDES, sphere_radius * 0.3, sphere_radius * 0.3, cap_bottom, cap_bottom + 1.4, PI / SIDES)

	# Four struts on the diagonals, from the deck up to the sphere's middle.
	var strut_out := sphere_radius + 0.8
	for i in 4:
		var direction := Basis(Vector3.UP, PI / 4.0 + i * PI / 2.0) * Vector3.RIGHT
		var foot := direction * strut_out + Vector3(0, deck_top, 0)
		MeshBuilder.add_box(struts, Vector3(1.1, center.y + 1.0 - deck_top, 1.1), Transform3D(Basis(), foot + Vector3(0, (center.y + 1.0 - deck_top) / 2.0, 0)))
		MeshBuilder.add_strut(struts, foot + Vector3(0, center.y - deck_top, 0), center + direction * (sphere_radius - 0.5), 0.6)

	var mesh := ArrayMesh.new()
	frost.commit(mesh)
	mesh.surface_set_material(0, _frost_material())
	stripe.commit(mesh)
	mesh.surface_set_material(1, MeshBuilder.make_material(stripe_color))
	struts.commit(mesh)
	mesh.surface_set_material(2, MeshBuilder.make_material(strut_color))
	_sphere.mesh = mesh


# A faceted sphere: bands of panels between rings of latitude, closed by a point at each pole.
func _add_sphere(st: SurfaceTool, center: Vector3) -> void:
	var rings := []
	for k in range(1, RINGS):
		var latitude := -PI / 2.0 + k * PI / RINGS
		var ring := []
		for i in SIDES:
			var angle := PI / SIDES + i * TAU / SIDES
			ring.append(center + sphere_radius * Vector3(cos(latitude) * cos(angle), sin(latitude), cos(latitude) * sin(angle)))
		rings.append(ring)

	for k in rings.size() - 1:
		var lower: Array = rings[k]
		var upper: Array = rings[k + 1]
		for i in SIDES:
			var j := (i + 1) % SIDES
			MeshBuilder.add_quad(st, lower[i], lower[j], upper[j], upper[i], (lower[i] + upper[j]) / 2.0 - center)

	var bottom := center + Vector3(0, -sphere_radius, 0)
	var top := center + Vector3(0, sphere_radius, 0)
	var first: Array = rings[0]
	var last: Array = rings[rings.size() - 1]
	for i in SIDES:
		var j := (i + 1) % SIDES
		MeshBuilder.add_triangle(st, first[i], first[j], bottom, (first[i] + first[j] + bottom) / 3.0 - center)
		MeshBuilder.add_triangle(st, last[i], last[j], top, (last[i] + last[j] + top) / 3.0 - center)


func _frost_material() -> StandardMaterial3D:
	var material := MeshBuilder.make_material(frost_color)
	material.roughness = 0.6
	material.metallic = 0.0
	return material
