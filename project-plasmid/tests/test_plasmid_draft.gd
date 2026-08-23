## F02-M01 — the build phase's editing model. Spec §4, §5.4, §7.0.
var runner: Object


func set_runner(r: Object) -> void:
	runner = r


func _block(kind: Block.Kind, period: int = 0) -> Block:
	return Block.new(kind, period)


# ------------------------------------------------------------------------- placement

func test_a_starting_protein_can_be_built_block_by_block() -> void:
	# §5.4's starting protein, assembled the way a player would: one block at a time,
	# with nothing hand-edited. The milestone's whole acceptance condition.
	var draft := PlasmidDraft.new()
	draft.append(_block(Block.Kind.PROMOTER, 12))
	draft.append(_block(Block.Kind.CATABOLIC_ENZYME))
	draft.append(_block(Block.Kind.FOOD))
	draft.append(_block(Block.Kind.TERMINATOR))

	runner.check_eq(draft.notation(), "P12-CAT-FOOD-TERM", "notation of the assembled draft")
	runner.check(draft.is_viable(), "a working starting protein reported problems")


func test_what_the_editor_builds_runs_in_the_simulation_unchanged() -> void:
	# The handoff M04 will formalise: whatever the ring holds is what the sim runs.
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-TERM-P12-TRA-MEM-FOOD-TERM")
	var battle := Battle.new(draft.to_plasmid(), EnvironmentDef.knife_edge())
	var outcome := battle.run()

	runner.check(outcome.divided(), "the editor's plasmid failed to run a battle")


func test_inserting_places_the_block_before_the_given_index() -> void:
	var draft := PlasmidDraft.from_notation("P12-CAT-TERM")
	draft.insert_at(2, _block(Block.Kind.FOOD))
	runner.check_eq(draft.notation(), "P12-CAT-FOOD-TERM", "insert before index 2")


func test_inserting_past_the_end_appends() -> void:
	# Dropping onto empty ring space should mean "put it at the end", not fail.
	var draft := PlasmidDraft.from_notation("P12-CAT")
	draft.insert_at(99, _block(Block.Kind.FOOD))
	runner.check_eq(draft.notation(), "P12-CAT-FOOD", "an out-of-range insert should append")


func test_removing_returns_the_block_and_closes_the_gap() -> void:
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-TERM")
	var removed := draft.remove_at(1)

	runner.check_eq(removed.kind, Block.Kind.CATABOLIC_ENZYME, "returned the wrong block")
	runner.check_eq(draft.notation(), "P12-FOOD-TERM", "gap was not closed")


func test_removing_out_of_range_does_nothing() -> void:
	var draft := PlasmidDraft.from_notation("P12-CAT")
	runner.check_eq(draft.remove_at(7), null, "an out-of-range remove returned something")
	runner.check_eq(draft.notation(), "P12-CAT", "an out-of-range remove changed the plasmid")


func test_moving_a_block_one_place_right_actually_moves_it() -> void:
	# The off-by-one that makes a drag look ignored: if the target index is read against
	# the list *before* the block leaves it, a one-place move puts it back where it was.
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-TERM")
	draft.move(1, 2)
	runner.check_eq(draft.notation(), "P12-FOOD-CAT-TERM", "a one-place move did nothing")


func test_moving_a_block_across_the_ring() -> void:
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-TERM")
	draft.move(3, 0)
	runner.check_eq(draft.notation(), "TERM-P12-CAT-FOOD", "move to the front")


func test_moving_onto_itself_is_a_no_op() -> void:
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-TERM")
	draft.move(2, 2)
	runner.check_eq(draft.notation(), "P12-CAT-FOOD-TERM", "self-move changed the plasmid")


func test_reordering_changes_what_the_protein_does() -> void:
	# §5.3 seen from the editor's side: the same four blocks, one drag apart, import
	# versus export. This is the thing the build phase exists to let a player discover.
	var draft := PlasmidDraft.from_notation("P12-MEM-TRA-FOOD-TERM")
	var importing := draft.resolved_proteins()[0]
	runner.check(
		importing.has_function(ProteinFunction.Kind.IMPORT), "setup: expected an importer"
	)

	draft.move(3, 1)  # FOOD to the cytoplasmic side of the membrane
	var exporting := draft.resolved_proteins()[0]
	runner.check_eq(draft.notation(), "P12-FOOD-MEM-TRA-TERM", "unexpected arrangement")
	runner.check(
		exporting.has_function(ProteinFunction.Kind.EXPORT),
		"dragging the target across the membrane did not flip the transporter"
	)


# ------------------------------------------------------------------------ change signal

func test_every_edit_announces_itself() -> void:
	# The scene layer redraws on this signal, so an edit that stays silent is an edit
	# the player cannot see.
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-TERM")
	var counter := {"n": 0}
	draft.changed.connect(func() -> void: counter["n"] += 1)

	draft.append(_block(Block.Kind.RBS))
	draft.insert_at(0, _block(Block.Kind.TERMINATOR))
	draft.remove_at(0)
	draft.move(0, 1)

	runner.check_eq(counter["n"], 4, "not every edit emitted changed")


# ----------------------------------------------------------------------------- problems

func test_an_empty_plasmid_says_so() -> void:
	var draft := PlasmidDraft.new()
	runner.check(not draft.is_viable(), "an empty plasmid reported itself viable")
	runner.check(draft.problems()[0].contains("empty"), "unhelpful message")


func test_a_plasmid_with_no_promoter_is_flagged() -> void:
	var draft := PlasmidDraft.from_notation("CAT-FOOD-TERM")
	runner.check(not draft.is_viable(), "a promoterless plasmid reported itself viable")
	runner.check(
		str(draft.problems()).contains("promoter"), "the problem did not mention the promoter"
	)


func test_a_plasmid_that_only_expresses_inert_proteins_is_flagged() -> void:
	# A cytoplasmic transporter occupies a slot and pays upkeep forever while moving
	# nothing (§3.2, §5.3). The build phase should say so before the battle does.
	var draft := PlasmidDraft.from_notation("P12-TRA-FOOD-TERM")
	runner.check(not draft.is_viable(), "an all-inert plasmid reported itself viable")
	runner.check(str(draft.problems()).contains("inert"), "the problem did not mention inertness")


func test_a_working_plasmid_has_no_problems() -> void:
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-TERM-P12-TRA-MEM-FOOD-TERM")
	runner.check_eq(
		draft.problems().size(), 0, "a working plasmid reported: %s" % str(draft.problems())
	)


# ------------------------------------------------------------------------------ palette

func test_the_palette_offers_every_block_the_grammar_has() -> void:
	var kinds := {}
	for block in BlockStyle.palette():
		kinds[block.kind] = true

	for kind in Block.Kind.values():
		runner.check(
			kinds.has(kind),
			"the palette cannot place %s, so it is unreachable" % Block.Kind.keys()[kind]
		)


func test_the_palette_offers_every_promoter_tier() -> void:
	var periods := []
	for block in BlockStyle.palette():
		if block.kind == Block.Kind.PROMOTER:
			periods.append(block.period)
	runner.check_eq(periods, Balance.PROMOTER_PERIODS, "palette promoter tiers")


func test_every_block_kind_has_a_style_and_a_label() -> void:
	for kind in Block.Kind.values():
		var style := BlockStyle.of(kind)
		runner.check(
			style != BlockStyle.UNKNOWN,
			"%s has no style, so it would draw as a magenta '?'" % Block.Kind.keys()[kind]
		)
		runner.check(not str(style["blurb"]).is_empty(), "%s has no blurb" % Block.Kind.keys()[kind])


func test_a_promoter_shows_its_tier_in_its_label() -> void:
	# §3.1's whole decision is which tier you bought, so two promoters must not look alike.
	runner.check_eq(BlockStyle.label_for(Block.new(Block.Kind.PROMOTER, 4)), "P4", "label")
	runner.check_eq(BlockStyle.label_for(Block.new(Block.Kind.PROMOTER, 12)), "P12", "label")
