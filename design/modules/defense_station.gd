@tool
extends "res://design/modules/reinforcing_junction.gd"
## The defense station: a reinforcing junction that also defends the platform. It is
## the same block, with a red band, and still joins up to four frame trusses with the
## rail passing through, so it counts toward the rule that a module or junction is
## needed at least every 3 frame pieces. A phased plasma turret stands on top and
## another hangs underneath; the bottom one turns the other way while scanning.
## Distances are in meters.

const PlasmaTurretScript := preload("res://design/modules/plasma_turret.gd")

## How fast the turrets turn while scanning, in degrees per second. 0 stops scanning,
## and the barrels hold at tilt_deg.
@export var scan_speed_deg := 8.0:
	set(value):
		scan_speed_deg = value
		_apply_turret_settings()
## How far the barrels tilt up from level when the turrets aren't scanning.
@export_range(0.0, 60.0) var tilt_deg := 20.0:
	set(value):
		tilt_deg = value
		_apply_turret_settings()

var _turrets: Array[Node3D] = []


func _init() -> void:
	band_color = Color("e5534b")


func _rebuild() -> void:
	super()
	if not is_inside_tree():
		return
	if _turrets.is_empty():
		for flip in [false, true]:
			var turret: Node3D = PlasmaTurretScript.new()
			turret.position = Vector3(0, KEEL_BOTTOM if flip else DECK_TOP, 0)
			if flip:
				turret.rotation = Vector3(PI, 0, 0)
			add_child(turret)
			_turrets.append(turret)
	_apply_turret_settings()


func _apply_turret_settings() -> void:
	for turret in _turrets:
		turret.scan_speed_deg = scan_speed_deg
		turret.tilt_deg = tilt_deg
