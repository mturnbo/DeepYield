extends Control
## Shown when the run has an outcome: the result, a few numbers and a button for a new run.

const LIGHT := Color(0.9, 0.92, 0.96)
const MINT := Color("7fe8cb")
const RED := Color("e5534b")

var _game: Node
var _title_label: Label
var _hours_label: Label
var _reserve_label: Label
var _crew_label: Label
var _new_run_button: Button

@onready var _list: VBoxContainer = $Center/Panel/Margin/List


static func title_text(outcome: String, reason: String) -> String:
	match outcome:
		"won":
			return "Platform held"
		"collapsed":
			if reason == "energy":
				return "Collapse: energy ran out"
			return "Collapse: oxygen and water ran out"
	return "Run ended"


static func title_color(outcome: String) -> Color:
	match outcome:
		"won":
			return MINT
		"collapsed":
			return RED
	return LIGHT


static func hours_operated(summary: Dictionary) -> int:
	if summary["outcome"] == "collapsed":
		return int(summary["hours"]) + 1
	return int(summary["hours"])


static func crew_text(hour: int) -> String:
	if hour == -1:
		return "Whole crew on the platform: never"
	return "Whole crew on the platform: hour %d" % hour


func _ready() -> void:
	_game = get_parent().get_parent()
	_game.stepped.connect(refresh)
	_game.run_started.connect(_on_run_started)
	_build()
	visible = false


func _build() -> void:
	_title_label = _add_label()
	_title_label.add_theme_font_size_override("font_size", 28)
	_hours_label = _add_label()
	_reserve_label = _add_label()
	_crew_label = _add_label()
	_new_run_button = Button.new()
	_new_run_button.text = "New run"
	_new_run_button.pressed.connect(func() -> void: _game.new_run(_game.run_seed + 1))
	_list.add_child(_new_run_button)


func _add_label() -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", LIGHT)
	_list.add_child(label)
	return label


func _on_run_started() -> void:
	visible = false


func refresh() -> void:
	var state: GameState = _game.state
	if state.outcome == "":
		return
	var summary := state.summary()
	_title_label.text = title_text(summary["outcome"], summary["reason"])
	_title_label.add_theme_color_override("font_color", title_color(summary["outcome"]))
	_hours_label.text = "Hours operated: %d" % hours_operated(summary)
	_reserve_label.text = "Ship reserve left: %d h" % int(floor(summary["reserve_hours_left"]))
	_crew_label.text = crew_text(int(summary["first_all_on_platform_hour"]))
	visible = true
	_game.set_speed("paused")
