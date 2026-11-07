@tool
extends "res://design/modules/module_base.gd"
## Metal storage: a module base with a bronze band and a raised block topped with
## seven lidded bins, one for each asteroid metal, colored by the metal it holds.
## A low loader runs along the front of the block where the two missing bins
## would be. Distances are in meters.

@export var block_size := 19.0:
	set(value):
		block_size = value
		_rebuild()
@export var block_height := 3.0:
	set(value):
		block_height = value
		_rebuild()
@export var bin_size := 5.0:
	set(value):
		bin_size = value
		_rebuild()
@export var bin_height := 3.4:
	set(value):
		bin_height = value
		_rebuild()
@export var block_color := Color("9a9ea5"):
	set(value):
		block_color = value
		_rebuild()
@export var loader_color := Color("7b8290"):
	set(value):
		loader_color = value
		_rebuild()

# Each bin's grid cell (x, z) on the block, and the color of the metal it holds.
const BINS := [
	[Vector2i(-1, -1), Color("c0714a")],  # iron
	[Vector2i(0, -1), Color("9db39a")],   # nickel
	[Vector2i(1, -1), Color("d9dde2")],   # magnesium
	[Vector2i(-1, 0), Color("5e6b85")],   # silicon
	[Vector2i(0, 0), Color("b7c0cc")],    # aluminum
	[Vector2i(1, 0), Color("d8c7a8")],    # palladium
	[Vector2i(1, 1), Color("ece6d6")],    # platinum
]

var _block: MeshInstance3D


func _init() -> void:
	band_color = Color("b98a5e")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _block == null:
		_block = MeshInstance3D.new()
		add_child(_block)

	var deck_top := hull_height / 2.0 + band_height + deck_height
	var block_top := deck_top + block_height
	var cell := block_size / 3.0

	var block := SurfaceTool.new()
	var loader := SurfaceTool.new()
	block.begin(Mesh.PRIMITIVE_TRIANGLES)
	loader.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshBuilder.add_box(block, Vector3(block_size, block_height, block_size), Transform3D(Basis(), Vector3(0, deck_top + block_height / 2.0, 0)))
	MeshBuilder.add_box(loader, Vector3(cell * 2.0 - 1.0, 1.4, bin_size * 0.8), Transform3D(Basis(), Vector3(-cell / 2.0, block_top + 0.7, cell)))

	var mesh := ArrayMesh.new()
	block.commit(mesh)
	mesh.surface_set_material(0, MeshBuilder.make_material(block_color))
	loader.commit(mesh)
	mesh.surface_set_material(1, MeshBuilder.make_material(loader_color))
	for entry in BINS:
		var bin := SurfaceTool.new()
		bin.begin(Mesh.PRIMITIVE_TRIANGLES)
		var center := Vector3(entry[0].x * cell, block_top, entry[0].y * cell)
		MeshBuilder.add_box(bin, Vector3(bin_size, bin_height, bin_size), Transform3D(Basis(), center + Vector3(0, bin_height / 2.0, 0)))
		MeshBuilder.add_box(bin, Vector3(bin_size - 0.6, 0.3, bin_size - 0.6), Transform3D(Basis(), center + Vector3(0, bin_height + 0.15, 0)))
		bin.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MeshBuilder.make_material(entry[1]))
	_block.mesh = mesh
