@tool
extends Node3D
## A robot mining ship, about 5 m wide, 8 m long and 3 m high, small enough to fly
## through a dock's bay door and park on its pad. A rounded hull with a flat roof
## plate on top, a sloped sensor window at the nose, two booster engines on the
## sides near the back, and a robot arm on each side. The arms fold flat against
## the hull; arms_out unfolds them. The nose points along -Z, and the origin is the
## middle of the ship. Distances are in meters.

## 0 keeps the arms folded flat against the hull; 1 swings them all the way out.
@export_range(0.0, 1.0) var arms_out := 0.0:
	set(value):
		arms_out = value
		_pose_arms()
@export var hull_color := Color("dfe3e8"):
	set(value):
		hull_color = value
		_rebuild()
@export var roof_color := Color("c9ced6"):
	set(value):
		roof_color = value
		_rebuild()
@export var stripe_color := Color("f2c230"):
	set(value):
		stripe_color = value
		_rebuild()
@export var arm_color := Color("7b8290"):
	set(value):
		arm_color = value
		_rebuild()
@export var engine_color := Color("9aa0a8"):
	set(value):
		engine_color = value
		_rebuild()
@export var exhaust_color := Color("7fd8ff"):
	set(value):
		exhaust_color = value
		_rebuild()

# Hull cross-sections from nose to tail: (z, half width, bottom, top).
const STATIONS := [
	Vector4(-4.0, 1.5, -0.9, 0.3),
	Vector4(-3.3, 1.75, -1.3, 1.0),
	Vector4(-2.0, 1.85, -1.5, 1.2),
	Vector4(2.0, 1.85, -1.5, 1.2),
	Vector4(3.4, 1.8, -1.3, 1.2),
	Vector4(4.0, 1.6, -1.0, 1.2),
]
const DARK := Color("3a3e45")
const GLASS := Color("1e2a3a")
const UPPER_ARM := 2.6
const FOREARM := 2.4
# The forearm folds back under the upper arm, this far below it.
const FOLD_DROP := 0.45
const SHOULDER := Vector3(1.97, -0.15, -2.2)
const BOOSTER_RADIUS := 0.5
const BOOSTER_X := 1.95
const BOOSTER_FRONT := 1.0
const BOOSTER_BACK := 4.0

var _hull: MeshInstance3D
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _hull == null:
		_hull = MeshInstance3D.new()
		add_child(_hull)
	for shoulder in _shoulders:
		shoulder.queue_free()
	_shoulders.clear()
	_elbows.clear()

	var hull := SurfaceTool.new()
	var roof := SurfaceTool.new()
	var stripe := SurfaceTool.new()
	var dark := SurfaceTool.new()
	var glass := SurfaceTool.new()
	var engines := SurfaceTool.new()
	var exhaust := SurfaceTool.new()
	for st in [hull, roof, stripe, dark, glass, engines, exhaust]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_hull(hull)
	_add_roof(roof)
	_add_window(glass)
	for side in [-1.0, 1.0]:
		MeshBuilder.add_box(stripe, Vector3(0.06, 0.12, 5.8), Transform3D(Basis(), Vector3(side * 1.86, 0.55, 0.4)))
		_add_booster(engines, dark, exhaust, side)
		_add_arm(side)

	var mesh := ArrayMesh.new()
	for pair in [[hull, hull_color], [roof, roof_color], [stripe, stripe_color], [dark, DARK], [engines, engine_color]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	glass.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _glow_material(GLASS, Color(0.2, 0.45, 0.7), 0.4))
	exhaust.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _glow_material(exhaust_color, exhaust_color, 1.5))
	_hull.mesh = mesh
	_pose_arms()


# Lofts the hull through the cross-sections and closes the nose and tail.
func _add_hull(st: SurfaceTool) -> void:
	var sections := []
	for station in STATIONS:
		sections.append(_section(station))
	for k in sections.size() - 1:
		var front: Array = sections[k]
		var back: Array = sections[k + 1]
		var middle := _section_center(STATIONS[k].lerp(STATIONS[k + 1], 0.5))
		for i in front.size():
			var j := (i + 1) % front.size()
			MeshBuilder.add_quad(st, front[i], front[j], back[j], back[i], (front[i] + back[j]) / 2.0 - middle)
	for pair in [[sections[0], STATIONS[0], Vector3.FORWARD], [sections[sections.size() - 1], STATIONS[STATIONS.size() - 1], Vector3.BACK]]:
		var points: Array = pair[0]
		var center := _section_center(pair[1])
		for i in points.size():
			MeshBuilder.add_triangle(st, center, points[i], points[(i + 1) % points.size()], pair[2])


# A rounded-bottom cross-section: straight sides that lean in a little at the top,
# and a bottom that curves round into a narrower flat underside.
func _section(station: Vector4) -> Array:
	var w := station.y
	var bottom := station.z
	var top := station.w
	var h := top - bottom
	var shape := [
		Vector2(0.92, h), Vector2(1.0, h * 0.7), Vector2(1.0, h * 0.45),
		Vector2(0.8, h * 0.12), Vector2(0.45, 0.0),
		Vector2(-0.45, 0.0), Vector2(-0.8, h * 0.12),
		Vector2(-1.0, h * 0.45), Vector2(-1.0, h * 0.7), Vector2(-0.92, h),
	]
	var points := []
	for p in shape:
		points.append(Vector3(p.x * w, bottom + p.y, station.x))
	return points


func _section_center(station: Vector4) -> Vector3:
	return Vector3(0, (station.z + station.w) / 2.0, station.x)


# A thin flat plate over the whole top, wider than the hull, with its front corners cut.
func _add_roof(st: SurfaceTool) -> void:
	var outline := [
		Vector2(-1.4, -3.5), Vector2(1.4, -3.5), Vector2(2.0, -2.9),
		Vector2(2.0, 4.2), Vector2(-2.0, 4.2), Vector2(-2.0, -2.9),
	]
	var center := Vector3(0, 0, 0.35)
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var a_low := Vector3(a.x, 1.2, a.y)
		var b_low := Vector3(b.x, 1.2, b.y)
		var a_high := Vector3(a.x, 1.42, a.y)
		var b_high := Vector3(b.x, 1.42, b.y)
		MeshBuilder.add_quad(st, a_low, b_low, b_high, a_high, (a_low + b_low) / 2.0 - Vector3(center.x, 1.2, center.z))
		MeshBuilder.add_triangle(st, center + Vector3(0, 1.42, 0), a_high, b_high, Vector3.UP)
		MeshBuilder.add_triangle(st, center + Vector3(0, 1.2, 0), b_low, a_low, Vector3.DOWN)


# The sensor window on the sloped nose, between the first two cross-sections.
func _add_window(st: SurfaceTool) -> void:
	var slope := Basis(Vector3.RIGHT, -PI / 4.0)
	var spot := Vector3(0, 0.68, -3.62) + slope * Vector3(0, 0.05, 0)
	MeshBuilder.add_box(st, Vector3(2.6, 0.08, 0.75), Transform3D(slope, spot))


# A booster on a short pylon against the side, with a dark nozzle and a glowing exhaust.
func _add_booster(body: SurfaceTool, dark: SurfaceTool, exhaust: SurfaceTool, side: float) -> void:
	var length := BOOSTER_BACK - BOOSTER_FRONT
	var along_z := Basis(Vector3.RIGHT, PI / 2.0)
	var x := side * BOOSTER_X
	var y := -0.35
	_add_tube(body, BOOSTER_RADIUS, BOOSTER_RADIUS, 0.0, length, Transform3D(along_z, Vector3(x, y, BOOSTER_FRONT)))
	_add_tube(dark, BOOSTER_RADIUS * 1.1, BOOSTER_RADIUS * 1.1, -0.05, 0.3, Transform3D(along_z, Vector3(x, y, BOOSTER_FRONT)))
	_add_tube(dark, BOOSTER_RADIUS, BOOSTER_RADIUS * 0.8, 0.0, 0.4, Transform3D(along_z, Vector3(x, y, BOOSTER_BACK)))
	_add_tube(exhaust, BOOSTER_RADIUS * 0.65, BOOSTER_RADIUS * 0.65, 0.0, 0.05, Transform3D(along_z, Vector3(x, y, BOOSTER_BACK + 0.4)))
	MeshBuilder.add_box(dark, Vector3(0.5, 0.25, length * 0.7), Transform3D(Basis(), Vector3(side * 1.75, y, (BOOSTER_FRONT + BOOSTER_BACK) / 2.0)))


func _add_tube(st: SurfaceTool, start_radius: float, end_radius: float, start: float, end: float, xform: Transform3D) -> void:
	var piece := SurfaceTool.new()
	piece.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_prism(piece, 12, start_radius, end_radius, start, end, PI / 12.0)
	st.append_from(piece.commit(), 0, xform)


# An arm on one side: a shoulder joint, an upper arm that runs back along the hull,
# and an elbow joint and forearm with a two-finger claw that fold forward again
# underneath it. The elbow parts hang off the elbow node so they move with the forearm.
func _add_arm(side: float) -> void:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(side * SHOULDER.x, SHOULDER.y, SHOULDER.z)
	add_child(shoulder)
	var elbow := Node3D.new()
	elbow.position = Vector3(0, 0, UPPER_ARM)
	shoulder.add_child(elbow)

	var upper := SurfaceTool.new()
	var lower := SurfaceTool.new()
	var joints := SurfaceTool.new()
	var hand := SurfaceTool.new()
	for st in [upper, lower, joints, hand]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_box(upper, Vector3(0.22, 0.32, UPPER_ARM), Transform3D(Basis(), Vector3(0, 0, UPPER_ARM / 2.0)))
	_add_tube(joints, 0.28, 0.28, -0.14, 0.14, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3.ZERO))
	MeshBuilder.add_box(lower, Vector3(0.2, 0.28, FOREARM), Transform3D(Basis(), Vector3(0, -FOLD_DROP, -FOREARM / 2.0)))
	_add_tube(hand, 0.24, 0.24, -0.12, 0.12, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0, -FOLD_DROP / 2.0, 0)))
	MeshBuilder.add_box(hand, Vector3(0.18, FOLD_DROP + 0.3, 0.3), Transform3D(Basis(), Vector3(0, -FOLD_DROP / 2.0, 0)))
	for finger in [-0.1, 0.1]:
		MeshBuilder.add_box(hand, Vector3(0.12, 0.08, 0.5), Transform3D(Basis(), Vector3(0, -FOLD_DROP + finger, -FOREARM - 0.2)))

	var arm_mesh := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	upper.commit(mesh)
	mesh.surface_set_material(0, MeshBuilder.make_material(arm_color))
	joints.commit(mesh)
	mesh.surface_set_material(1, MeshBuilder.make_material(DARK))
	arm_mesh.mesh = mesh
	shoulder.add_child(arm_mesh)

	var forearm_mesh := MeshInstance3D.new()
	var forearm := ArrayMesh.new()
	lower.commit(forearm)
	forearm.surface_set_material(0, MeshBuilder.make_material(arm_color))
	hand.commit(forearm)
	forearm.surface_set_material(1, MeshBuilder.make_material(DARK))
	forearm_mesh.mesh = forearm
	elbow.add_child(forearm_mesh)

	_shoulders.append(shoulder)
	_elbows.append(elbow)


# Swings each shoulder out and opens each elbow. The right arm's angles are mirrored
# for the left, so both open away from the hull.
func _pose_arms() -> void:
	for i in _shoulders.size():
		var side := -1.0 if _shoulders[i].position.x < 0.0 else 1.0
		_shoulders[i].rotation = Vector3(0, side * arms_out * deg_to_rad(120.0), 0)
		_elbows[i].rotation = Vector3(0, -side * arms_out * deg_to_rad(160.0), 0)


func _glow_material(color: Color, glow: Color, strength: float) -> StandardMaterial3D:
	var material := MeshBuilder.make_material(color)
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = strength
	return material
