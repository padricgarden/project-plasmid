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
##   1. the environment drips food into the medium
##   2. finished builds occupy slots, evicting the oldest if the rack is full
##   3. promoters at their period fire: pay synthesis, start builds
##   4. resident proteins act: transport first, then catabolism
##   5. metabolites age; anything reaching MATURATION_AGE banks
## [/codeblock]
##
## Racking before firing is what makes build time honest: a protein with N build ticks
## occupies its slot exactly N ticks after the firing that paid for it. Transport before
## catabolism means food imported on a tick is digestible on that same tick, so the
## pipeline has no built-in stall. Ageing last means a metabolite produced during a tick
## ends that tick at age 0 and banks exactly [constant Balance.MATURATION_AGE] ticks
## later, which is the reading §2.1 implies.

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


## The shared environment pool. One object even in Prototype 1, because F06's second
## cell draws from this same one (§7.1).
var medium: Medium

## Food the cell has imported and not yet digested.
var internal_food: int = 0

## What the environment delivers, and what its food is worth. Null means a bare sim with
## no environment at all — nothing is delivered and nothing can be imported. A battle
## must set one.
var environment: EnvironmentDef = null


func _init() -> void:
	pool = MetabolitePool.new()
	plasmid = Plasmid.new()
	medium = Medium.new()
	for i in range(ResolvedProtein.Compartment.size()):
		racks.append(SlotRack.new(Balance.SLOTS_PER_COMPARTMENT))


## Set up a battle: install the genome and the environment, and endow the cell with the
## metabolites it needs to express anything at all.
##
## The endowment is what separates a battle from a bare sim. Without it the cell cannot
## pay for its first transcript, so it never builds a protein, so it never earns —
## a permanent deadlock rather than the §2.5 death spiral, which is a *recoverable*
## economic misjudgement. Tests that want to observe an unfunded cell should call
## [method set_plasmid] and [method set_environment] directly instead.
func begin_battle(p_plasmid: Plasmid, p_environment: EnvironmentDef) -> void:
	set_plasmid(p_plasmid)
	set_environment(p_environment)
	pool.add(starting_endowment())


## One full round of synthesis plus a buffer, so a cell can always express its genome
## once and fund the first import that starts paying it back. Scaled to the genome
## because a flat value soft-locks larger plasmids — see [constant
## Balance.STARTING_METABOLITE_BUFFER].
func starting_endowment() -> int:
	var total := Balance.STARTING_METABOLITE_BUFFER
	for unit in _units:
		total += unit.total_synthesis_cost()
	return total


## Install an environment and seed the medium with whatever it starts with (§7.4).
func set_environment(p_environment: EnvironmentDef) -> void:
	environment = p_environment
	medium.food = p_environment.starting_food


## Banked growth needed to divide, given how many blocks the plasmid carries (§4.1).
func growth_target() -> int:
	return Burden.growth_target(plasmid.size())


## Whether the cell has been over the toxin threshold long enough to burst (§1).
##
## Always false in Prototype 1: there is no Toxin block in the grammar until F05, so the
## condition cannot become true. The call site exists now so that F05-M01 only has to
## make this return something — not also hunt down every place that should have asked.
##
## Its two numbers, the threshold and the consecutive-tick count, are deliberately
## [i]not[/i] invented yet. The spec gives neither, and putting values in the register
## for a path no test can reach would be registering fiction.
func is_lysing() -> bool:
	return false


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
	_deliver_food()
	_finish_builds()
	_fire_promoters()
	_run_effectors()

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
	copy.medium = medium.clone()
	copy.environment = environment
	copy.internal_food = internal_food
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


## Step 2: proteins whose build time has elapsed take a slot.
func _finish_builds() -> void:
	var still_building: Array[PendingBuild] = []
	for build in _builds:
		build.ticks_remaining -= 1
		if build.ticks_remaining > 0:
			still_building.append(build)
		else:
			_occupy_slot(build.product)
	_builds = still_building


## Step 3: every promoter whose period divides this tick fires.
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


## Step 1: the environment drips.
func _deliver_food() -> void:
	if environment == null:
		return
	var delivered := medium.deliver(environment)
	if delivered > 0:
		_emit(SimEvent.Type.FOOD_DELIVERED, {"count": delivered, "in_medium": medium.food})


## Step 4: every resident effector whose cadence lands on this tick does its work.
##
## Transport runs across all compartments before any catabolism, so food imported this
## tick can be digested this tick. Racks are walked in compartment order and occupants
## oldest-first, which is what keeps contention for the last unit of food deterministic
## (§4.2) once F06 has two cells reaching for it.
func _run_effectors() -> void:
	for compartment in range(racks.size()):
		for occupant in racks[compartment].occupants():
			if not occupant.acts_on_tick(tick):
				continue
			for function in occupant.product.resolved.functions:
				match function.kind:
					ProteinFunction.Kind.IMPORT:
						_import_food()
					ProteinFunction.Kind.EXPORT:
						_export_food()
					# EXCHANGE needs two different targets and is unreachable until F05
					# adds Toxin, so there is nothing here to run yet.

	for compartment in range(racks.size()):
		for occupant in racks[compartment].occupants():
			if not occupant.acts_on_tick(tick):
				continue
			for function in occupant.product.resolved.functions:
				if function.kind == ProteinFunction.Kind.CATABOLISE:
					_catabolise(occupant.product, function)


## An importer with nothing to import costs nothing. That is deliberate: charging for a
## move that did not happen is exactly how §10's "importer becomes a trap block" risk
## would materialise, since a full membrane rack in a scarce medium would bleed the pool
## dry for no return.
func _import_food() -> void:
	if medium.food <= 0:
		return
	if not try_spend(Balance.TRANSPORT_COST, &"import"):
		return
	medium.take_food(1)
	internal_food += 1
	_emit(SimEvent.Type.FOOD_IMPORTED, {"in_medium": medium.food, "internal": internal_food})


func _export_food() -> void:
	if internal_food <= 0:
		return
	if not try_spend(Balance.TRANSPORT_COST, &"export"):
		return
	internal_food -= 1
	medium.add_food(1)
	_emit(SimEvent.Type.FOOD_EXPORTED, {"in_medium": medium.food, "internal": internal_food})


## Catabolism is free on food and yields the environment's tier value (§2.2, §7.3).
##
## Where the enzyme sits decides what it eats. An enzyme on the extracellular side of a
## membrane protein destroys food in the medium and yields nothing to anybody — the
## metabolites are outside the cell and lost. That is §8's denial elite, "a cell
## secreting a catabolic enzyme that destroys extracellular food", falling out of the
## topology rather than needing a special block. Turning medium polymer into medium
## sugar instead is §7.3's pre-digestion and arrives with F06.
func _catabolise(product: GeneProduct, function: ProteinFunction) -> void:
	var resolved := product.resolved
	var outside := resolved.membrane_index >= 0 and function.effector_index > resolved.membrane_index

	if outside:
		if medium.food <= 0:
			return
		medium.take_food(1)
		_emit(SimEvent.Type.FOOD_DESTROYED, {"in_medium": medium.food})
		return

	if internal_food <= 0:
		return
	internal_food -= 1
	var yielded := environment.food_yield if environment != null else 0
	_emit(SimEvent.Type.FOOD_CATABOLISED, {"yield": yielded, "internal": internal_food})
	produce(yielded)


func _occupy_slot(product: GeneProduct) -> void:
	var target := racks[product.resolved.compartment]
	var was_full := target.is_full()
	var evicted := target.insert(product, tick)

	_emit(SimEvent.Type.PROTEIN_BUILT, {
		"promoter": product.source_promoter_index,
		"compartment": product.resolved.compartment,
		"occupied": target.count(),
		"capacity": target.capacity,
		"into_full_rack": was_full,
	})
	if evicted != null:
		_emit(SimEvent.Type.PROTEIN_EVICTED, {
			"evicted_promoter": evicted.product.source_promoter_index,
			"evicted_by_promoter": product.source_promoter_index,
			"compartment": product.resolved.compartment,
		})


func _emit(type: SimEvent.Type, data: Dictionary = {}) -> void:
	_events.append(SimEvent.new(type, tick, data))


func _drain_events() -> Array[SimEvent]:
	var drained := _events
	_events = []
	return drained
