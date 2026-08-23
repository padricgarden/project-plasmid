class_name Burden
extends RefCounted
## Plasmid burden: how much growth a genome must bank before it can divide. Spec §4.1.
##
## [code]target = BASE + c × (B^exp − B_start^exp)[/code], normalised so a starting-sized
## genome sits at exactly BASE.
##
## The exponent is nearly linear on purpose. The real diminishing return comes from
## slots, not from this curve: only 24 proteins can ever be resident, so block count and
## throughput decouple hard past a full rack. §4.1 is explicit — [b]tune `c`, not the
## exponent[/b].
##
## Float maths is confined to this function. The result is rounded to an int once and
## everything downstream compares integers, so nothing accumulates drift.


static func growth_target(block_count: int) -> int:
	var grown := pow(float(maxi(block_count, 0)), Balance.BURDEN_EXPONENT)
	var baseline := pow(float(Balance.STARTING_BLOCK_COUNT), Balance.BURDEN_EXPONENT)
	return Balance.BASE_GROWTH_TARGET + roundi(Balance.BURDEN_COEFFICIENT * (grown - baseline))
