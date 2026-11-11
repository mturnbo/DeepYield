@tool
extends "res://design/modules/module_base.gd"
## The trade port: a module base with a mint band, stacked cargo crates on the
## south half of the deck and a crane in the north-east corner. The crane's mint
## boom reaches west over the north half, with a hook hanging near its tip.
## West of the mast, a cargo lift rises out of a shaft in the deck, bringing a
## crate up from inside the module base. Distances are in meters.

@export var mast_height := 16.0:
	set(value):
		mast_height = value
		_rebuild()
@export var boom_length := 24.0:
	set(value):
		boom_length = value
		_rebuild()
@export var mast_color := Color("7d8696"):
	set(value):
		mast_color = value
		_rebuild()
## How far the lift platform stands above the deck. 0 leaves it flush with the deck.
@export var lift_height := 2.5:
	set(value):
		lift_height = value
		_rebuild()

# Each crate: x and z of its center, which layer it sits in, and its color.
const CRATES := [
	[-3.2, 2.0, 0, Color("e36fa8")], [-3.2, 2.0, 1, Color("e36fa8")],
	[3.5, 2.0, 0, Color("a9ddf5")], [3.5, 2.0, 1, Color("c0714a")],
	[-3.2, 7.4, 0, Color("c0714a")],
	[3.5, 7.4, 0, Color("8fa3b8")],
]
const CRATE_SIZE := Vector3(6.0, 4.0, 4.6)
const CRATE_FRAME := 0.35
const MAST_SPOT := Vector3(7.7, 0, -5.6)
const MAST_WIDTH := 1.8
const BOOM_SIZE := 1.6
const BOOM_TAIL := 3.0
const CABLE_LENGTH := 5.5
const HOOK_SIZE := Vector3(1.0, 0.8, 1.0)
const DARK := Color("3a3e45")
const LIFT_SPOT := Vector3(-4.0, 0, -6.6)
const LIFT_PLATFORM := Vector3(7.0, 0.4, 5.6)
const LIFT_GAP := 0.3
const LIFT_TRIM := 0.5
const LIFT_POST := 0.5
const LIFT_POST_HEIGHT := 7.5
const LIFT_CRATE_COLOR := Color("a9ddf5")
const SHAFT_COLOR := Color("14171c")
const HAZARD_COLOR := Color("f2c230")
const PLATFORM_COLOR := Color("7b8290")

var _port: MeshInstance3D


func _init() -> void:
	band_color = Color("59d4b0")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _port == null:
		_port = MeshInstance3D.new()
		add_child(_port)

	var mesh := ArrayMesh.new()
	var deck_top := hull_height / 2.0 + band_height + deck_height
	_add_crates(mesh, _crate_list(deck_top))
	_add_lift(mesh, deck_top)
	_add_crane(mesh, deck_top)
	_port.mesh = mesh


# Every crate as its center and color: the stacks on the deck plus the one
# riding the lift.
func _crate_list(deck_top: float) -> Array:
	var crates := []
	for crate in CRATES:
		crates.append([Vector3(crate[0], deck_top + CRATE_SIZE.y * (crate[2] + 0.5), crate[1]), crate[3]])
	var platform_top := deck_top + lift_height
	crates.append([LIFT_SPOT + Vector3(0, platform_top + CRATE_SIZE.y / 2.0, 0), LIFT_CRATE_COLOR])
	return crates


# Crates are grouped by color so each color is one surface. Each crate has a
# darker frame around both ends.
func _add_crates(mesh: ArrayMesh, crates: Array) -> void:
	var by_color := {}
	for crate in crates:
		var color: Color = crate[1]
		if not by_color.has(color):
			by_color[color] = []
		by_color[color].append(crate[0])

	var frames := SurfaceTool.new()
	frames.begin(Mesh.PRIMITIVE_TRIANGLES)
	for color in by_color:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for center in by_color[color]:
			_box(st, CRATE_SIZE, center)
			for end in [-1.0, 1.0]:
				_add_crate_frame(frames, center + Vector3(end * (CRATE_SIZE.x - CRATE_FRAME) / 2.0, 0, 0))
		_commit(st, mesh, color)
	_commit(frames, mesh, DARK)


# A raised ring around one end of a crate, standing slightly proud of every face.
func _add_crate_frame(st: SurfaceTool, center: Vector3) -> void:
	var proud := 0.06
	var depth := CRATE_FRAME + proud * 2.0
	var tall := CRATE_SIZE.y + proud * 2.0
	var wide := CRATE_SIZE.z + proud * 2.0
	var bar_y := (CRATE_SIZE.y - CRATE_FRAME) / 2.0 + proud
	var bar_z := (CRATE_SIZE.z - CRATE_FRAME) / 2.0 + proud
	for side in [-1.0, 1.0]:
		_box(st, Vector3(depth, CRATE_FRAME, wide), center + Vector3(0, side * bar_y, 0))
		_box(st, Vector3(depth, tall, CRATE_FRAME), center + Vector3(0, 0, side * bar_z))


# A dark shaft opening in the deck with a hazard-striped rim, a guide post at each
# corner, and the platform raised on a central ram.
func _add_lift(mesh: ArrayMesh, deck_top: float) -> void:
	var shaft := SurfaceTool.new()
	var hazard := SurfaceTool.new()
	var posts := SurfaceTool.new()
	var platform := SurfaceTool.new()
	for st in [shaft, hazard, posts, platform]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var opening := Vector3(LIFT_PLATFORM.x + LIFT_GAP * 2.0, 0.04, LIFT_PLATFORM.z + LIFT_GAP * 2.0)
	_box(shaft, opening, LIFT_SPOT + Vector3(0, deck_top + 0.02, 0))

	var trim_y := deck_top + 0.05
	var trim_x := (opening.x + LIFT_TRIM) / 2.0
	var trim_z := (opening.z + LIFT_TRIM) / 2.0
	for side in [-1.0, 1.0]:
		_box(hazard, Vector3(opening.x + LIFT_TRIM * 2.0, 0.1, LIFT_TRIM), LIFT_SPOT + Vector3(0, trim_y, side * trim_z))
		_box(hazard, Vector3(LIFT_TRIM, 0.1, opening.z), LIFT_SPOT + Vector3(side * trim_x, trim_y, 0))

	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			var post_spot := LIFT_SPOT + Vector3(x_side * trim_x, deck_top + LIFT_POST_HEIGHT / 2.0, z_side * trim_z)
			_box(posts, Vector3(LIFT_POST, LIFT_POST_HEIGHT, LIFT_POST), post_spot)

	if lift_height > 0.0:
		_box(posts, Vector3(1.0, lift_height, 1.0), LIFT_SPOT + Vector3(0, deck_top + lift_height / 2.0, 0))
	_box(platform, LIFT_PLATFORM, LIFT_SPOT + Vector3(0, deck_top + lift_height - LIFT_PLATFORM.y / 2.0, 0))

	_commit(shaft, mesh, SHAFT_COLOR)
	_commit(hazard, mesh, HAZARD_COLOR)
	_commit(posts, mesh, DARK)
	_commit(platform, mesh, PLATFORM_COLOR)


func _add_crane(mesh: ArrayMesh, deck_top: float) -> void:
	var mast := SurfaceTool.new()
	var boom := SurfaceTool.new()
	var dark := SurfaceTool.new()
	for st in [mast, boom, dark]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top := deck_top + mast_height
	_box(mast, Vector3(MAST_WIDTH, mast_height, MAST_WIDTH), MAST_SPOT + Vector3(0, deck_top + mast_height / 2.0, 0))
	_box(dark, Vector3(MAST_WIDTH + 1.0, 0.8, MAST_WIDTH + 1.0), MAST_SPOT + Vector3(0, deck_top + 0.4, 0))

	var boom_east := MAST_SPOT.x + BOOM_TAIL
	var boom_west := MAST_SPOT.x - boom_length
	var boom_y := top + BOOM_SIZE / 2.0
	_box(boom, Vector3(boom_east - boom_west, BOOM_SIZE, BOOM_SIZE), Vector3((boom_east + boom_west) / 2.0, boom_y, MAST_SPOT.z))
	_box(dark, Vector3(2.2, 1.8, 2.2), Vector3(boom_east - 1.0, boom_y, MAST_SPOT.z))

	var hook_x := boom_west + 2.0
	var cable_top := top
	_box(dark, Vector3(0.15, CABLE_LENGTH, 0.15), Vector3(hook_x, cable_top - CABLE_LENGTH / 2.0, MAST_SPOT.z))
	_box(dark, HOOK_SIZE, Vector3(hook_x, cable_top - CABLE_LENGTH - HOOK_SIZE.y / 2.0, MAST_SPOT.z))

	_commit(mast, mesh, mast_color)
	_commit(boom, mesh, band_color)
	_commit(dark, mesh, DARK)


func _commit(st: SurfaceTool, mesh: ArrayMesh, color: Color) -> void:
	st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(color))


func _box(st: SurfaceTool, size: Vector3, center: Vector3) -> void:
	MeshBuilder.add_box(st, size, Transform3D(Basis(), center))
