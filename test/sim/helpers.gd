extends RefCounted


static func new_state() -> GameState:
	return GameState.new(Balance.load_default(), 1)


static func place_starter(state: GameState) -> Dictionary:
	var ids := {}
	assert(state.place_first("command", Vector2.ZERO) == "")
	ids["command"] = 0
	ids["fusion_generator"] = _place(state, ids, "command", 0, 2, "fusion_generator")
	ids["gas_storage"] = _place(state, ids, "command", 1, 2, "gas_storage")
	ids["metal_storage"] = _place(state, ids, "command", 3, 2, "metal_storage")
	ids["refinery"] = _place(state, ids, "metal_storage", 0, 2, "refinery")
	ids["factory"] = _place(state, ids, "gas_storage", 0, 2, "factory")
	ids["assembly"] = _place(state, ids, "fusion_generator", 0, 2, "assembly")
	ids["ship_dock"] = _place(state, ids, "command", 2, 3, "ship_dock")
	return ids


static func finish_construction(state: GameState) -> void:
	var steps := 0
	while not state.construction.sites.is_empty() and steps < 500:
		state.step()
		steps += 1


static func _place(state: GameState, ids: Dictionary, from_kind: String, port: int, run: int, kind: String) -> int:
	var result := state.place(ids[from_kind], port, run, kind)
	assert(result == "", "starter placement of " + kind + " refused: " + result)
	return state.layout.nodes.size() - 1
