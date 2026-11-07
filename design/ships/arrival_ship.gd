@tool
extends Node3D
## The arrival ship that becomes the platform: a faceted, armored hull about 225 m
## from bow to engines. From front to back:
## - A short, blunt angled bow.
## - A tall cargo bay with two big roof doors, holding most of the material for
##   building the first modules. A phased plasma turret, the same as a defense
##   station's, stands out from each side near its front. The ship is slow to
##   maneuver and lightly armed: it can help fight off pirates, but not as well as
##   the defense stations.
## - A 40 m neck, as wide as the core, that sets the cargo bay apart from the bases.
## - The midsection: a square core with a real module base on each of its four faces,
##   decks facing out, so the bases form a square around the ship. They detach to
##   become the first modules: command on top, the fusion generator underneath, and
##   gas and metal storage on the sides. The four corners between the bases each hold
##   two frame assemblies end to end, eight in all, each a bundle of four frame pieces.
## - The aft section the ship keeps after the platform is built: crew quarters, a
##   tall stepped bridge tower and three engines.
## The bow points along -Z, and the origin is the middle of the midsection.
## Distances are in meters.

@export var greeble_seed := 11:
	set(value):
		greeble_seed = value
		_rebuild()
@export var hull_color := Color("737a74"):
	set(value):
		hull_color = value
		_rebuild()
@export var dark_color := Color("4a504b"):
	set(value):
		dark_color = value
		_rebuild()
@export var panel_color := Color("8a918a"):
	set(value):
		panel_color = value
		_rebuild()
@export var window_color := Color("9fd4ff"):
	set(value):
		window_color = value
		_rebuild()
@export var engine_color := Color("7fd8ff"):
	set(value):
		engine_color = value
		_rebuild()

const ModuleBaseScript := preload("res://design/modules/module_base.gd")
const FramePieceScript := preload("res://design/modules/frame_piece.gd")
const PlasmaTurretScript := preload("res://design/modules/plasma_turret.gd")

# The core is just wider than a 30 m base, so the side bases clear the top and
# bottom ones and leave a square pocket at each corner.
const CORE := 32.0
const MID_FRONT := -17.0
const MID_BACK := 17.0
# The neck between the cargo bay and the midsection.
const CARGO_BACK := -57.0
const CARGO_FRONT := -129.0
const BOW_TIP := -146.0
const STERN := 78.0
# A module base reaches 4.2 m below its origin to the bottom of its keel.
const BASE_KEEL := 4.2
# Each base: band color, and the turn about Z that points its deck outward.
# Command on top, gas storage on the right, fusion generator underneath, metal
# storage on the left.
const BASES := [
	[Color("e8b04a"), 0.0],
	[Color("c58be0"), -PI / 2.0],
	[Color("4fd1e8"), PI],
	[Color("b98a5e"), PI / 2.0],
]
const CARGO_HALF_WIDTH := 25.0
const CARGO_TOP := 24.0
const CARGO_BOTTOM := -24.0
const AFT_TOP := 16.0
const AFT_BOTTOM := -20.0
# The turrets sit on the cargo bay's sides, this far back from its front. They are
# the same design as a defense station's, built twice as big to suit the hull.
const TURRET_SETBACK := 14.0
const TURRET_SCALE := 2.0
const FRAME_PIECE_LENGTH := 15.0
const FRAME_SIZE := 4.0
const GREEBLE_COUNT := 60

var _hull: MeshInstance3D
var _parts: Array[Node3D] = []


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _hull == null:
		_hull = MeshInstance3D.new()
		add_child(_hull)
	for part in _parts:
		part.queue_free()
	_parts.clear()

	var hull := SurfaceTool.new()
	var dark := SurfaceTool.new()
	var panels := SurfaceTool.new()
	var windows := SurfaceTool.new()
	var engines := SurfaceTool.new()
	for st in [hull, dark, panels, windows, engines]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_bow_and_cargo_bay(hull, dark, panels)
	_add_midsection(hull, dark)
	_add_aft(hull, dark, windows, engines)
	_add_greebles(panels, dark)

	var mesh := ArrayMesh.new()
	for pair in [[hull, hull_color], [dark, dark_color], [panels, panel_color]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	for pair in [[windows, window_color], [engines, engine_color]]:
		pair[0].commit(mesh)
		var glow := MeshBuilder.make_material(pair[1])
		glow.emission_enabled = true
		glow.emission = pair[1]
		glow.emission_energy_multiplier = 1.5
		mesh.surface_set_material(mesh.get_surface_count() - 1, glow)
	_hull.mesh = mesh


# The bow narrows to a blunt, angled nose in front of the cargo bay. The cargo bay
# has two big roof doors with a dark seam between them, and a turret on each side.
func _add_bow_and_cargo_bay(hull: SurfaceTool, dark: SurfaceTool, panels: SurfaceTool) -> void:
	_loft(hull, [
		[BOW_TIP, _profile(18.0, 6.0, -12.0, 5.0)],
		[CARGO_FRONT, _profile(CARGO_HALF_WIDTH * 2.0, CARGO_TOP, CARGO_BOTTOM, 10.0)],
		[CARGO_BACK, _profile(CARGO_HALF_WIDTH * 2.0, CARGO_TOP, CARGO_BOTTOM, 10.0)],
	])
	var door_length := CARGO_BACK - CARGO_FRONT - 8.0
	var door_middle := (CARGO_FRONT + CARGO_BACK) / 2.0
	for side in [-1.0, 1.0]:
		MeshBuilder.add_box(panels, Vector3(13.0, 0.6, door_length), Transform3D(Basis(), Vector3(side * 7.0, CARGO_TOP + 0.3, door_middle)))
	MeshBuilder.add_box(dark, Vector3(1.0, 0.7, door_length), Transform3D(Basis(), Vector3(0, CARGO_TOP + 0.35, door_middle)))

	# A turret stands up along its own +Y, so each is turned to face out from its side.
	for side in [-1.0, 1.0]:
		var turret: Node3D = PlasmaTurretScript.new()
		turret.position = Vector3(side * CARGO_HALF_WIDTH, 0, CARGO_FRONT + TURRET_SETBACK)
		turret.rotation = Vector3(0, 0, -side * PI / 2.0)
		turret.scale = Vector3.ONE * TURRET_SCALE
		_add_part(turret)


# The square core, running back from the neck, a module base on each face with a clamp at each of its diagonal
# corners, and two frame assemblies in each corner pocket.
func _add_midsection(hull: SurfaceTool, dark: SurfaceTool) -> void:
	var half := CORE / 2.0
	_loft(hull, [
		[CARGO_BACK, _profile(CORE, half, -half, 2.0)],
		[MID_BACK, _profile(CORE, half, -half, 2.0)],
	])
	for entry in BASES:
		var turn := Basis(Vector3.BACK, entry[1])
		var base: Node3D = ModuleBaseScript.new()
		base.band_color = entry[0]
		base.basis = turn
		base.position = turn * Vector3(0, half + BASE_KEEL + 0.3, 0)
		_add_part(base)
		for corner in 4:
			var direction := Basis(Vector3.UP, PI / 4.0 + corner * PI / 2.0) * Vector3.RIGHT
			MeshBuilder.add_box(dark, Vector3(3.0, 1.2, 3.0), Transform3D(turn * Basis(Vector3.UP, PI / 4.0), turn * (direction * 12.0 + Vector3(0, half + 0.6, 0))))

	var pocket := half + 0.6 + 0.5 * (2.0 * FRAME_SIZE + 0.6)
	for x_side in [-1.0, 1.0]:
		for y_side in [-1.0, 1.0]:
			for z_start in [-FRAME_PIECE_LENGTH, 0.0]:
				_add_frame_assembly(dark, Vector3(x_side * pocket, y_side * pocket, z_start), x_side, y_side)


# Four frame pieces bundled two by two along Z, held by two dark straps, with a
# diagonal mount back to the core's corner.
func _add_frame_assembly(dark: SurfaceTool, start: Vector3, x_side: float, y_side: float) -> void:
	var gap := FRAME_SIZE / 2.0 + 0.1
	for dx in [-gap, gap]:
		for dy in [-gap, gap]:
			var piece: Node3D = FramePieceScript.new()
			piece.position = start + Vector3(dx, dy, 0)
			piece.rotation = Vector3(0, -PI / 2.0, 0)
			_add_part(piece)
	var bundle := 2.0 * FRAME_SIZE + 0.6
	var corner := Vector3(x_side * (CORE / 2.0 - 1.0), y_side * (CORE / 2.0 - 1.0), 0)
	for z in [start.z + 2.0, start.z + FRAME_PIECE_LENGTH - 2.0]:
		var middle := Vector3(start.x, start.y, z)
		for offset in [-bundle / 2.0, bundle / 2.0]:
			MeshBuilder.add_box(dark, Vector3(bundle + 0.6, 0.6, 1.0), Transform3D(Basis(), middle + Vector3(0, offset, 0)))
			MeshBuilder.add_box(dark, Vector3(0.6, bundle + 0.6, 1.0), Transform3D(Basis(), middle + Vector3(offset, 0, 0)))
		MeshBuilder.add_strut(dark, corner + Vector3(0, 0, z), middle - Vector3(x_side, y_side, 0) * bundle / 2.0, 1.2)


# The section the ship keeps: a deck, a three-step bridge tower with a band of lit
# windows on its top step, two masts, and three engines across the stern.
func _add_aft(hull: SurfaceTool, dark: SurfaceTool, windows: SurfaceTool, engines: SurfaceTool) -> void:
	_loft(hull, [
		[MID_BACK, _profile(44.0, AFT_TOP, AFT_BOTTOM, 9.0)],
		[STERN - 12.0, _profile(44.0, AFT_TOP, AFT_BOTTOM, 9.0)],
		[STERN, _profile(34.0, AFT_TOP - 4.0, AFT_BOTTOM + 4.0, 8.0)],
	])
	var tiers := [
		[30.0, 22.0, 64.0, 10.0],
		[22.0, 28.0, 58.0, 9.0],
		[15.0, 33.0, 52.0, 8.0],
	]
	var bottom := AFT_TOP
	for tier in tiers:
		var top: float = bottom + tier[3]
		_loft(hull, [
			[tier[1], _profile(tier[0], top, bottom, 2.5)],
			[tier[2], _profile(tier[0], top, bottom, 2.5)],
		])
		bottom = top
	var top_tier: Array = tiers[tiers.size() - 1]
	var window_y: float = bottom - top_tier[3] / 2.0
	var top_half: float = top_tier[0] / 2.0
	MeshBuilder.add_box(windows, Vector3(top_half * 2.0 - 4.0, 1.8, 0.3), Transform3D(Basis(), Vector3(0, window_y, top_tier[1] - 0.1)))
	for side in [-1.0, 1.0]:
		MeshBuilder.add_box(windows, Vector3(0.3, 1.8, top_tier[2] - top_tier[1] - 4.0), Transform3D(Basis(), Vector3(side * (top_half + 0.05), window_y, (top_tier[1] + top_tier[2]) / 2.0)))
		MeshBuilder.add_box(dark, Vector3(0.8, 10.0, 0.8), Transform3D(Basis(), Vector3(side * 3.5, bottom + 5.0, top_tier[2] - 6.0)))

	var along_z := Basis(Vector3.RIGHT, PI / 2.0)
	for x in [-11.0, 0.0, 11.0]:
		var nozzle := SurfaceTool.new()
		nozzle.begin(Mesh.PRIMITIVE_TRIANGLES)
		MeshBuilder.add_prism(nozzle, 16, 4.0, 5.2, 0.0, 9.0, PI / 16.0)
		dark.append_from(nozzle.commit(), 0, Transform3D(along_z, Vector3(x, -2.0, STERN)))
		var flame := SurfaceTool.new()
		flame.begin(Mesh.PRIMITIVE_TRIANGLES)
		MeshBuilder.add_prism(flame, 16, 4.6, 4.6, 0.0, 0.2, PI / 16.0)
		engines.append_from(flame.commit(), 0, Transform3D(along_z, Vector3(x, -2.0, STERN + 9.0)))


# Small boxes scattered along the cargo bay roof beside the doors, and on the aft
# deck in front of the bridge tower, for scale and texture.
func _add_greebles(panels: SurfaceTool, dark: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = greeble_seed
	for i in GREEBLE_COUNT:
		var size := Vector3(rng.randf_range(0.6, 1.2), rng.randf_range(0.5, 2.0), rng.randf_range(1.0, 5.0))
		var spot: Vector3
		if i % 2 == 0:
			var x := rng.randf_range(14.0, 14.5) * (1.0 if rng.randf() < 0.5 else -1.0)
			spot = Vector3(x, CARGO_TOP + size.y / 2.0, rng.randf_range(CARGO_FRONT + 3.0, CARGO_BACK - 3.0))
		else:
			size = Vector3(rng.randf_range(1.0, 3.0), size.y, rng.randf_range(0.6, 1.5))
			spot = Vector3(rng.randf_range(-11.0, 11.0), AFT_TOP + size.y / 2.0, rng.randf_range(MID_BACK + 1.0, 21.0))
		MeshBuilder.add_box(panels if rng.randf() < 0.6 else dark, size, Transform3D(Basis(), spot))


func _add_part(part: Node3D) -> void:
	add_child(part)
	_parts.append(part)


# A cross-section with its four corners cut at 45 degrees, as (x, y) points going around it.
func _profile(width: float, top: float, bottom: float, cut: float) -> Array:
	var half := width / 2.0
	return [
		Vector2(-half + cut, top), Vector2(half - cut, top), Vector2(half, top - cut),
		Vector2(half, bottom + cut), Vector2(half - cut, bottom), Vector2(-half + cut, bottom),
		Vector2(-half, bottom + cut), Vector2(-half, top - cut),
	]


# Joins cross-sections placed one after another along Z into a closed, flat-shaded
# solid. Each station is [z, profile]; every profile has the same number of points.
func _loft(st: SurfaceTool, stations: Array) -> void:
	var rings := []
	var centers := []
	for station in stations:
		var ring := []
		var middle := Vector2.ZERO
		for point in station[1]:
			ring.append(Vector3(point.x, point.y, station[0]))
			middle += point
		middle /= station[1].size()
		rings.append(ring)
		centers.append(Vector3(middle.x, middle.y, station[0]))

	for k in rings.size() - 1:
		var front: Array = rings[k]
		var back: Array = rings[k + 1]
		var axis: Vector3 = (centers[k] + centers[k + 1]) / 2.0
		for i in front.size():
			var j := (i + 1) % front.size()
			var middle: Vector3 = (front[i] + front[j] + back[i] + back[j]) / 4.0
			MeshBuilder.add_quad(st, front[i], front[j], back[j], back[i], Vector3(middle.x - axis.x, middle.y - axis.y, 0))

	for pair in [[rings[0], centers[0], Vector3.FORWARD], [rings[rings.size() - 1], centers[centers.size() - 1], Vector3.BACK]]:
		var ring: Array = pair[0]
		for i in ring.size():
			MeshBuilder.add_triangle(st, pair[1], ring[i], ring[(i + 1) % ring.size()], pair[2])
