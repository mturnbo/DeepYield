class_name LifeSupport
extends RefCounted

var reserve: float
var on_platform := 0
var dependent := 0
var _beds_per_habitat: int
var _places_per_plant: int
var _people_per_ice: float
var _person_hours_per_nitrogen: float


func _init(balance: Dictionary) -> void:
	reserve = float(balance["arrival_ship"]["reserve_person_hours"])
	_beds_per_habitat = int(balance["life"]["habitat_beds"])
	_places_per_plant = int(balance["life"]["plant_capacity"])
	_people_per_ice = float(balance["life"]["people_per_ice"])
	_person_hours_per_nitrogen = float(balance["life"]["person_hours_per_nitrogen"])


func step(state: GameState) -> String:
	var beds := _beds_per_habitat * _running_count(state, "habitat")
	var plant_places := _places_per_plant * _running_count(state, "electrolysis_plant")
	var ice_places := int(floor(state.cradle_ice * _people_per_ice))
	var nitrogen_places := int(floor(state.storage.amount("nitrogen") * _person_hours_per_nitrogen))
	on_platform = mini(mini(state.crew, beds), mini(plant_places, mini(ice_places, nitrogen_places)))
	dependent = state.crew - on_platform
	state.cradle_ice -= on_platform / _people_per_ice
	state.storage.take("nitrogen", on_platform / _person_hours_per_nitrogen)
	reserve -= dependent
	if reserve <= 0.0 and dependent > 0:
		return "air_water"
	return ""


func reserve_hours(crew: int) -> float:
	if crew == 0:
		return INF
	return reserve / crew


func _running_count(state: GameState, kind: String) -> int:
	var count := 0
	for node in state.layout.built_nodes(kind):
		if state.is_running(node.id):
			count += 1
	return count
