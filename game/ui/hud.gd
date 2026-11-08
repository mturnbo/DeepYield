extends Control
## Top bar with the clock, speed buttons and key numbers; side panel with alerts and the checklist.

const ShipPopup = preload("res://game/ui/ship_popup.gd")
const LIGHT := Color(0.9, 0.92, 0.96)
const MUTED := Color(0.6, 0.65, 0.75)
const MINT := Color("7fe8cb")
const GOLD := Color("f2c96b")
const LOW_HOURS := 200.0

signal ship_chosen(id: int)

var _game: Node
var _fleet_buttons: Array[Button] = []
var _clock_label: Label
var _speed_buttons := {}
var _power_label: Label
var _fuel_label: Label
var _platform_label: Label
var _reserve_label: Label
var _ice_label: Label
var _crew_label: Label
var _robots_label: Label
var _frame_label: Label

@onready var _row: HBoxContainer = $TopBar/Margin/Row
@onready var _alerts: VBoxContainer = $SidePanel/Margin/List/Alerts
@onready var _checklist: VBoxContainer = $SidePanel/Margin/List/Checklist
@onready var _fleet: VBoxContainer = $SidePanel/Margin/List/Fleet


static func day_hour_text(hour: int) -> String:
	return "Day %d, %02d:00" % [hour / 24 + 1, hour % 24]


func _ready() -> void:
	_game = get_parent().get_parent()
	_build_top_bar()
	_game.stepped.connect(refresh)
	_game.speed_changed.connect(refresh)
	refresh.call_deferred()


func refresh() -> void:
	var state: GameState = _game.state
	_clock_label.text = day_hour_text(state.hour)
	_refresh_speed_buttons()
	_refresh_numbers(state)
	_refresh_alerts(state)
	_refresh_checklist(state)
	_refresh_fleet(state)


func _build_top_bar() -> void:
	_clock_label = _add_label()
	_add_speed_button("paused", "Pause")
	_add_speed_button("normal", "▶")
	_add_speed_button("fast", "▶▶")
	_power_label = _add_label()
	_fuel_label = _add_label()
	_platform_label = _add_label()
	_reserve_label = _add_label()
	_ice_label = _add_label()
	_crew_label = _add_label()
	_robots_label = _add_label()
	_frame_label = _add_label()


func _add_label() -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", LIGHT)
	_row.add_child(label)
	return label


func _add_speed_button(speed: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void: _game.set_speed(speed))
	_row.add_child(button)
	_speed_buttons[speed] = button


func _refresh_speed_buttons() -> void:
	for speed in _speed_buttons:
		var color := MINT if speed == _game.clock.speed else LIGHT
		_speed_buttons[speed].add_theme_color_override("font_color", color)


func _refresh_numbers(state: GameState) -> void:
	_power_label.text = "Power %d / %d MW" % [state.power.supply_mw, state.power.demand_mw]
	_set_warning(_power_label, state.power.short)
	_refresh_fuel(state)
	_platform_label.text = "On platform %d / %d" % [state.life.on_platform, state.crew]
	var reserve := state.life.reserve_hours(state.crew)
	_reserve_label.text = "Ship reserve %d h" % int(floor(reserve))
	_set_warning(_reserve_label, reserve < LOW_HOURS)
	_ice_label.text = "Ice %d u" % int(state.cradle_ice)
	_crew_label.text = "Crew %d" % state.crew
	var free_robots := state.robots - state.construction.robots_busy()
	_robots_label.text = "Robots %d / %d" % [free_robots, state.robots]
	_frame_label.text = "Frame %d" % int(state.stock.amount("frame_piece"))


func _refresh_fuel(state: GameState) -> void:
	if state.layout.built_nodes("fusion_generator").is_empty():
		_fuel_label.text = "Fuel —"
		_set_warning(_fuel_label, false)
		return
	var fuel_hours := state.power.fuel_hours_left(state.storage)
	if is_inf(fuel_hours):
		_fuel_label.text = "Fuel —"
		_set_warning(_fuel_label, false)
		return
	_fuel_label.text = "Fuel %d h" % int(floor(fuel_hours))
	_set_warning(_fuel_label, fuel_hours < LOW_HOURS)


func _set_warning(label: Label, warning: bool) -> void:
	label.add_theme_color_override("font_color", GOLD if warning else LIGHT)


func _refresh_alerts(state: GameState) -> void:
	_clear(_alerts)
	for alert in Advisor.alerts(state):
		var row := _add_row(_alerts, "●", GOLD, alert["text"], LIGHT)
		row.name = alert["id"]


func _refresh_checklist(state: GameState) -> void:
	_clear(_checklist)
	for item in Advisor.checklist(state):
		var row: HBoxContainer
		if item["done"]:
			row = _add_row(_checklist, "✓", MINT, item["text"], MUTED)
		else:
			row = _add_row(_checklist, "○", MUTED, item["text"], LIGHT)
		row.name = item["id"]


func _refresh_fleet(state: GameState) -> void:
	if _fleet_buttons.size() != state.fleet.ships.size():
		_rebuild_fleet(state.fleet.ships.size())
	for ship in state.fleet.ships:
		_fleet_buttons[ship.id].text = "%s · %s · %d%%" % [ShipPopup.ship_name(ship), ShipPopup.where_text(ship), ShipPopup.condition_percent(ship)]


func _rebuild_fleet(count: int) -> void:
	_clear(_fleet)
	_fleet_buttons = []
	for id in count:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: ship_chosen.emit(id))
		_fleet.add_child(button)
		_fleet_buttons.append(button)


func _add_row(parent: VBoxContainer, mark: String, mark_color: Color, text: String, text_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var mark_label := Label.new()
	mark_label.text = mark
	mark_label.add_theme_color_override("font_color", mark_color)
	row.add_child(mark_label)
	var text_label := Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size.x = 190
	text_label.add_theme_color_override("font_color", text_color)
	row.add_child(text_label)
	parent.add_child(row)
	return row


func _clear(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
