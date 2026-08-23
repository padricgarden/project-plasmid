class_name SlotOccupant
extends RefCounted
## One protein resident in a slot, holding the state that belongs to the copy rather
## than to the gene. Spec §2.2, §3.
##
## [GeneProduct] is compiled once and shared by every copy of a gene, so anything
## per-copy has to live here — which for now means when it was racked, and therefore
## when it next acts.

var product: GeneProduct

## Effectors act on a fixed cadence counted from the tick they took their slot, so
## copies racked on different ticks act on different ticks. That staggering matters:
## in lockstep, eight enzymes would dump their whole yield into the pool every third
## tick, and §2.1's ageing — plus §7.5's buffer-versus-shock tension — would be reading
## a spiky pool instead of a smooth one.
var racked_at_tick: int


func _init(p_product: GeneProduct, p_racked_at_tick: int) -> void:
	product = p_product
	racked_at_tick = p_racked_at_tick


func acts_on_tick(tick: int) -> bool:
	return (tick - racked_at_tick) % Balance.EFFECTOR_COOLDOWN_TICKS == 0


func clone() -> SlotOccupant:
	return SlotOccupant.new(product, racked_at_tick)


func _to_string() -> String:
	return "SlotOccupant(P@%d, racked t%d)" % [product.source_promoter_index, racked_at_tick]
