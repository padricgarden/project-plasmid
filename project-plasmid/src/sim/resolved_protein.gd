class_name ResolvedProtein
extends RefCounted
## A protein with its compartment and its functions worked out. Spec §3, §5.3.
##
## The output of [Adjacency]. M04 racks these into slots by compartment; M05 runs their
## functions; F02-M02 draws them.

enum Compartment {
	## Cytoplasm. The default for anything without a membrane or extracellular domain.
	INTERNAL,
	## Embedded in the membrane. The contested compartment — every transporter and
	## sensor competes for it, which is what makes topology decisions costly (§3.2).
	MEMBRANE,
	## Secreted. Requires an Extracellular Domain, which arrives with polymer
	## pre-digestion in F06 — unreachable in Prototype 1, but §3 fixes the rack at
	## 8 / 8 / 8, so M04 needs the third compartment to exist.
	EXTERNAL,
}

var compartment: Compartment

## Where the membrane sits within the protein; -1 when not membrane-embedded. Blocks
## before it are cytoplasmic, blocks after it extracellular (§5.1).
var membrane_index: int

## Every effector in block order, inert ones included — the build phase needs to show
## a block that does nothing as a block that does nothing (§9.2).
var functions: Array[ProteinFunction]


func _init(
	p_compartment: Compartment, p_membrane_index: int, p_functions: Array[ProteinFunction] = []
) -> void:
	compartment = p_compartment
	membrane_index = p_membrane_index
	functions = p_functions


func active_functions() -> Array[ProteinFunction]:
	var active: Array[ProteinFunction] = []
	for f in functions:
		if f.is_active():
			active.append(f)
	return active


## True when the protein occupies a slot and does nothing for it — the most expensive
## mistake available in the build phase, since it pays synthesis upkeep forever (§3.2).
func is_inert() -> bool:
	return active_functions().is_empty()


## Whether the block at [param position] within this protein sits on the extracellular
## side of the membrane. Spec §5.1 — blocks left of the membrane domain are cytoplasmic,
## blocks right of it extracellular.
##
## The sim reads this to decide whether an enzyme eats the cell's food or the medium's,
## and the topology preview reads it to decide which side of the membrane to draw a block
## on. One implementation so those two can never disagree about where a block is.
func is_outside(position: int) -> bool:
	return membrane_index >= 0 and position > membrane_index


func has_function(kind: ProteinFunction.Kind) -> bool:
	for f in functions:
		if f.kind == kind:
			return true
	return false
