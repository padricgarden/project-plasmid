class_name Sandbox
extends RefCounted
## The build-phase sandbox: the plasmid you are editing, run on a copy. Spec §9.1.
##
## §9.1 asks for tick-through in the build phase — step forward one tick at a time and
## watch proteins get built, slots fill, the membrane populate. This is that, and it is
## also where every other readout in F03 gets its numbers: in a deterministic sim
## (§4.2) the honest way to predict what a plasmid will do is to run it.
##
## [b]It must produce exactly what the committed battle produces.[/b] A sandbox that
## drifts from the real thing is worse than none at all — it would teach players a game
## they are not playing. F01-M06 proved `SimState.clone()` carries everything the tick
## loop reads; this leans on that, and a test re-checks it here.

var battle: Battle

## Everything that has happened so far, in order. The event log (M04) is a view over it.
var events: Array[SimEvent] = []


func _init(plasmid: Plasmid, environment: EnvironmentDef) -> void:
	reset(plasmid, environment)


func reset(plasmid: Plasmid, environment: EnvironmentDef) -> void:
	battle = Battle.new(plasmid, environment)
	events = []


func state() -> SimState:
	return battle.state


func tick() -> int:
	return battle.state.tick


func is_finished() -> bool:
	return battle.is_finished()


func outcome() -> BattleOutcome:
	return battle.outcome


## Advance the sandbox, returning only what happened during these ticks.
func step(count: int = 1) -> Array[SimEvent]:
	var produced: Array[SimEvent] = []
	for i in range(count):
		if battle.is_finished():
			break
		var tick_events := battle.step()
		produced.append_array(tick_events)
		events.append_array(tick_events)
	return produced


func run_to_end() -> BattleOutcome:
	step(Balance.BATTLE_LENGTH_TICKS + 1)
	return battle.outcome
