class_name SlotRack
extends RefCounted
## One compartment's protein slots. Spec §3, §3.4.
##
## [b]One protein per slot, no stacking.[/b] A second copy of an enzyme costs a second
## slot, so throughput scales by spending slots rather than by expression volume. This
## is the design's most unusual and most valuable property (§3.1) — a "stack identical
## proteins" optimisation would silently delete the entire skill ceiling.
##
## Insertion evicts the oldest occupant when full. Because promoter firing is
## deterministic (§4.2), the rack settles into a stable repeating cycle rather than a
## random walk, which is what makes a build predictable enough to be worth planning.
##
## Occupants are held oldest-first; age is queue position, not a timestamp. Stable
## physical slot numbering is a presentation concern and belongs to F03 if it turns out
## the event log needs it.

var capacity: int

## Oldest first. Shares [GeneProduct] references rather than copying them — products are
## immutable once compiled.
var _occupants: Array[GeneProduct] = []


func _init(p_capacity: int) -> void:
	capacity = p_capacity


## Rack a protein, returning whatever it evicted, or null if there was room.
##
## Note that a full rack still accepts the insertion and pays for it. A promoter firing
## into a full rack is meant to be a visible waste of money, not a silent no-op (§2.3).
func insert(product: GeneProduct) -> GeneProduct:
	_occupants.append(product)
	if _occupants.size() <= capacity:
		return null
	return _occupants.pop_front()


func count() -> int:
	return _occupants.size()


func is_full() -> bool:
	return _occupants.size() >= capacity


## Oldest first.
func occupants() -> Array[GeneProduct]:
	return _occupants.duplicate()


## How many slots each promoter currently holds, keyed by promoter ring index. This is
## the equilibrium §3.1 predicts and the rack §9.2 wants drawn.
func composition() -> Dictionary:
	var counts := {}
	for product in _occupants:
		var key := product.source_promoter_index
		counts[key] = counts.get(key, 0) + 1
	return counts


func clone() -> SlotRack:
	var copy := SlotRack.new(capacity)
	copy._occupants = _occupants.duplicate()
	return copy
