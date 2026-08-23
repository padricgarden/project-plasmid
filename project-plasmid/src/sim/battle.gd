class_name Battle
extends RefCounted
## One battle: a cell, an environment, and the clock. Spec §1, §7.0.
##
## Pure, like everything under src/sim/. It owns a [SimState] and decides when the match
## is over; it knows nothing about how fast anyone is watching. F04's speed controls
## change how quickly ticks are consumed from here, never what a tick does.
##
## F06 gives this a second cell and the loss conditions §1 states as comparisons —
## "opponent divides first", "time limit expires with lower growth". The clock and the
## termination check stay here; only the number of cells changes.

var state: SimState

## Ticks before the clock decides it (§7.0).
var length_ticks: int

## Null while the battle is still running.
var outcome: BattleOutcome = null


func _init(
	plasmid: Plasmid,
	environment: EnvironmentDef,
	p_length_ticks: int = Balance.BATTLE_LENGTH_TICKS
) -> void:
	length_ticks = p_length_ticks
	state = SimState.new()
	state.begin_battle(plasmid, environment)


func is_finished() -> bool:
	return outcome != null


## Ticks left to play. Zero once the battle is decided, not merely once the clock runs
## out — a cell that divides on tick 73 has no time remaining, it has finished.
func ticks_remaining() -> int:
	if is_finished():
		return 0
	return maxi(0, length_ticks - state.tick)


## Advance one tick, returning what happened. Returns nothing once the battle has ended;
## a finished battle is inert, so a presentation layer that keeps calling cannot
## accidentally run the clock past the result.
func step() -> Array[SimEvent]:
	if is_finished():
		return []

	var events := state.step()
	_check_outcome()
	if outcome != null:
		events.append(
			SimEvent.new(
				SimEvent.Type.BATTLE_ENDED,
				outcome.ended_at_tick,
				{
					"outcome": outcome.kind,
					"banked": outcome.banked_growth,
					"target": outcome.growth_target,
				}
			)
		)
	return events


## Run to completion and report. The instant-resolve path (§7.0), and the one the
## headless balance harness uses.
func run() -> BattleOutcome:
	while not is_finished():
		step()
	return outcome


## Run to completion, collecting every event in order. For determinism checks and for
## F03-M04's log.
func run_collecting() -> Array[SimEvent]:
	var all: Array[SimEvent] = []
	while not is_finished():
		all.append_array(step())
	return all


## Division is tested first on purpose: a cell that reaches its target on the very last
## tick has divided, not run out of time.
func _check_outcome() -> void:
	if state.banked_growth >= state.growth_target():
		_finish(BattleOutcome.Kind.DIVIDED)
	elif state.is_lysing():
		_finish(BattleOutcome.Kind.LYSED)
	elif state.tick >= length_ticks:
		_finish(BattleOutcome.Kind.TIME_EXPIRED)


func _finish(kind: BattleOutcome.Kind) -> void:
	outcome = BattleOutcome.new(
		kind, state.tick, state.banked_growth, state.growth_target()
	)
