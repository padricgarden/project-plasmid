class_name ExpressionUnit
extends RefCounted
## One promoter and everything it expresses when it fires. Spec §4, §4.2.
##
## Operon members share a clock and share regulation (§4) — and therefore share a bill.
## [method total_synthesis_cost] is charged as a unit, so a transcript the cell cannot
## afford expresses none of its proteins rather than an arbitrary prefix of them.

var promoter_index: int

## Ticks between firings. One of [constant Balance.PROMOTER_PERIODS].
var period: int

var products: Array[GeneProduct]


func _init(
	p_promoter_index: int, p_period: int, p_products: Array[GeneProduct] = []
) -> void:
	promoter_index = p_promoter_index
	period = p_period
	products = p_products


## What one firing costs (§2.2). This is also the upkeep the rack charges forever once
## it is full, since every firing then evicts to make room (§3.2).
func total_synthesis_cost() -> int:
	var total := 0
	for product in products:
		total += product.synthesis_cost
	return total


## A promoter reading straight into a terminator expresses nothing and costs nothing.
func is_silent() -> bool:
	return products.is_empty()


## Metabolites per tick this gene costs to keep expressing — the churn §3.2 asks the
## readout panel to surface as upkeep/tick. Returned scaled by [param scale] so callers
## can keep the economy in integers.
func upkeep_per_tick_scaled(scale: int) -> int:
	if period <= 0:
		return 0
	return total_synthesis_cost() * scale / period


func _to_string() -> String:
	return "ExpressionUnit(P@%d every %d, %d product(s))" % [
		promoter_index, period, products.size()
	]
