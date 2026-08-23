## F01-M04 — compiling a plasmid into priced, timed expression. Spec §2.2, §3.5, §4.
var runner: Object


func set_runner(r: Object) -> void:
	runner = r


func _units(notation: String) -> Array[ExpressionUnit]:
	var result := PlasmidNotation.parse(notation)
	runner.check(result.ok(), "failed to parse '%s': %s" % [notation, result.error])
	return GeneExpression.compile(result.plasmid)


func _protein_of(length: int) -> ProteinDef:
	var blocks: Array[Block] = []
	for i in range(length):
		blocks.append(Block.new(Block.Kind.CATABOLIC_ENZYME))
	return ProteinDef.new(blocks)


func test_synthesis_cost_is_one_per_three_blocks_rounded_up() -> void:
	# §2.2's own worked examples: a 3-block protein costs 1, a 7-block protein costs 3.
	for case in [[1, 1], [2, 1], [3, 1], [4, 2], [6, 2], [7, 3], [9, 3], [10, 4]]:
		runner.check_eq(
			GeneExpression.synthesis_cost(_protein_of(case[0])),
			case[1],
			"%d blocks should cost %d" % [case[0], case[1]]
		)


func test_build_time_scales_with_length_and_is_never_zero() -> void:
	runner.check_eq(GeneExpression.build_ticks(_protein_of(1)), 1, "one block")
	runner.check_eq(GeneExpression.build_ticks(_protein_of(5)), 5, "five blocks")
	runner.check(GeneExpression.build_ticks(ProteinDef.new()) >= 1, "build time must not be zero")


func test_each_promoter_compiles_to_one_unit_carrying_its_period() -> void:
	var units := _units("P4-CAT-FOOD-TERM-P12-CAT-FOOD-TERM")

	runner.check_eq(units.size(), 2, "expected one unit per promoter")
	runner.check_eq(units[0].period, 4, "first period")
	runner.check_eq(units[1].period, 12, "second period")
	runner.check_eq(units[1].promoter_index, 4, "second promoter ring position")


func test_an_operon_is_priced_per_protein_not_per_transcript() -> void:
	# Two 2-block proteins from one promoter cost 1 each. The identical fused 4-block
	# transcript costs 2 as well, so an RBS is free of any pricing penalty (§4).
	var operon := _units("P12-CAT-FOOD-RBS-CAT-FOOD-TERM")[0]
	runner.check_eq(operon.products.size(), 2, "expected two products")
	runner.check_eq(operon.total_synthesis_cost(), 2, "operon cost")

	var fused := _units("P12-CAT-FOOD-CAT-FOOD-TERM")[0]
	runner.check_eq(fused.products.size(), 1, "expected one fused product")
	runner.check_eq(fused.total_synthesis_cost(), 2, "fused cost should match the operon")


func test_a_fused_transcript_is_slower_to_build_than_the_operon_that_splits_it() -> void:
	# §4's stated cost for omitting a terminator: one long transcript, more build ticks.
	var operon := _units("P12-CAT-FOOD-RBS-CAT-FOOD-TERM")[0]
	var fused := _units("P12-CAT-FOOD-CAT-FOOD-TERM")[0]

	runner.check_eq(operon.products[0].build_ticks, 2, "each operon member builds in 2")
	runner.check_eq(fused.products[0].build_ticks, 4, "the fused protein should take 4")


func test_products_carry_their_resolved_function_and_source_promoter() -> void:
	var unit := _units("P6-MEM-TRA-FOOD-TERM")[0]
	var product := unit.products[0]

	runner.check_eq(product.source_promoter_index, 0, "source promoter")
	runner.check_eq(
		product.resolved.compartment, ResolvedProtein.Compartment.MEMBRANE, "compartment"
	)
	runner.check(
		product.resolved.has_function(ProteinFunction.Kind.IMPORT), "should be an importer"
	)


func test_a_promoter_reading_into_a_terminator_is_silent_and_free() -> void:
	var unit := _units("P12-TERM-P6-CAT-FOOD-TERM")[0]
	runner.check(unit.is_silent(), "expected a silent unit")
	runner.check_eq(unit.total_synthesis_cost(), 0, "a silent promoter should cost nothing")


func test_upkeep_per_tick_reflects_rate_times_cost() -> void:
	# §3.2: churn is the rent on slot share. A 2-block protein on a 4-tick promoter is
	# 1 metabolite every 4 ticks, forever — 0.25/tick, scaled here by 100 to stay integer.
	var fast := _units("P4-CAT-FOOD-TERM")[0]
	runner.check_eq(fast.upkeep_per_tick_scaled(100), 25, "0.25/tick expected")

	var slow := _units("P12-CAT-FOOD-TERM")[0]
	runner.check_eq(slow.upkeep_per_tick_scaled(100), 8, "0.083/tick expected, truncated")
