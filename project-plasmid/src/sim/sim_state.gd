class_name SimState
extends RefCounted
## The whole simulated world, and the only thing [method step] mutates.
##
## Pure: no Node, no scene tree, no rendering, no unseeded randomness. Construct it,
## step it, read it. The build-phase sandbox (spec §9.1, F03-M01) steps a [method clone],
## so step must have no side effects outside this object — no signals, no globals,
## no logging to anything but the returned event list.
##
## Currently holds one cell's economy. F06 adds a second cell and a shared medium
## alongside; the shape is meant to absorb that without a rewrite.

## [b]Tick resolution order.[/b] Fixed here as milestones land — append to it, and do
## not reorder without re-measuring, because §2.4's baseline benchmark is sensitive to
## where spending falls relative to ageing.
##
## [codeblock]
##   1. (F01-M04) promoters fire; proteins build and are racked
##   2. (F01-M05) resident proteins act: transport, then catabolism
##   3.           metabolites age; anything reaching MATURATION_AGE banks
## [/codeblock]
##
## Ageing last means a metabolite produced during a tick ends that tick at age 0 and
## banks exactly [constant Balance.MATURATION_AGE] ticks later, which is the reading
## §2.1 implies.

## Ticks elapsed. The tick currently being simulated during [method step].
var tick: int = 0

## Immature metabolites. Vulnerable (§2.1).
var pool: MetabolitePool

## Growth banked out of the pool. Safe: cannot be spent, stolen, or lost (§2.1).
## Nothing in this class may decrement it.
var banked_growth: int = 0

## Events accumulated since the last [method step] returned. Output, not state —
## deliberately not carried across [method clone].
var _events: Array[SimEvent] = []


func _init() -> void:
	pool = MetabolitePool.new()


## Advance one tick. Returns everything that happened during it, in order.
func step() -> Array[SimEvent]:
	# Steps 1 and 2 of the resolution order land here as F01-M04 and F01-M05.

	var matured := pool.advance()
	if matured > 0:
		banked_growth += matured
		_emit(SimEvent.Type.METABOLITE_MATURED, {
			"count": matured,
			"banked_total": banked_growth,
		})

	tick += 1
	return _drain_events()


## Emit freshly catabolised metabolites into the pool at age 0.
func produce(count: int) -> void:
	if count <= 0:
		return
	pool.add(count)
	_emit(SimEvent.Type.METABOLITE_PRODUCED, {"count": count})


## Pay for an action. Returns false and spends nothing if the pool cannot cover it —
## the §2.5 stall, where a cell that has run its pool dry cannot afford the pump that
## would save it. [param reason] is carried into the event log (§9.3) so a stall is
## always attributable to a specific action.
func try_spend(amount: int, reason: StringName) -> bool:
	if pool.try_spend(amount):
		_emit(SimEvent.Type.METABOLITE_SPENT, {"amount": amount, "reason": reason})
		return true
	_emit(SimEvent.Type.SPEND_FAILED, {
		"amount": amount,
		"reason": reason,
		"available": pool.available(),
	})
	return false


## A deep copy that can be stepped without touching this one. Used by the build-phase
## sandbox, and by any prediction that needs to run the world forward speculatively.
func clone() -> SimState:
	var copy := SimState.new()
	copy.tick = tick
	copy.pool = pool.clone()
	copy.banked_growth = banked_growth
	return copy


func _emit(type: SimEvent.Type, data: Dictionary = {}) -> void:
	_events.append(SimEvent.new(type, tick, data))


func _drain_events() -> Array[SimEvent]:
	var drained := _events
	_events = []
	return drained
