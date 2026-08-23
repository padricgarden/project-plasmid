class_name Prediction
extends RefCounted
## What a plasmid will actually do, worked out by running it. Spec §9.2, §7.4.
##
## Every number here comes from a real battle on a copy of the cell, never from a second
## model of the economy. That is deliberate: §9.2's readout is only useful if it is right,
## and a hand-written predictor would be a second implementation of the tick loop that
## drifts from the first the moment either changes. The sim is deterministic (§4.2), so
## running it *is* the prediction.
##
## Rates are integers scaled by [constant SCALE], because the economy is integer (§2.4)
## and a float here would be the only float in it.

## Where the pipeline is pinching. §9.2 calls naming this "the single most important"
## thing the panel does — "which step is rate-limiting" — because it turns a bad build
## into a specific thing to fix.
enum Stage {
	## Nothing to import: the environment is not delivering enough (§7.4). Not fixable
	## on the plasmid, which is exactly what makes it worth saying out loud.
	SUPPLY,
	## Food is sitting in the medium uncollected — too few importers, or none.
	IMPORT,
	## Food arrives faster than the enzymes destroy it.
	DIGESTION,
	## The pool cannot pay for what is built. §2.5's death spiral.
	METABOLITES,
	## Nothing is obviously pinching.
	BALANCED,
}

const SCALE := 100

## How long to run when predicting. Twice a battle, because the panel is showing steady
## state: racks need time to settle, and a cell that divides at tick 73 would otherwise
## report the economics of its opening ramp and nothing else.
const PREDICTION_TICKS := Balance.BATTLE_LENGTH_TICKS * 2

## Food left standing before a stage counts as that stage's fault. Small enough to catch
## a real backlog, large enough to ignore the one or two units in flight at any moment.
const BACKLOG := 5

var ticks: int = 0

## Slot composition per compartment at the end of the run, keyed by promoter ring index.
## This is §3.1's equilibrium, and §9.2 wants it drawn as the rack it is.
var racks: Array = []

var gross_scaled: int = 0
var upkeep_scaled: int = 0
var transport_scaled: int = 0
var net_scaled: int = 0

var food_delivered: int = 0
var food_captured: int = 0
var food_left: int = 0
var undigested: int = 0
## Split by cause, because they mean opposite things. A cell with importers that cannot
## afford to run them has an economy problem; a cell with no importers at all also stalls
## eventually, but telling it "cut a gene" would be exactly wrong.
var transport_stalls: int = 0
var synthesis_stalls: int = 0

var bottleneck: Stage = Stage.BALANCED
var divides_at_tick: int = -1
var growth_target: int = 0
var banked_growth: int = 0


## Run a plasmid and measure it.
##
## Rates are averaged over the back of the run rather than the whole of it. A cell spends
## its opening ticks filling empty slot racks, and that ramp is not the steady state §9.2
## asks the panel to show — including it would make every build look worse than it is.
static func run(
	plasmid: Plasmid, environment: EnvironmentDef, ticks: int = PREDICTION_TICKS
) -> Prediction:
	var result := Prediction.new()
	result.ticks = ticks

	# Driven as a bare SimState rather than a Battle, deliberately. A battle stops the
	# moment the cell divides, which for a healthy build is long before its racks settle —
	# the panel would then be reporting the opening ramp as if it were steady state.
	var state := SimState.new()
	state.begin_battle(plasmid, environment)

	var settle_after := ticks / 2
	var measured_ticks := 0

	for t in range(ticks):
		var in_window := t >= settle_after
		if in_window:
			measured_ticks += 1

		for event in state.step():
			match event.type:
				SimEvent.Type.FOOD_DELIVERED:
					result.food_delivered += event.data["count"]
				SimEvent.Type.FOOD_IMPORTED:
					result.food_captured += 1
				SimEvent.Type.METABOLITE_PRODUCED:
					if in_window:
						result.gross_scaled += event.data["count"] * SCALE
				SimEvent.Type.METABOLITE_SPENT:
					if not in_window:
						continue
					if event.data["reason"] == &"synthesis":
						result.upkeep_scaled += event.data["amount"] * SCALE
					else:
						result.transport_scaled += event.data["amount"] * SCALE
				SimEvent.Type.SPEND_FAILED:
					if event.data["reason"] == &"synthesis":
						result.synthesis_stalls += 1
					else:
						result.transport_stalls += 1

		if result.divides_at_tick < 0 and state.banked_growth >= state.growth_target():
			result.divides_at_tick = t + 1

	if measured_ticks > 0:
		result.gross_scaled /= measured_ticks
		result.upkeep_scaled /= measured_ticks
		result.transport_scaled /= measured_ticks
	result.net_scaled = result.gross_scaled - result.upkeep_scaled - result.transport_scaled

	result.food_left = state.medium.food
	result.undigested = state.internal_food
	result.banked_growth = state.banked_growth
	result.growth_target = state.growth_target()
	result.racks = []
	for rack in state.racks:
		result.racks.append(rack.composition())

	result.bottleneck = result._find_bottleneck()
	return result


## Find where work is piling up, reading the pipeline from the back.
##
## [b]Order matters, and it is not the obvious one.[/b] Running out of metabolites is
## usually a *symptom*: a cell with no importers earns nothing, so of course it eventually
## cannot pay for synthesis — but telling that player "cut a gene" sends them the wrong
## way when the real answer is "you have no importers". So physical backlogs are read
## first, and the economy is only blamed when food is moving freely and the cell still
## cannot afford itself.
func _find_bottleneck() -> Stage:
	if undigested > BACKLOG:
		# Food is getting in and then sitting there: not enough enzymes.
		return Stage.DIGESTION
	if transport_stalls > 0:
		# There are importers; the cell just cannot afford to run them. That is an economy
		# problem, and it is why this is checked before the food piling up outside — the
		# backlog is the symptom, not the cause.
		return Stage.METABOLITES
	if food_left > BACKLOG:
		# Food is outside, nothing inside is backed up, and nothing stalled trying to fetch
		# it. There simply are not enough importers.
		return Stage.IMPORT
	if synthesis_stalls > 0:
		return Stage.METABOLITES
	if food_delivered > 0 and food_captured >= food_delivered - BACKLOG:
		# Everything the medium offered was taken and used. Nothing on the plasmid will
		# help; the limit is the environment (§7.4).
		return Stage.SUPPLY
	return Stage.BALANCED


## Share of what the environment offered that this cell actually took. §7.4 calls capture
## rate "the real stat" once food is contested, so it is surfaced now rather than waiting
## for F06 to make it competitive.
func capture_percent() -> int:
	if food_delivered <= 0:
		return 0
	return mini(100, food_captured * 100 / food_delivered)


func stage_name(stage: Stage) -> String:
	match stage:
		Stage.SUPPLY:
			return "Food supply"
		Stage.IMPORT:
			return "Import"
		Stage.DIGESTION:
			return "Digestion"
		Stage.METABOLITES:
			return "Metabolites"
		_:
			return "Balanced"


func bottleneck_advice() -> String:
	match bottleneck:
		Stage.SUPPLY:
			return (
				"You are eating everything the medium delivers. More importers or enzymes "
				+ "will not help — this environment simply has no more food in it."
			)
		Stage.IMPORT:
			return "Food is piling up outside. Add importers, or express the ones you have faster."
		Stage.DIGESTION:
			return "Food is coming in faster than you digest it. Add catabolic enzymes."
		Stage.METABOLITES:
			return (
				"You cannot afford to run what you built. Something stalled for lack of "
				+ "metabolites — cut a gene, or slow a promoter down."
			)
		_:
			return "Nothing is obviously pinching."


## Format a scaled rate for display, e.g. 133 -> "1.33".
static func rate_text(scaled: int) -> String:
	var sign_text := "-" if scaled < 0 else ""
	var magnitude := absi(scaled)
	return "%s%d.%02d" % [sign_text, magnitude / SCALE, magnitude % SCALE]
