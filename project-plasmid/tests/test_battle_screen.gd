## F04-M01 to M04 — the watch phase. Spec §7.0, §3.4, §2.1, §7.4.
var runner: Object

var _nodes: Array = []

const STARTING_CELL := "P12-CAT-FOOD-TERM-P12-TRA-MEM-FOOD-TERM"

## Fast promoters, so the racks fill inside a battle and then churn. The starting cell on
## P12 promoters needs 96 ticks just to fill eight slots and divides at 64, so it never
## evicts anything — a fine build, and useless for watching eviction.
const CHURNING_CELL := "P2-CAT-FOOD-TERM-P2-MEM-TRA-FOOD-TERM"


func set_runner(r: Object) -> void:
	runner = r


func after_all() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _plasmid(notation: String) -> Plasmid:
	var result := PlasmidNotation.parse(notation)
	runner.check(result.ok(), "failed to parse '%s': %s" % [notation, result.error])
	return result.plasmid


func _screen(notation: String = STARTING_CELL, env: EnvironmentDef = null) -> BattleScreen:
	var screen := BattleScreen.new()
	runner.root.add_child(screen)
	_nodes.append(screen)
	screen.begin(_plasmid(notation), env if env != null else EnvironmentDef.knife_edge())
	return screen


func _digest(events: Array) -> String:
	var parts := PackedStringArray()
	for event in events:
		parts.append(str(event))
	return "\n".join(parts)


# ------------------------------------------------------- M02: speed changes nothing but speed

func test_instant_and_one_times_reach_the_same_outcome_and_the_same_log() -> void:
	# The milestone's done-when, and the architecture rule made checkable: speed controls
	# change how fast ticks are consumed, never what a tick does.
	var slow := _screen()
	while not slow.battle.is_finished():
		slow._consume(1)

	var fast := _screen()
	fast.run_instantly()

	runner.check(slow.battle.is_finished() and fast.battle.is_finished(), "one did not finish")
	runner.check_eq(
		slow.battle.outcome.kind, fast.battle.outcome.kind, "outcomes differ between speeds"
	)
	runner.check_eq(
		slow.battle.outcome.ended_at_tick,
		fast.battle.outcome.ended_at_tick,
		"battles ended on different ticks"
	)
	runner.check_eq(_digest(slow._events), _digest(fast._events), "event logs differ")


func test_every_speed_reaches_the_same_place() -> void:
	var reference := _screen()
	reference.run_instantly()

	for chunk in [1, 2, 4, 7]:
		var screen := _screen()
		while not screen.battle.is_finished():
			screen._consume(chunk)
		runner.check_eq(
			_digest(screen._events),
			_digest(reference._events),
			"consuming %d ticks at a time changed the battle" % chunk
		)


func test_the_clock_converts_seconds_into_ticks_at_the_chosen_rate() -> void:
	var clock := BattleClock.new()
	clock.speed = BattleClock.Speed.NORMAL
	runner.check_eq(clock.advance(Balance.TICK_SECONDS), 1, "1x should give one tick per tick-time")

	clock.reset()
	clock.speed = BattleClock.Speed.QUADRUPLE
	runner.check_eq(clock.advance(Balance.TICK_SECONDS), 4, "4x should give four")

	clock.reset()
	clock.speed = BattleClock.Speed.PAUSED
	runner.check_eq(clock.advance(10.0), 0, "paused should give none")


func test_the_clock_carries_leftover_time_rather_than_dropping_it() -> void:
	# Otherwise a run of short frames silently loses time and 2x is not twice 1x.
	var clock := BattleClock.new()
	clock.speed = BattleClock.Speed.NORMAL
	var ticks := 0
	for i in range(100):
		ticks += clock.advance(Balance.TICK_SECONDS / 10.0)
	runner.check_eq(ticks, 10, "ten tick-times of tiny frames should still be ten ticks")


func test_a_paused_battle_does_not_advance() -> void:
	var screen := _screen()
	screen._on_speed_pressed(BattleClock.Speed.PAUSED)
	var before := screen.battle.state.tick
	screen._process(5.0)
	runner.check_eq(screen.battle.state.tick, before, "a paused battle ran anyway")


func test_choosing_instant_resolves_immediately() -> void:
	var screen := _screen()
	screen._on_speed_pressed(BattleClock.Speed.INSTANT)
	runner.check(screen.battle.is_finished(), "instant did not finish the battle")


# ------------------------------------------------------------- M01: the cell, and evictions

func test_the_cell_view_shows_the_racks_filling() -> void:
	var screen := _screen(STARTING_CELL, EnvironmentDef.scarce())
	screen._consume(4)
	var early := screen.battle.state.rack(ResolvedProtein.Compartment.INTERNAL).count()
	screen._consume(100)
	var late := screen.battle.state.rack(ResolvedProtein.Compartment.INTERNAL).count()

	runner.check(late > early, "the rack never filled: %d then %d" % [early, late])


func test_evictions_are_named_rather_than_left_to_be_noticed() -> void:
	# §3.4: eviction is always visible and always logged. A protein vanishing silently is
	# the most confusing thing this game can do.
	var screen := _screen(CHURNING_CELL, EnvironmentDef.abundant())
	screen.run_instantly()

	runner.check(
		not screen._cell._evictions.is_empty(),
		"a full battle produced no eviction the cell view could show"
	)
	var text: String = screen._cell._evictions.values()[0]
	runner.check(text.contains("gene"), "the eviction does not name who: '%s'" % text)
	runner.check(text.contains("tick"), "the eviction does not say when: '%s'" % text)


func test_the_cell_view_forgets_evictions_when_a_new_battle_starts() -> void:
	var screen := _screen(CHURNING_CELL, EnvironmentDef.abundant())
	screen.run_instantly()
	runner.check(not screen._cell._evictions.is_empty(), "setup: expected evictions")

	screen.begin(_plasmid(CHURNING_CELL), EnvironmentDef.abundant())
	runner.check(
		screen._cell._evictions.is_empty(), "a new battle inherited the last one's evictions"
	)


# ---------------------------------------------------- M03: growth, the pool, and the ending

func test_banked_growth_and_the_pool_are_tracked_separately() -> void:
	# §2.1's split is the whole economy: one is safe, the other is spendable and losable.
	# The bar draws them differently, so it has to hold them separately.
	var screen := _screen()
	screen._consume(40)

	runner.check(screen._growth._target > 0, "no target to measure against")
	runner.check(
		screen._growth._banked == screen.battle.state.banked_growth, "banked growth is wrong"
	)
	runner.check_eq(
		screen._growth._pool, screen.battle.state.pool.available(), "pool is wrong"
	)


func test_the_pool_can_move_while_banked_growth_stands_still() -> void:
	# The §2.5 death spiral has to be visible as it happens, which means the two figures
	# must be able to disagree — a merged bar would show nothing happening.
	var screen := _screen()
	var seen_pool_without_growth := false
	var last_banked := 0

	for i in range(60):
		screen._consume(1)
		var banked: int = screen.battle.state.banked_growth
		if screen.battle.state.pool.available() > 0 and banked == last_banked:
			seen_pool_without_growth = true
		last_banked = banked

	runner.check(
		seen_pool_without_growth, "the pool and banked growth never differed, so nothing to show"
	)


func test_every_ending_is_described() -> void:
	var divided := _screen(STARTING_CELL, EnvironmentDef.knife_edge())
	divided.run_instantly()
	runner.check(
		divided._outcome_label.text.to_lower().contains("divided"),
		"a win was not announced: '%s'" % divided._outcome_label.text
	)

	var timed_out := _screen(STARTING_CELL, EnvironmentDef.scarce())
	timed_out.run_instantly()
	runner.check(
		timed_out._outcome_label.text.to_lower().contains("time ran out"),
		"a timeout was not announced: '%s'" % timed_out._outcome_label.text
	)


func test_the_screen_announces_the_outcome_to_whoever_is_listening() -> void:
	var screen := _screen()
	var reported: Array[BattleOutcome] = []
	screen.finished.connect(func(outcome: BattleOutcome) -> void: reported.append(outcome))

	screen.run_instantly()
	runner.check_eq(reported.size(), 1, "the outcome was announced %d times" % reported.size())
	runner.check_eq(
		reported[0].ended_at_tick, screen.battle.outcome.ended_at_tick, "wrong outcome reported"
	)


func test_a_finished_battle_stops_accepting_time() -> void:
	var screen := _screen()
	screen.run_instantly()
	var ended_at := screen.battle.state.tick

	screen._process(10.0)
	runner.check_eq(screen.battle.state.tick, ended_at, "a finished battle kept running")


# ------------------------------------------------------------------------ M04: the medium

func test_the_medium_view_tracks_what_is_actually_out_there() -> void:
	var screen := _screen(STARTING_CELL, EnvironmentDef.abundant())
	screen._consume(30)
	runner.check_eq(
		screen._medium._food, screen.battle.state.medium.food, "the medium view is stale"
	)
	runner.check(
		screen._medium._delivery.contains("Abundant"),
		"the medium does not name the environment: '%s'" % screen._medium._delivery
	)


func test_scarcity_is_visible_as_scarcity() -> void:
	# §7.4 makes delivery the primary balance lever, so how much food is out there should
	# be apparent before the growth rate reports it second-hand.
	var scarce := _screen(STARTING_CELL, EnvironmentDef.scarce())
	scarce._consume(60)

	var rich := _screen(STARTING_CELL, EnvironmentDef.abundant())
	rich._consume(60)

	runner.check(
		rich._medium._food > scarce._medium._food,
		"a rich medium held no more visible food than a scarce one (%d vs %d)"
		% [rich._medium._food, scarce._medium._food]
	)


# ------------------------------------------------------------------------- the shell

func test_committing_in_the_editor_starts_the_battle_screen() -> void:
	var main: Main = load("res://src/main.tscn").instantiate()
	runner.root.add_child(main)
	_nodes.append(main)

	runner.check(main.editor.visible, "the editor should be showing first")
	runner.check(not main.battle_screen.visible, "the battle screen should be hidden first")

	main.editor._on_commit_pressed()
	runner.check(main.battle_screen.visible, "committing did not open the battle screen")
	runner.check(not main.editor.visible, "the editor is still showing")
	runner.check(main.battle_screen.battle != null, "the battle screen has no battle")
	runner.check_eq(
		PlasmidNotation.serialise(main.battle_screen.battle.state.plasmid),
		main.editor.draft.notation(),
		"the battle is running a different plasmid than the one committed"
	)


func test_going_back_returns_to_the_plasmid_that_was_committed() -> void:
	var main: Main = load("res://src/main.tscn").instantiate()
	runner.root.add_child(main)
	_nodes.append(main)

	var before := main.editor.draft.notation()
	main.editor._on_commit_pressed()
	main.battle_screen.run_instantly()
	main._on_dismissed()

	runner.check(main.editor.visible, "the editor did not come back")
	runner.check(not main.battle_screen.visible, "the battle screen is still showing")
	runner.check_eq(main.editor.draft.notation(), before, "the plasmid changed while watching")
