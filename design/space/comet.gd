@tool
extends Node3D
## A comet passing the platform: an icy nucleus inside a soft glow, with a blue ion
## tail and a pale dust tail that point away from the sun. It drifts very slowly and
## tumbles. Distances are in meters. This plays in the editor too.

@export var sun: DirectionalLight3D
@export var comet_seed := 3:
	set(value):
		comet_seed = value
		_rebuild()
@export var nucleus_size := 30.0:
	set(value):
		nucleus_size = value
		_rebuild()
@export var coma_radius := 110.0:
	set(value):
		coma_radius = value
		_rebuild()
@export var ion_tail_length := 650.0:
	set(value):
		ion_tail_length = value
		_rebuild()
@export var dust_tail_length := 420.0:
	set(value):
		dust_tail_length = value
		_rebuild()
@export var ice_color := Color("cfe3ee"):
	set(value):
		ice_color = value
		_rebuild()
@export var coma_color := Color(0.55, 0.8, 1.0):
	set(value):
		coma_color = value
		_rebuild()
@export var ion_tail_color := Color(0.35, 0.6, 1.0):
	set(value):
		ion_tail_color = value
		_rebuild()
@export var dust_tail_color := Color(0.95, 0.9, 0.8):
	set(value):
		dust_tail_color = value
		_rebuild()
@export var drift_velocity := Vector3(0.5, 0.0, -0.3)
@export var spin_speed := 0.04

const GLOW_SHADER := preload("res://design/space/comet_glow.gdshader")
# How far the dust tail bends back from the comet's path.
const DUST_TAIL_LAG := 0.35

var _body: Node3D
var _nucleus: MeshInstance3D
var _ion_tail: Node3D
var _dust_tail: Node3D
var _spin_axis := Vector3.UP


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if _body == null:
		return
	_body.position += drift_velocity * delta
	_nucleus.rotate(_spin_axis, spin_speed * delta)
	if sun == null:
		return
	# Light travels along the sun's -Z, which is also the direction away from the sun.
	var away := -sun.global_basis.z
	_point_tail(_ion_tail, away)
	_point_tail(_dust_tail, away - drift_velocity.normalized() * DUST_TAIL_LAG)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _body != null:
		_body.queue_free()
	_body = Node3D.new()
	add_child(_body)

	var rng := RandomNumberGenerator.new()
	rng.seed = comet_seed
	_nucleus = MeshInstance3D.new()
	_nucleus.mesh = MeshBuilder.make_rock_mesh(rng, 0.3)
	_nucleus.scale = Vector3.ONE * nucleus_size
	var ice := StandardMaterial3D.new()
	ice.albedo_color = ice_color
	ice.roughness = 0.5
	ice.emission_enabled = true
	ice.emission = ice_color * 0.25
	ice.cull_mode = BaseMaterial3D.CULL_DISABLED
	_nucleus.material_override = ice
	_body.add_child(_nucleus)
	_spin_axis = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()

	var coma := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = coma_radius
	sphere.height = coma_radius * 2.0
	coma.mesh = sphere
	coma.material_override = _glow_material(coma_color, 0.3, 3.5, 0.0)
	coma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(coma)

	_ion_tail = _make_tail(ion_tail_length, coma_radius * 0.15, coma_radius * 0.5, ion_tail_color, 0.35)
	_dust_tail = _make_tail(dust_tail_length, coma_radius * 0.3, coma_radius * 1.1, dust_tail_color, 0.22)


# A tail is a pivot at the head with a widening cone that runs along the pivot's -Z.
func _make_tail(tail_length: float, head_radius: float, end_radius: float, color: Color, strength: float) -> Node3D:
	var pivot := Node3D.new()
	_body.add_child(pivot)
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = tail_length
	mesh.bottom_radius = head_radius
	mesh.top_radius = end_radius
	mesh.radial_segments = 24
	mesh.cap_top = false
	mesh.cap_bottom = false
	cone.mesh = mesh
	cone.material_override = _glow_material(color, strength, 2.5, tail_length)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.rotation = Vector3(-PI / 2.0, 0, 0)
	cone.position = Vector3(0, 0, -tail_length / 2.0)
	pivot.add_child(cone)
	return pivot


func _point_tail(pivot: Node3D, direction: Vector3) -> void:
	var up := Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.FORWARD
	pivot.look_at(pivot.global_position + direction, up)


func _glow_material(color: Color, strength: float, softness: float, tail_length: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GLOW_SHADER
	material.set_shader_parameter("glow_color", color)
	material.set_shader_parameter("intensity", strength)
	material.set_shader_parameter("edge_softness", softness)
	material.set_shader_parameter("tail_length", tail_length)
	return material
