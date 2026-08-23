## F01-M04 — slot racks and FIFO eviction. Spec §3, §3.4.
var runner: Object


func set_runner(r: Object) -> void:
	runner = r


func _product(promoter_index: int) -> GeneProduct:
	var protein := ProteinDef.new()
	return GeneProduct.new(protein, ResolvedProtein.new(
		ResolvedProtein.Compartment.INTERNAL, -1
	), promoter_index, 1, 1)


func test_fills_to_capacity_without_evicting() -> void:
	var slots := SlotRack.new(Balance.SLOTS_PER_COMPARTMENT)
	for i in range(Balance.SLOTS_PER_COMPARTMENT):
		runner.check_eq(slots.insert(_product(i)), null, "evicted while there was room")
	runner.check_eq(slots.count(), Balance.SLOTS_PER_COMPARTMENT, "wrong occupancy")
	runner.check(slots.is_full(), "should be full")


func test_eviction_takes_the_oldest_occupant() -> void:
	var slots := SlotRack.new(3)
	slots.insert(_product(10))
	slots.insert(_product(20))
	slots.insert(_product(30))

	var evicted := slots.insert(_product(40))
	runner.check(evicted != null, "a full rack accepted a fourth protein without evicting")
	runner.check_eq(evicted.source_promoter_index, 10, "evicted something other than the oldest")
	runner.check_eq(slots.count(), 3, "capacity was exceeded")


func test_copies_of_one_gene_each_cost_a_slot() -> void:
	# No stacking (§3.4). Eight copies of the same gene fill the rack; this is what makes
	# throughput scale by spending slots rather than by expression volume.
	var slots := SlotRack.new(Balance.SLOTS_PER_COMPARTMENT)
	for i in range(Balance.SLOTS_PER_COMPARTMENT):
		slots.insert(_product(0))

	runner.check_eq(slots.count(), Balance.SLOTS_PER_COMPARTMENT, "copies were stacked")
	runner.check_eq(slots.composition().get(0, 0), 8, "composition did not count copies")


func test_composition_counts_slots_per_promoter() -> void:
	var slots := SlotRack.new(8)
	for i in range(6):
		slots.insert(_product(0))
	for i in range(2):
		slots.insert(_product(4))

	var comp := slots.composition()
	runner.check_eq(comp.get(0, 0), 6, "promoter 0 slot count")
	runner.check_eq(comp.get(4, 0), 2, "promoter 4 slot count")


func test_clone_is_independent_of_its_original() -> void:
	var slots := SlotRack.new(2)
	slots.insert(_product(1))
	var copy := slots.clone()

	copy.insert(_product(2))
	copy.insert(_product(3))
	runner.check_eq(slots.count(), 1, "clone shares occupants with the original")
	runner.check_eq(copy.count(), 2, "clone did not fill")
