class_name PlatformLayout
extends RefCounted

const DIRECTIONS: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]

var nodes: Array[PlatformNode] = []
var _layout: Dictionary


func _init(layout_balance: Dictionary) -> void:
	_layout = layout_balance


func check_first(kind: String, center: Vector2, arrival_ship: Vector2) -> String:
	if center.distance_to(arrival_ship) > float(_layout["first_node_max_distance"]):
		return "Too far from the arrival ship"
	return ""


func add_first(kind: String, center: Vector2) -> PlatformNode:
	return _create(kind, center)


func new_center(from_id: int, port: int, run: int, kind: String) -> Vector2:
	var from_node := node(from_id)
	var piece_length := float(_layout["piece_length"])
	var distance := from_node.size / 2.0 + run * piece_length + _size_of(kind) / 2.0
	return from_node.center + DIRECTIONS[port] * distance


func check_placement(from_id: int, port: int, run: int, kind: String) -> String:
	if run < 1 or run > int(_layout["max_run"]):
		return "The frame can only run 1 to 3 pieces"
	var from_node := node(from_id)
	if from_node.links[port] != -1:
		return "That port is already used"
	if from_node.kind == "ship_dock":
		return "The dock can only join one module"
	var center := new_center(from_id, port, run, kind)
	var too_close := _find_too_close(kind, center)
	if too_close != null:
		return "Too close to the " + too_close.kind.replace("_", " ")
	if _overlaps_existing(from_node, port, run, kind, center):
		return "Overlaps the frame or a module"
	if _outside_build_area(kind, center):
		return "Outside the build area"
	return ""


func add(from_id: int, port: int, run: int, kind: String) -> PlatformNode:
	var center := new_center(from_id, port, run, kind)
	var new_node := _create(kind, center)
	var opposite := (port + 2) % 4
	new_node.parent_port = port
	new_node.run = run
	new_node.links[opposite] = from_id
	node(from_id).links[port] = new_node.id
	return new_node


func node(id: int) -> PlatformNode:
	return nodes[id]


func built_nodes(kind := "") -> Array[PlatformNode]:
	var result: Array[PlatformNode] = []
	for candidate in nodes:
		if candidate.built and (kind == "" or candidate.kind == kind):
			result.append(candidate)
	return result


func frame_piece_count(only_built: bool) -> int:
	var total := 0
	for candidate in nodes:
		if only_built and not candidate.built:
			continue
		total += candidate.run
	return total


func _create(kind: String, center: Vector2) -> PlatformNode:
	var created := PlatformNode.new()
	created.id = nodes.size()
	created.kind = kind
	created.center = center
	created.size = _size_of(kind)
	nodes.append(created)
	return created


func _size_of(kind: String) -> float:
	if kind == "junction":
		return float(_layout["junction_size"])
	return float(_layout["module_size"])


func _is_wide(kind: String) -> bool:
	return _layout["wide_kinds"].has(kind)


func _find_too_close(kind: String, center: Vector2) -> PlatformNode:
	if kind == "junction":
		return null
	for existing in nodes:
		if existing.kind == "junction":
			continue
		var spacing := float(_layout["module_spacing"])
		if _is_wide(kind) or _is_wide(existing.kind):
			spacing = float(_layout["wide_spacing"])
		if existing.center.distance_to(center) < spacing:
			return existing
	return null


func _square_of(center: Vector2, size: float) -> Rect2:
	return Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size))


func _run_rect(from_center: Vector2, from_size: float, port: int, run: int) -> Rect2:
	var direction := DIRECTIONS[port]
	var length := run * float(_layout["piece_length"])
	var width := float(_layout["frame_width"])
	var start := from_center + direction * from_size / 2.0
	var middle := start + direction * length / 2.0
	var extent := Vector2(length, width) if port % 2 == 0 else Vector2(width, length)
	return Rect2(middle - extent / 2.0, extent)


func _overlaps_existing(from_node: PlatformNode, port: int, run: int, kind: String, center: Vector2) -> bool:
	var new_square := _square_of(center, _size_of(kind))
	var new_run := _run_rect(from_node.center, from_node.size, port, run)
	for existing in nodes:
		if existing.id != from_node.id:
			var square := _square_of(existing.center, existing.size)
			if square.intersects(new_square) or square.intersects(new_run):
				return true
		if existing.parent_port >= 0:
			var parent_center := _parent_center(existing)
			var parent_size := _parent_size(existing)
			var run_rect := _run_rect(parent_center, parent_size, existing.parent_port, existing.run)
			if run_rect.intersects(new_square) or run_rect.intersects(new_run):
				return true
	return false


func _parent_center(child: PlatformNode) -> Vector2:
	return nodes[child.links[(child.parent_port + 2) % 4]].center


func _parent_size(child: PlatformNode) -> float:
	return nodes[child.links[(child.parent_port + 2) % 4]].size


func _outside_build_area(kind: String, center: Vector2) -> bool:
	var limit := float(_layout["build_area"]) / 2.0
	var half := _size_of(kind) / 2.0
	var offset := center - nodes[0].center
	return absf(offset.x) + half > limit or absf(offset.y) + half > limit
