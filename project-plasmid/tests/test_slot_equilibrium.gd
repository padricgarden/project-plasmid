## F01-M04 — the §3.1 slot-share equilibrium.
##
## This is the most important test in the project. §3.1 — "steady-state slot count =
## share of expression rate in that compartment × slots available" — is the design's
## most unusual property, and it is supposed to *emerge* from deterministic firing plus
## FIFO eviction, never to be computed and assigned. If a refactor ever breaks it, this
## file is the only thing that will notice.
var runner: Object

## Enough production to keep synthesis affordable. M05 replaces this with an actual food
## engine; until then the point is to isolate slot behaviour from the economy.
const SUBSIDY := 12

const SETTLE_TICKS := 150
const SAMPLE_TICKS := 50


func set_runner(r: Object) -> void:
	runner = r


func _run(notation: String, ticks: int) -> SimState:
	var result := PlasmidNotation.parse(notation)
	runner.check(result.ok(), "failed to parse '%s': %s" % [notation, result.error])

	var state := SimState.new()
	state.set_plasmid(result.plasmid)
	for t in range(ticks):
		state.produce(SUBSIDY)
		state.step()
	return state


## Sample the internal rack once per tick across the final stretch, so a rack that
## oscillates between two compositions fails as loudly as one that settles wrong.
func _steady_compositions(notation: String) -> Array:
	var result := PlasmidNotation.parse(notation)
	runner.check(result.ok(), "failed to parse '%s': %s" % [notation, result.error])

	var state := SimState.new()
	state.set_plasmid(result.plasmid)
	var samples: Array = []
	for t in range(SETTLE_TICKS + SAMPLE_TICKS):
		state.produce(SUBSIDY)
		state.step()
		if t >= SETTLE_TICKS:
			samples.append(state.rack(ResolvedProtein.Compartment.INTERNAL).composition())
	return samples


func _check_stable(samples: Array, expected: Dictionary, label: String) -> void:
	for i in range(samples.size()):
		var sample: Dictionary = samples[i]
		runner.check_eq(
			sample.size(), expected.size(), "%s: wrong number of genes holding slots" % label
		)
		for promoter in expected:
			runner.check_eq(
				sample.get(promoter, 0),
				expected[promoter],
				"%s: promoter %d at sample %d" % [label, promoter, i]
			)


func test_a_four_tick_and_a_twelve_tick_promoter_settle_at_six_to_two() -> void:
	# §3.1's own worked example. Rates 3:1 over 8 slots, so 6:2 — reached by eviction
	# alone, with nothing in the sim aware that 6 or 2 are the answers.
	_check_stable(
		_steady_compositions("P4-CAT-FOOD-TERM-P12-CAT-FOOD-TERM"), {0: 6, 4: 2}, "6:2"
	)


## A long protein on the fast promoter and a one-block protein on the slow one, so the
## slow gene lands three copies while the fast gene is still building its first. The rack
## therefore *fills* at 5:3 and must be driven to 6:2 afterwards.
const CONVERGENCE_CASE := (
	"P4-CAT-FOOD-CAT-FOOD-CAT-FOOD-CAT-FOOD-CAT-FOOD-CAT-FOOD-TERM-P12-CAT-TERM"
)


func test_the_rack_converges_rather_than_freezing_at_whatever_filled_it_first() -> void:
	# This is the case that actually proves eviction dynamics decide composition. In the
	# plain 4/12 case above the first eight arrivals already happen to be 6:2, so a rack
	# that froze the instant it filled would pass and prove nothing. Here the fill order
	# is 5:3 and only continued FIFO turnover reaches 6:2.
	_check_never_starved(CONVERGENCE_CASE)
	_check_stable(_steady_compositions(CONVERGENCE_CASE), {0: 6, 14: 2}, "converged 6:2")


## Guard for the test above. Its whole value rests on the slow gene landing copies early,
## which quietly stops happening if the subsidy cannot cover both genes firing on the
## same tick — the fast gene spends first and the slow one stalls (§2.5). That failure
## restores the 6:2 fill order and makes the test pass for the wrong reason.
func _check_never_starved(notation: String) -> void:
	var result := PlasmidNotation.parse(notation)
	runner.check(result.ok(), "failed to parse '%s': %s" % [notation, result.error])

	var state := SimState.new()
	state.set_plasmid(result.plasmid)
	for t in range(SETTLE_TICKS):
		state.produce(SUBSIDY)
		for event in state.step():
			if event.type == SimEvent.Type.SPEND_FAILED:
				runner.fail(
					"gene %s stalled at tick %d — the subsidy is too small for this case"
					% [str(event.data.get("promoter", "?")), event.tick]
				)
				return


func test_two_equal_promoters_split_the_rack_evenly() -> void:
	_check_stable(
		_steady_compositions("P6-CAT-FOOD-TERM-P6-CAT-FOOD-TERM"), {0: 4, 4: 4}, "4:4"
	)


func test_four_equal_promoters_take_two_slots_each() -> void:
	_check_stable(
		_steady_compositions(
			"P12-CAT-FOOD-TERM-P12-CAT-FOOD-TERM-P12-CAT-FOOD-TERM-P12-CAT-FOOD-TERM"
		),
		{0: 2, 4: 2, 8: 2, 12: 2},
		"2:2:2:2"
	)


func test_the_same_ratio_is_reachable_at_two_different_upkeeps() -> void:
	# The skill §3.1 describes: (4, 12) and (2, 6) hold an identical 6:2 rack, but the
	# faster pair fires twice as often and pays twice the synthesis upkeep forever. The
	# composition is the same; only the bill differs.
	_check_stable(
		_steady_compositions("P4-CAT-FOOD-TERM-P12-CAT-FOOD-TERM"), {0: 6, 4: 2}, "cheap 6:2"
	)
	_check_stable(
		_steady_compositions("P2-CAT-FOOD-TERM-P6-CAT-FOOD-TERM"), {0: 6, 4: 2}, "costly 6:2"
	)

	var cheap := GeneExpression.compile(PlasmidNotation.parse(
		"P4-CAT-FOOD-TERM-P12-CAT-FOOD-TERM"
	).plasmid)
	var costly := GeneExpression.compile(PlasmidNotation.parse(
		"P2-CAT-FOOD-TERM-P6-CAT-FOOD-TERM"
	).plasmid)

	var cheap_upkeep := 0
	for unit in cheap:
		cheap_upkeep += unit.upkeep_per_tick_scaled(100)
	var costly_upkeep := 0
	for unit in costly:
		costly_upkeep += unit.upkeep_per_tick_scaled(100)

	runner.check_eq(
		costly_upkeep, cheap_upkeep * 2, "the faster pair should cost exactly double"
	)


func test_a_lone_gene_holds_the_whole_rack() -> void:
	var state := _run("P12-CAT-FOOD-TERM", 120)
	var slots := state.rack(ResolvedProtein.Compartment.INTERNAL)
	runner.check_eq(slots.count(), Balance.SLOTS_PER_COMPARTMENT, "should fill every slot")
	runner.check_eq(slots.composition().get(0, 0), 8, "one gene, eight copies")


func test_compartments_compete_separately() -> void:
	# A membrane protein never evicts a cytoplasmic one. Membrane slots are contested
	# only by things that need the membrane (§3.2).
	var state := _run("P12-CAT-FOOD-TERM-P12-MEM-TRA-FOOD-TERM", 150)

	runner.check_eq(
		state.rack(ResolvedProtein.Compartment.INTERNAL).composition().get(0, 0),
		8,
		"the enzyme should hold every internal slot"
	)
	runner.check_eq(
		state.rack(ResolvedProtein.Compartment.MEMBRANE).composition().get(4, 0),
		8,
		"the importer should hold every membrane slot"
	)


func test_expression_stops_when_the_cell_cannot_pay_for_it() -> void:
	# §2.5 applied to expression: no subsidy, so the first firing is the only one that
	# can happen — and with an empty pool, not even that.
	var result := PlasmidNotation.parse("P4-CAT-FOOD-TERM")
	var state := SimState.new()
	state.set_plasmid(result.plasmid)

	for t in range(40):
		state.step()

	runner.check_eq(
		state.rack(ResolvedProtein.Compartment.INTERNAL).count(),
		0,
		"proteins were built without paying for them"
	)


func test_firing_into_a_full_rack_still_costs_metabolites() -> void:
	# §2.3's teaching moment: a promoter expressing into a full rack is wasting money,
	# and the player is supposed to be able to see that it is.
	var result := PlasmidNotation.parse("P2-CAT-FOOD-TERM")
	var state := SimState.new()
	state.set_plasmid(result.plasmid)

	var wasted := 0
	for t in range(80):
		state.produce(SUBSIDY)
		for event in state.step():
			if event.type == SimEvent.Type.PROTEIN_BUILT and event.data["into_full_rack"]:
				wasted += 1

	runner.check(wasted > 0, "a full rack never reported a wasted expression")
	runner.check(
		state.banked_growth > 0, "setup: the subsidy should still be banking growth"
	)


func test_eviction_is_reported_with_both_genes_named() -> void:
	var result := PlasmidNotation.parse("P4-CAT-FOOD-TERM-P12-CAT-FOOD-TERM")
	var state := SimState.new()
	state.set_plasmid(result.plasmid)

	var evictions: Array = []
	for t in range(120):
		state.produce(SUBSIDY)
		for event in state.step():
			if event.type == SimEvent.Type.PROTEIN_EVICTED:
				evictions.append(event)

	runner.check(not evictions.is_empty(), "a full rack never evicted anything")
	var first: SimEvent = evictions[0]
	runner.check(
		first.data.has("evicted_promoter") and first.data.has("evicted_by_promoter"),
		"eviction event did not name both genes, so §9.3 cannot render it"
	)


func test_stepping_a_clone_does_not_disturb_the_rack() -> void:
	var state := _run("P4-CAT-FOOD-TERM", 60)
	var before := state.rack(ResolvedProtein.Compartment.INTERNAL).count()

	var copy := state.clone()
	for t in range(60):
		copy.produce(SUBSIDY)
		copy.step()

	runner.check_eq(
		state.rack(ResolvedProtein.Compartment.INTERNAL).count(),
		before,
		"a sandbox run mutated the original's rack"
	)
	runner.check_eq(state.tick, 60, "a sandbox run advanced the original's clock")
