@tool
extends "res://design/modules/module_base.gd"
## The fusion generator: a module base with a cyan band, a wide glowing cyan ring
## around a dark basin, and the dark reactor core standing in the middle. The top
## of the core glows and slowly pulses between yellow and orange, lighting the core
## around it. Distances are in meters. The pulse plays in the editor too.

@export var ring_radius := 12.8:
	set(value):
		ring_radius = value
		_rebuild()
@export var core_radius := 6.2:
	set(value):
		core_radius = value
		_rebuild()
@export var core_height := 7.5:
	set(value):
		core_height = value
		_rebuild()
@export var ring_color := Color("4fd1e8"):
	set(value):
		ring_color = value
		_rebuild()
@export var basin_color := Color("1c2a44"):
	set(value):
		basin_color = value
		_rebuild()
@export var core_color := Color("2b3550"):
	set(value):
		core_color = value
		_rebuild()
@export var pulse_yellow := Color("ffd84a")
@export var pulse_orange := Color("ff5410")
## Seconds from yellow to orange and back.
@export var pulse_period := 6.0

const RING_SIDES := 24
const CORE_SIDES := 16
const RING_WIDTH := 2.3
const RING_HEIGHT := 2.2

var _generator: MeshInstance3D
var _top: MeshInstance3D
var _top_material: StandardMaterial3D
var _top_light: OmniLight3D
var _time := 0.0


func _init() -> void:
	band_color = Color("4fd1e8")


func _process(delta: float) -> void:
	if _top_material == null:
		return
	_time += delta
	var mix := 0.5 - 0.5 * cos(_time * TAU / pulse_period)
	var color := pulse_yellow.lerp(pulse_orange, mix)
	_top_material.albedo_color = color
	_top_material.emission = color
	_top_light.light_color = color


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _generator == null:
		_generator = MeshInstance3D.new()
		add_child(_generator)
		_top = MeshInstance3D.new()
		add_child(_top)
		_top_light = OmniLight3D.new()
		_top_light.omni_range = 22.0
		_top_light.light_energy = 2.0
		add_child(_top_light)

	var deck_top := hull_height / 2.0 + band_height + deck_height
	var core_top := deck_top + core_height

	var ring := SurfaceTool.new()
	var basin := SurfaceTool.new()
	var core := SurfaceTool.new()
	for st in [ring, basin, core]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_ring(ring, ring_radius - RING_WIDTH, ring_radius, deck_top, deck_top + RING_HEIGHT)
	MeshBuilder.add_prism(basin, RING_SIDES, ring_radius - RING_WIDTH, ring_radius - RING_WIDTH, deck_top, deck_top + RING_HEIGHT * 0.45, PI / RING_SIDES)
	MeshBuilder.add_prism(core, CORE_SIDES, core_radius, core_radius, deck_top, core_top, PI / CORE_SIDES)

	var mesh := ArrayMesh.new()
	ring.commit(mesh)
	mesh.surface_set_material(0, _glow_material(ring_color, 0.7))
	basin.commit(mesh)
	mesh.surface_set_material(1, MeshBuilder.make_material(basin_color))
	core.commit(mesh)
	mesh.surface_set_material(2, MeshBuilder.make_material(core_color))
	_generator.mesh = mesh

	# The glowing top sits inside a dark rim on top of the core.
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_prism(top, CORE_SIDES, core_radius * 0.78, core_radius * 0.78, core_top, core_top + 0.15, PI / CORE_SIDES)
	_top_material = _glow_material(pulse_yellow, 1.2)
	var top_mesh := top.commit()
	top_mesh.surface_set_material(0, _top_material)
	_top.mesh = top_mesh
	_top_light.position = Vector3(0, core_top + 3.0, 0)
	_top_light.light_color = pulse_yellow


# A flat ring: outer and inner walls with a top and bottom between them.
func _add_ring(st: SurfaceTool, inner: float, outer: float, bottom: float, top: float) -> void:
	for i in RING_SIDES:
		var a0 := PI / RING_SIDES + i * TAU / RING_SIDES
		var a1 := a0 + TAU / RING_SIDES
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var middle := (d0 + d1) / 2.0
		var up := Vector3(0, top, 0)
		var down := Vector3(0, bottom, 0)
		MeshBuilder.add_quad(st, d0 * outer + down, d1 * outer + down, d1 * outer + up, d0 * outer + up, middle)
		MeshBuilder.add_quad(st, d0 * inner + down, d0 * inner + up, d1 * inner + up, d1 * inner + down, -middle)
		MeshBuilder.add_quad(st, d0 * inner + up, d0 * outer + up, d1 * outer + up, d1 * inner + up, Vector3.UP)
		MeshBuilder.add_quad(st, d0 * inner + down, d1 * inner + down, d1 * outer + down, d0 * outer + down, Vector3.DOWN)


func _glow_material(color: Color, strength: float) -> StandardMaterial3D:
	var material := MeshBuilder.make_material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = strength
	return material
