extends GutTest

const Helpers = preload("res://test/sim/helpers.gd")
const ModulePanel = preload("res://game/ui/module_panel.gd")
const WorldPicker = preload("res://game/view/world_picker.gd")

var game: Node
var panel: Node
var ids: Dictionary


func before_each() -> void:
	game = add_child_autofree(load("res://game/main.tscn").instantiate())
	panel = game.get_node("UI/ModulePanel")
	ids = Helpers.place_starter(game.state)


func _finish_building() -> void:
	Helpers.finish_construction(game.state)
	game.state.step()


func test_status_under_construction_shows_percent() -> void:
	game.state.step()
	var progress: float = game.state.construction.progress(ids["factory"])
	assert_eq(ModulePanel.status_text(game.state, ids["factory"]), "Under construction %d%%" % int(progress * 100.0))


func test_status_no_operator() -> void:
	_finish_building()
	game.state.power.operated[ids["factory"]] = false
	assert_eq(ModulePanel.status_text(game.state, ids["factory"]), "No operator")


func test_status_no_power() -> void:
	_finish_building()
	game.state.power.powered[ids["factory"]] = false
	game.state.power.on_battery = false
	assert_eq(ModulePanel.status_text(game.state, ids["factory"]), "No power")


func test_status_on_battery() -> void:
	_finish_building()
	game.state.power.on_battery = true
	assert_eq(ModulePanel.status_text(game.state, ids["factory"]), "On battery")


func test_status_running() -> void:
	_finish_building()
	assert_eq(ModulePanel.status_text(game.state, ids["factory"]), "Running")


func test_status_uncrewed_module_without_power_says_no_power() -> void:
	_finish_building()
	game.state.power.powered[ids["gas_storage"]] = false
	assert_eq(ModulePanel.status_text(game.state, ids["gas_storage"]), "No power")


func test_nearest_node_picks_closest_within_half_size() -> void:
	var first: PlatformNode = game.state.layout.node(ids["command"])
	assert_eq(WorldPicker.nearest_node(game.state, first.center + Vector2(first.size / 2.0 - 1.0, 0)).id, ids["command"])


func test_nearest_node_misses_outside_half_size() -> void:
	var first: PlatformNode = game.state.layout.node(ids["command"])
	assert_null(WorldPicker.nearest_node(game.state, first.center + Vector2(first.size / 2.0 + 1.0, 0)))


func test_nearest_node_chooses_closer_of_two() -> void:
	var near: PlatformNode = game.state.layout.node(ids["factory"])
	var picked := WorldPicker.nearest_node(game.state, near.center + Vector2(2, 2))
	assert_eq(picked.id, ids["factory"])


func test_open_replaces_previous_panel() -> void:
	panel.open(ids["factory"])
	panel.open(ids["refinery"])
	assert_true(panel.visible)
	assert_eq(panel._title_label.text, "Refinery")


func test_close_button_hides_panel() -> void:
	panel.open(ids["factory"])
	panel._close_button.pressed.emit()
	assert_false(panel.visible)


func test_escape_closes_panel() -> void:
	panel.open(ids["factory"])
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	panel._unhandled_input(escape)
	assert_false(panel.visible)


func test_takes_in_and_puts_out_lines() -> void:
	panel.open(ids["refinery"])
	assert_eq(panel._takes_label.text, "Takes in: " + ModulePanel.FLOWS["refinery"]["in"])
	assert_eq(panel._puts_label.text, "Puts out: " + ModulePanel.FLOWS["refinery"]["out"])
	panel.open(ids["command"])
	assert_eq(panel._takes_label.text, "Takes in: " + ModulePanel.FLOWS["command"]["in"])


func test_every_kind_has_flow_lines() -> void:
	for kind in game.state.balance["modules"]:
		assert_true(ModulePanel.FLOWS.has(kind), kind)
	assert_eq(ModulePanel.FLOWS["junction"]["in"], "—")


func test_add_button_queues_module_part_and_remove_unqueues() -> void:
	_finish_building()
	for material in {"iron": 3, "aluminum": 1, "silicon": 1}:
		game.state.stock.add(material, 5.0)
	panel.open(ids["factory"])
	panel._add_buttons["module_part"].pressed.emit()
	assert_eq(game.state.production.queues["factory"], ["module_part"])
	assert_eq(panel._remove_buttons.size(), 1)
	panel._remove_buttons[0].pressed.emit()
	assert_eq(game.state.production.queues["factory"], [])
	assert_eq(panel._remove_buttons.size(), 0)


func test_queued_module_part_finishes() -> void:
	_finish_building()
	for material in {"iron": 3, "aluminum": 1, "silicon": 1}:
		game.state.stock.add(material, 5.0)
	panel.open(ids["factory"])
	panel._add_buttons["module_part"].pressed.emit()
	var parts_before: float = game.state.stock.amount("module_part")
	for i in 6:
		game.state.step()
	assert_eq(game.state.stock.amount("module_part"), parts_before + 1.0)


func test_current_job_shows_progress() -> void:
	_finish_building()
	for material in {"iron": 3, "aluminum": 1, "silicon": 1}:
		game.state.stock.add(material, 5.0)
	game.state.queue_item("factory", "module_part")
	game.state.queue_item("factory", "frame_piece")
	game.state.step()
	game.state.step()
	panel.open(ids["factory"])
	assert_eq(panel._job_label.text, "Making Module part")
	assert_gt(panel._job_bar.value, 0.0)
	assert_lt(panel._job_bar.value, 1.0)
	assert_eq(panel._remove_buttons.size(), 1)


func test_idle_factory_shows_idle() -> void:
	_finish_building()
	panel.open(ids["factory"])
	assert_eq(panel._job_label.text, "Idle")


func test_repair_entries_have_no_remove_button() -> void:
	_finish_building()
	game.state.production.add_repair(1)
	game.state.production.queues["assembly"].append("habitat")
	panel.open(ids["assembly"])
	assert_eq(panel._queue_rows.size(), 2)
	assert_eq(panel._queue_rows[0], "Ship repair — Ship 2")
	assert_eq(panel._remove_buttons.size(), 1)


func test_repair_job_in_progress_shows_ship() -> void:
	_finish_building()
	game.state.stock.add("module_part", 1.0)
	game.state.production.add_repair(0)
	game.state.step()
	panel.open(ids["assembly"])
	assert_eq(panel._job_label.text, "Ship repair — Ship 1")


func test_assembly_has_no_add_button_for_repair() -> void:
	panel.open(ids["assembly"])
	assert_false(panel._add_buttons.has("ship_repair"))
	assert_true(panel._add_buttons.has("habitat"))


func test_add_button_tooltip_lists_inputs_and_hours() -> void:
	panel.open(ids["factory"])
	assert_eq(panel._add_buttons["module_part"].tooltip_text, "3 iron, 1 aluminum, 1 silicon · 4 h")


func test_refusal_reason_shows_in_red() -> void:
	panel.open(ids["factory"])
	panel._on_add("habitat")
	assert_eq(panel._refusal_label.text, "Factory can't make that")
	assert_true(panel._refusal_label.visible)
	assert_eq(game.state.production.queues["factory"], [])


func test_refusal_clears_after_successful_add() -> void:
	panel.open(ids["factory"])
	panel._on_add("habitat")
	panel._on_add("frame_piece")
	assert_false(panel._refusal_label.visible)


func test_storage_rows_show_amounts_and_capacity() -> void:
	_finish_building()
	game.state.storage.add("iron", 12.0)
	panel.open(ids["metal_storage"])
	var capacity: float = game.state.storage.capacity("iron")
	assert_eq(panel._storage_rows.size(), 7)
	assert_eq(panel._storage_rows["iron"]["label"].text, "Iron  12 / %d u" % int(capacity))
	assert_eq(panel._storage_rows["iron"]["bar"].value, 12.0 / capacity)


func test_gas_storage_lists_three_gases() -> void:
	_finish_building()
	panel.open(ids["gas_storage"])
	assert_eq(panel._storage_rows.keys(), ["hydrogen", "helium", "nitrogen"])


func test_refresh_on_step_updates_storage() -> void:
	_finish_building()
	panel.open(ids["metal_storage"])
	game.state.storage.add("nickel", 5.0)
	game.stepped.emit()
	assert_eq(panel._storage_rows["nickel"]["label"].text, "Nickel  5 / %d u" % int(game.state.storage.capacity("nickel")))


func test_plant_shows_cradle_and_supply() -> void:
	_finish_building()
	var plant_id := _build_plant()
	game.state.cradle_ice = 120.0
	game.state.life.on_platform = 7
	panel.open(plant_id)
	assert_eq(panel._plant_label.text, "Cradle 120 / %d u\nSupplying 7 of %d people" % [int(game.state.cradle_capacity()), game.state.crew])


func _build_plant() -> int:
	game.state.stock.add("frame_piece", 10.0)
	game.state.assembled["electrolysis_plant"] = 1
	var placed := false
	for port in 4:
		placed = placed or game.state.place(ids["assembly"], port, 3, "electrolysis_plant") == ""
	assert_true(placed)
	Helpers.finish_construction(game.state)
	return game.state.layout.nodes.size() - 1
