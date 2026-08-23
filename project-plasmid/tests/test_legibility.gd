## F03-M01 to M04 — sandbox, steady-state prediction, bottleneck, event log.
## Spec §9.1, §9.2, §9.3, §7.4.
var runner: Object

var _editors: Array = []

const STARTING_CELL := "P12-CAT-FOOD-TERM-P12-TRA-MEM-FOOD-TERM"

## Far more food than any Prototype 1 engine can eat, so the limit falls on the plasmid
## instead of the environment.
const SATURATED_DELIVERY := 2000

## Two internal genes at rates 3 and 1 competing for eight slots, plus importers to pay
## for it all. Without the importer gene the cell earns nothing, runs its endowment out
## and stalls before its racks ever settle — which is a fine thing for the sim to do and
## a useless thing to measure steady state on.
const COMPETING_GENES := (
	"P4-CAT-FOOD-TERM-P12-CAT-FOOD-TERM-P4-MEM-TRA-FOOD-TERM"
)


func set_runner(r: Object) -> void:
	runner = r


func _plasmid(notation: String) -> Plasmid:
	var result := PlasmidNotation.parse(notation)
	runner.check(result.ok(), "failed to parse '%s': %s" % [notation, result.error])
	return result.plasmid


func _saturated() -> EnvironmentDef:
	var env := EnvironmentDef.new()
	env.display_name = "Saturated"
	env.food_delivery_scaled = SATURATED_DELIVERY
	env.food_yield = 3
	env.starting_food = 200
	return env


func _digest(events: Array) -> String:
	var parts := PackedStringArray()
	for event in events:
		parts.append(str(event))
	return "\n".join(parts)


# ------------------------------------------------------- M01: the sandbox is faithful

func test_the_sandbox_produces_exactly_what_the_committed_battle_produces() -> void:
	# §9.1's whole value rests on this. A sandbox that drifts from the real battle would
	# teach players a game they are not playing.
	var plasmid := _plasmid(STARTING_CELL)
	var environment := EnvironmentDef.knife_edge()

	var sandbox := Sandbox.new(plasmid, environment)
	sandbox.run_to_end()

	var committed := Battle.new(plasmid, environment)
	var straight_through := committed.run_collecting()

	runner.check(not sandbox.events.is_empty(), "the sandbox produced no events")
	runner.check_eq(
		_digest(sandbox.events), _digest(straight_through), "the sandbox diverged from the battle"
	)


func test_stepping_one_tick_at_a_time_matches_running_straight_through() -> void:
	var plasmid := _plasmid(STARTING_CELL)
	var environment := EnvironmentDef.knife_edge()

	var one_at_a_time := Sandbox.new(plasmid, environment)
	for t in range(60):
		one_at_a_time.step()

	var in_one_go := Sandbox.new(plasmid, environment)
	in_one_go.step(60)

	runner.check_eq(
		_digest(one_at_a_time.events), _digest(in_one_go.events), "step size changed the outcome"
	)
	runner.check_eq(one_at_a_time.tick(), in_one_go.tick(), "clocks disagree")


func test_the_sandbox_shows_slots_filling_up_over_time() -> void:
	# What §9.1 asks a player to be able to watch: proteins get built, slots fill. Uses a
	# scarce medium so the battle runs its full length — a healthy cell divides at tick 73
	# and the sandbox rightly stops there, before the rack has finished filling.
	var sandbox := Sandbox.new(_plasmid(STARTING_CELL), EnvironmentDef.scarce())
	var internal := ResolvedProtein.Compartment.INTERNAL

	sandbox.step(4)
	var early := sandbox.state().rack(internal).count()
	sandbox.step(100)
	var late := sandbox.state().rack(internal).count()

	runner.check(early < late, "the rack never filled: %d then %d" % [early, late])
	runner.check_eq(late, Balance.SLOTS_PER_COMPARTMENT, "the rack did not reach capacity")


func test_the_sandbox_never_touches_the_plasmid_it_was_given() -> void:
	var plasmid := _plasmid(STARTING_CELL)
	var before := PlasmidNotation.serialise(plasmid)

	var sandbox := Sandbox.new(plasmid, EnvironmentDef.abundant())
	sandbox.run_to_end()

	runner.check_eq(PlasmidNotation.serialise(plasmid), before, "the sandbox edited the plasmid")


# ------------------------------------------------- M02: the steady-state readout panel

func test_the_predicted_rack_is_the_one_the_sim_settles_into() -> void:
	# §3.1's equilibrium, shown. A 4-tick and a 12-tick promoter competing for eight
	# internal slots settle at 6:2 — the case where a strong promoter starves a weak one.
	var prediction := Prediction.run(_plasmid(COMPETING_GENES), _saturated())
	var internal: Dictionary = prediction.racks[ResolvedProtein.Compartment.INTERNAL]

	runner.check_eq(internal.get(0, 0), 6, "the fast gene should hold six slots")
	runner.check_eq(internal.get(4, 0), 2, "the slow gene should hold two")


func test_the_predicted_rack_matches_the_one_the_cell_really_reaches() -> void:
	# The panel is showing the cell the player is about to run, so the two must land in
	# the same place. Compared against a plain SimState driven the same distance, since a
	# Battle would stop at division long before the racks settle.
	for notation in [
		STARTING_CELL,
		"P4-CAT-FOOD-TERM-P12-CAT-FOOD-TERM",
		"P6-CAT-FOOD-TERM-P6-MEM-TRA-FOOD-TERM",
	]:
		var environment := EnvironmentDef.knife_edge()
		var prediction := Prediction.run(_plasmid(notation), environment)

		var actual := SimState.new()
		actual.begin_battle(_plasmid(notation), environment)
		for t in range(Prediction.PREDICTION_TICKS):
			actual.step()

		for compartment in range(actual.racks.size()):
			runner.check_eq(
				prediction.racks[compartment],
				actual.rack(compartment).composition(),
				"%s: predicted rack differs from the real one in compartment %d"
				% [notation, compartment]
			)


func test_measured_upkeep_matches_the_churn_the_formula_predicts() -> void:
	# §3.2: churn is the rent on slot share, paid every tick forever. The measured spend
	# has to match what ExpressionUnit works out analytically, or one of the two is lying.
	var plasmid := _plasmid(COMPETING_GENES)
	var expected := 0
	for unit in GeneExpression.compile(plasmid):
		expected += unit.upkeep_per_tick_scaled(Prediction.SCALE)

	var prediction := Prediction.run(plasmid, _saturated())
	runner.check(
		absi(prediction.upkeep_scaled - expected) <= 3,
		"formula says %s upkeep, the run measured %s"
		% [Prediction.rate_text(expected), Prediction.rate_text(prediction.upkeep_scaled)]
	)


func test_net_is_gross_minus_what_it_costs_to_run() -> void:
	var prediction := Prediction.run(_plasmid(STARTING_CELL), EnvironmentDef.knife_edge())
	runner.check_eq(
		prediction.net_scaled,
		prediction.gross_scaled - prediction.upkeep_scaled - prediction.transport_scaled,
		"net does not reconcile with gross, upkeep and transport"
	)
	runner.check(prediction.gross_scaled > 0, "a working cell predicted no yield at all")


func test_a_richer_environment_predicts_a_better_rate() -> void:
	var scarce := Prediction.run(_plasmid(STARTING_CELL), EnvironmentDef.scarce())
	var rich := Prediction.run(_plasmid(STARTING_CELL), EnvironmentDef.abundant())
	runner.check(
		rich.net_scaled > scarce.net_scaled,
		"abundant food did not predict a better rate than scarce: %s vs %s"
		% [Prediction.rate_text(rich.net_scaled), Prediction.rate_text(scarce.net_scaled)]
	)


func test_rates_read_as_decimals() -> void:
	runner.check_eq(Prediction.rate_text(133), "1.33", "positive")
	runner.check_eq(Prediction.rate_text(8), "0.08", "small")
	runner.check_eq(Prediction.rate_text(-25), "-0.25", "negative")


# ---------------------------------------------- M03: the pipeline and its narrow point

func test_starving_a_working_build_moves_the_bottleneck_to_the_front() -> void:
	# The milestone's done-when. Same plasmid, less food; nothing about the readout
	# changes except what it points at.
	var fed := Prediction.run(_plasmid(STARTING_CELL), _saturated())
	var starved := Prediction.run(_plasmid(STARTING_CELL), EnvironmentDef.scarce())

	runner.check(
		fed.bottleneck != Prediction.Stage.SUPPLY,
		"a saturated medium was still called supply-limited"
	)
	runner.check_eq(
		starved.bottleneck,
		Prediction.Stage.SUPPLY,
		"a starved cell was not called supply-limited (got %s)"
		% starved.stage_name(starved.bottleneck)
	)


func test_a_cell_with_no_importers_is_called_import_limited() -> void:
	var prediction := Prediction.run(_plasmid("P12-CAT-FOOD-TERM"), EnvironmentDef.abundant())
	runner.check_eq(
		prediction.bottleneck,
		Prediction.Stage.IMPORT,
		"food piled up outside and the panel did not say so (got %s)"
		% prediction.stage_name(prediction.bottleneck)
	)
	runner.check(
		prediction.bottleneck_advice().to_lower().contains("importer"),
		"the advice does not name the fix: %s" % prediction.bottleneck_advice()
	)


func test_the_classifier_names_each_stage_from_what_it_sees() -> void:
	# Unit-tested rather than driven from a plasmid, because DIGESTION is not reachable
	# with the Prototype 1 block set: enzymes and importers share one cadence and a single
	# gene fills its whole compartment, so an 8-importer cell always has 8 enzymes to match.
	# F05 makes it reachable by putting regulation proteins into the internal rack.
	var backlogged := Prediction.new()
	backlogged.undigested = Prediction.BACKLOG + 10
	runner.check_eq(
		backlogged._find_bottleneck(), Prediction.Stage.DIGESTION, "food stuck inside"
	)

	var unaffordable := Prediction.new()
	unaffordable.transport_stalls = 3
	unaffordable.food_left = Prediction.BACKLOG + 50
	runner.check_eq(
		unaffordable._find_bottleneck(),
		Prediction.Stage.METABOLITES,
		"importers that cannot pay should read as an economy problem, not a missing importer"
	)

	var uncollected := Prediction.new()
	uncollected.food_left = Prediction.BACKLOG + 50
	runner.check_eq(uncollected._find_bottleneck(), Prediction.Stage.IMPORT, "food stuck outside")

	var starved := Prediction.new()
	starved.food_delivered = 100
	starved.food_captured = 100
	runner.check_eq(starved._find_bottleneck(), Prediction.Stage.SUPPLY, "ate everything offered")

	runner.check_eq(
		Prediction.new()._find_bottleneck(), Prediction.Stage.BALANCED, "nothing pinching"
	)


func test_a_cell_that_cannot_pay_is_called_out_before_anything_else() -> void:
	# §2.5's spiral. Telling someone with an empty pool to add importers sends them the
	# wrong way, so the economy is checked first.
	var broke := Prediction.run(
		_plasmid(
			"P2-CAT-FOOD-CAT-FOOD-CAT-FOOD-TERM-P2-MEM-TRA-FOOD-TERM"
			+ "-P2-CAT-FOOD-TERM-P2-MEM-TRA-FOOD-TERM"
		),
		EnvironmentDef.scarce()
	)
	runner.check(
		broke.transport_stalls + broke.synthesis_stalls > 0, "setup: expected this build to stall"
	)
	runner.check_eq(
		broke.bottleneck,
		Prediction.Stage.METABOLITES,
		"a stalling cell was not called out as unaffordable (got %s)"
		% broke.stage_name(broke.bottleneck)
	)


func test_every_stage_has_advice_a_player_can_act_on() -> void:
	var prediction := Prediction.new()
	for stage in Prediction.Stage.values():
		prediction.bottleneck = stage
		runner.check(
			prediction.bottleneck_advice().length() > 20,
			"%s has no advice" % prediction.stage_name(stage)
		)
		runner.check(not prediction.stage_name(stage).is_empty(), "a stage has no name")


func test_capture_rate_is_reported() -> void:
	# §7.4: "capture rate, not consumption rate, becomes the real stat".
	var starved := Prediction.run(_plasmid(STARTING_CELL), EnvironmentDef.scarce())
	runner.check(starved.capture_percent() > 80, "a starved cell should capture nearly everything")

	var no_importers := Prediction.run(_plasmid("P12-CAT-FOOD-TERM"), EnvironmentDef.abundant())
	runner.check_eq(no_importers.capture_percent(), 0, "a cell with no importers captured food")


# ---------------------------------------------------------------- M04: the event log

func test_every_event_type_has_a_sentence() -> void:
	# §9.3's requirement, and the reason a loss reads as a misjudgement rather than noise.
	for type in SimEvent.Type.values():
		var event := SimEvent.new(type, 7, {})
		var text := EventLog.sentence(event)
		runner.check(
			not text.contains("no words for"),
			"%s has no sentence in the log" % SimEvent.Type.keys()[type]
		)
		runner.check(text.length() > 10, "%s renders too tersely" % SimEvent.Type.keys()[type])


func test_the_log_reads_like_the_spec_example() -> void:
	# §9.3: "Tick 41: Importer evicted Sensor-A from membrane slot 3."
	var event := SimEvent.new(
		SimEvent.Type.PROTEIN_EVICTED,
		41,
		{
			"evicted_by_promoter": 4,
			"evicted_promoter": 0,
			"compartment": ResolvedProtein.Compartment.MEMBRANE,
		}
	)
	var text := EventLog.line(event)
	runner.check(text.begins_with("Tick 41:"), "no tick prefix: %s" % text)
	runner.check(text.to_lower().contains("evicted"), "does not read as an eviction: %s" % text)
	runner.check(text.to_lower().contains("membrane"), "does not say where: %s" % text)


func test_a_stall_is_reported_with_the_numbers_that_caused_it() -> void:
	var event := SimEvent.new(
		SimEvent.Type.SPEND_FAILED, 12, {"amount": 4, "reason": &"import", "available": 1}
	)
	var text := EventLog.sentence(event)
	runner.check(text.contains("4") and text.contains("1"), "no numbers: %s" % text)
	runner.check(text.to_lower().contains("import"), "does not say what stalled: %s" % text)


func test_expressing_into_a_full_rack_is_called_out_as_waste() -> void:
	# §2.3's intended teaching moment needs words, not just a number moving.
	var wasteful := SimEvent.new(
		SimEvent.Type.PROTEIN_BUILT,
		30,
		{"promoter": 0, "compartment": 0, "occupied": 8, "capacity": 8, "into_full_rack": true}
	)
	runner.check(
		EventLog.sentence(wasteful).to_lower().contains("full"),
		"a wasted expression read like a normal one: %s" % EventLog.sentence(wasteful)
	)


func test_the_log_hides_routine_bookkeeping_by_default() -> void:
	# A log that reports every maturation buries the eviction that decided the battle.
	var sandbox := Sandbox.new(_plasmid(STARTING_CELL), EnvironmentDef.knife_edge())
	sandbox.run_to_end()

	var everything := EventLog.render(sandbox.events, true)
	var turning_points := EventLog.render(sandbox.events, false)

	runner.check(turning_points.size() > 0, "the log is empty")
	runner.check(
		turning_points.size() < everything.size() / 4,
		"filtering barely helped: %d of %d" % [turning_points.size(), everything.size()]
	)


func test_the_same_battle_always_produces_the_same_log() -> void:
	# §4.2 and §10: a replay must read identically, or the log cannot be trusted.
	var first := Sandbox.new(_plasmid(STARTING_CELL), EnvironmentDef.knife_edge())
	first.run_to_end()
	var second := Sandbox.new(_plasmid(STARTING_CELL), EnvironmentDef.knife_edge())
	second.run_to_end()

	runner.check_eq(
		"\n".join(EventLog.render(first.events, true)),
		"\n".join(EventLog.render(second.events, true)),
		"two identical battles produced different logs"
	)


func test_the_log_ends_by_saying_how_the_battle_ended() -> void:
	var sandbox := Sandbox.new(_plasmid(STARTING_CELL), EnvironmentDef.knife_edge())
	sandbox.run_to_end()
	var lines := EventLog.render(sandbox.events, false)

	runner.check(
		lines[lines.size() - 1].to_lower().contains("divided"),
		"the log does not end with the result: %s" % lines[lines.size() - 1]
	)


# ------------------------------------------------------------------ the panels on screen

func _editor() -> PlasmidEditor:
	var editor: PlasmidEditor = load("res://src/ui/plasmid_editor.tscn").instantiate()
	runner.root.add_child(editor)
	_editors.append(editor)
	return editor


func test_the_readouts_are_all_present_and_populated() -> void:
	var editor := _editor()
	runner.check(editor._readout != null, "no steady-state panel")
	runner.check(editor._pipeline != null, "no pipeline view")
	runner.check(editor._sandbox != null, "no sandbox panel")
	runner.check(editor._sandbox.sandbox != null, "the sandbox was never pointed at a plasmid")


func test_the_readouts_follow_an_edit() -> void:
	# A stale panel is worse than none: it would describe a plasmid the player has already
	# changed.
	var editor := _editor()
	var before := editor._readout._verdict.text

	for i in range(4):
		editor._on_palette_pressed(Block.new(Block.Kind.CATABOLIC_ENZYME))

	# Four more blocks means a higher burden target (§4.1), so the verdict must move even
	# though these particular blocks sit past the last terminator and are never read.
	runner.check(editor._readout._verdict.text != before, "the readout did not follow the edit")
	runner.check(
		str(editor.draft.problems()).contains("never transcribed"),
		"dead weight past the last terminator was not flagged: %s" % str(editor.draft.problems())
	)


func test_the_readouts_follow_the_environment() -> void:
	var editor := _editor()
	editor._on_environment_selected(2)
	var scarce := editor._readout._rates.text
	editor._on_environment_selected(0)

	runner.check(editor._readout._rates.text != scarce, "the readout ignored the environment")


func test_stepping_the_sandbox_advances_its_clock_and_its_log() -> void:
	var editor := _editor()
	runner.check_eq(editor._sandbox.sandbox.tick(), 0, "the sandbox did not start at zero")

	editor._sandbox._on_step(30)
	runner.check_eq(editor._sandbox.sandbox.tick(), 30, "stepping did not advance the clock")
	runner.check(not editor._sandbox._log.text.is_empty(), "nothing was logged")
	runner.check(
		editor._sandbox._status.text.contains("Tick 30"), editor._sandbox._status.text
	)


func test_the_sandbox_never_disturbs_the_plasmid_being_edited() -> void:
	var editor := _editor()
	var before := editor.draft.notation()
	editor._sandbox._on_run_to_end()
	runner.check_eq(editor.draft.notation(), before, "the sandbox edited the plasmid")


func after_all() -> void:
	for editor in _editors:
		if is_instance_valid(editor):
			editor.free()
	_editors.clear()
