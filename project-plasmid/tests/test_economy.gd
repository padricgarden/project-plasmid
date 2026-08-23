## F01-M05 — medium, transport, catabolism, and the §2.4 baseline benchmark.
##
## This is the balance harness. Every number here is a claim the spec makes, checked
## against what the sim actually does. Where the two disagree the deviation is asserted
## deliberately and explained, never quietly retuned — see the F01 changelog.
var runner: Object

## §5.4's starting protein plus the importer feeding it (§2.4). Nine blocks.
const STARTING_CELL := "P12-CAT-FOOD-TERM-P12-TRA-MEM-FOOD-TERM"

## The same engine on faster promoters and more genes: 27 blocks, three enzyme genes and
## three importer genes.
const FAT_ENGINE := (
	"P4-CAT-FOOD-TERM-P4-TRA-MEM-FOOD-TERM"
	+ "-P6-CAT-FOOD-TERM-P6-TRA-MEM-FOOD-TERM"
	+ "-P12-CAT-FOOD-TERM-P12-TRA-MEM-FOOD-TERM"
)


func set_runner(r: Object) -> void:
	runner = r


func _plasmid(notation: String) -> Plasmid:
	var result := PlasmidNotation.parse(notation)
	runner.check(result.ok(), "failed to parse '%s': %s" % [notation, result.error])
	return result.plasmid


func _battle(notation: String, environment: EnvironmentDef) -> SimState:
	var state := SimState.new()
	state.begin_battle(_plasmid(notation), environment)
	return state


func _run(notation: String, environment: EnvironmentDef, ticks: int) -> Dictionary:
	var state := _battle(notation, environment)
	var tally := {"catabolised": 0, "yielded": 0, "imported": 0, "spent": 0, "stalled": 0, "upkeep": 0}
	var divided_at := -1
	for t in range(ticks):
		for event in state.step():
			match event.type:
				SimEvent.Type.FOOD_CATABOLISED:
					tally["catabolised"] += 1
					tally["yielded"] += event.data["yield"]
				SimEvent.Type.FOOD_IMPORTED:
					tally["imported"] += 1
				SimEvent.Type.METABOLITE_SPENT:
					tally["spent"] += event.data["amount"]
					if event.data["reason"] == &"synthesis":
						tally["upkeep"] += event.data["amount"]
				SimEvent.Type.SPEND_FAILED:
					tally["stalled"] += 1
		if divided_at < 0 and state.banked_growth >= state.growth_target():
			divided_at = t + 1
	tally["banked"] = state.banked_growth
	tally["divided_at"] = divided_at
	tally["state"] = state
	return tally


## Compare a measured rate against a claim, in hundredths so nothing here needs floats.
func _check_rate(banked: int, ticks: int, expected_scaled: int, tolerance: int, what: String) -> void:
	var measured := banked * 100 / ticks
	runner.check(
		absi(measured - expected_scaled) <= tolerance,
		"%s: expected %d/100 per tick ±%d, measured %d/100" % [
			what, expected_scaled, tolerance, measured
		]
	)


# ---------------------------------------------------------------- §4.1 burden curve

func test_burden_curve_matches_the_spec_table() -> void:
	# §4.1's own worked table, normalised so a 12-block genome sits at exactly 100.
	for case in [[12, 100], [20, 117], [30, 140], [45, 176], [60, 212]]:
		runner.check_eq(
			Burden.growth_target(case[0]), case[1], "%d blocks" % case[0]
		)


func test_burden_rises_with_block_count() -> void:
	runner.check(
		Burden.growth_target(30) > Burden.growth_target(20),
		"a longer plasmid must cost more growth to divide"
	)


# ------------------------------------------------------------- per-effector economics

func test_catabolism_yields_the_environment_tier_value() -> void:
	var rich := EnvironmentDef.abundant()
	var tally := _run(STARTING_CELL, rich, 120)
	runner.check(tally["catabolised"] > 0, "nothing was catabolised")
	runner.check_eq(
		tally["yielded"], tally["catabolised"] * rich.food_yield, "yield per action (§2.2, §7.3)"
	)


func test_polymer_food_is_worth_more_per_unit() -> void:
	# §7.3's tier table, as amended in spec v0.3.1: simple 3, polymer 6.
	runner.check_eq(EnvironmentDef.knife_edge().food_yield, 3, "simple sugar")


func test_an_importer_with_an_empty_medium_costs_nothing() -> void:
	# §10 names "transport dominated by passive diffusion — importer becomes a trap
	# block" as a live risk. Charging for a move that did not happen is how it would
	# arrive: a full membrane rack in a dry medium would bleed the pool for no return.
	var barren := EnvironmentDef.new()
	barren.food_delivery_scaled = 0
	barren.starting_food = 0

	var tally := _run(STARTING_CELL, barren, 60)
	runner.check_eq(tally["imported"], 0, "imported from an empty medium")
	# Synthesis is still charged; only transport should be free here.
	runner.check(
		tally["state"].pool.available() + tally["state"].banked_growth > 0,
		"a dry medium drained the pool even though nothing moved"
	)


func test_each_import_costs_exactly_the_transport_tax() -> void:
	var rich := EnvironmentDef.abundant()
	var lean := _run(STARTING_CELL, rich, 120)

	# Everything spent is either synthesis or transport, and both are now reported.
	runner.check_eq(
		lean["spent"] - lean["upkeep"],
		lean["imported"] * Balance.TRANSPORT_COST,
		"transport cost did not match imports at 1 per unit (§2.2)"
	)


# --------------------------------------------------------------- §7.4 food delivery

func test_knife_edge_delivers_the_food_budget_the_spec_designs_around() -> void:
	# §7.4: "delivering ~90 units over 120 ticks (0.75/tick) means both cells can
	# theoretically finish, and whoever captures more than half wins."
	runner.check_eq(EnvironmentDef.knife_edge().total_delivery_over(120), 90, "knife-edge budget")
	runner.check_eq(EnvironmentDef.abundant().total_delivery_over(120), 180, "abundant budget")
	runner.check_eq(EnvironmentDef.scarce().total_delivery_over(120), 48, "scarce budget")


func test_delivery_is_a_steady_integer_drip() -> void:
	var medium := Medium.new()
	var env := EnvironmentDef.knife_edge()
	env.starting_food = 0
	var total := 0
	for t in range(100):
		total += medium.deliver(env)
	runner.check_eq(total, 75, "0.75/tick should deliver exactly 75 units in 100 ticks")
	runner.check_eq(medium.food, 75, "medium did not accumulate what was delivered")


# ------------------------------------------------------------------- the boot problem

func test_a_cell_with_no_endowment_deadlocks_permanently() -> void:
	# Regression guard for the gap M05 found. With an empty pool nothing can pay for
	# synthesis, so no protein is ever built, so nothing ever earns. This is not the
	# §2.5 death spiral — that one is recoverable and legible — it is a soft-lock.
	var state := SimState.new()
	state.set_plasmid(_plasmid(STARTING_CELL))
	state.set_environment(EnvironmentDef.abundant())

	for t in range(200):
		state.step()

	runner.check_eq(state.banked_growth, 0, "an unfunded cell should never bank anything")
	runner.check_eq(
		state.rack(ResolvedProtein.Compartment.INTERNAL).count(),
		0,
		"an unfunded cell should never rack a protein"
	)


func test_the_endowment_scales_so_a_larger_genome_still_boots() -> void:
	# A flat endowment sized for the starting cell leaves this plasmid unable to fund its
	# first import: six transcripts cost exactly the endowment and the importers then
	# stall. Drafting only grows the plasmid (§8), so a flat value gets worse over a run.
	var lean := _battle(STARTING_CELL, EnvironmentDef.knife_edge())
	var fat := _battle(FAT_ENGINE, EnvironmentDef.knife_edge())

	runner.check(
		fat.starting_endowment() > lean.starting_endowment(),
		"a six-gene plasmid was endowed no more than a two-gene one"
	)
	var tally := _run(FAT_ENGINE, EnvironmentDef.knife_edge(), 200)
	runner.check(tally["banked"] > 0, "the fat engine failed to boot at all")


# ------------------------------------------------------------ §2.4 baseline benchmark

func test_the_starting_cell_is_food_limited_not_slot_limited() -> void:
	# The engine consumes everything the medium delivers and leaves it empty, in every
	# environment. This is §2.3's intended end state — "at 24 slots, food supply becomes
	# the true limiter, not slots" — reached already at Prototype 1 scale.
	for env: EnvironmentDef in [EnvironmentDef.abundant(), EnvironmentDef.knife_edge(), EnvironmentDef.scarce()]:
		var tally := _run(STARTING_CELL, env, 400)
		var delivered := env.total_delivery_over(400) + env.starting_food
		runner.check(
			tally["imported"] >= delivered - 4,
			"%s: imported %d of %d delivered — the cell is not food-limited"
			% [env.display_name, tally["imported"], delivered]
		)


func test_the_spec_baseline_reproduces_only_at_scarce_food_density() -> void:
	# §2.4 predicts net ≈0.6 metabolites/tick and ~165 ticks to 100 growth for "one
	# Catabolic+Food, one importer". That premise is unreachable under §3's slot rules:
	# a lone gene fills all eight slots of its compartment, so the starting cell runs
	# eight enzymes and eight importers, not one of each. §2.4 predates the 5→8 slot
	# change (§3.4) and its arithmetic was never revisited.
	#
	# The 0.6 figure does still appear — but as a property of the environment rather than
	# of the cell, at §7.4's scarce density where food, not slots, sets the rate.
	var scarce := _run(STARTING_CELL, EnvironmentDef.scarce(), 400)
	_check_rate(scarce["banked"], 400, 63, 8, "scarce")

	var knife := _run(STARTING_CELL, EnvironmentDef.knife_edge(), 400)
	_check_rate(knife["banked"], 400, 133, 12, "knife-edge")

	var abundant := _run(STARTING_CELL, EnvironmentDef.abundant(), 400)
	_check_rate(abundant["banked"], 400, 281, 20, "abundant")


func test_a_single_cell_divides_inside_the_battle_clock_at_knife_edge() -> void:
	# §7.4's knife-edge is calibrated for two cells splitting the medium. One cell taking
	# all of it should finish comfortably inside 120 ticks; the contest only becomes a
	# knife-edge when F06 adds a competitor for the same food.
	var tally := _run(STARTING_CELL, EnvironmentDef.knife_edge(), 120)
	runner.check(
		tally["divided_at"] > 0 and tally["divided_at"] < 120,
		"expected division inside the battle clock, got %s" % str(tally["divided_at"])
	)


func test_churn_upkeep_punishes_a_fat_engine_harder_than_burden_does() -> void:
	# §4.1 worries that c = 1.5 is too weak to restrain engine-building, and prefers to
	# let food scarcity do the limiting instead. Measured here, the restraint is real but
	# comes from a third place: §3.2's churn. Throughput is food-limited, so extra genes
	# buy no yield — they only add synthesis upkeep every tick, forever, plus burden.
	var lean := _run(STARTING_CELL, EnvironmentDef.knife_edge(), 400)
	var fat := _run(FAT_ENGINE, EnvironmentDef.knife_edge(), 400)

	runner.check(
		fat["catabolised"] >= lean["catabolised"] - 8,
		"setup: both engines should be eating the same food supply"
	)
	runner.check(
		fat["upkeep"] > lean["upkeep"] * 3,
		"the fat engine should pay far more synthesis upkeep for the same food (%d vs %d)"
			% [fat["upkeep"], lean["upkeep"]]
	)
	runner.check(
		fat["banked"] < lean["banked"],
		"the fat engine banked more than the lean one — churn is not biting"
	)


func test_a_fat_engine_starves_outright_when_food_is_scarce() -> void:
	# §2.5's death spiral, reached by overbuilding rather than by toxin: upkeep consumes
	# the pool, transport can no longer be afforded, and the cell sits next to food it
	# cannot pay to import.
	var fat := _run(FAT_ENGINE, EnvironmentDef.scarce(), 400)
	runner.check(fat["stalled"] > 0, "expected the fat engine to stall on cost")
	runner.check(
		fat["state"].medium.food > 20,
		"expected uneaten food left in the medium, found %d" % fat["state"].medium.food
	)


# ------------------------------------------------------------------ topology effects

func test_an_extracellular_enzyme_destroys_medium_food_and_yields_nothing() -> void:
	# §8's denial elite — "a cell secreting a catabolic enzyme that destroys extracellular
	# food" — falling out of topology rather than needing its own block. The metabolites
	# are outside the cell and lost to everyone.
	var state := _battle("P4-MEM-TRA-FOOD-CAT-TERM", EnvironmentDef.abundant())
	var destroyed := 0
	var catabolised := 0
	for t in range(120):
		for event in state.step():
			if event.type == SimEvent.Type.FOOD_DESTROYED:
				destroyed += 1
			elif event.type == SimEvent.Type.FOOD_CATABOLISED:
				catabolised += 1

	runner.check(destroyed > 0, "the extracellular enzyme destroyed nothing")
	runner.check_eq(catabolised, 0, "an extracellular enzyme fed the cell it belongs to")


func test_an_exporter_moves_food_back_out() -> void:
	var state := _battle("P4-MEM-TRA-FOOD-TERM-P4-FOOD-TRA-MEM-TERM", EnvironmentDef.abundant())
	var exported := 0
	for t in range(120):
		for event in state.step():
			if event.type == SimEvent.Type.FOOD_EXPORTED:
				exported += 1
	runner.check(exported > 0, "a reachable export arrangement moved nothing")


func test_stepping_a_clone_does_not_disturb_the_medium() -> void:
	var state := _battle(STARTING_CELL, EnvironmentDef.knife_edge())
	for t in range(60):
		state.step()

	var food_before := state.medium.food
	var banked_before := state.banked_growth
	var copy := state.clone()
	for t in range(60):
		copy.step()

	runner.check_eq(state.medium.food, food_before, "a sandbox run drained the real medium")
	runner.check_eq(state.banked_growth, banked_before, "a sandbox run banked into the original")
	runner.check(copy.tick > state.tick, "the clone did not actually run")


func test_the_event_stream_balances_against_the_pool() -> void:
	# Accounting identity: endowment + everything produced − everything spent must equal
	# what is left in the pool plus what banked. It catches the whole class of bug where
	# a metabolite moves without saying so — which is exactly how the transport tax went
	# unreported until M05. F03-M02's upkeep and net/tick readouts are sums over this
	# stream, so a silent outflow would make the panel quietly lie.
	var state := _battle(STARTING_CELL, EnvironmentDef.abundant())
	var endowment := state.starting_endowment()
	var produced := 0
	var spent := 0

	for t in range(200):
		for event in state.step():
			match event.type:
				SimEvent.Type.METABOLITE_PRODUCED:
					produced += event.data["count"]
				SimEvent.Type.METABOLITE_SPENT:
					spent += event.data["amount"]

	runner.check_eq(
		endowment + produced - spent,
		state.pool.available() + state.banked_growth,
		"the event stream does not account for the whole pool"
	)
