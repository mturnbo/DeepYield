extends Node3D

signal stepped
signal speed_changed
signal run_started

var state: GameState
var run_seed := 0
var clock: SimClock
var sub_hour := 0.0
var keys_locked := false
var _speed_before_pause := "normal"


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and has_node("UI") and $UI.is_ancestor_of(node):
		node.focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	var balance := Balance.load_default()
	run_seed = int(balance["seed"])
	state = GameState.new(balance, run_seed)
	clock = SimClock.new(balance["seconds_per_hour"])
	clock.speed = "paused"


func _process(delta: float) -> void:
	var steps := clock.advance(delta)
	for i in steps:
		if state.outcome != "":
			break
		state.step()
	sub_hour = clock.pending_fraction()
	if steps > 0:
		stepped.emit()


func set_speed(speed: String) -> void:
	if speed != "paused":
		_speed_before_pause = speed
	clock.speed = speed
	speed_changed.emit()


func new_run(seed: int) -> void:
	run_seed = seed
	state = GameState.new(Balance.load_default(), run_seed)
	clock = SimClock.new(state.balance["seconds_per_hour"])
	clock.speed = "paused"
	sub_hour = 0.0
	keys_locked = false
	_speed_before_pause = "normal"
	run_started.emit()
	speed_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if state.outcome != "":
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	match event.keycode:
		KEY_SPACE, KEY_P:
			set_speed(_speed_before_pause if clock.speed == "paused" else "paused")
		KEY_1:
			if not keys_locked:
				set_speed("normal")
		KEY_2:
			if not keys_locked:
				set_speed("fast")
