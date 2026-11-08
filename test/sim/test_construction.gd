extends GutTest

var construction: Construction


func before_each() -> void:
	construction = Construction.new(Balance.load_default()["work"])


func test_one_site_gets_four_robots() -> void:
	construction.add_site(0, 120.0)
	construction.step(20)
	assert_eq(construction.progress(0), 4.0 / 120.0)
	assert_eq(construction.robots_busy(), 4)


func test_robots_split_in_order() -> void:
	for id in 6:
		construction.add_site(id, 8.0)
	construction.step(20)
	for id in 5:
		assert_eq(construction.progress(id), 0.5)
	assert_eq(construction.progress(5), 0.0)
	assert_eq(construction.robots_busy(), 20)


func test_site_finishes() -> void:
	construction.add_site(7, 8.0)
	assert_eq(construction.step(4), [] as Array[int])
	assert_eq(construction.step(4), [7] as Array[int])
	assert_true(construction.sites.is_empty())


func test_no_robots_no_progress() -> void:
	construction.add_site(0, 8.0)
	assert_eq(construction.step(0), [] as Array[int])
	assert_eq(construction.progress(0), 0.0)
	assert_eq(construction.robots_busy(), 0)


func test_leftover_robots_stay_idle() -> void:
	construction.add_site(0, 8.0)
	construction.step(20)
	assert_eq(construction.robots_busy(), 4)


func test_last_robot_hours_do_not_overshoot() -> void:
	construction.add_site(0, 6.0)
	construction.step(4)
	assert_eq(construction.step(4), [0] as Array[int])
