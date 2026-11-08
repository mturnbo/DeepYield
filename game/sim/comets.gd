class_name Comets
extends RefCounted

var passes: Array[Dictionary] = []
var _in_reach: int
var _forecast: int


func _init(comet_balance: Dictionary, rng: RandomNumberGenerator) -> void:
	_in_reach = int(comet_balance["in_reach"])
	_forecast = int(comet_balance["forecast"])
	var first_arrival: Array = comet_balance["first_arrival"]
	var gap: Array = comet_balance["gap"]
	var distance: Array = comet_balance["distance"]
	var arrives := rng.randi_range(int(first_arrival[0]), int(first_arrival[1]))
	for i in int(comet_balance["passes"]):
		if i > 0:
			arrives += rng.randi_range(int(gap[0]), int(gap[1]))
		var comet_distance := rng.randf_range(float(distance[0]), float(distance[1]))
		passes.append({"arrives": arrives, "leaves": arrives + _in_reach, "distance": comet_distance})


func current(hour: int) -> int:
	for i in passes.size():
		if passes[i]["arrives"] <= hour and hour < passes[i]["leaves"]:
			return i
	return -1


func next_forecast(hour: int) -> int:
	for i in passes.size():
		if passes[i]["leaves"] > hour:
			if i == 0 or hour >= passes[i]["arrives"] - _forecast:
				return i
			return -1
	return -1


func ended_at(hour: int) -> int:
	for i in passes.size():
		if passes[i]["leaves"] == hour:
			return i
	return -1
