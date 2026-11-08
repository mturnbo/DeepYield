class_name SimClock
extends RefCounted

const MAX_STEPS_PER_FRAME := 8

var speed: String = "normal"
var _seconds_per_hour: Dictionary
var _pending_hours := 0.0


func _init(seconds_per_hour: Dictionary) -> void:
	_seconds_per_hour = seconds_per_hour


func advance(delta: float) -> int:
	if speed == "paused":
		return 0
	_pending_hours += delta / _seconds_per_hour[speed]
	var steps := mini(int(_pending_hours), MAX_STEPS_PER_FRAME)
	_pending_hours -= steps
	return steps


func pending_fraction() -> float:
	return minf(_pending_hours, 1.0)
