@tool
extends Node3D
## A field of low-poly, flat-shaded asteroids. Distances are in meters.
## Move this node to move the field. Change any setting in the Inspector and the
## field rebuilds in the editor right away.
## The whole formation turns slowly, each rock wanders a little around its spot,
## and each rock tumbles. This plays in the editor too.

@export var field_seed := 7:
	set(value):
		field_seed = value
		_rebuild()
@export_range(1, 600) var asteroid_count := 110:
	set(value):
		asteroid_count = value
		_rebuild()
@export var field_radius := 130.0:
	set(value):
		field_radius = value
		_rebuild()
@export var field_thickness := 18.0:
	set(value):
		field_thickness = value
		_rebuild()
@export var min_size := 1.2:
	set(value):
		min_size = value
		_rebuild()
@export var max_size := 14.0:
	set(value):
		max_size = value
		_rebuild()
@export_range(0.0, 1.0) var lumpiness := 0.25:
	set(value):
		lumpiness = value
		_rebuild()
@export var spin_speed := 0.06
@export var formation_turn_speed_deg := 0.4
@export var wander_distance := 2.4
@export var wander_period := 60.0
@export var rock_colors: Array[Color] = [
	Color("5b5e68"),
	Color("464851"),
	Color("6e655c"),
	Color("7a5546"),
	Color("5d6b5e"),
	Color("4b5368"),
]

const SHAPE_VARIANTS := 12

var _formation: Node3D
var _rocks: Array[MeshInstance3D] = []
var _homes: Array[Vector3] = []
var _wander_phases: Array[Vector3] = []
var _wander_rates: Array[float] = []
var _spin_axes: Array[Vector3] = []
var _spin_rates: Array[float] = []
var _time := 0.0


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if _formation == null:
		return
	_time += delta
	_formation.rotate_y(deg_to_rad(formation_turn_speed_deg) * delta)
	var base_rate := TAU / wander_period
	for i in _rocks.size():
		var t := _time * base_rate * _wander_rates[i]
		var phase := _wander_phases[i]
		var offset := Vector3(sin(t + phase.x), 0.5 * sin(t * 0.7 + phase.y), sin(t * 0.85 + phase.z))
		_rocks[i].position = _homes[i] + offset * wander_distance
		_rocks[i].rotate(_spin_axes[i], _spin_rates[i] * spin_speed * delta)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _formation == null:
		_formation = Node3D.new()
		add_child(_formation)
	for rock in _rocks:
		rock.queue_free()
	_rocks.clear()
	_homes.clear()
	_wander_phases.clear()
	_wander_rates.clear()
	_spin_axes.clear()
	_spin_rates.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed
	# Separate generator for motion so the layout stays the same for a given seed.
	var motion_rng := RandomNumberGenerator.new()
	motion_rng.seed = field_seed + 1

	var meshes: Array[ArrayMesh] = []
	for i in SHAPE_VARIANTS:
		meshes.append(MeshBuilder.make_rock_mesh(rng, lumpiness))

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
		_formation.add_child(rock)
		_rocks.append(rock)
		_homes.append(rock.position)
		_wander_phases.append(Vector3(motion_rng.randf() * TAU, motion_rng.randf() * TAU, motion_rng.randf() * TAU))
		_wander_rates.append(motion_rng.randf_range(0.7, 1.3))
		_spin_axes.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
		_spin_rates.append(rng.randf_range(0.2, 1.0))


# Tries a few spots and keeps the first one that doesn't overlap another rock.
func _open_position(rng: RandomNumberGenerator, size: float) -> Vector3:
	var spot := _random_position(rng)
	for attempt in 12:
		var clear := true
		for i in _rocks.size():
			if _homes[i].distance_to(spot) < (_rocks[i].scale.x + size) * 1.3:
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
