## F01-M01 — tick loop, banked growth, and the event stream. Spec §2.1, §2.5, §9.3.
var runner: Object


func set_runner(r: Object) -> void:
	runner = r


func _step_n(state: SimState, n: int) -> Array:
	var all: Array = []
	for i in range(n):
		all.append_array(state.step())
	return all


func _of_type(events: Array, type: SimEvent.Type) -> Array:
	return events.filter(func(e): return e.type == type)


func test_matured_metabolites_become_banked_growth() -> void:
	var state := SimState.new()
	state.produce(3)
	_step_n(state, Balance.MATURATION_AGE)

	runner.check_eq(state.banked_growth, 3, "maturation did not bank")
	runner.check_eq(state.pool.available(), 0, "pool was not drained by maturation")


func test_banked_growth_survives_the_pool_being_emptied() -> void:
	var state := SimState.new()
	state.produce(2)
	_step_n(state, Balance.MATURATION_AGE)
	runner.check_eq(state.banked_growth, 2, "setup: expected 2 banked before the wipe")

	state.produce(5)
	runner.check(state.try_spend(5, &"test"), "could not spend the fresh pool")

	runner.check_eq(state.pool.available(), 0, "pool should be empty")
	runner.check_eq(state.banked_growth, 2, "spending reached banked growth")


func test_spending_more_than_the_pool_holds_stalls() -> void:
	var state := SimState.new()
	state.produce(1)

	runner.check(not state.try_spend(2, &"efflux"), "overspend was allowed")
	runner.check_eq(state.pool.available(), 1, "a failed spend still cost metabolites")


func test_maturation_emits_an_event_carrying_the_tick_it_happened_on() -> void:
	var state := SimState.new()
	state.produce(1)
	var matured := _of_type(
		_step_n(state, Balance.MATURATION_AGE), SimEvent.Type.METABOLITE_MATURED
	)

	runner.check_eq(matured.size(), 1, "expected exactly one maturation event")
	runner.check_eq(matured[0].data["count"], 1, "wrong count on the event")
	runner.check_eq(
		matured[0].tick,
		Balance.MATURATION_AGE - 1,
		"event carried the tick after the one it happened on"
	)


func test_a_stall_is_visible_in_the_event_stream() -> void:
	var state := SimState.new()
	state.try_spend(1, &"efflux")

	var failures := _of_type(state.step(), SimEvent.Type.SPEND_FAILED)
	runner.check_eq(failures.size(), 1, "the §2.5 stall left no trace in the log")
	runner.check_eq(failures[0].data["reason"], &"efflux", "stall was not attributable")


func test_events_do_not_repeat_on_the_following_step() -> void:
	var state := SimState.new()
	state.produce(1)
	runner.check_eq(state.step().size(), 1, "expected the production event")
	runner.check_eq(state.step().size(), 0, "events were replayed on the next step")


func test_stepping_a_clone_does_not_touch_the_original() -> void:
	var state := SimState.new()
	state.produce(4)
	var copy: SimState = state.clone()

	_step_n(copy, Balance.MATURATION_AGE)

	runner.check_eq(copy.banked_growth, 4, "clone did not run forward")
	runner.check_eq(state.banked_growth, 0, "a sandbox run leaked into the original")
	runner.check_eq(state.tick, 0, "a sandbox run advanced the original's clock")
	runner.check_eq(state.pool.available(), 4, "a sandbox run drained the original's pool")
