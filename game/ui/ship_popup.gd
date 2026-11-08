extends PanelContainer
## One mining ship: where it is, what it carries, its assignment editor, ice orders and repair.

const ModulePanel = preload("res://game/ui/module_panel.gd")
const LIGHT := Color(0.9, 0.92, 0.96)
const MUTED := Color(0.6, 0.65, 0.75)
const MINT := Color("7fe8cb")
const RED := Color("e5534b")
const DISABLED := Color(1, 1, 1, 0.3)
const TOP_OFFSET := 64.0
const WINDOW_MARGIN := 40.0
const SITES := ["nebula", "asteroids"]
const LEG_STATES := ["outbound", "working", "inbound", "ice_outbound", "carving", "towing"]

var _game: Node
var _ship_id := -1
var _site := "nebula"
var _title_label: Label
var _where_label: Label
var _condition_label: Label
var _cargo_label: Label
var _assignment_label: Label
var _next_label: Label
var _leg_label: Label
var _site_buttons := {}
var _checks := {}
var _check_grid: GridContainer
var _apply_label: Label
var _fetch_buttons := {}
var _fetch_label: Label
var _repair_button: Button

@onready var _scroll: ScrollContainer = $Margin/Scroll
@onready var _list: VBoxContainer = $Margin/Scroll/List


static func ship_name(ship: MiningShip) -> String:
	return "Ship %d" % (ship.id + 1)


static func where_text(ship: MiningShip) -> String:
	match ship.state:
		"in_cargo":
			return "In cargo bay"
		"docked":
			return "Waiting to unload" if ship.waiting_for_room else "Docked"
		"outbound":
			return "To the " + ship.destination
		"ice_outbound":
			return "To the comet"
		"working":
			return "Mining"
		"carving":
			return "Carving ice"
		"towing":
			return "Towing ice"
		"at_plant":
			return "Waiting at the plant"
		"inbound":
			return "Coming home"
		"holding":
			return "Holding"
	return ""


static func condition_percent(ship: MiningShip) -> int:
	return int(round(ship.condition * 100.0))


static func cargo_text(ship: MiningShip) -> String:
	var parts: Array[String] = []
	for material in ship.cargo:
		if int(ship.cargo[material]) > 0:
			parts.append("%d %s" % [int(ship.cargo[material]), material])
	if parts.is_empty():
		return "Cargo: empty"
	return "Cargo: " + ", ".join(parts)


static func assignment_text(label: String, assignment: Dictionary) -> String:
	if assignment.is_empty():
		return label + ": none"
	var names: Array[String] = []
	for material in assignment["materials"]:
		names.append(material)
	return "%s: %s, %s" % [label, ModulePanel.display_name(assignment["site"]), ", ".join(names)]


static func chunk_text(chunk: int) -> String:
	return "%d,%03d u" % [chunk / 1000, chunk % 1000]


func _ready() -> void:
	_game = get_parent().get_parent()
	_game.stepped.connect(refresh)
	_game.run_started.connect(_on_run_started)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open(id: int) -> void:
	_ship_id = id
	var ship: MiningShip = _game.state.fleet.ship(id)
	_site = ship.assignment.get("site", "nebula")
	_game.get_node("UI/ModulePanel").close()
	_rebuild(ship)
	visible = true
	refresh()


func _on_run_started() -> void:
	close()


func close() -> void:
	_ship_id = -1
	visible = false


func refresh() -> void:
	if _ship_id == -1:
		return
	var state: GameState = _game.state
	var ship: MiningShip = state.fleet.ship(_ship_id)
	_where_label.text = where_text(ship)
	_condition_label.text = "Condition %d%%" % condition_percent(ship)
	_cargo_label.text = cargo_text(ship)
	_assignment_label.text = assignment_text("Assignment", ship.assignment)
	_next_label.text = assignment_text("Next", ship.next_assignment)
	_next_label.visible = not ship.next_assignment.is_empty()
	_leg_label.text = "%d h left on this leg" % ship.hours_left
	_leg_label.visible = LEG_STATES.has(ship.state)
	var comet_in_reach := state.comets.current(state.hour) >= 0
	for chunk in _fetch_buttons:
		_fetch_buttons[chunk].disabled = not comet_in_reach
	_repair_button.disabled = ship.repair_requested
	_repair_button.text = "Repair requested" if ship.repair_requested else "Repair"
	_fit_to_window()


func _fit_to_window() -> void:
	var available := get_viewport().get_visible_rect().size.y - TOP_OFFSET - WINDOW_MARGIN
	_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, available)


func _rebuild(ship: MiningShip) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_site_buttons = {}
	_checks = {}
	_fetch_buttons = {}
	_add_header(ship)
	_where_label = _add_label(LIGHT)
	_condition_label = _add_label(LIGHT)
	_cargo_label = _add_label(LIGHT)
	_leg_label = _add_label(MUTED)
	_assignment_label = _add_label(MUTED)
	_next_label = _add_label(MUTED)
	_add_editor(ship)
	_add_ice_orders()
	_add_repair()


func _add_label(color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 230
	label.add_theme_color_override("font_color", color)
	_list.add_child(label)
	return label


func _add_header(ship: MiningShip) -> void:
	var row := HBoxContainer.new()
	_title_label = Label.new()
	_title_label.text = ship_name(ship)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", LIGHT)
	row.add_child(_title_label)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.pressed.connect(close)
	row.add_child(close_button)
	_list.add_child(row)


func _add_editor(ship: MiningShip) -> void:
	_add_section_title("Assignment")
	var site_row := HBoxContainer.new()
	var group := ButtonGroup.new()
	for site in SITES:
		var button := Button.new()
		button.text = ModulePanel.display_name(site)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = site == _site
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_disabled_color", DISABLED)
		button.pressed.connect(func() -> void: _on_site(site))
		site_row.add_child(button)
		_site_buttons[site] = button
	_list.add_child(site_row)
	_check_grid = GridContainer.new()
	_check_grid.columns = 2
	_list.add_child(_check_grid)
	_fill_checks(ship.assignment.get("materials", []) if ship.assignment.get("site", "") == _site else [])
	var apply_button := Button.new()
	apply_button.text = "Apply"
	apply_button.pressed.connect(_on_apply)
	_list.add_child(apply_button)
	_apply_label = _add_label(RED)
	_apply_label.visible = false


func _add_section_title(text: String) -> void:
	var label := _add_label(MUTED)
	label.text = text


func _fill_checks(selected: Array) -> void:
	for child in _check_grid.get_children():
		_check_grid.remove_child(child)
		child.queue_free()
	_checks = {}
	for material in _game.state.balance["mining"][_site]["materials"]:
		var box := CheckBox.new()
		box.text = ModulePanel.display_name(material)
		box.button_pressed = selected.has(material)
		box.add_theme_color_override("font_disabled_color", DISABLED)
		box.toggled.connect(func(_on: bool) -> void: _update_check_limits())
		_check_grid.add_child(box)
		_checks[material] = box
	_update_check_limits()


func _checked_materials() -> Array:
	var chosen: Array = []
	for material in _checks:
		if _checks[material].button_pressed:
			chosen.append(material)
	return chosen


func _update_check_limits() -> void:
	var full: bool = _checked_materials().size() >= int(_game.state.balance["mining"][_site]["max"])
	for material in _checks:
		_checks[material].disabled = full and not _checks[material].button_pressed


func _on_site(site: String) -> void:
	_site = site
	_fill_checks([])
	_apply_label.visible = false


func _on_apply() -> void:
	var refusal: String = _game.state.assign_ship(_ship_id, _site, _checked_materials())
	_show_result(_apply_label, refusal)
	refresh()


func _show_result(label: Label, refusal: String) -> void:
	label.visible = true
	label.text = refusal if refusal != "" else "Assigned"
	label.add_theme_color_override("font_color", RED if refusal != "" else MINT)


func _add_ice_orders() -> void:
	_add_section_title("Fetch ice")
	var row := HBoxContainer.new()
	for chunk in _game.state.balance["comets"]["chunks"]:
		var button := Button.new()
		button.text = chunk_text(int(chunk))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_disabled_color", DISABLED)
		button.pressed.connect(func() -> void: _on_fetch(int(chunk)))
		row.add_child(button)
		_fetch_buttons[int(chunk)] = button
	_list.add_child(row)
	_fetch_label = _add_label(RED)
	_fetch_label.visible = false


func _on_fetch(chunk: int) -> void:
	var refusal: String = _game.state.fetch_ice(_ship_id, chunk)
	_fetch_label.visible = refusal != ""
	_fetch_label.text = refusal
	refresh()


func _add_repair() -> void:
	_repair_button = Button.new()
	_repair_button.add_theme_color_override("font_disabled_color", DISABLED)
	_repair_button.pressed.connect(func() -> void:
		_game.state.request_repair(_ship_id)
		refresh())
	_list.add_child(_repair_button)
