class_name PendingBuild
extends RefCounted
## A protein being synthesised, counting down to its slot. Spec §3.5.
##
## Builds run concurrently and independently: every firing starts its own, even while
## an earlier one from the same promoter is still in progress. That matters more than it
## looks — if a firing could be dropped because the gene was busy, its effective rate
## would stop being 1/period and §3.1's slot-share equilibrium would quietly stop
## holding for the fastest promoters.

var product: GeneProduct
var ticks_remaining: int


func _init(p_product: GeneProduct, p_ticks_remaining: int) -> void:
	product = p_product
	ticks_remaining = p_ticks_remaining


func clone() -> PendingBuild:
	return PendingBuild.new(product, ticks_remaining)
