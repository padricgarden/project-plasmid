class_name Adjacency
extends RefCounted
## Resolves what a protein does from the order of its blocks. Spec §5.3.
##
## This is the file that makes arrangement a puzzle rather than a list. Everything here
## is derived: no block stores what it does, so the same Transporter is an importer, an
## exporter or dead weight depending only on its neighbours. Keep it that way — one
## place for these rules is what stops the editor, the readout panel and the sim from
## each growing their own slightly different version.
##
## [b]Rules implemented[/b] (§5.3):
## [br]1. A target domain sets the target for [i]both[/i] its neighbours.
## [br]2. An effector with two different targets acts on both. The doubled cost is M05's.
## [br]3. Transport only functions when membrane-embedded.
## [br]4. Transporter direction is read off which side of the membrane its target sits.
##
## [b]Decided here, because §5.3 does not say[/b]:
## [br]• A membrane-embedded transporter reaches [i]through[/i] the membrane domain it
## sits against, seeing the block on its far side. Without this, no arrangement can put
## targets on both sides of a transporter — the transporter's two neighbours can only
## straddle the membrane if the membrane is the transporter — and exchange (§2.2's
## "efficiency play") would be unreachable. Reach-through is transporter-only, since
## rule 3 already makes membrane interaction their special case.
## [br]• Two targets of the [i]same[/i] kind on opposite sides is inert, not an exchange.
## Trading food for food moves nothing, and saying so plainly serves §9 better than
## charging nothing for a no-op.
## [br]• Multiple membrane domains: the first one sets the boundary. Real proteins cross
## the bilayer repeatedly; the game does not need to, and one boundary keeps the
## topology preview drawable.

## Blocks that do work and therefore need resolving.
const EFFECTORS := [Block.Kind.TRANSPORTER_DOMAIN, Block.Kind.CATABOLIC_ENZYME]

## Blocks that designate what an effector acts on (§5.2). Toxin and Metabolite join
## this list in F05.
const TARGETS := [Block.Kind.FOOD]

## Which way to look from an effector. Typed so the index arithmetic stays typed.
const SIDES: Array[int] = [-1, 1]


static func resolve(def: ProteinDef) -> ResolvedProtein:
	var blocks := def.blocks
	var membrane_index := _first_membrane(blocks)
	var compartment := (
		ResolvedProtein.Compartment.MEMBRANE
		if membrane_index >= 0
		else ResolvedProtein.Compartment.INTERNAL
	)

	var functions: Array[ProteinFunction] = []
	for i in range(blocks.size()):
		match blocks[i].kind:
			Block.Kind.TRANSPORTER_DOMAIN:
				functions.append(_resolve_transporter(blocks, i, membrane_index))
			Block.Kind.CATABOLIC_ENZYME:
				functions.append(_resolve_catabolic(blocks, i))

	return ResolvedProtein.new(compartment, membrane_index, functions)


static func _resolve_transporter(
	blocks: Array[Block], index: int, membrane_index: int
) -> ProteinFunction:
	# Rule 3: the constraint that makes topology matter at all.
	if membrane_index < 0:
		return ProteinFunction.inert(
			index, "a transporter that is not membrane-embedded moves nothing"
		)

	var target_indices := _adjacent_targets(blocks, index, true)
	if target_indices.is_empty():
		return ProteinFunction.inert(index, "no target block sits next to this transporter")

	# Rule 4: direction is read off the membrane, not off the block.
	var cytoplasmic: Array = []
	var extracellular: Array = []
	for t in target_indices:
		if t < membrane_index:
			_append_distinct(cytoplasmic, blocks[t].kind)
		else:
			_append_distinct(extracellular, blocks[t].kind)

	if cytoplasmic.is_empty():
		return ProteinFunction.new(ProteinFunction.Kind.IMPORT, index, extracellular)
	if extracellular.is_empty():
		return ProteinFunction.new(ProteinFunction.Kind.EXPORT, index, cytoplasmic)

	if cytoplasmic == extracellular:
		return ProteinFunction.inert(
			index, "moves the same target both ways, so nothing crosses the membrane"
		)

	var both: Array = cytoplasmic.duplicate()
	for kind in extracellular:
		_append_distinct(both, kind)
	return ProteinFunction.new(ProteinFunction.Kind.EXCHANGE, index, both)


static func _resolve_catabolic(blocks: Array[Block], index: int) -> ProteinFunction:
	# Catabolism works in any compartment — rule 3 restricts transport, not enzymes.
	var target_indices := _adjacent_targets(blocks, index, false)
	if target_indices.is_empty():
		return ProteinFunction.inert(index, "no target block sits next to this enzyme")

	var kinds: Array = []
	for t in target_indices:
		_append_distinct(kinds, blocks[t].kind)
	return ProteinFunction.new(ProteinFunction.Kind.CATABOLISE, index, kinds)


## Indices of the target blocks an effector at [param index] can act on.
##
## Rule 1 read from the effector's side: a target sets the target for both its
## neighbours, so an effector picks up a target on either side of itself. With
## [param reach_through_membrane], it also sees past an adjacent membrane domain.
static func _adjacent_targets(
	blocks: Array[Block], index: int, reach_through_membrane: bool
) -> PackedInt32Array:
	var found := PackedInt32Array()
	for step in SIDES:
		var probe := index + step
		if not _in_range(blocks, probe):
			continue
		if reach_through_membrane and blocks[probe].kind == Block.Kind.MEMBRANE_DOMAIN:
			probe += step
			if not _in_range(blocks, probe):
				continue
		if blocks[probe].kind in TARGETS:
			found.append(probe)
	return found


static func _first_membrane(blocks: Array[Block]) -> int:
	for i in range(blocks.size()):
		if blocks[i].kind == Block.Kind.MEMBRANE_DOMAIN:
			return i
	return -1


static func _in_range(blocks: Array[Block], index: int) -> bool:
	# A protein is a run, not a ring: it does not wrap. Adjacency across a protein
	# boundary would let one gene's blocks change another gene's behaviour.
	return index >= 0 and index < blocks.size()


static func _append_distinct(list: Array, value: Variant) -> void:
	if not list.has(value):
		list.append(value)
