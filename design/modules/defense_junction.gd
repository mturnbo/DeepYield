@tool
extends "res://design/modules/reinforcing_junction.gd"
## The defense junction: the same block as a reinforcing junction, with a red band
## and a phased plasma turret on top and another hanging underneath. Each turret is a
## low drum with a domed top that turns all the way around, and twin red barrels on a
## mount that tilts from level up to 60 degrees, away from the platform. The muzzles
## glow. While scanning, the turrets turn slowly, the bottom one the other way, and
## their barrels rise and fall. Distances are in meters. Scanning plays in the
## editor too.

## How fast the turrets turn while scanning, in degrees per second. 0 stops scanning,
## and the barrels hold at tilt_deg.
@export var scan_speed_deg := 8.0
## How far the barrels tilt up from level when the turrets aren't scanning.
@export_range(0.0, 60.0) var tilt_deg := 20.0:
	set(value):
		tilt_deg = value
		_set_tilt(value)
@export var turret_color := Color("7d8696"):
	set(value):
		turret_color = value
		_rebuild()
@export var barrel_color := Color("e5534b"):
	set(value):
		barrel_color = value
		_rebuild()
@export var plasma_color := Color("c77dff"):
	set(value):
		plasma_color = value
		_rebuild()

const TURRET_SIDES := 16
const BARREL_LENGTH := 4.5
const MAX_TILT_DEG := 60.0
# While scanning, the barrels go from level to fully up and back over this many seconds.
const TILT_PERIOD := 16.0
# Where the barrel mount pivots, on the drum's side.
const GUN_PIVOT := Vector3(2.7, 1.2, 0)

# Each turret hangs off a fixed mount, turns on a yaw node inside it, and tilts its
# barrels on a pitch node inside that.
var _mounts: Array[Node3D] = []
var _yaws: Array[Node3D] = []
var _pitches: Array[Node3D] = []
var _time := 0.0


func _init() -> void:
	band_color = Color("e5534b")


func _process(delta: float) -> void:
	if scan_speed_deg == 0.0:
		return
	_time += delta
	for yaw in _yaws:
		yaw.rotate_y(deg_to_rad(scan_speed_deg) * delta)
	_set_tilt(MAX_TILT_DEG * (0.5 - 0.5 * cos(_time * TAU / TILT_PERIOD)))


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _mounts.is_empty():
		for flip in [false, true]:
			var mount := Node3D.new()
			mount.position = Vector3(0, KEEL_BOTTOM if flip else DECK_TOP, 0)
			if flip:
				mount.rotation = Vector3(PI, 0, 0)
			add_child(mount)
			var yaw := Node3D.new()
			mount.add_child(yaw)
			yaw.add_child(MeshInstance3D.new())
			var pitch := Node3D.new()
			pitch.position = GUN_PIVOT
			yaw.add_child(pitch)
			pitch.add_child(MeshInstance3D.new())
			_mounts.append(mount)
			_yaws.append(yaw)
			_pitches.append(pitch)

	var body := _make_body_mesh()
	var gun := _make_gun_mesh()
	for i in _yaws.size():
		(_yaws[i].get_child(0) as MeshInstance3D).mesh = body
		(_pitches[i].get_child(0) as MeshInstance3D).mesh = gun
	_set_tilt(tilt_deg)


# Tilting turns the barrel mount about its pivot, raising the barrels' far end.
func _set_tilt(degrees: float) -> void:
	for pitch in _pitches:
		pitch.rotation = Vector3(0, 0, deg_to_rad(clampf(degrees, 0.0, MAX_TILT_DEG)))


# The turret standing up from its mount: a dark ring, the drum, a shoulder and a low dome.
func _make_body_mesh() -> ArrayMesh:
	var ring := SurfaceTool.new()
	var drum := SurfaceTool.new()
	for st in [ring, drum]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offset := PI / TURRET_SIDES
	MeshBuilder.add_prism(ring, TURRET_SIDES, 3.0, 3.0, 0.0, 0.4, offset)
	MeshBuilder.add_prism(drum, TURRET_SIDES, 2.7, 2.7, 0.4, 1.9, offset)
	MeshBuilder.add_prism(drum, TURRET_SIDES, 2.7, 2.1, 1.9, 2.4, offset)
	MeshBuilder.add_prism(drum, TURRET_SIDES, 1.6, 1.6, 2.4, 2.9, offset)

	var mesh := ArrayMesh.new()
	ring.commit(mesh)
	mesh.surface_set_material(0, MeshBuilder.make_material(Color("3a3e45")))
	drum.commit(mesh)
	mesh.surface_set_material(1, MeshBuilder.make_material(turret_color))
	return mesh


# The barrel mount around its pivot, with twin barrels reaching out along +X and a
# glowing muzzle on each.
func _make_gun_mesh() -> ArrayMesh:
	var mount := SurfaceTool.new()
	var barrels := SurfaceTool.new()
	var muzzles := SurfaceTool.new()
	for st in [mount, barrels, muzzles]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_box(mount, Vector3(1.0, 1.0, 1.8), Transform3D())
	for z in [-0.55, 0.55]:
		MeshBuilder.add_box(barrels, Vector3(BARREL_LENGTH, 0.35, 0.35), Transform3D(Basis(), Vector3(BARREL_LENGTH / 2.0, 0, z)))
		MeshBuilder.add_box(muzzles, Vector3(0.2, 0.3, 0.3), Transform3D(Basis(), Vector3(BARREL_LENGTH + 0.1, 0, z)))

	var mesh := ArrayMesh.new()
	mount.commit(mesh)
	mesh.surface_set_material(0, MeshBuilder.make_material(Color("3a3e45")))
	barrels.commit(mesh)
	mesh.surface_set_material(1, MeshBuilder.make_material(barrel_color))
	muzzles.commit(mesh)
	var glow := MeshBuilder.make_material(plasma_color)
	glow.emission_enabled = true
	glow.emission = plasma_color
	glow.emission_energy_multiplier = 2.0
	mesh.surface_set_material(2, glow)
	return mesh
