extends PanelContainer
## Lists the kits and assembled modules the player can place; greyed when none are left.

signal item_chosen(kind: String)

var _game: Node
var _buttons := {}

@onready var _list: VBoxContainer = $Margin/List


func _ready() -> void:
	_game = get_parent().get_parent()
	_game.stepped.connect(refresh)
	refresh.call_deferred()


func refresh() -> void:
	for kind in _game.state.kits:
		_show_entry("kit:" + kind, kind, kind_name(kind) + " (kit)", _game.state.kits[kind])
	for kind in _game.state.assembled:
		var count: int = _game.state.assembled[kind]
		_show_entry("assembled:" + kind, kind, "%s ×%d" % [kind_name(kind), count], count)


func kind_name(kind: String) -> String:
	var words := kind.replace("_", " ")
	return words.substr(0, 1).to_upper() + words.substr(1)


func _show_entry(key: String, kind: String, text: String, count: int) -> void:
	if not _buttons.has(key):
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
		button.pressed.connect(func() -> void: item_chosen.emit(kind))
		_list.add_child(button)
		_buttons[key] = button
	_buttons[key].text = text
	_buttons[key].disabled = count == 0
