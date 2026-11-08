extends PanelContainer
## Shows one selected module: its status, what it takes in and puts out, and by kind
## its storage contents, production queue or ice cradle.

const LIGHT := Color(0.9, 0.92, 0.96)
const MUTED := Color(0.6, 0.65, 0.75)
const MINT := Color("7fe8cb")
const GOLD := Color("f2c96b")
const RED := Color("e5534b")
const FLOWS := {
	"command": {"in": "Nothing", "out": "The suggested build order"},
	"ship_dock": {"in": "Mining ships and their cargo", "out": "Raw metal and gas to storage, argon to the refinery"},
	"fusion_generator": {"in": "Hydrogen", "out": "Power for every module"},
	"refinery": {"in": "Raw metal, argon for magnesium and aluminum", "out": "Refined metal for the factory and assembly"},
	"factory": {"in": "Refined metal", "out": "Frame pieces and module parts"},
	"assembly": {"in": "Parts and refined metal", "out": "Modules, mining ships, robots and ship repairs"},
	"gas_storage": {"in": "Hydrogen, helium and nitrogen from the dock", "out": "Hydrogen for the generator, nitrogen for air"},
	"metal_storage": {"in": "Raw metal from the dock", "out": "Raw metal for the refinery"},
	"electrolysis_plant": {"in": "Comet ice, nitrogen", "out": "Water and air for the crew"},
	"habitat": {"in": "Water and air from the plant", "out": "Beds for the crew"},
	"junction": {"in": "—", "out": "—"},
}

var _game: Node
var _node_id := -1
var _refusal := ""
var _structure_key := []
var _title_label: Label
var _close_button: Button
var _status_label: Label
var _takes_label: Label
var _puts_label: Label
var _storage_rows := {}
var _job_label: Label
var _job_bar: ProgressBar
var _queue_rows: Array[String] = []
var _remove_buttons: Array[Button] = []
var _add_buttons := {}
var _refusal_label: Label
var _plant_label: Label

@onready var _list: VBoxContainer = $Margin/List


static func display_name(text: String) -> String:
	var words := text.replace("_", " ")
	return words.substr(0, 1).to_upper() + words.substr(1)


static func status_text(state: GameState, id: int) -> String:
	var platform_node := state.layout.node(id)
	if not platform_node.built:
		return "Under construction %d%%" % int(state.construction.progress(id) * 100.0)
	var crewed: bool = state.balance["modules"][platform_node.kind]["crewed"]
	if crewed and not state.power.operated.get(id, false):
		return "No operator"
	if not state.power.powered.get(id, false) and not state.power.on_battery:
		return "No power"
	if state.power.on_battery:
		return "On battery"
	return "Running"


static func status_color(text: String) -> Color:
	if text == "Running":
		return MINT
	if text == "On battery" or text.begins_with("Under construction"):
		return GOLD
	return RED


func _ready() -> void:
	_game = get_parent().get_parent()
	_game.stepped.connect(refresh)
	_game.run_started.connect(_on_run_started)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open(id: int) -> void:
	_game.get_node("UI/ShipPopup").close()
	_node_id = id
	_refusal = ""
	_structure_key = []
	visible = true
	refresh()


func _on_run_started() -> void:
	close()


func close() -> void:
	_node_id = -1
	visible = false


func refresh() -> void:
	if _node_id == -1:
		return
	if _structure_of(_game.state) == _structure_key:
		_update_in_place(_game.state)
	else:
		_rebuild()


func _structure_of(state: GameState) -> Array:
	var kind := state.layout.node(_node_id).kind
	if kind != "factory" and kind != "assembly":
		return [_node_id]
	var job: Dictionary = state.production.current[kind]
	return [_node_id, state.production.queues[kind].duplicate(), job.get("item", ""), job.get("ship_id", -1)]


func _update_in_place(state: GameState) -> void:
	var text := status_text(state, _node_id)
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", status_color(text))
	for material in _storage_rows:
		_storage_rows[material]["label"].text = _storage_text(state, material)
		_storage_rows[material]["bar"].value = _storage_fill(state, material)
	if _job_bar != null:
		_job_bar.value = _job_fill(state, state.layout.node(_node_id).kind)
	if _plant_label != null:
		_plant_label.text = _plant_text(state)


func _rebuild() -> void:
	_clear_content()
	var state: GameState = _game.state
	_structure_key = _structure_of(state)
	var kind := state.layout.node(_node_id).kind
	_add_header(kind)
	_add_status(state)
	_add_flows(kind)
	match kind:
		"gas_storage", "metal_storage":
			_add_storage_rows(state, kind)
		"factory", "assembly":
			_add_production(state, kind)
		"electrolysis_plant":
			_add_plant(state)


func _clear_content() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_storage_rows = {}
	_queue_rows = []
	_remove_buttons = []
	_add_buttons = {}
	_job_bar = null
	_plant_label = null


func _add_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 200
	label.add_theme_color_override("font_color", color)
	_list.add_child(label)
	return label


func _add_bar(value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 8)
	_list.add_child(bar)
	return bar


func _add_header(kind: String) -> void:
	var row := HBoxContainer.new()
	_title_label = Label.new()
	_title_label.text = display_name(kind)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", LIGHT)
	row.add_child(_title_label)
	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.pressed.connect(close)
	row.add_child(_close_button)
	_list.add_child(row)


func _add_status(state: GameState) -> void:
	var text := status_text(state, _node_id)
	_status_label = _add_label(text, status_color(text))


func _add_flows(kind: String) -> void:
	_takes_label = _add_label("Takes in: " + FLOWS[kind]["in"], MUTED)
	_puts_label = _add_label("Puts out: " + FLOWS[kind]["out"], MUTED)


func _add_storage_rows(state: GameState, kind: String) -> void:
	for material in state.balance["storage"][kind]:
		var label := _add_label(_storage_text(state, material), LIGHT)
		var bar := _add_bar(_storage_fill(state, material))
		_storage_rows[material] = {"label": label, "bar": bar}


func _storage_text(state: GameState, material: String) -> String:
	return "%s  %d / %d u" % [display_name(material), int(state.storage.amount(material)), int(state.storage.capacity(material))]


func _storage_fill(state: GameState, material: String) -> float:
	var capacity := state.storage.capacity(material)
	return state.storage.amount(material) / capacity if capacity > 0.0 else 0.0


func _add_plant(state: GameState) -> void:
	_plant_label = _add_label(_plant_text(state), LIGHT)


func _plant_text(state: GameState) -> String:
	return "Cradle %d / %d u\nSupplying %d of %d people" % [
		int(state.cradle_ice), int(state.cradle_capacity()), state.life.on_platform, state.crew]


func _add_production(state: GameState, building: String) -> void:
	_add_current_job(state, building)
	_add_queue(state, building)
	_add_recipe_buttons(state, building)
	_refusal_label = _add_label(_refusal, RED)
	_refusal_label.visible = _refusal != ""


func _job_text(entry: String) -> String:
	if entry.begins_with("ship_repair:"):
		return "Ship repair — Ship %d" % (int(entry.get_slice(":", 1)) + 1)
	return display_name(entry)


func _add_current_job(state: GameState, building: String) -> void:
	var job: Dictionary = state.production.current[building]
	if job.is_empty():
		_job_label = _add_label("Idle", MUTED)
		_job_bar = _add_bar(0.0)
		return
	var text := "Making " + display_name(job["item"])
	if job["item"] == "ship_repair":
		text = "Ship repair — Ship %d" % (int(job["ship_id"]) + 1)
	_job_label = _add_label(text, LIGHT)
	_job_bar = _add_bar(_job_fill(state, building))


func _job_fill(state: GameState, building: String) -> float:
	var job: Dictionary = state.production.current[building]
	if job.is_empty():
		return 0.0
	var hours: float = state.balance["recipes"][building][job["item"]]["hours"]
	return (hours - job["hours_left"]) / hours


func _add_queue(state: GameState, building: String) -> void:
	var queue: Array = state.production.queues[building]
	if not queue.is_empty():
		_add_label("Queue", MUTED)
	for index in queue.size():
		var row := HBoxContainer.new()
		var text := _job_text(queue[index])
		_queue_rows.append(text)
		var label := Label.new()
		label.text = text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", LIGHT)
		row.add_child(label)
		if not queue[index].begins_with("ship_repair:"):
			row.add_child(_make_remove_button(building, index))
		_list.add_child(row)


func _make_remove_button(building: String, index: int) -> Button:
	var button := Button.new()
	button.text = "×"
	button.pressed.connect(func() -> void: _on_remove(building, index))
	_remove_buttons.append(button)
	return button


func _add_recipe_buttons(state: GameState, building: String) -> void:
	_add_label("Add to queue", MUTED)
	var recipes: Dictionary = state.balance["recipes"][building]
	for item in recipes:
		if item == "ship_repair":
			continue
		var button := Button.new()
		button.text = display_name(item)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = _recipe_text(recipes[item])
		button.pressed.connect(func() -> void: _on_add(item))
		_list.add_child(button)
		_add_buttons[item] = button


func _recipe_text(recipe: Dictionary) -> String:
	var inputs: Array[String] = []
	for material in recipe["takes"]:
		inputs.append("%d %s" % [int(recipe["takes"][material]), material.replace("_", " ")])
	return "%s · %d h" % [", ".join(inputs), int(recipe["hours"])]


func _on_add(item: String) -> void:
	var building: String = _game.state.layout.node(_node_id).kind
	_refusal = _game.state.queue_item(building, item)
	_rebuild()


func _on_remove(building: String, index: int) -> void:
	_game.state.remove_queued(building, index)
	_rebuild()
