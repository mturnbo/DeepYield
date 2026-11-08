extends Node3D

signal stepped
signal speed_changed

var state: GameState
var clock: SimClock
var sub_hour := 0.0
var keys_locked := false
var _speed_before_pause := "normal"


func _ready() -> void:
	var balance := Balance.load_default()
	state = GameState.new(balance, int(balance["seed"]))
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


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
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
