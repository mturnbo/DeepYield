class_name Construction
extends RefCounted

var sites: Array = []
var _robots_per_job: int
var _busy := 0


func _init(work_balance: Dictionary) -> void:
	_robots_per_job = int(work_balance["robots_per_job"])


func add_site(node_id: int, robot_hours: float) -> void:
	sites.append({"node_id": node_id, "total": robot_hours, "done": 0.0})


func step(robots: int) -> Array[int]:
	var finished: Array[int] = []
	var free := robots
	for site in sites:
		var assigned := mini(free, _robots_per_job)
		site["done"] += assigned
		free -= assigned
		if site["done"] >= site["total"]:
			finished.append(site["node_id"])
	_busy = robots - free
	sites = sites.filter(func(site): return not finished.has(site["node_id"]))
	return finished


func progress(node_id: int) -> float:
	for site in sites:
		if site["node_id"] == node_id:
			return site["done"] / site["total"]
	return 1.0


func robots_busy() -> int:
	return _busy
