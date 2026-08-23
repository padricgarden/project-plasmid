## F01-M03 — adjacency and topology resolution. Spec §5.3, §5.4.
var runner: Object

## Every arrangement reachable with the Prototype 1 block set, and what it resolves to.
## Read the right-hand column as "compartment: functions in block order".
const CASES := [
	# Rule 1 — a target sets the target for both its neighbours, either side.
	["CAT-FOOD", "INTERNAL: CATABOLISE[FOOD]"],
	["FOOD-CAT", "INTERNAL: CATABOLISE[FOOD]"],
	# ...and one target block can serve two effectors at once. Dense sandwiches are
	# "the primary skill expression" (§5.3).
	["CAT-FOOD-CAT", "INTERNAL: CATABOLISE[FOOD] CATABOLISE[FOOD]"],

	# Rule 3 — the negative case. A cytoplasmic transporter does nothing at all.
	["TRA-FOOD", "INTERNAL: inert"],
	["FOOD-TRA", "INTERNAL: inert"],

	# Rule 4 — direction is read off which side of the membrane the target sits.
	["MEM-TRA-FOOD", "MEMBRANE: IMPORT[FOOD]"],
	["MEM-FOOD-TRA", "MEMBRANE: IMPORT[FOOD]"],
	["TRA-MEM-FOOD", "MEMBRANE: IMPORT[FOOD]"],
	["FOOD-TRA-MEM", "MEMBRANE: EXPORT[FOOD]"],
	["FOOD-MEM-TRA", "MEMBRANE: EXPORT[FOOD]"],

	# A transporter with nothing to move, and one moving the same target both ways.
	["MEM-TRA", "MEMBRANE: inert"],
	["FOOD-TRA-MEM-FOOD", "MEMBRANE: inert"],

	# §5.3's two-for-one: one target block feeding a transporter and an enzyme.
	["MEM-TRA-FOOD-CAT", "MEMBRANE: IMPORT[FOOD] CATABOLISE[FOOD]"],
	["CAT-FOOD-TRA-MEM", "MEMBRANE: CATABOLISE[FOOD] EXPORT[FOOD]"],

	# §5.4's starting protein, and a lone membrane anchor doing nothing.
	["CAT-FOOD", "INTERNAL: CATABOLISE[FOOD]"],
	["MEM-CAT-FOOD", "MEMBRANE: CATABOLISE[FOOD]"],
]


func set_runner(r: Object) -> void:
	runner = r


## Build a protein by running its blocks through a real plasmid, so these cases exercise
## M02's transcription too rather than hand-assembling a ProteinDef.
func _resolve(spelling: String) -> ResolvedProtein:
	var result := PlasmidNotation.parse("P12-%s-TERM" % spelling)
	runner.check(result.ok(), "failed to parse '%s': %s" % [spelling, result.error])
	var proteins := result.plasmid.transcribe()[0].proteins
	runner.check_eq(proteins.size(), 1, "'%s' should transcribe to one protein" % spelling)
	return Adjacency.resolve(proteins[0])


func _describe(resolved: ResolvedProtein) -> String:
	var parts := PackedStringArray()
	for f in resolved.active_functions():
		var names := f.targets.map(func(t): return Block.Kind.keys()[t])
		parts.append("%s[%s]" % [ProteinFunction.Kind.keys()[f.kind], "+".join(names)])
	var body := "inert" if parts.is_empty() else " ".join(parts)
	return "%s: %s" % [ResolvedProtein.Compartment.keys()[resolved.compartment], body]


func test_every_prototype_one_arrangement_resolves_as_specified() -> void:
	for case in CASES:
		var spelling: String = case[0]
		runner.check_eq(_describe(_resolve(spelling)), case[1], "arrangement '%s'" % spelling)


func test_the_same_blocks_in_a_different_order_do_different_work() -> void:
	# The whole point of §5.3, stated as one assertion: MEM, TRA and FOOD import in one
	# order and export in another.
	runner.check_eq(_describe(_resolve("MEM-TRA-FOOD")), "MEMBRANE: IMPORT[FOOD]", "import order")
	runner.check_eq(_describe(_resolve("FOOD-TRA-MEM")), "MEMBRANE: EXPORT[FOOD]", "export order")


func test_a_cytoplasmic_transporter_says_why_it_is_doing_nothing() -> void:
	var resolved := _resolve("TRA-FOOD")
	runner.check(resolved.is_inert(), "a cytoplasmic transporter should be inert")
	runner.check_eq(resolved.functions.size(), 1, "the inert effector should still be reported")
	runner.check(
		resolved.functions[0].reason.contains("membrane-embedded"),
		"reason did not explain the membrane requirement: %s" % resolved.functions[0].reason
	)


func test_moving_one_target_both_ways_is_inert_rather_than_a_free_exchange() -> void:
	var resolved := _resolve("FOOD-TRA-MEM-FOOD")
	runner.check(resolved.is_inert(), "same-target exchange should move nothing")
	runner.check(
		not resolved.has_function(ProteinFunction.Kind.EXCHANGE),
		"food-for-food was resolved as a free exchange"
	)


func test_a_transporter_reaches_through_the_membrane_domain_it_sits_against() -> void:
	# Without reach-through, TRA's only neighbour here is MEM and the protein is inert —
	# and no arrangement could ever put targets on both sides, making exchange
	# unreachable. See the note at the top of adjacency.gd.
	var resolved := _resolve("TRA-MEM-FOOD")
	runner.check(not resolved.is_inert(), "transporter did not see past the membrane domain")
	runner.check(resolved.has_function(ProteinFunction.Kind.IMPORT), "expected an importer")


func test_membrane_domain_sets_the_compartment_and_the_boundary() -> void:
	var internal := _resolve("CAT-FOOD")
	runner.check_eq(
		internal.compartment, ResolvedProtein.Compartment.INTERNAL, "no membrane means internal"
	)
	runner.check_eq(internal.membrane_index, -1, "internal protein reported a boundary")

	var membrane := _resolve("CAT-FOOD-MEM-TRA")
	runner.check_eq(membrane.compartment, ResolvedProtein.Compartment.MEMBRANE, "compartment")
	runner.check_eq(membrane.membrane_index, 2, "boundary in the wrong place")


func test_the_first_membrane_domain_sets_the_boundary() -> void:
	var resolved := _resolve("MEM-TRA-FOOD-MEM")
	runner.check_eq(resolved.membrane_index, 0, "a later membrane domain moved the boundary")
	runner.check(resolved.has_function(ProteinFunction.Kind.IMPORT), "expected an importer")


func test_adjacency_does_not_cross_a_protein_boundary() -> void:
	# An RBS splits one transcript into two proteins. The enzyme ending the first must
	# not pick up the target starting the second — one gene's blocks changing another
	# gene's behaviour would make the plasmid unreadable.
	var result := PlasmidNotation.parse("P12-MEM-TRA-CAT-RBS-FOOD-CAT-TERM")
	runner.check(result.ok(), "setup failed: %s" % result.error)
	var proteins := result.plasmid.transcribe()[0].proteins
	runner.check_eq(proteins.size(), 2, "expected an operon of two proteins")

	var first := Adjacency.resolve(proteins[0])
	runner.check(first.is_inert(), "first protein reached across the RBS for a target")
