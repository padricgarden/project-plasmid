## F02-M03 and F02-M04 — the plain-language readout, and committing. Spec §4.1, §5.3,
## §7.0, §9.
var runner: Object

var _opened: Array = []


func set_runner(r: Object) -> void:
	runner = r


func after_all() -> void:
	for editor in _opened:
		if is_instance_valid(editor):
			editor.free()
	_opened.clear()


func _editor(notation: String = PlasmidEditor.STARTING_NOTATION) -> PlasmidEditor:
	var editor: PlasmidEditor = load("res://src/ui/plasmid_editor.tscn").instantiate()
	runner.root.add_child(editor)
	_opened.append(editor)
	if notation != PlasmidEditor.STARTING_NOTATION:
		editor.set_draft(PlasmidDraft.from_notation(notation))
	return editor


func _describe(notation: String, env: EnvironmentDef = null) -> String:
	var draft := PlasmidDraft.from_notation(notation)
	var resolved := Adjacency.resolve(draft.protein_containing(1))
	return "\n".join(ProteinDescription.lines(resolved, env))


# ------------------------------------------------------ M03: telling import from export

func test_the_readout_says_import_or_export_in_words() -> void:
	# The milestone's done-when: a player can tell which way a transporter moves things
	# without running the sim. Same three blocks, one order apart.
	var importing := _describe("P12-MEM-TRA-FOOD-TERM")
	runner.check(
		importing.to_lower().contains("pulls food in"),
		"an importer is not described as importing: %s" % importing
	)
	runner.check(not importing.to_lower().contains("pushes"), "importer described as exporting")

	var exporting := _describe("P12-FOOD-TRA-MEM-TERM")
	runner.check(
		exporting.to_lower().contains("pushes food out"),
		"an exporter is not described as exporting: %s" % exporting
	)


func test_the_readout_names_the_transport_tax() -> void:
	# §2.2's workhorse tax should be visible before it is paid.
	var text := _describe("P12-MEM-TRA-FOOD-TERM")
	runner.check(
		text.contains(str(Balance.TRANSPORT_COST)), "the transport cost is not shown: %s" % text
	)


func test_a_dead_transporter_says_why_and_says_it_still_costs() -> void:
	# §3.2: an inert protein still holds a slot and still pays upkeep, which is what makes
	# it the expensive mistake rather than a harmless one.
	var text := _describe("P12-TRA-FOOD-TERM")
	runner.check(text.to_lower().contains("does nothing"), "not called out as dead: %s" % text)
	runner.check(
		text.to_lower().contains("membrane-embedded"), "no reason given: %s" % text
	)
	runner.check(text.to_lower().contains("slot"), "does not mention the cost: %s" % text)


func test_digestion_reports_the_environment_yield() -> void:
	var abundant := _describe("P12-CAT-FOOD-TERM", EnvironmentDef.abundant())
	runner.check(
		abundant.contains(str(EnvironmentDef.abundant().food_yield)),
		"the yield is not shown: %s" % abundant
	)


func test_an_outside_enzyme_is_described_as_denial_not_as_food() -> void:
	# §8's starving elite falls out of topology; the readout has to not call it feeding.
	var text := _describe("P12-MEM-TRA-FOOD-CAT-TERM")
	runner.check(
		text.to_lower().contains("nobody gets them") or text.to_lower().contains("starves"),
		"an extracellular enzyme is not described as denial: %s" % text
	)


func test_the_readout_says_which_side_of_the_membrane_the_protein_is_on() -> void:
	runner.check(
		_describe("P12-MEM-TRA-FOOD-TERM").to_lower().contains("membrane"), "membrane protein"
	)
	runner.check(
		_describe("P12-CAT-FOOD-TERM").to_lower().contains("cytoplasm"), "internal protein"
	)


func test_every_reachable_arrangement_gets_a_sentence() -> void:
	# No arrangement should leave the panel blank; a player who selects a block and is
	# told nothing learns nothing.
	for notation in [
		"P12-CAT-FOOD-TERM", "P12-FOOD-CAT-TERM", "P12-TRA-FOOD-TERM",
		"P12-MEM-TRA-FOOD-TERM", "P12-TRA-MEM-FOOD-TERM", "P12-FOOD-TRA-MEM-TERM",
		"P12-FOOD-MEM-TRA-TERM", "P12-MEM-TRA-FOOD-CAT-TERM", "P12-CAT-FOOD-TRA-MEM-TERM",
		"P12-MEM-TERM", "P12-FOOD-TERM",
	]:
		var text := _describe(notation, EnvironmentDef.knife_edge())
		runner.check(text.strip_edges().length() > 20, "%s produced no description" % notation)


func test_the_editor_shows_the_description_for_the_selected_block() -> void:
	var editor := _editor("P12-MEM-TRA-FOOD-TERM")
	editor.select_block(2)
	runner.check(
		editor._function_label.text.to_lower().contains("pulls food in"),
		"the panel does not describe the selected protein: '%s'" % editor._function_label.text
	)


func test_punctuation_is_described_as_punctuation() -> void:
	var editor := _editor("P12-CAT-FOOD-TERM")
	editor.select_block(3)
	runner.check(
		editor._function_label.text.to_lower().contains("punctuation"),
		"a terminator was not explained: '%s'" % editor._function_label.text
	)


func test_the_palette_groups_blocks_by_the_job_they_do() -> void:
	var groups := BlockStyle.palette_groups()
	runner.check(groups.size() >= 3, "the palette is not grouped at all")

	var seen := {}
	for group in groups:
		runner.check(not str(group["name"]).is_empty(), "a palette group has no heading")
		for block in group["blocks"]:
			seen[block.kind] = true
	for kind in Block.Kind.values():
		runner.check(
			seen.has(kind), "%s fell out of the grouped palette" % Block.Kind.keys()[kind]
		)


# --------------------------------------------------------------------- M04: committing

func test_the_budget_line_shows_blocks_and_the_burden_adjusted_target() -> void:
	var editor := _editor("P12-CAT-FOOD-TERM")
	runner.check(editor._budget_label.text.contains("4 blocks"), editor._budget_label.text)
	runner.check(
		editor._budget_label.text.contains(str(Burden.growth_target(4))),
		"the §4.1 target is missing: '%s'" % editor._budget_label.text
	)


func test_adding_blocks_raises_the_target_on_screen() -> void:
	var editor := _editor("P12-CAT-FOOD-TERM")
	var before := editor._budget_label.text

	for i in range(6):
		editor._on_palette_pressed(Block.new(Block.Kind.CATABOLIC_ENZYME))

	runner.check(editor._budget_label.text != before, "the budget line did not follow the edit")
	runner.check(
		editor._budget_label.text.contains(str(Burden.growth_target(editor.draft.size()))),
		"the target does not match the block count: '%s'" % editor._budget_label.text
	)


func test_committing_locks_the_plasmid() -> void:
	# §7.0: the build phase is the entire decision, so committing is a real door.
	var editor := _editor()
	var before := editor.draft.notation()

	editor._on_commit_pressed()
	runner.check(editor.is_committed, "the editor did not enter a committed state")
	runner.check(not editor._ring.editable, "the ring is still draggable after committing")

	editor._on_palette_pressed(Block.new(Block.Kind.FOOD))
	editor.select_block(1)
	editor._on_remove_pressed()

	runner.check_eq(editor.draft.notation(), before, "a committed plasmid was edited")


func test_committing_announces_the_plasmid_it_committed() -> void:
	# F04 will drive its watch phase from this signal.
	var editor := _editor()
	var seen := {"notation": "", "environment": ""}
	editor.committed.connect(
		func(plasmid: Plasmid, env: EnvironmentDef) -> void:
			seen["notation"] = PlasmidNotation.serialise(plasmid)
			seen["environment"] = env.display_name
	)

	editor._on_commit_pressed()
	runner.check_eq(seen["notation"], editor.draft.notation(), "committed a different plasmid")
	runner.check_eq(seen["environment"], editor.environment.display_name, "wrong environment")


func test_the_committed_plasmid_is_a_snapshot_not_a_live_reference() -> void:
	# Editing after going back must not reach into the battle that already ran.
	var editor := _editor()
	var captured: Array[Plasmid] = []
	editor.committed.connect(func(plasmid: Plasmid, _e: EnvironmentDef) -> void:
		captured.append(plasmid))

	editor._on_commit_pressed()
	var committed_notation := PlasmidNotation.serialise(captured[0])

	editor._on_edit_pressed()
	editor._on_palette_pressed(Block.new(Block.Kind.FOOD))

	runner.check_eq(
		PlasmidNotation.serialise(captured[0]),
		committed_notation,
		"editing after the battle changed the plasmid the battle ran"
	)


func test_an_unviable_plasmid_cannot_be_committed() -> void:
	var editor := _editor("P12-TRA-FOOD-TERM")
	runner.check(editor._commit_button.disabled, "an all-inert plasmid offered a commit button")

	editor._on_commit_pressed()
	runner.check(not editor.is_committed, "an unviable plasmid was committed anyway")


func test_committing_hands_off_rather_than_resolving_the_battle_itself() -> void:
	# F04 owns the watch phase. Two places resolving battles would be two places to keep
	# agreeing about what a battle is, so the editor announces and stops.
	var editor := _editor()
	editor._on_commit_pressed()
	runner.check(
		editor._outcome_label.text.to_lower().contains("watching"),
		"the editor should hand off, not report a result: '%s'" % editor._outcome_label.text
	)


func test_the_environment_choice_is_handed_to_the_battle() -> void:
	# §7.4's densities, reachable from the screen and carried through to what runs.
	var editor := _editor()
	var handed: Array[EnvironmentDef] = []
	editor.committed.connect(func(_p: Plasmid, env: EnvironmentDef) -> void: handed.append(env))

	editor._on_environment_selected(2)
	editor._on_commit_pressed()
	runner.check_eq(handed[0].display_name, "Scarce", "the chosen environment was not passed on")


func test_going_back_to_editing_unlocks_the_ring() -> void:
	var editor := _editor()
	editor._on_commit_pressed()
	editor._on_edit_pressed()

	runner.check(not editor.is_committed, "still committed after going back")
	runner.check(editor._ring.editable, "the ring is still locked")
	runner.check(editor._outcome_label.text.is_empty(), "a stale outcome is still on screen")

	var before := editor.draft.size()
	editor._on_palette_pressed(Block.new(Block.Kind.FOOD))
	runner.check_eq(editor.draft.size(), before + 1, "editing did not resume")
