class_name SimState
extends RefCounted
## The whole simulated world, and the only thing [method step] mutates.
##
## Pure: no Node, no scene tree, no rendering, no unseeded randomness. Construct it,
## step it, read it. The build-phase sandbox (spec §9.1, F03-M01) steps a [method clone],
## so step must have no side effects outside this object — no signals, no globals,
## no logging to anything but the returned event list.
##
## Currently holds one cell's plasmid, economy and slot racks. When F06 adds a second
## cell and a shared medium, the per-cell fields here move into a `Cell` object and this
## keeps the tick loop and the medium. That move is mechanical and deliberately deferred:
## with one cell there is nothing yet to separate, and M05's medium will show exactly
## where the seam belongs.

## [b]Tick resolution order.[/b] Fixed here as milestones land — append to it, and do
## not reorder without re-measuring, because §2.4's baseline benchmark is sensitive to
## where spending falls relative to ageing.
##
## [codeblock]
##   1. finished builds occupy slots, evicting the oldest if the rack is full
##   2. promoters at their period fire: pay synthesis, start builds
##   3. (F01-M05) resident proteins act: transport, then catabolism
##   4. metabolites age; anything reaching MATURATION_AGE banks
## [/codeblock]
##
## Racking before firing is what makes build time honest: a protein with N build ticks
## occupies its slot exactly N ticks after the firing that paid for it. Ageing last means
## a metabolite produced during a tick ends that tick at age 0 and banks exactly
## [constant Balance.MATURATION_AGE] ticks later, which is the reading §2.1 implies.

## Ticks elapsed. The tick currently being simulated during [method step].
var tick: int = 0

## Immature metabolites. Vulnerable (§2.1).
var pool: MetabolitePool

## Growth banked out of the pool. Safe: cannot be spent, stolen, or lost (§2.1).
## Nothing in this class may decrement it.
var banked_growth: int = 0

## The cell's genome. Fixed for the duration of a battle — there is no mid-battle input
## (§7.0), so this only changes between battles.
var plasmid: Plasmid

## One rack per compartment, indexed by [enum ResolvedProtein.Compartment].
var racks: Array[SlotRack] = []

## Compiled from [member plasmid]; what each promoter expresses and what it costs.
var _units: Array[ExpressionUnit] = []

## Proteins mid-synthesis, in the order their firings started them.
var _builds: Array[PendingBuild] = []

## Events accumulated since the last [method step] returned. Output, not state —
## deliberately not carried across [method clone].
var _events: Array[SimEvent] = []


func _init() -> void:
	pool = MetabolitePool.new()
	plasmid = Plasmid.new()
	for i in range(ResolvedProtein.Compartment.size()):
		racks.append(SlotRack.new(Balance.SLOTS_PER_COMPARTMENT))


## Install a genome and compile what it expresses. Compilation happens here rather than
## per firing because §5.3 resolution cannot change unless the plasmid does.
func set_plasmid(p_plasmid: Plasmid) -> void:
	plasmid = p_plasmid
	_units = GeneExpression.compile(p_plasmid)
	_builds = []


func rack(compartment: ResolvedProtein.Compartment) -> SlotRack:
	return racks[compartment]


func expression_units() -> Array[ExpressionUnit]:
	return _units


func builds_in_progress() -> int:
	return _builds.size()


## Advance one tick. Returns everything that happened during it, in order.
func step() -> Array[SimEvent]:
	_finish_builds()
	_fire_promoters()
	# Step 3 of the resolution order lands here as F01-M05.

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
##
## The plasmid and its compiled units are shared rather than copied: neither changes
## during a battle (§7.0), and [method set_plasmid] replaces both references rather than
## mutating them.
func clone() -> SimState:
	var copy := SimState.new()
	copy.tick = tick
	copy.pool = pool.clone()
	copy.banked_growth = banked_growth
	copy.plasmid = plasmid
	copy._units = _units
	copy.racks = []
	for r in racks:
		copy.racks.append(r.clone())
	copy._builds = []
	for b in _builds:
		copy._builds.append(b.clone())
	return copy


## Step 1: proteins whose build time has elapsed take a slot.
func _finish_builds() -> void:
	var still_building: Array[PendingBuild] = []
	for build in _builds:
		build.ticks_remaining -= 1
		if build.ticks_remaining > 0:
			still_building.append(build)
		else:
			_occupy_slot(build.product)
	_builds = still_building


## Step 2: every promoter whose period divides this tick fires.
##
## An operon shares a clock and shares regulation (§4), so it also shares its bill: the
## transcript is paid for as a unit, and one the cell cannot afford expresses none of its
## proteins rather than an arbitrary prefix.
func _fire_promoters() -> void:
	for unit in _units:
		if unit.is_silent() or unit.period <= 0:
			continue
		if tick % unit.period != 0:
			continue

		var cost := unit.total_synthesis_cost()
		if cost > 0 and not pool.try_spend(cost):
			_emit(SimEvent.Type.SPEND_FAILED, {
				"amount": cost,
				"reason": &"synthesis",
				"promoter": unit.promoter_index,
				"available": pool.available(),
			})
			continue
		if cost > 0:
			_emit(SimEvent.Type.METABOLITE_SPENT, {
				"amount": cost,
				"reason": &"synthesis",
				"promoter": unit.promoter_index,
			})

		for product in unit.products:
			_builds.append(PendingBuild.new(product, product.build_ticks))


func _occupy_slot(product: GeneProduct) -> void:
	var target := racks[product.resolved.compartment]
	var was_full := target.is_full()
	var evicted := target.insert(product)

	_emit(SimEvent.Type.PROTEIN_BUILT, {
		"promoter": product.source_promoter_index,
		"compartment": product.resolved.compartment,
		"occupied": target.count(),
		"capacity": target.capacity,
		"into_full_rack": was_full,
	})
	if evicted != null:
		_emit(SimEvent.Type.PROTEIN_EVICTED, {
			"evicted_promoter": evicted.source_promoter_index,
			"evicted_by_promoter": product.source_promoter_index,
			"compartment": product.resolved.compartment,
		})


func _emit(type: SimEvent.Type, data: Dictionary = {}) -> void:
	_events.append(SimEvent.new(type, tick, data))


func _drain_events() -> Array[SimEvent]:
	var drained := _events
	_events = []
	return drained
