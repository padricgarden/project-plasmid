## F01-M02 — the plasmid text notation. Spec §4, §4.2.
var runner: Object


func set_runner(r: Object) -> void:
	runner = r


func _parse(text: String) -> Plasmid:
	var result := PlasmidNotation.parse(text)
	runner.check(result.ok(), "failed to parse '%s': %s" % [text, result.error])
	return result.plasmid


func test_round_trips_unchanged() -> void:
	for text in [
		"P12-CAT-FOOD-TERM",
		"P12-CAT-FOOD-TERM-P6-MEM-TRA-FOOD-TERM",
		"P4-CAT-FOOD-RBS-MEM-TRA-FOOD-TERM",
		"P2-MEM-TRA-FOOD",
	]:
		var plasmid := _parse(text)
		runner.check_eq(PlasmidNotation.serialise(plasmid), text, "round trip changed it")


func test_parses_kinds_in_order() -> void:
	var plasmid := _parse("P12-CAT-FOOD-TERM")
	runner.check_eq(plasmid.size(), 4, "wrong block count")
	runner.check_eq(plasmid.at(0).kind, Block.Kind.PROMOTER, "block 0")
	runner.check_eq(plasmid.at(1).kind, Block.Kind.CATABOLIC_ENZYME, "block 1")
	runner.check_eq(plasmid.at(2).kind, Block.Kind.FOOD, "block 2")
	runner.check_eq(plasmid.at(3).kind, Block.Kind.TERMINATOR, "block 3")


func test_promoter_period_survives_the_round_trip() -> void:
	for period in Balance.PROMOTER_PERIODS:
		var plasmid := _parse("P%d-CAT-FOOD-TERM" % period)
		runner.check_eq(plasmid.at(0).period, period, "period %d was lost" % period)


func test_tolerates_whitespace_and_lower_case() -> void:
	var plasmid := _parse("  p12 - cat - food - term  ")
	runner.check_eq(
		PlasmidNotation.serialise(plasmid),
		"P12-CAT-FOOD-TERM",
		"did not normalise to canonical form"
	)


func test_empty_text_is_an_empty_plasmid() -> void:
	var result := PlasmidNotation.parse("")
	runner.check(result.ok(), "empty text should parse, not error")
	runner.check_eq(result.plasmid.size(), 0, "empty text produced blocks")


func test_unknown_token_is_rejected_with_the_token_named() -> void:
	var result := PlasmidNotation.parse("P12-CAT-SPLINE-TERM")
	runner.check(not result.ok(), "an unknown block token was accepted")
	runner.check(
		result.error.contains("SPLINE"), "error did not name the offending token: %s" % result.error
	)
	runner.check_eq(result.plasmid, null, "a failed parse returned a half-built plasmid")


func test_promoter_period_outside_the_closed_family_is_rejected() -> void:
	# 8 is the tempting one: it looks like a reasonable tier and it is not a divisor of
	# 12, so it would give a rack of 4.8 : 3.2 against a P12 gene and never settle (§3.1).
	var result := PlasmidNotation.parse("P8-CAT-FOOD-TERM")
	runner.check(not result.ok(), "a period outside PROMOTER_PERIODS was accepted")
	runner.check(result.error.contains("8"), "error did not name the period: %s" % result.error)


func test_malformed_promoter_token_is_rejected() -> void:
	var result := PlasmidNotation.parse("PX-CAT-FOOD-TERM")
	runner.check(not result.ok(), "a malformed promoter token was accepted")
