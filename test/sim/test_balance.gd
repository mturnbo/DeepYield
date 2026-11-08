extends GutTest


func test_loads_default():
	var balance = Balance.load_default()
	assert_eq(balance["seconds_per_hour"]["normal"], 2.0)
	assert_eq(int(balance["start"]["crew"]), 12)
