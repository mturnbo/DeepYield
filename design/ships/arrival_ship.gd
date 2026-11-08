@tool
extends Node3D
## The arrival ship that becomes the platform: a faceted, armored hull about 225 m
## from bow to engines. From front to back:
## - A short, blunt angled bow.
## - A tall cargo bay with two big roof doors, holding most of the material for
##   building the first modules. A phased plasma turret, the same as a defense
##   station's, stands out from each side near its front, with the Big Space
##   Corporation logo painted just behind it. The ship is slow to maneuver and
##   lightly armed: it can help fight off pirates, but not as well as the defense
##   stations.
## - A 40 m neck, as wide as the core, that sets the cargo bay apart from the bases.
## - The midsection: a square core with a real module base on each of its four faces,
##   decks facing out, so the bases form a square around the ship. They detach to
##   become the first modules: command on top, the fusion generator underneath, and
##   gas and metal storage on the sides. The four corners between the bases each hold
##   two frame assemblies end to end, eight in all, each a bundle of four frame pieces.
## - The aft section the ship keeps after the platform is built: crew quarters, a
##   tall stepped bridge tower and three engines.
## The hull is covered in welded metal plates and fitted with maneuvering thrusters,
## pipes, airlock hatches, vent grilles, a sensor dome and navigation lights.
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

# Which of the four bases (in BASES order) are still on the ship, and how many of
# the eight frame assemblies are still in the corner pockets.
@export var bases_present := [true, true, true, true]:
	set(value):
		bases_present = value
		_rebuild()
@export var frame_bundles_present := 8:
	set(value):
		frame_bundles_present = value
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
# The Big Space Corporation logo painted on each side of the cargo bay, behind the
# turret. The image is square with black corners, so only the round seal inside it
# is drawn.
const LOGO_TEXTURE := preload("res://design/brand/Big Space Corporation Logo 01.png")
const LOGO_DIAMETER := 12.0
const LOGO_SETBACK := 34.0
const LOGO_SEGMENTS := 64
const FRAME_PIECE_LENGTH := 15.0
const FRAME_SIZE := 4.0
const GREEBLE_COUNT := 60
# The hull plating is a generated image of a grid of plates, repeated every
# PLATING_TILE meters. Each plate is PLATING_LENGTH long along the hull and
# PLATING_HEIGHT across it.
const PLATING_TILE := 24.0
const PLATING_LENGTH := 8.0
const PLATING_HEIGHT := 6.0
const PLATING_PIXELS := 768
# Navigation lights: red on the left (port), green on the right (starboard).
const PORT_COLOR := Color("ff3b30")
const STARBOARD_COLOR := Color("3bff7a")

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
	var port := SurfaceTool.new()
	var starboard := SurfaceTool.new()
	for st in [hull, dark, panels, windows, engines, port, starboard]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_bow_and_cargo_bay(hull, dark, panels)
	_add_midsection(hull, dark)
	_add_aft(hull, dark, windows, engines)
	_add_greebles(panels, dark)
	_add_fittings(dark, panels, port, starboard)

	var hull_material := MeshBuilder.make_material(hull_color)
	hull_material.albedo_texture = _make_plating_texture()
	hull_material.uv1_scale = Vector3.ONE / PLATING_TILE
	var mesh := ArrayMesh.new()
	for pair in [[hull, hull_material], [dark, MeshBuilder.make_material(dark_color)], [panels, MeshBuilder.make_material(panel_color)]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	for pair in [[windows, window_color], [engines, engine_color], [port, PORT_COLOR], [starboard, STARBOARD_COLOR]]:
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

	# The logo faces along its own +Z, so each is turned to face out from its side.
	var logo_mesh := _make_logo_mesh()
	for side in [-1.0, 1.0]:
		var logo := MeshInstance3D.new()
		logo.mesh = logo_mesh
		logo.position = Vector3(side * (CARGO_HALF_WIDTH + 0.05), 0, CARGO_FRONT + LOGO_SETBACK)
		logo.rotation = Vector3(0, side * PI / 2.0, 0)
		_add_part(logo)


# A flat disc facing +Z, showing the round seal from the middle of the logo image.
func _make_logo_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := LOGO_DIAMETER / 2.0
	# The seal nearly fills the image, so the disc stops just short of its edges.
	var uv_radius := 0.49
	for i in LOGO_SEGMENTS:
		var corners := []
		for angle in [TAU * i / LOGO_SEGMENTS, TAU * (i + 1) / LOGO_SEGMENTS]:
			corners.append(Vector2(cos(angle), sin(angle)))
		# Godot treats clockwise triangles as front faces, so go center, then the later corner.
		for point in [Vector2.ZERO, corners[1], corners[0]]:
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(0.5 + uv_radius * point.x, 0.5 - uv_radius * point.y))
			st.add_vertex(Vector3(point.x * radius, point.y * radius, 0))
	var material := MeshBuilder.make_material(Color.WHITE)
	material.albedo_texture = LOGO_TEXTURE
	material.metallic = 0.0
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh


# The square core, running back from the neck, a module base on each face with a clamp at each of its diagonal
# corners, and two frame assemblies in each corner pocket.
func _add_midsection(hull: SurfaceTool, dark: SurfaceTool) -> void:
	var half := CORE / 2.0
	_loft(hull, [
		[CARGO_BACK, _profile(CORE, half, -half, 2.0)],
		[MID_BACK, _profile(CORE, half, -half, 2.0)],
	])
	for index in BASES.size():
		if not bases_present[index]:
			continue
		var entry: Array = BASES[index]
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
	var bundles_built := 0
	for x_side in [-1.0, 1.0]:
		for y_side in [-1.0, 1.0]:
			for z_start in [-FRAME_PIECE_LENGTH, 0.0]:
				if bundles_built >= frame_bundles_present:
					return
				bundles_built += 1
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


# An even grid of large metal plates, each a slightly different shade, with dark
# welded seams between them. The image repeats every PLATING_TILE meters.
func _make_plating_texture() -> ImageTexture:
	var image := Image.create(PLATING_PIXELS, PLATING_PIXELS, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = greeble_seed
	var pixels_per_meter := PLATING_PIXELS / PLATING_TILE
	var plate_length := int(PLATING_LENGTH * pixels_per_meter)
	var plate_height := int(PLATING_HEIGHT * pixels_per_meter)
	var seam := 2
	var seam_color := Color(0.72, 0.72, 0.72)
	for x in range(0, PLATING_PIXELS, plate_length):
		for y in range(0, PLATING_PIXELS, plate_height):
			var shade := rng.randf_range(0.95, 1.0)
			image.fill_rect(Rect2i(x, y, plate_length, plate_height), Color(shade, shade, shade))
			image.fill_rect(Rect2i(x, y, seam, plate_height), seam_color)
			image.fill_rect(Rect2i(x, y, plate_length, seam), seam_color)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# Fittings on the hull, one set on each side: maneuvering thruster clusters at the
# front corners of the cargo bay and the back corners of the aft section, two pipes
# and an airlock hatch along the neck, vent grilles on the aft section, and a
# navigation light at the widest points. A sensor dome and antenna stand on the bow.
func _add_fittings(dark: SurfaceTool, panels: SurfaceTool, port: SurfaceTool, starboard: SurfaceTool) -> void:
	var aft_half := 22.0
	var neck_half := CORE / 2.0
	for side in [-1.0, 1.0]:
		for y in [-11.0, 11.0]:
			_add_thruster_cluster(dark, Vector3(side * CARGO_HALF_WIDTH, y, CARGO_FRONT + 4.0), side, signf(y), -1.0)
		for y in [-8.0, 4.0]:
			_add_thruster_cluster(dark, Vector3(side * aft_half, y, STERN - 16.0), side, signf(y), 1.0)

		for y in [-9.0, 9.0]:
			_add_tube(dark, Vector3(side * (neck_half + 0.9), y, CARGO_BACK), Vector3(side * (neck_half + 0.9), y, MID_FRONT), 0.8)
			var z := CARGO_BACK + 4.0
			while z < MID_FRONT:
				MeshBuilder.add_box(dark, Vector3(2.2, 2.2, 0.8), Transform3D(Basis(), Vector3(side * (neck_half + 0.9), y, z)))
				z += 8.0
		var hatch_z := (CARGO_BACK + MID_FRONT) / 2.0
		MeshBuilder.add_box(dark, Vector3(0.3, 5.4, 4.4), Transform3D(Basis(), Vector3(side * (neck_half + 0.15), 0, hatch_z)))
		MeshBuilder.add_box(panels, Vector3(0.5, 4.4, 3.4), Transform3D(Basis(), Vector3(side * (neck_half + 0.25), 0, hatch_z)))
		MeshBuilder.add_box(dark, Vector3(0.6, 0.3, 2.4), Transform3D(Basis(), Vector3(side * (neck_half + 0.3), 0.6, hatch_z)))

		for z in [30.0, 40.0, 50.0]:
			MeshBuilder.add_box(dark, Vector3(0.3, 5.0, 7.0), Transform3D(Basis(), Vector3(side * (aft_half + 0.15), -2.0, z)))
			for k in 5:
				MeshBuilder.add_box(panels, Vector3(0.5, 0.35, 6.4), Transform3D(Basis(), Vector3(side * (aft_half + 0.25), -4.0 + k * 1.0, z)))

		var lights: SurfaceTool = port if side < 0.0 else starboard
		MeshBuilder.add_box(lights, Vector3.ONE * 0.8, Transform3D(Basis(), Vector3(side * (CARGO_HALF_WIDTH + 0.4), 13.0, CARGO_FRONT + 1.0)))
		MeshBuilder.add_box(lights, Vector3.ONE * 0.8, Transform3D(Basis(), Vector3(side * (aft_half + 0.4), 6.0, STERN - 13.0)))

	var dome_spot := Transform3D(Basis(), Vector3(0, CARGO_TOP, CARGO_FRONT + 2.0))
	_add_prism_at(dark, dome_spot, 16, 1.9, 1.9, 0.0, 0.5)
	_add_prism_at(panels, dome_spot, 16, 1.7, 1.4, 0.5, 1.4)
	_add_prism_at(panels, dome_spot, 16, 1.4, 0.4, 1.4, 2.1)
	MeshBuilder.add_box(dark, Vector3(0.3, 7.0, 0.3), Transform3D(Basis(), Vector3(5.0, CARGO_TOP + 3.5, CARGO_FRONT + 2.0)))
	MeshBuilder.add_box(dark, Vector3(3.0, 0.2, 0.2), Transform3D(Basis(), Vector3(5.0, CARGO_TOP + 5.5, CARGO_FRONT + 2.0)))


# A block of maneuvering thrusters on the hull, with a nozzle pointing out from the
# side, one up or down, and one forward or back.
func _add_thruster_cluster(dark: SurfaceTool, on_hull: Vector3, side: float, up: float, along: float) -> void:
	var center := on_hull + Vector3(side * 1.2, 0, 0)
	MeshBuilder.add_box(dark, Vector3.ONE * 2.4, Transform3D(Basis(), center))
	for direction in [Vector3(side, 0, 0), Vector3(0, up, 0), Vector3(0, 0, along)]:
		_add_prism_at(dark, Transform3D(_basis_toward(direction), center + direction * 1.2), 8, 0.35, 0.6, 0.0, 0.8)


# A pipe running in a straight line between two points.
func _add_tube(st: SurfaceTool, from: Vector3, to: Vector3, radius: float) -> void:
	var along := to - from
	_add_prism_at(st, Transform3D(_basis_toward(along.normalized()), from), 12, radius, radius, 0.0, along.length())


# A prism like MeshBuilder.add_prism, placed by a transform.
func _add_prism_at(st: SurfaceTool, xform: Transform3D, sides: int, bottom_radius: float, top_radius: float, bottom_y: float, top_y: float) -> void:
	var prism := SurfaceTool.new()
	prism.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_prism(prism, sides, bottom_radius, top_radius, bottom_y, top_y, PI / sides)
	st.append_from(prism.commit(), 0, xform)


# A turn that points +Y along the given direction.
func _basis_toward(direction: Vector3) -> Basis:
	if direction.dot(Vector3.UP) < -0.99:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, direction))


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
# The hull plating is laid out along the faces: on the sides, across along Z and up
# by the distance around the profile; on the end caps, flat across X and Y.
func _loft(st: SurfaceTool, stations: Array) -> void:
	var rings := []
	var centers := []
	var around := []
	for station in stations:
		var ring := []
		var middle := Vector2.ZERO
		for point in station[1]:
			ring.append(Vector3(point.x, point.y, station[0]))
			middle += point
		middle /= station[1].size()
		rings.append(ring)
		centers.append(Vector3(middle.x, middle.y, station[0]))
		# The distance around the profile to each point, ending back at the first.
		var distances := [0.0]
		for i in ring.size():
			distances.append(distances[i] + ring[i].distance_to(ring[(i + 1) % ring.size()]))
		around.append(distances)

	for k in rings.size() - 1:
		var front: Array = rings[k]
		var back: Array = rings[k + 1]
		var axis: Vector3 = (centers[k] + centers[k + 1]) / 2.0
		for i in front.size():
			var j := (i + 1) % front.size()
			var middle: Vector3 = (front[i] + front[j] + back[i] + back[j]) / 4.0
			var outward := Vector3(middle.x - axis.x, middle.y - axis.y, 0)
			var corners := [front[i], front[j], back[j], back[i]]
			var uvs := [
				Vector2(front[i].z, around[k][i]), Vector2(front[j].z, around[k][i + 1]),
				Vector2(back[j].z, around[k + 1][i + 1]), Vector2(back[i].z, around[k + 1][i]),
			]
			_add_plated_triangle(st, [corners[0], corners[1], corners[2]], [uvs[0], uvs[1], uvs[2]], outward)
			_add_plated_triangle(st, [corners[0], corners[2], corners[3]], [uvs[0], uvs[2], uvs[3]], outward)

	for pair in [[rings[0], centers[0], Vector3.FORWARD], [rings[rings.size() - 1], centers[centers.size() - 1], Vector3.BACK]]:
		var ring: Array = pair[0]
		var center: Vector3 = pair[1]
		for i in ring.size():
			var points := [center, ring[i], ring[(i + 1) % ring.size()]]
			var uvs := []
			for point in points:
				uvs.append(Vector2(point.x, point.y))
			_add_plated_triangle(st, points, uvs, pair[2])


# Like MeshBuilder.add_triangle, with a plating UV at each corner.
func _add_plated_triangle(st: SurfaceTool, points: Array, uvs: Array, outward: Vector3) -> void:
	var cross: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
	var order := [0, 1, 2]
	if cross.dot(outward) > 0.0:
		order = [0, 2, 1]
		cross = -cross
	var normal := -cross.normalized()
	for index in order:
		st.set_normal(normal)
		st.set_uv(uvs[index])
		st.add_vertex(points[index])
