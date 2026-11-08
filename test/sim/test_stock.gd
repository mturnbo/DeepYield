extends GutTest

var stock: Stock


func before_each() -> void:
	stock = Stock.new()


func test_unknown_key_is_zero() -> void:
	assert_eq(stock.amount("argon"), 0.0)


func test_add_accumulates() -> void:
	stock.add("argon", 2.0)
	stock.add("argon", 3.0)
	assert_eq(stock.amount("argon"), 5.0)


func test_has_all() -> void:
	stock.add("iron", 3.0)
	assert_true(stock.has_all({"iron": 3.0}))
	assert_false(stock.has_all({"iron": 3.0, "nickel": 1.0}))


func test_stock_take_all_is_all_or_nothing() -> void:
	stock.add("iron", 3.0)
	stock.add("nickel", 1.0)
	assert_false(stock.take_all({"iron": 4.0, "nickel": 1.0}))
	assert_eq(stock.amount("iron"), 3.0)
	assert_true(stock.take_all({"iron": 3.0, "nickel": 1.0}))
	assert_eq(stock.amount("iron"), 0.0)
	assert_eq(stock.amount("nickel"), 0.0)
