## F01-M06 — battle resolution and determinism. Spec §1, §4.2, §7.0, §10.
var runner: Object

const STARTING_CELL := "P12-CAT-FOOD-TERM-P12-TRA-MEM-FOOD-TERM"


func set_runner(r: Object) -> void:
	runner = r


func _plasmid(notation: String) -> Plasmid:
	var result := PlasmidNotation.parse(notation)
	runner.check(result.ok(), "failed to parse '%s': %s" % [notation, result.error])
	return result.plasmid


func _battle(notation: String, environment: EnvironmentDef, length: int = -1) -> Battle:
	if length < 0:
		return Battle.new(_plasmid(notation), environment)
	return Battle.new(_plasmid(notation), environment, length)


## A canonical rendering of an event stream, for comparing two runs exactly. Godot
## dictionaries keep insertion order, so identical simulation produces identical text.
func _digest(events: Array) -> String:
	var lines := PackedStringArray()
	for event in events:
		lines.append(str(event))
	return "\n".join(lines)


# ------------------------------------------------------------------ termination paths

func test_a_cell_that_reaches_its_target_divides() -> void:
	var battle := _battle(STARTING_CELL, EnvironmentDef.knife_edge())
	var outcome := battle.run()

	runner.check_eq(outcome.kind, BattleOutcome.Kind.DIVIDED, "expected a division")
	runner.check(outcome.divided(), "divided() disagrees with kind")
	runner.check(
		outcome.banked_growth >= outcome.growth_target,
		"divided without reaching the target: %d/%d" % [
			outcome.banked_growth, outcome.growth_target
		]
	)
	runner.check(
		outcome.ended_at_tick < Balance.BATTLE_LENGTH_TICKS,
		"division should have landed inside the clock, got tick %d" % outcome.ended_at_tick
	)


func test_a_cell_that_runs_out_of_clock_times_out() -> void:
	# The starting cell needs ~151 ticks at scarce density (measured at M05), so 120 is
	# not enough. This is §7.4's scarce environment doing exactly what it is for.
	var battle := _battle(STARTING_CELL, EnvironmentDef.scarce())
	var outcome := battle.run()

	runner.check_eq(outcome.kind, BattleOutcome.Kind.TIME_EXPIRED, "expected the clock to decide")
	runner.check_eq(
		outcome.ended_at_tick, Balance.BATTLE_LENGTH_TICKS, "ended on the wrong tick"
	)
	runner.check(
		outcome.banked_growth < outcome.growth_target,
		"timed out despite reaching the target"
	)
	runner.check(
		outcome.progress_percent() > 0 and outcome.progress_percent() < 100,
		"a partial run should report partial progress, got %d%%" % outcome.progress_percent()
	)


func test_dividing_on_the_final_tick_counts_as_dividing() -> void:
	# Precedence: reaching the target on the last tick is a win, not a timeout. Found by
	# first measuring the tick the cell actually divides on, then giving it exactly that
	# many ticks to do it in.
	var measured := _battle(STARTING_CELL, EnvironmentDef.knife_edge()).run()
	runner.check(measured.divided(), "setup: expected a division to measure")

	var exact := _battle(STARTING_CELL, EnvironmentDef.knife_edge(), measured.ended_at_tick)
	var outcome := exact.run()
	runner.check_eq(
		outcome.kind, BattleOutcome.Kind.DIVIDED, "the clock stole a division on the last tick"
	)


func test_lysis_is_wired_but_cannot_fire_without_toxin() -> void:
	# F05-M01 makes this condition reachable. Until then the honest answer is that a cell
	# with no toxin in its grammar cannot burst, and the outcome should never appear.
	var state := SimState.new()
	runner.check(not state.is_lysing(), "a cell with no toxin reported itself lysing")

	for env: EnvironmentDef in [
		EnvironmentDef.abundant(), EnvironmentDef.knife_edge(), EnvironmentDef.scarce()
	]:
		var outcome := _battle(STARTING_CELL, env).run()
		runner.check(
			outcome.kind != BattleOutcome.Kind.LYSED,
			"%s: a battle lysed with no toxin in the game" % env.display_name
		)


func test_a_finished_battle_is_inert() -> void:
	var battle := _battle(STARTING_CELL, EnvironmentDef.knife_edge())
	battle.run()

	var ended_at := battle.state.tick
	runner.check_eq(battle.step().size(), 0, "a finished battle kept producing events")
	runner.check_eq(battle.state.tick, ended_at, "a finished battle kept running the clock")
	runner.check_eq(battle.ticks_remaining(), 0, "a finished battle reported time left")


func test_the_end_of_the_battle_is_announced_exactly_once() -> void:
	var battle := _battle(STARTING_CELL, EnvironmentDef.knife_edge())
	var endings := 0
	for event in battle.run_collecting():
		if event.type == SimEvent.Type.BATTLE_ENDED:
			endings += 1

	runner.check_eq(endings, 1, "§9.3 needs exactly one ending to render")


# ------------------------------------------------------------------------ determinism

func test_two_runs_from_identical_inputs_produce_identical_event_streams() -> void:
	# §4.2 and §10: expression is deterministic by design, so a replay must be exact.
	# F03-M01's sandbox, F04-M02's instant resolve and F08-M02's saved runs all depend on
	# this holding byte for byte, not merely on the outcome matching.
	var first := _digest(_battle(STARTING_CELL, EnvironmentDef.knife_edge()).run_collecting())
	var second := _digest(_battle(STARTING_CELL, EnvironmentDef.knife_edge()).run_collecting())

	runner.check(not first.is_empty(), "setup: the battle produced no events at all")
	runner.check_eq(first.length(), second.length(), "replays differ in length")
	runner.check(first == second, "two identical battles produced different event streams")


func test_the_determinism_check_can_actually_tell_streams_apart() -> void:
	# Guard against the test above passing because the digest is blind. A different
	# environment must produce a visibly different stream.
	var knife := _digest(_battle(STARTING_CELL, EnvironmentDef.knife_edge()).run_collecting())
	var rich := _digest(_battle(STARTING_CELL, EnvironmentDef.abundant()).run_collecting())

	runner.check(knife != rich, "the digest cannot distinguish two different battles")


func test_a_battle_resumed_from_a_clone_continues_identically() -> void:
	# The build-phase sandbox (§9.1) steps a clone and must reach the same place the real
	# battle would. Splitting a run in half and comparing the tail proves the copy carries
	# every piece of state the tick loop reads.
	var whole := _battle(STARTING_CELL, EnvironmentDef.knife_edge())
	var straight_through: Array[SimEvent] = []
	while not whole.is_finished():
		straight_through.append_array(whole.step())

	var split := _battle(STARTING_CELL, EnvironmentDef.knife_edge())
	var first_half: Array[SimEvent] = []
	for t in range(40):
		first_half.append_array(split.step())

	# Continue from a copy of the halfway state rather than from the battle itself.
	var resumed := Battle.new(_plasmid(STARTING_CELL), EnvironmentDef.knife_edge())
	resumed.state = split.state.clone()
	var second_half: Array[SimEvent] = []
	while not resumed.is_finished():
		second_half.append_array(resumed.step())

	first_half.append_array(second_half)
	runner.check_eq(
		_digest(first_half), _digest(straight_through), "resuming from a clone diverged"
	)


func test_the_outcome_is_reproducible_across_every_environment() -> void:
	for env: EnvironmentDef in [
		EnvironmentDef.abundant(), EnvironmentDef.knife_edge(), EnvironmentDef.scarce()
	]:
		var a := _battle(STARTING_CELL, env).run()
		var b := _battle(STARTING_CELL, env).run()
		runner.check_eq(a.kind, b.kind, "%s: outcome kind differed between runs" % env.display_name)
		runner.check_eq(
			a.ended_at_tick, b.ended_at_tick, "%s: ended on different ticks" % env.display_name
		)
		runner.check_eq(
			a.banked_growth, b.banked_growth, "%s: banked different growth" % env.display_name
		)


# ------------------------------------------------------------------------- the outcome

func test_the_outcome_records_the_burden_adjusted_target() -> void:
	var battle := _battle(STARTING_CELL, EnvironmentDef.knife_edge())
	var expected := Burden.growth_target(battle.state.plasmid.size())
	var outcome := battle.run()

	runner.check_eq(outcome.growth_target, expected, "outcome did not carry the §4.1 target")


func test_a_longer_plasmid_has_further_to_go() -> void:
	# §4.1's burden, visible at the level a player experiences it: the same engine with
	# more blocks needs more growth before it can divide.
	var lean := _battle(STARTING_CELL, EnvironmentDef.knife_edge()).run()
	var padded := _battle(
		STARTING_CELL + "-P12-CAT-FOOD-CAT-FOOD-CAT-FOOD-TERM", EnvironmentDef.knife_edge()
	).run()

	runner.check(
		padded.growth_target > lean.growth_target,
		"adding blocks did not raise the target: %d vs %d" % [
			padded.growth_target, lean.growth_target
		]
	)
