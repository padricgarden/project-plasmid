class_name MetabolitePool
extends RefCounted
## The immature metabolite pool. Spec §2.1.
##
## Metabolites enter at age 0 and age one tick at a time. On reaching
## [constant Balance.MATURATION_AGE] they leave permanently and become banked growth.
## Until then they are vulnerable — spendable, and later stealable and destroyable —
## which is what makes a bursty economy structurally different from a steady one.
##
## Stored as counts bucketed by age rather than one entry per metabolite: ageing is a
## shift, maturation is whatever falls off the end, and the whole pool copies in
## O(MATURATION_AGE) regardless of size — which the build-phase sandbox (F03-M01)
## needs, since it clones the world on every edit.
##
## [b]This class holds no reference to banked growth.[/b] "Banked growth is safe"
## (§2.1) is therefore structural rather than a rule to remember: no bug in here can
## reach it. Keep it that way — maturation reports a count and the caller banks it.

## Count of metabolites at each age, index 0 being freshly produced.
var _by_age: PackedInt32Array


func _init() -> void:
	_by_age.resize(Balance.MATURATION_AGE)


## Total immature metabolites in the pool. Excludes anything already banked.
func available() -> int:
	var total := 0
	for count in _by_age:
		total += count
	return total


## Add freshly produced metabolites at age 0.
func add(count: int) -> void:
	assert(count >= 0, "cannot add a negative number of metabolites")
	_by_age[0] += count


## Spend youngest-first, per §2.1 — a player should never feel robbed of a
## nearly-matured metabolite.
##
## All-or-nothing: returns [code]false[/code] and changes nothing if the pool cannot
## cover the full amount. That is what makes the §2.5 death spiral a stall (the pump
## simply does not fire) rather than a debt, and it keeps the pool from ever going
## negative. Callers that want partial fulfilment must clamp against
## [method available] themselves — that is a per-action design decision, not the
## pool's to make.
func try_spend(amount: int) -> bool:
	assert(amount >= 0, "cannot spend a negative number of metabolites")
	if amount > available():
		return false
	var remaining := amount
	for age in range(_by_age.size()):
		if remaining == 0:
			break
		var taken: int = mini(remaining, _by_age[age])
		_by_age[age] -= taken
		remaining -= taken
	return true


## Age every metabolite by one tick and return how many matured out of the pool.
## The caller is responsible for turning that count into banked growth.
func advance() -> int:
	var matured := _by_age[_by_age.size() - 1]
	for age in range(_by_age.size() - 1, 0, -1):
		_by_age[age] = _by_age[age - 1]
	_by_age[0] = 0
	return matured


## How many metabolites are sitting at a given age. For tests and for the readout
## panel's buffer display (F03-M02).
func count_at_age(age: int) -> int:
	return _by_age[age]


func clone() -> MetabolitePool:
	var copy := MetabolitePool.new()
	copy._by_age = _by_age.duplicate()
	return copy
