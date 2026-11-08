extends GutTest

var storage: Storage


func before_each() -> void:
	storage = Storage.new(Balance.load_default()["storage"])


func test_no_storage_means_no_room() -> void:
	assert_eq(storage.room("hydrogen"), 0.0)
	assert_eq(storage.add("hydrogen", 5.0), 0.0)


func test_capacity_per_module() -> void:
	storage.set_modules(1, 1)
	assert_eq(storage.capacity("hydrogen"), 60.0)
	assert_eq(storage.capacity("iron"), 30.0)
	storage.set_modules(2, 0)
	assert_eq(storage.capacity("hydrogen"), 120.0)
	assert_eq(storage.capacity("iron"), 0.0)


func test_material_without_container_has_no_capacity() -> void:
	storage.set_modules(3, 3)
	assert_eq(storage.capacity("argon"), 0.0)
	assert_eq(storage.add("argon", 4.0), 0.0)


func test_add_stops_at_capacity() -> void:
	storage.set_modules(1, 0)
	assert_eq(storage.add("helium", 70.0), 60.0)
	assert_true(storage.is_full("helium"))
	assert_eq(storage.room("helium"), 0.0)


func test_take_only_what_is_there() -> void:
	storage.set_modules(0, 1)
	storage.add("iron", 5.0)
	assert_eq(storage.take("iron", 8.0), 5.0)
	assert_eq(storage.amount("iron"), 0.0)


func test_take_part_of_what_is_there() -> void:
	storage.set_modules(0, 1)
	storage.add("iron", 5.0)
	assert_eq(storage.take("iron", 2.0), 2.0)
	assert_eq(storage.amount("iron"), 3.0)


func test_most_stored() -> void:
	storage.set_modules(0, 1)
	assert_eq(storage.most_stored(["iron", "nickel"]), "")
	storage.add("iron", 4.0)
	storage.add("nickel", 9.0)
	assert_eq(storage.most_stored(["iron", "nickel"]), "nickel")


func test_most_stored_tie_goes_to_list_order() -> void:
	storage.set_modules(0, 1)
	storage.add("iron", 4.0)
	storage.add("nickel", 4.0)
	assert_eq(storage.most_stored(["nickel", "iron"]), "nickel")
