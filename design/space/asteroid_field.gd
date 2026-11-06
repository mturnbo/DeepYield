@tool
extends Node3D
## A field of low-poly, flat-shaded asteroids.
## Move this node to move the field. Change any setting in the Inspector and the
## field rebuilds in the editor right away.

@export var field_seed := 7:
	set(value):
		field_seed = value
		_rebuild()
@export_range(1, 600) var asteroid_count := 110:
	set(value):
		asteroid_count = value
		_rebuild()
@export var field_radius := 22.0:
	set(value):
		field_radius = value
		_rebuild()
@export var field_thickness := 3.0:
	set(value):
		field_thickness = value
		_rebuild()
@export var min_size := 0.2:
	set(value):
		min_size = value
		_rebuild()
@export var max_size := 2.4:
	set(value):
		max_size = value
		_rebuild()
@export_range(0.0, 1.0) var lumpiness := 0.25:
	set(value):
		lumpiness = value
		_rebuild()
@export var spin_speed := 0.2
@export var rock_colors: Array[Color] = [
	Color("5b5e68"),
	Color("464851"),
	Color("6e655c"),
	Color("7a5546"),
	Color("5d6b5e"),
	Color("4b5368"),
]

const SHAPE_VARIANTS := 12

var _rocks: Array[MeshInstance3D] = []
var _spin_axes: Array[Vector3] = []
var _spin_rates: Array[float] = []


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for i in _rocks.size():
		_rocks[i].rotate(_spin_axes[i], _spin_rates[i] * spin_speed * delta)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for rock in _rocks:
		rock.queue_free()
	_rocks.clear()
	_spin_axes.clear()
	_spin_rates.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed

	var meshes: Array[ArrayMesh] = []
	for i in SHAPE_VARIANTS:
		meshes.append(_make_rock_mesh(rng))

	var materials: Array[StandardMaterial3D] = []
	for color in rock_colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials.append(material)

	for i in asteroid_count:
		var rock := MeshInstance3D.new()
		rock.mesh = meshes[rng.randi() % meshes.size()]
		rock.material_override = materials[rng.randi() % materials.size()]
		var size := lerpf(min_size, max_size, pow(rng.randf(), 4.0))
		rock.position = _open_position(rng, size)
		rock.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		rock.scale = Vector3.ONE * size
		add_child(rock)
		_rocks.append(rock)
		_spin_axes.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
		_spin_rates.append(rng.randf_range(0.2, 1.0))


# Tries a few spots and keeps the first one that doesn't overlap another rock.
func _open_position(rng: RandomNumberGenerator, size: float) -> Vector3:
	var spot := _random_position(rng)
	for attempt in 12:
		var clear := true
		for rock in _rocks:
			if rock.position.distance_to(spot) < (rock.scale.x + size) * 1.3:
				clear = false
				break
		if clear:
			return spot
		spot = _random_position(rng)
	return spot


func _random_position(rng: RandomNumberGenerator) -> Vector3:
	# Denser toward the middle, thinner at the edges.
	var angle := rng.randf() * TAU
	var distance := field_radius * pow(rng.randf(), 0.75)
	var height := rng.randfn(0.0, field_thickness * 0.5)
	return Vector3(cos(angle) * distance, height, sin(angle) * distance)


func _make_rock_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	var stretch := Vector3(rng.randf_range(0.7, 1.3), rng.randf_range(0.6, 1.0), rng.randf_range(0.7, 1.3))

	var points := _icosphere_points()
	for i in points.size():
		var p := points[i]
		points[i] = p * (1.0 + noise.get_noise_3dv(p * 1.7) * lumpiness * 2.0) * stretch

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in _icosphere_faces():
		var a := points[face[0]]
		var b := points[face[1]]
		var c := points[face[2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(a + b + c) < 0.0:
			normal = -normal
		surface.set_normal(normal)
		surface.add_vertex(a)
		surface.set_normal(normal)
		surface.add_vertex(b)
		surface.set_normal(normal)
		surface.add_vertex(c)
	return surface.commit()


# An icosahedron subdivided once: 42 points and 80 faces.
var _ico_points: PackedVector3Array = []
var _ico_faces: Array[PackedInt32Array] = []


func _icosphere_points() -> PackedVector3Array:
	if _ico_points.is_empty():
		_build_icosphere()
	return _ico_points.duplicate()


func _icosphere_faces() -> Array[PackedInt32Array]:
	if _ico_faces.is_empty():
		_build_icosphere()
	return _ico_faces


func _build_icosphere() -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var corners := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	_ico_points = PackedVector3Array()
	for corner in corners:
		_ico_points.append(corner.normalized())

	var midpoints := {}
	for face in faces:
		var ab := _midpoint(face[0], face[1], midpoints)
		var bc := _midpoint(face[1], face[2], midpoints)
		var ca := _midpoint(face[2], face[0], midpoints)
		_ico_faces.append(PackedInt32Array([face[0], ab, ca]))
		_ico_faces.append(PackedInt32Array([face[1], bc, ab]))
		_ico_faces.append(PackedInt32Array([face[2], ca, bc]))
		_ico_faces.append(PackedInt32Array([ab, bc, ca]))


func _midpoint(a: int, b: int, cache: Dictionary) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if cache.has(key):
		return cache[key]
	_ico_points.append(((_ico_points[a] + _ico_points[b]) / 2.0).normalized())
	cache[key] = _ico_points.size() - 1
	return cache[key]
