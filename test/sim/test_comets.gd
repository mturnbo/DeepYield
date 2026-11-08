extends GutTest

var balance := Balance.load_default()


func _comets(seed: int) -> Comets:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return Comets.new(balance["comets"], rng)


func test_first_pass_in_window() -> void:
	for seed in range(1, 21):
		var first := _comets(seed).passes[0]
		assert_between(first["arrives"], 400, 600)
		assert_eq(first["leaves"], first["arrives"] + 200)


func test_pass_count_from_balance() -> void:
	assert_eq(_comets(1).passes.size(), 12)


func test_gaps_in_window() -> void:
	for seed in range(1, 21):
		var passes := _comets(seed).passes
		for i in range(1, passes.size()):
			var gap: int = passes[i]["arrives"] - passes[i - 1]["arrives"]
			assert_between(gap, 1500, 2500)


func test_distance_in_range() -> void:
	for seed in range(1, 21):
		for comet_pass in _comets(seed).passes:
			assert_between(comet_pass["distance"], 1.0, 2.0)


func test_in_reach_and_end() -> void:
	var comets := _comets(3)
	var first := comets.passes[0]
	assert_eq(comets.current(first["arrives"] - 1), -1)
	assert_eq(comets.current(first["arrives"]), 0)
	assert_eq(comets.current(first["leaves"] - 1), 0)
	assert_eq(comets.current(first["leaves"]), -1)
	assert_eq(comets.ended_at(first["leaves"]), 0)
	assert_eq(comets.ended_at(first["leaves"] - 1), -1)


func test_forecast_visibility() -> void:
	var comets := _comets(3)
	assert_eq(comets.next_forecast(0), 0)
	var first_leaves: int = comets.passes[0]["leaves"]
	var second_visible: int = comets.passes[1]["arrives"] - 400
	assert_eq(comets.next_forecast(first_leaves - 1), 0)
	assert_eq(comets.next_forecast(first_leaves), -1)
	assert_eq(comets.next_forecast(second_visible - 1), -1)
	assert_eq(comets.next_forecast(second_visible), 1)


func test_forecast_none_after_last_pass() -> void:
	var comets := _comets(3)
	assert_eq(comets.next_forecast(comets.passes[-1]["leaves"]), -1)


func test_same_seed_same_schedule() -> void:
	assert_eq(_comets(7).passes, _comets(7).passes)


func test_different_seed_different_schedule() -> void:
	assert_ne(_comets(7).passes, _comets(8).passes)


func test_game_state_owns_schedule() -> void:
	var state := GameState.new(balance, 5)
	assert_eq(state.comets.passes.size(), 12)
