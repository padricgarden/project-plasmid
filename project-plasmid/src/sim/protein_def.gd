class_name ProteinDef
extends RefCounted
## The ordered run of domain blocks that one stretch of a transcript translates into.
## Spec §4, §5.
##
## Structure only. What the protein [i]does[/i] is resolved from adjacency and topology
## in F01-M03, and what it costs to synthesise in F01-M04 — deliberately not here, so
## the §5.3 rules live in exactly one place and cannot drift between two.

var blocks: Array[Block]

## Where each block came from on the ring, parallel to [member blocks].
##
## Kept because a protein genuinely does come from specific ring positions, and losing
## that makes it impossible to point at one: the editor has to highlight the blocks a
## protein is made of (F02-M02) and the readout has to name them (F02-M03). Recovering it
## by re-walking §4's transcription rules in the UI would mean two copies of those rules.
##
## A readthrough protein wraps, so these are not necessarily contiguous or ascending.
var ring_indices: PackedInt32Array


func _init(p_blocks: Array[Block] = [], p_ring_indices: PackedInt32Array = []) -> void:
	blocks = p_blocks
	ring_indices = p_ring_indices


## Whether this protein was translated from the block at [param ring_index].
func covers(ring_index: int) -> bool:
	return ring_indices.has(ring_index)


## Block count. Drives synthesis cost and build time once M04 lands (§2.2, §3.5).
func length() -> int:
	return blocks.size()


func is_empty() -> bool:
	return blocks.is_empty()


## The kinds in order. For tests and for the topology preview (F02-M02).
func kinds() -> Array:
	return blocks.map(func(b): return b.kind)


func _to_string() -> String:
	var names := blocks.map(func(b): return Block.Kind.keys()[b.kind])
	return "ProteinDef(%s)" % "+".join(names)
