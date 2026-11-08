extends Node3D
## Shows the platform: one visual per layout node (the module and the frame pieces
## leading to it), a ghost look and progress label while it is being built, and an
## ice chunk in every electrolysis plant's cradle.

const MODEL_SCRIPTS := {
	"command": "res://design/modules/command_module.gd",
	"ship_dock": "res://design/modules/ship_dock.gd",
	"fusion_generator": "res://design/modules/fusion_generator.gd",
	"refinery": "res://design/modules/refinery.gd",
	"factory": "res://game/view/placeholder_module.gd",
	"assembly": "res://game/view/placeholder_module.gd",
	"gas_storage": "res://design/modules/gas_storage.gd",
	"metal_storage": "res://design/modules/metal_storage.gd",
	"electrolysis_plant": "res://design/modules/electrolysis_plant.gd",
	"habitat": "res://design/modules/habitat_module.gd",
	"junction": "res://design/modules/reinforcing_junction.gd",
}
const FRAME_SCRIPT := "res://design/modules/frame_piece.gd"
const ICE_SCRIPT := "res://design/modules/ice_chunk.gd"
const PIECE_LENGTH := 15.0
const FRAME_ROTATIONS := [0.0, -PI / 2.0, PI, PI / 2.0]
const DIRECTIONS := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
const GHOST_TRANSPARENCY := 0.6

var visuals := {}
var _game: Node
var _labels := {}
var _ice_chunks := {}


func _ready() -> void:
	_game = get_parent()
	_game.stepped.connect(sync)
	sync.call_deferred()


func world_position(center: Vector2) -> Vector3:
	return Vector3(center.x, 0, center.y)


func node_visual(id: int) -> Node3D:
	return visuals.get(id)


func model_of(id: int) -> Node3D:
	var holder: Node3D = visuals.get(id)
	if holder == null:
		return null
	return holder.get_child(0)


func sync() -> void:
	var state: GameState = _game.state
	for platform_node in state.layout.nodes:
		if not visuals.has(platform_node.id):
			_create_visual(state, platform_node)
		_update_build_look(state, platform_node)
	_update_ice(state)


func _create_visual(state: GameState, platform_node: PlatformNode) -> void:
	var holder := Node3D.new()
	holder.position = world_position(platform_node.center)
	add_child(holder)
	holder.add_child(make_model(platform_node.kind))
	if platform_node.parent_port >= 0:
		_add_frame_pieces(state, holder, platform_node)
	visuals[platform_node.id] = holder
	if platform_node.kind == "electrolysis_plant":
		var chunk := Node3D.new()
		chunk.set_script(load(ICE_SCRIPT))
		chunk.position.y = load(MODEL_SCRIPTS["electrolysis_plant"]).ICE_MOUNT_Y
		chunk.visible = false
		holder.add_child(chunk)
		_ice_chunks[platform_node.id] = chunk


func make_model(kind: String) -> Node3D:
	var model := Node3D.new()
	model.set_script(load(MODEL_SCRIPTS[kind]))
	if kind == "ship_dock":
		model.demo_cycle = false
	if kind == "factory" or kind == "assembly":
		model.top_style = kind
	return model


func _add_frame_pieces(state: GameState, holder: Node3D, platform_node: PlatformNode) -> void:
	var port := platform_node.parent_port
	var parent_node := state.layout.node(platform_node.links[(port + 2) % 4])
	var direction: Vector2 = DIRECTIONS[port]
	for i in platform_node.run:
		var start := parent_node.center + direction * (parent_node.size / 2.0 + PIECE_LENGTH * i)
		var piece := Node3D.new()
		piece.set_script(load(FRAME_SCRIPT))
		piece.position = world_position(start - platform_node.center)
		piece.rotation.y = FRAME_ROTATIONS[port]
		holder.add_child(piece)


func _update_build_look(state: GameState, platform_node: PlatformNode) -> void:
	var holder: Node3D = visuals[platform_node.id]
	if platform_node.built:
		if _labels.has(platform_node.id):
			_labels[platform_node.id].queue_free()
			_labels.erase(platform_node.id)
			set_transparency(holder, 0.0)
		return
	set_transparency(holder, GHOST_TRANSPARENCY)
	if not _labels.has(platform_node.id):
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.06
		label.font_size = 100
		label.outline_size = 16
		label.no_depth_test = true
		label.position.y = 30
		holder.add_child(label)
		_labels[platform_node.id] = label
	var percent := int(state.construction.progress(platform_node.id) * 100.0)
	_labels[platform_node.id].text = "Building %d%%" % percent


func set_transparency(root: Node, value: float) -> void:
	for child in root.get_children():
		if child is GeometryInstance3D and not child is Label3D:
			child.transparency = value
		set_transparency(child, value)


func _update_ice(state: GameState) -> void:
	var capacity := state.cradle_capacity()
	for id in _ice_chunks:
		var chunk: Node3D = _ice_chunks[id]
		chunk.visible = state.cradle_ice > 0.0 and capacity > 0.0
		if chunk.visible:
			chunk.scale = Vector3.ONE * pow(state.cradle_ice / capacity, 1.0 / 3.0)
