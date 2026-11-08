extends GutTest

var seconds_per_hour := {"normal": 2.0, "fast": 0.5}


func _make_clock(speed: String) -> SimClock:
	var clock := SimClock.new(seconds_per_hour)
	clock.speed = speed
	return clock


func test_normal_speed_steps_every_two_seconds():
	var clock := _make_clock("normal")
	assert_eq(clock.advance(1.9), 0)
	assert_eq(clock.advance(0.2), 1)


func test_fast_speed():
	var clock := _make_clock("fast")
	assert_eq(clock.advance(1.0), 2)


func test_paused_never_steps():
	var clock := _make_clock("paused")
	assert_eq(clock.advance(100.0), 0)


func test_long_frame_is_capped_and_remainder_kept():
	var clock := _make_clock("fast")
	assert_eq(clock.advance(10.0), 8)
	assert_eq(clock.advance(0.0), 8)
	assert_eq(clock.advance(0.0), 4)


func test_pending_fraction_is_the_part_of_an_hour_not_yet_stepped():
	var clock := _make_clock("normal")
	clock.advance(3.0)
	assert_almost_eq(clock.pending_fraction(), 0.5, 0.0001)


func test_pending_fraction_starts_at_zero():
	assert_eq(_make_clock("normal").pending_fraction(), 0.0)


func test_pending_fraction_never_exceeds_one_after_a_capped_frame():
	var clock := _make_clock("fast")
	clock.advance(10.0)
	assert_eq(clock.pending_fraction(), 1.0)
