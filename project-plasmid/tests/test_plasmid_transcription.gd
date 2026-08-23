## F01-M02 — transcription, readthrough, wrapping and operons. Spec §4.
var runner: Object


func set_runner(r: Object) -> void:
	runner = r


func _plasmid(text: String) -> Plasmid:
	var result := PlasmidNotation.parse(text)
	runner.check(result.ok(), "failed to parse '%s': %s" % [text, result.error])
	return result.plasmid


func _kind_names(protein: ProteinDef) -> Array:
	return protein.blocks.map(func(b): return Block.Kind.keys()[b.kind])


func test_a_terminated_gene_yields_one_protein() -> void:
	# §5.4's starting protein: Catabolic Enzyme + Food Domain.
	var transcripts := _plasmid("P12-CAT-FOOD-TERM").transcribe()

	runner.check_eq(transcripts.size(), 1, "expected one transcript")
	runner.check_eq(transcripts[0].period, 12, "transcript did not take the promoter's period")
	runner.check_eq(transcripts[0].proteins.size(), 1, "expected one protein")
	runner.check_eq(
		_kind_names(transcripts[0].proteins[0]),
		["CATABOLIC_ENZYME", "FOOD"],
		"structural blocks leaked into the protein"
	)


func test_terminator_stops_transcription_before_the_next_gene() -> void:
	var transcripts := _plasmid("P12-CAT-FOOD-TERM-P6-MEM-TRA-FOOD-TERM").transcribe()

	runner.check_eq(transcripts.size(), 2, "expected one transcript per promoter")
	runner.check_eq(
		_kind_names(transcripts[0].proteins[0]),
		["CATABOLIC_ENZYME", "FOOD"],
		"the first promoter read past its terminator"
	)


func test_an_unterminated_gene_reads_through_and_wraps_around_the_ring() -> void:
	# The last gene has no terminator, so it reads into the first — §4's whole reason
	# for the ring being a ring.
	var transcripts := _plasmid("P12-CAT-FOOD-TERM-P6-MEM-TRA-FOOD").transcribe()
	var from_second: Transcript = transcripts[1]

	runner.check_eq(from_second.promoter_index, 4, "second transcript started in the wrong place")
	runner.check_eq(from_second.proteins.size(), 1, "readthrough should fuse into one protein")
	runner.check_eq(
		_kind_names(from_second.proteins[0]),
		["MEMBRANE_DOMAIN", "TRANSPORTER_DOMAIN", "FOOD", "CATABOLIC_ENZYME", "FOOD"],
		"wrapped transcript did not fuse both genes"
	)


func test_a_promoter_met_mid_transcript_is_read_through_not_stopped_at() -> void:
	# "One promoter drives two genes" (§4). The downstream promoter is skipped as
	# content but still fires its own transcript — readthrough adds one, replaces none.
	var transcripts := _plasmid("P12-CAT-FOOD-P6-MEM-TRA").transcribe()

	runner.check_eq(transcripts.size(), 2, "the downstream promoter stopped firing")
	runner.check_eq(
		_kind_names(transcripts[0].proteins[0]),
		["CATABOLIC_ENZYME", "FOOD", "MEMBRANE_DOMAIN", "TRANSPORTER_DOMAIN"],
		"transcription stopped at the downstream promoter instead of reading through"
	)


func test_rbs_splits_one_transcript_into_separate_proteins() -> void:
	# The operon: one promoter, two proteins, sharing a clock and sharing regulation.
	var transcripts := _plasmid("P12-CAT-FOOD-RBS-MEM-TRA-FOOD-TERM").transcribe()
	var proteins := transcripts[0].proteins

	runner.check_eq(proteins.size(), 2, "RBS did not start a second protein")
	runner.check_eq(_kind_names(proteins[0]), ["CATABOLIC_ENZYME", "FOOD"], "first protein")
	runner.check_eq(
		_kind_names(proteins[1]),
		["MEMBRANE_DOMAIN", "TRANSPORTER_DOMAIN", "FOOD"],
		"second protein"
	)


func test_a_leading_rbs_does_not_produce_an_empty_protein() -> void:
	var transcripts := _plasmid("P12-RBS-CAT-FOOD-TERM").transcribe()
	runner.check_eq(transcripts[0].proteins.size(), 1, "a leading RBS produced an empty protein")


func test_a_promoter_reading_straight_into_a_terminator_produces_nothing() -> void:
	var transcripts := _plasmid("P12-TERM-P6-CAT-FOOD-TERM").transcribe()
	runner.check_eq(transcripts[0].proteins.size(), 0, "expected no proteins")
	runner.check_eq(transcripts[1].proteins.size(), 1, "the second gene should be unaffected")


func test_a_ring_with_no_terminator_transcribes_itself_once_and_stops() -> void:
	# The guard that stops readthrough looping forever: reading ends on returning to the
	# promoter it started from.
	var plasmid := _plasmid("P12-CAT-FOOD-P6-MEM-TRA")
	var transcripts := plasmid.transcribe()

	runner.check_eq(transcripts.size(), 2, "expected one transcript per promoter")
	for transcript in transcripts:
		runner.check_eq(
			transcript.translated_length(),
			4,
			"each promoter should read the whole ring once, minus both promoters"
		)


func test_transcripts_come_back_in_ring_order() -> void:
	var transcripts := _plasmid("P12-CAT-FOOD-TERM-P6-MEM-TRA-FOOD-TERM").transcribe()
	runner.check_eq(transcripts[0].promoter_index, 0, "first transcript out of order")
	runner.check_eq(transcripts[1].promoter_index, 4, "second transcript out of order")


func test_ring_indexing_wraps_in_both_directions() -> void:
	var plasmid := _plasmid("P12-CAT-FOOD-TERM")
	runner.check_eq(plasmid.at(4).kind, Block.Kind.PROMOTER, "forward wrap")
	runner.check_eq(plasmid.at(-1).kind, Block.Kind.TERMINATOR, "backward wrap")


func test_clone_is_independent_of_its_original() -> void:
	var plasmid := _plasmid("P12-CAT-FOOD-TERM")
	var copy := plasmid.clone()

	copy.blocks[1].kind = Block.Kind.MEMBRANE_DOMAIN
	runner.check_eq(
		plasmid.at(1).kind, Block.Kind.CATABOLIC_ENZYME, "clone shares blocks with the original"
	)
