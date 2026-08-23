class_name GeneProduct
extends RefCounted
## One protein as the sim will actually express it: its blocks, what those blocks
## resolve to, which promoter drives it, and what it costs in metabolites and in ticks.
##
## Compiled once by [Expression] when the plasmid is set, not recomputed per firing.
## Promoters fire every few ticks for a whole battle and §5.3 resolution cannot change
## unless the plasmid does, so resolving on every firing would be pure waste.
##
## Treated as immutable once compiled. [SlotRack] and [PendingBuild] share references to
## the same product rather than copying it, which is what keeps cloning a whole
## [SimState] cheap enough for the build-phase sandbox (F03-M01).

var definition: ProteinDef

## Compartment and functions, per §5.3.
var resolved: ResolvedProtein

## Ring position of the promoter that expresses this. Identifies which gene holds which
## slots — the rack composition §9.2 asks the readout panel to draw.
var source_promoter_index: int

## Metabolites charged when its promoter fires (§2.2).
var synthesis_cost: int

## Ticks between firing and occupying a slot (§3.5).
var build_ticks: int


func _init(
	p_definition: ProteinDef,
	p_resolved: ResolvedProtein,
	p_source_promoter_index: int,
	p_synthesis_cost: int,
	p_build_ticks: int
) -> void:
	definition = p_definition
	resolved = p_resolved
	source_promoter_index = p_source_promoter_index
	synthesis_cost = p_synthesis_cost
	build_ticks = p_build_ticks


func _to_string() -> String:
	return "GeneProduct(P@%d, %d blocks, cost %d, %d ticks)" % [
		source_promoter_index, definition.length(), synthesis_cost, build_ticks
	]
