@tool
extends Node3D
## A chunk of comet ice, carved out by laser and towed home. The flat top is the cut
## face that locks into the electrolysis plant's cradle, and the cone hangs below it.
## Every chunk has the same general shape: about 50 m across and a cone. The seed
## changes the details: lumps, glacier-like ridges running down the sides, a slight
## lean, uneven layers and the blue and dirty patches. The origin is the center of
## the top face. Distances are in meters.

@export var chunk_seed := 1:
	set(value):
		chunk_seed = value
		_rebuild()
@export var width := 50.0:
	set(value):
		width = value
		_rebuild()
@export var depth := 40.0:
	set(value):
		depth = value
		_rebuild()
## Big rounded bulges and hollows, as a share of the radius.
@export_range(0.0, 0.3) var lumpiness := 0.13:
	set(value):
		lumpiness = value
		_rebuild()
## Long grooves running down the sides, as a share of the radius.
@export_range(0.0, 0.3) var ridge_strength := 0.1:
	set(value):
		ridge_strength = value
		_rebuild()
## How far the tip can wander off center, as a share of the radius.
@export_range(0.0, 0.4) var lean := 0.15:
	set(value):
		lean = value
		_rebuild()
@export var ice_color := Color("dcecf5"):
	set(value):
		ice_color = value
		_rebuild()
@export var deep_color := Color("6fa8d6"):
	set(value):
		deep_color = value
		_rebuild()
@export var dirt_color := Color("7d7f85"):
	set(value):
		dirt_color = value
		_rebuild()
@export var cut_color := Color("a9c3d6"):
	set(value):
		cut_color = value
		_rebuild()

const SIDES := 32
const RINGS := 12
# How much smaller the blunt tip is than the top, as a share of the radius.
const TIP_SIZE := 0.08

var _mesh_instance: MeshInstance3D
var _tint: FastNoiseLite
var _dirt: FastNoiseLite


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)

	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed
	var lumps := _make_noise(rng.randi(), 0.035)
	var ridges := _make_noise(rng.randi(), 0.12)
	_tint = _make_noise(rng.randi(), 0.05)
	_dirt = _make_noise(rng.randi(), 0.04)

	var radius := width / 2.0
	var height := depth * rng.randf_range(0.9, 1.1)
	var stretch := Vector2(rng.randf_range(0.9, 1.1), rng.randf_range(0.9, 1.1))
	var tip_offset := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).limit_length(1.0) * lean * radius

	var rings := []
	var centers := []
	for k in RINGS + 1:
		var t := float(k) / RINGS
		if k > 0 and k < RINGS:
			t += rng.randf_range(-0.3, 0.3) / RINGS
		var center := Vector3(tip_offset.x * t * t, -height * t, tip_offset.y * t * t)
		var ring_radius := radius * lerpf(1.0, TIP_SIZE, t) * (1.0 + 0.12 * sin(t * PI))
		# The rim was cut cleanly, so it stays rounder than the rest.
		var roughness := lerpf(0.3, 1.0, minf(t * 3.0, 1.0)) * radius
		var twist := rng.randf_range(-0.5, 0.5) * TAU / SIDES
		var points := []
		for i in SIDES:
			var angle := i * TAU / SIDES + twist
			var direction := Vector3(cos(angle) * stretch.x, 0.0, sin(angle) * stretch.y)
			var point := center + direction * ring_radius
			var bulge := lumps.get_noise_3dv(point) * lumpiness
			var groove := ridges.get_noise_3d(point.x, point.y * 0.15, point.z) * ridge_strength
			points.append(point + direction.normalized() * (bulge + groove) * roughness)
		rings.append(points)
		centers.append(center)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in RINGS:
		var upper: Array = rings[k]
		var lower: Array = rings[k + 1]
		var axis: Vector3 = (centers[k] + centers[k + 1]) / 2.0
		for i in SIDES:
			var j := (i + 1) % SIDES
			_add_ice_triangle(st, upper[i], upper[j], lower[j], axis)
			_add_ice_triangle(st, upper[i], lower[j], lower[i], axis)

	var tip: Vector3 = centers[RINGS] + Vector3(0, -radius * TIP_SIZE, 0)
	var last: Array = rings[RINGS]
	for i in SIDES:
		_add_ice_triangle(st, last[i], last[(i + 1) % SIDES], tip, centers[RINGS])

	var top: Array = rings[0]
	for i in SIDES:
		st.set_color(cut_color.lerp(deep_color, 0.3 + 0.3 * _tint.get_noise_3dv(top[i])))
		MeshBuilder.add_triangle(st, Vector3.ZERO, top[i], top[(i + 1) % SIDES], Vector3.UP)

	var mesh := st.commit()
	mesh.surface_set_material(0, _ice_material())
	_mesh_instance.mesh = mesh


# Colors each face from where it sits: mostly pale ice, with deep blue bands and
# a few dirty patches.
func _add_ice_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, axis: Vector3) -> void:
	var middle := (a + b + c) / 3.0
	var band := 0.5 + 0.5 * sin(middle.y * 0.45 + _tint.get_noise_3dv(middle) * 4.0)
	var color := ice_color.lerp(deep_color, smoothstep(0.55, 1.0, band) * 0.8)
	var dirt := smoothstep(0.25, 0.55, _dirt.get_noise_3dv(middle))
	color = color.lerp(dirt_color, dirt * 0.7)
	st.set_color(color)
	MeshBuilder.add_triangle(st, a, b, c, middle - Vector3(axis.x, middle.y, axis.z))


func _make_noise(noise_seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	return noise


func _ice_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.35
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = deep_color * 0.08
	return material
