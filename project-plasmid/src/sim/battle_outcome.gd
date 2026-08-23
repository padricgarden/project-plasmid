class_name BattleOutcome
extends RefCounted
## How a battle ended, and the numbers that decided it. Spec §1, §7.0.
##
## A record rather than a verdict: it says what happened, not who won. Prototype 1 has no
## opponent to lose to, and §1's real loss conditions — "opponent divides first" and
## "time limit expires with lower growth" — are both comparisons that F06 can only make
## once there are two cells.

enum Kind {
	## Reached the burden-adjusted growth target and divided (§4.1). The win condition.
	DIVIDED,
	## Toxin held above threshold for too many consecutive ticks (§1).
	##
	## Unreachable in Prototype 1 — there is no toxin in the block grammar until F05.
	## The value exists so the outcome type is complete and F05-M01 only has to make the
	## condition true, rather than also having to find every place that should have asked.
	LYSED,
	## The clock ran out. In Prototype 1 that means simply "did not divide"; F06 turns it
	## into the comparison against the opponent's growth that §1 describes.
	TIME_EXPIRED,
}

var kind: Kind

## The tick the battle ended on.
var ended_at_tick: int

## Growth banked when it ended, and the target it was measured against (§4.1).
var banked_growth: int
var growth_target: int


func _init(
	p_kind: Kind, p_ended_at_tick: int, p_banked_growth: int, p_growth_target: int
) -> void:
	kind = p_kind
	ended_at_tick = p_ended_at_tick
	banked_growth = p_banked_growth
	growth_target = p_growth_target


func divided() -> bool:
	return kind == Kind.DIVIDED


## How far the cell got, in percent of its target. The growth bar F04-M03 draws.
func progress_percent() -> int:
	if growth_target <= 0:
		return 100
	return mini(100, banked_growth * 100 / growth_target)


func _to_string() -> String:
	return "BattleOutcome(%s at tick %d, %d/%d growth)" % [
		Kind.keys()[kind], ended_at_tick, banked_growth, growth_target
	]
