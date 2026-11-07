@tool
extends "res://design/modules/module_base.gd"
## The ship dock: a module base with a yellow band and an enclosed hangar on top.
## Ships fly in rather than land on a pad. The hangar has four bays, one per ship,
## each opening on one of the four sides that have frame ports. Each bay has a
## roll-up door that slides up into a housing over the opening and back down, with a
## row of blinking lights above it.
## With demo_cycle on, the doors open and close in turn so you can watch them.
## For safety the dock sits on the edge of the platform: it joins exactly one other
## module, and sits at least 3 frame pieces (45 m) from every other module, which
## puts its center 75 m or more from theirs.
## Distances are in meters.

@export var hangar_across_flats := 27.0:
	set(value):
		hangar_across_flats = value
		_rebuild()
@export var hangar_height := 11.0:
	set(value):
		hangar_height = value
		_rebuild()
@export var door_width := 8.5:
	set(value):
		door_width = value
		_rebuild()
@export var door_height := 8.0:
	set(value):
		door_height = value
		_rebuild()
## How fast a door rolls up or down, in meters per second.
@export var door_speed := 1.0
@export var demo_cycle := true
@export var door_color := Color("5c6068"):
	set(value):
		door_color = value
		_rebuild()
@export var stripe_color := Color("f2c230"):
	set(value):
		stripe_color = value
		_rebuild()
@export var pad_color := Color("1e2229"):
	set(value):
		pad_color = value
		_rebuild()
@export var lamp_color := Color("ffb02e"):
	set(value):
		lamp_color = value
		_rebuild()

const WALL := 0.8
const SLATS := 10
const SLAT_GAP := 0.08
const PAD_SIDES := 16
# In the demo, each door spends half of this open and half closed, a quarter out of step with the next.
const DEMO_PERIOD := 40.0
# The lights over the doors are on for half of each blink.
const BLINK_PERIOD := 1.2
const LAMPS_PER_DOOR := 3

var _hangar: MeshInstance3D
var _doors: Array[MeshInstance3D] = []
var _bay_lights: Array[OmniLight3D] = []
var _lamps: MeshInstance3D
var _lamp_material: StandardMaterial3D
var _door_open: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _door_target: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _time := 0.0


func _init() -> void:
	band_color = Color("f2c230")


func open_door(index: int) -> void:
	_door_target[index] = 1.0


func close_door(index: int) -> void:
	_door_target[index] = 0.0


func _process(delta: float) -> void:
	if _doors.is_empty():
		return
	_time += delta
	var lamps_on := fmod(_time, BLINK_PERIOD) < BLINK_PERIOD / 2.0
	_lamp_material.emission_energy_multiplier = 3.0 if lamps_on else 0.0
	for i in _doors.size():
		if demo_cycle:
			var phase := fmod(_time + i * DEMO_PERIOD / 4.0, DEMO_PERIOD)
			_door_target[i] = 1.0 if phase < DEMO_PERIOD / 2.0 else 0.0
		var moved := move_toward(_door_open[i], _door_target[i], door_speed * delta / door_height)
		if moved != _door_open[i]:
			_door_open[i] = moved
			_doors[i].mesh = _make_door_mesh(moved)


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _hangar == null:
		_hangar = MeshInstance3D.new()
		add_child(_hangar)
		_lamps = MeshInstance3D.new()
		add_child(_lamps)
		for direction in PORT_DIRECTIONS:
			var door := MeshInstance3D.new()
			door.basis = _facing(direction)
			add_child(door)
			_doors.append(door)
			var bay_light := OmniLight3D.new()
			bay_light.light_color = Color(1.0, 0.92, 0.75)
			bay_light.omni_range = 11.0
			bay_light.light_energy = 1.5
			add_child(bay_light)
			_bay_lights.append(bay_light)

	var deck_top := _deck_top()
	var walls := SurfaceTool.new()
	var roof := SurfaceTool.new()
	var housing := SurfaceTool.new()
	var pads := SurfaceTool.new()
	var rings := SurfaceTool.new()
	var lamps := SurfaceTool.new()
	for st in [walls, roof, housing, pads, rings, lamps]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in 8:
		var facing := Basis(Vector3.UP, i * PI / 4.0)
		if i % 2 == 0:
			_add_door_wall(walls, housing, lamps, facing, deck_top)
		else:
			_add_wall_box(walls, facing, Vector3(WALL, hangar_height, _side_length()), deck_top + hangar_height / 2.0, 0.0)

	# Partitions run from the middle out to the corners, splitting the hangar into four bays.
	var corner := _corner_radius(hangar_across_flats) - WALL
	for i in 4:
		var facing := Basis(Vector3.UP, PI / 4.0 + i * PI / 2.0)
		MeshBuilder.add_box(walls, Vector3(corner, hangar_height, 0.4), Transform3D(facing, facing * Vector3(corner / 2.0, deck_top + hangar_height / 2.0, 0)))

	MeshBuilder.add_prism(roof, 8, _corner_radius(hangar_across_flats), _corner_radius(hangar_across_flats), deck_top + hangar_height, deck_top + hangar_height + 0.5, PI / 8.0)

	for i in PORT_DIRECTIONS.size():
		var bay_center: Vector3 = PORT_DIRECTIONS[i] * hangar_across_flats * 0.27
		_add_pad(pads, rings, bay_center, deck_top)
		_bay_lights[i].position = bay_center + Vector3(0, deck_top + hangar_height - 1.5, 0)
		_doors[i].mesh = _make_door_mesh(_door_open[i])

	var mesh := ArrayMesh.new()
	for pair in [[walls, hull_color], [roof, deck_color], [housing, door_color.darkened(0.25)], [pads, pad_color]]:
		pair[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(pair[1]))
	rings.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _glow_material(stripe_color))
	_hangar.mesh = mesh

	_lamp_material = MeshBuilder.make_material(lamp_color.darkened(0.5))
	_lamp_material.emission_enabled = true
	_lamp_material.emission = lamp_color
	var lamp_mesh := lamps.commit()
	lamp_mesh.surface_set_material(0, _lamp_material)
	_lamps.mesh = lamp_mesh


# A wall with a door opening: a jamb either side, the wall above, the housing
# the door rolls up into, sticking out over the opening, and a row of lights above that.
func _add_door_wall(walls: SurfaceTool, housing: SurfaceTool, lamps: SurfaceTool, facing: Basis, deck_top: float) -> void:
	var jamb := (_side_length() - door_width) / 2.0
	var middle := deck_top + hangar_height / 2.0
	_add_wall_box(walls, facing, Vector3(WALL, hangar_height, jamb), middle, door_width / 2.0 + jamb / 2.0)
	_add_wall_box(walls, facing, Vector3(WALL, hangar_height, jamb), middle, -door_width / 2.0 - jamb / 2.0)
	var above := hangar_height - door_height
	_add_wall_box(walls, facing, Vector3(WALL, above, door_width), deck_top + door_height + above / 2.0, 0.0)

	var face := hangar_across_flats / 2.0
	var spot := Vector3(face + 0.5, deck_top + door_height + 0.7, 0)
	MeshBuilder.add_box(housing, Vector3(1.0, 1.4, door_width + 0.8), Transform3D(facing, facing * spot))

	var lamp_y := deck_top + door_height + 2.2
	for k in LAMPS_PER_DOOR:
		var along := lerpf(-door_width / 2.0 + 0.6, door_width / 2.0 - 0.6, float(k) / (LAMPS_PER_DOOR - 1))
		MeshBuilder.add_box(lamps, Vector3(0.5, 0.5, 0.7), Transform3D(facing, facing * Vector3(face + 0.2, lamp_y, along)))


# A wall piece whose outer face lies on the hangar's outside.
func _add_wall_box(st: SurfaceTool, facing: Basis, size: Vector3, center_y: float, along: float) -> void:
	var spot := Vector3(hangar_across_flats / 2.0 - WALL / 2.0, center_y, along)
	MeshBuilder.add_box(st, size, Transform3D(facing, facing * spot))


# A dark pad with a glowing yellow ring around it, where a ship settles.
func _add_pad(pads: SurfaceTool, rings: SurfaceTool, center: Vector3, deck_top: float) -> void:
	var ring := SurfaceTool.new()
	ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_prism(ring, PAD_SIDES, 4.4, 4.4, deck_top, deck_top + 0.08, 0.0)
	rings.append_from(ring.commit(), 0, Transform3D(Basis(), center))
	var pad := SurfaceTool.new()
	pad.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_prism(pad, PAD_SIDES, 3.9, 3.9, deck_top, deck_top + 0.12, 0.0)
	pads.append_from(pad.commit(), 0, Transform3D(Basis(), center))


# The door as horizontal slats. Opening lifts the slats, and any slat that reaches
# the top of the opening disappears into the housing. The bottom slat has a yellow
# stripe. Built facing east; the door's node turns it to its side.
func _make_door_mesh(open_amount: float) -> ArrayMesh:
	var deck_top := _deck_top()
	var top := deck_top + door_height
	var bottom := deck_top + open_amount * door_height
	if bottom >= top - SLAT_GAP:
		return null

	var slats := SurfaceTool.new()
	var stripe := SurfaceTool.new()
	for st in [slats, stripe]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slat_height := door_height / SLATS
	var x := hangar_across_flats / 2.0 - WALL / 2.0
	var slat_count := 0
	for k in SLATS:
		var slat_bottom := bottom + k * slat_height
		var slat_top := minf(slat_bottom + slat_height - SLAT_GAP, top)
		if slat_bottom >= slat_top:
			break
		var st := stripe if k == 0 else slats
		MeshBuilder.add_box(st, Vector3(0.3, slat_top - slat_bottom, door_width), Transform3D(Basis(), Vector3(x, (slat_bottom + slat_top) / 2.0, 0)))
		slat_count += 1

	var mesh := ArrayMesh.new()
	stripe.commit(mesh)
	mesh.surface_set_material(0, MeshBuilder.make_material(stripe_color))
	if slat_count > 1:
		slats.commit(mesh)
		mesh.surface_set_material(1, MeshBuilder.make_material(door_color))
	return mesh


func _facing(direction: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(-direction.z, direction.x))


func _deck_top() -> float:
	return hull_height / 2.0 + band_height + deck_height


func _side_length() -> float:
	return hangar_across_flats * tan(PI / 8.0)


func _glow_material(color: Color) -> StandardMaterial3D:
	var material := MeshBuilder.make_material(color)
	material.emission_enabled = true
	material.emission = color * 0.8
	return material
