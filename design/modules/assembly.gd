@tool
extends "res://design/modules/module_base.gd"
## The assembly: a module base with a purple band and an enclosed assembly hall.
## The hall runs east to west under an arched roof with ribs over it, skylights
## along the ridge and a row of small windows high on each side. Its east end is
## a tall two-leaf hangar door in a purple frame. Distances are in meters.

@export var hall_length := 20.0:
	set(value):
		hall_length = value
		_rebuild()
@export var hall_width := 18.0:
	set(value):
		hall_width = value
		_rebuild()
@export var wall_height := 8.0:
	set(value):
		wall_height = value
		_rebuild()
@export var roof_rise := 4.0:
	set(value):
		roof_rise = value
		_rebuild()
@export var wall_color := Color("9a9ea5"):
	set(value):
		wall_color = value
		_rebuild()
@export var roof_color := Color("c7cdd6"):
	set(value):
		roof_color = value
		_rebuild()
@export var door_color := Color("4a4f58"):
	set(value):
		door_color = value
		_rebuild()
@export var glass_color := Color("6fb7e8"):
	set(value):
		glass_color = value
		_rebuild()

const ARCH_FACETS := 7
const RIB_COUNT := 4
const RIB_WIDTH := 0.6
const RIB_DEPTH := 0.3
const DOOR_WIDTH := 13.0
const DOOR_HEIGHT := 9.0
const DOOR_FRAME := 0.6
const SEAM_COLOR := Color("2c3038")
const RIB_COLOR := Color("7b8290")

var _hall: MeshInstance3D


func _init() -> void:
	band_color = Color("a77bdb")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _hall == null:
		_hall = MeshInstance3D.new()
		add_child(_hall)

	var walls := SurfaceTool.new()
	var roof := SurfaceTool.new()
	var ribs := SurfaceTool.new()
	var door := SurfaceTool.new()
	var seams := SurfaceTool.new()
	var frame := SurfaceTool.new()
	var glass := SurfaceTool.new()
	for st in [walls, roof, ribs, door, seams, frame, glass]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var deck_top := hull_height / 2.0 + band_height + deck_height
	var half := hall_length / 2.0
	var outline := _hall_outline(deck_top, 0.0)
	_add_hall_walls(walls, roof, outline, -half, half)
	_add_cap(walls, outline, half, Vector3.RIGHT)
	_add_cap(walls, outline, -half, Vector3.LEFT)

	var rib_outline := _hall_outline(deck_top, RIB_DEPTH)
	var rib_spacing := hall_length / (RIB_COUNT + 1)
	for i in RIB_COUNT:
		var x := -half + rib_spacing * (i + 1)
		_add_hall_walls(ribs, ribs, rib_outline, x - RIB_WIDTH / 2.0, x + RIB_WIDTH / 2.0)
		_add_cap(ribs, rib_outline, x + RIB_WIDTH / 2.0, Vector3.RIGHT)
		_add_cap(ribs, rib_outline, x - RIB_WIDTH / 2.0, Vector3.LEFT)

	_add_door(door, seams, frame, half, deck_top)
	_add_skylights(glass, deck_top, rib_spacing)
	_add_windows(glass, deck_top, rib_spacing)

	var mesh := ArrayMesh.new()
	var surfaces := [[walls, wall_color], [roof, roof_color], [ribs, RIB_COLOR], [door, door_color], [seams, SEAM_COLOR], [frame, band_color], [glass, glass_color]]
	for pair in surfaces:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	_hall.mesh = mesh


# The hall's cross-section as (z, y) points: straight side walls under a circular
# arch. grow pushes the whole shape outward, for the ribs.
func _hall_outline(deck_top: float, grow: float) -> Array:
	var hz := hall_width / 2.0
	var radius := (hz * hz + roof_rise * roof_rise) / (2.0 * roof_rise)
	var center_y := deck_top + wall_height + roof_rise - radius
	var grown_radius := radius + grow
	var spring := asin((hz + grow) / grown_radius)
	var points := [Vector2(-hz - grow, deck_top), Vector2(hz + grow, deck_top)]
	for i in ARCH_FACETS + 1:
		var angle := spring - 2.0 * spring * i / ARCH_FACETS
		points.append(Vector2(sin(angle) * grown_radius, center_y + cos(angle) * grown_radius))
	return points


# Side walls and roof joining one cross-section at two points along X. The floor is
# left open; it sits on the deck.
func _add_hall_walls(sides: SurfaceTool, top: SurfaceTool, outline: Array, x_a: float, x_b: float) -> void:
	var middle_y: float = outline[0].y + (wall_height + roof_rise) / 2.0
	for i in range(1, outline.size()):
		var j := (i + 1) % outline.size()
		var p: Vector2 = outline[i]
		var q: Vector2 = outline[j]
		var a0 := Vector3(x_a, p.y, p.x)
		var a1 := Vector3(x_a, q.y, q.x)
		var b0 := Vector3(x_b, p.y, p.x)
		var b1 := Vector3(x_b, q.y, q.x)
		var edge_middle := (p + q) / 2.0
		var outward := Vector3(0, edge_middle.y - middle_y, edge_middle.x)
		var is_side := i == 1 or i == outline.size() - 1
		MeshBuilder.add_quad(sides if is_side else top, a0, a1, b1, b0, outward)


func _add_cap(st: SurfaceTool, outline: Array, x: float, outward: Vector3) -> void:
	var first := Vector3(x, outline[0].y, outline[0].x)
	for i in range(1, outline.size() - 1):
		var b := Vector3(x, outline[i].y, outline[i].x)
		var c := Vector3(x, outline[i + 1].y, outline[i + 1].x)
		MeshBuilder.add_triangle(st, first, b, c, outward)


# Two door leaves with a seam between them and panel lines across, in a purple frame.
func _add_door(leaves: SurfaceTool, seams: SurfaceTool, frame: SurfaceTool, east: float, deck_top: float) -> void:
	var middle_y := deck_top + DOOR_HEIGHT / 2.0
	_box(leaves, Vector3(0.3, DOOR_HEIGHT, DOOR_WIDTH), Vector3(east + 0.15, middle_y, 0))
	_box(seams, Vector3(0.36, DOOR_HEIGHT, 0.25), Vector3(east + 0.15, middle_y, 0))
	for i in range(1, 4):
		var y := deck_top + DOOR_HEIGHT * i / 4.0
		_box(seams, Vector3(0.36, 0.18, DOOR_WIDTH), Vector3(east + 0.15, y, 0))
	var frame_x := east + 0.2
	_box(frame, Vector3(0.4, DOOR_FRAME, DOOR_WIDTH + DOOR_FRAME * 2.0), Vector3(frame_x, deck_top + DOOR_HEIGHT + DOOR_FRAME / 2.0, 0))
	for side in [-1.0, 1.0]:
		_box(frame, Vector3(0.4, DOOR_HEIGHT, DOOR_FRAME), Vector3(frame_x, middle_y, side * (DOOR_WIDTH + DOOR_FRAME) / 2.0))


# Flat skylights along the ridge, one between each pair of ribs.
func _add_skylights(glass: SurfaceTool, deck_top: float, rib_spacing: float) -> void:
	var ridge := deck_top + wall_height + roof_rise
	for i in RIB_COUNT + 1:
		var x := -hall_length / 2.0 + rib_spacing * (i + 0.5)
		_box(glass, Vector3(rib_spacing * 0.5, 0.3, 2.4), Vector3(x, ridge, 0))


# A row of small windows high on the north and south walls.
func _add_windows(glass: SurfaceTool, deck_top: float, rib_spacing: float) -> void:
	var y := deck_top + wall_height - 1.6
	var face := hall_width / 2.0 + 0.05
	for side in [-1.0, 1.0]:
		for i in RIB_COUNT + 1:
			var x := -hall_length / 2.0 + rib_spacing * (i + 0.5)
			_box(glass, Vector3(rib_spacing * 0.45, 1.2, 0.2), Vector3(x, y, side * face))


func _box(st: SurfaceTool, size: Vector3, center: Vector3) -> void:
	MeshBuilder.add_box(st, size, Transform3D(Basis(), center))
