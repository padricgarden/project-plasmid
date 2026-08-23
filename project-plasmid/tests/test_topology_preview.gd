## F02-M02 — the topology preview. Spec §5.1, §5.3, §10.
##
## §10 names this widget as the single mitigation for "unified transporter illegible to
## new players", immediately followed by "do not split the block". So these tests are
## really about one question: can a player see which way a transporter moves things, and
## see when it moves nothing at all?
var runner: Object

var _opened: Array = []


func set_runner(r: Object) -> void:
	runner = r


func after_all() -> void:
	for editor in _opened:
		if is_instance_valid(editor):
			editor.free()
	_opened.clear()


func _editor(notation: String) -> PlasmidEditor:
	var scene: PackedScene = load("res://src/ui/plasmid_editor.tscn")
	var editor: PlasmidEditor = scene.instantiate()
	runner.root.add_child(editor)
	_opened.append(editor)
	editor.draft = PlasmidDraft.from_notation(notation)
	editor._ring.bind(editor.draft)
	return editor


## Select a ring position and read back what the preview would draw.
func _preview_of(editor: PlasmidEditor, ring_index: int) -> TopologyPreview:
	editor._ring.select(ring_index)
	editor._refresh()
	return editor._topology


# --------------------------------------------------- which protein a block belongs to

func test_a_domain_block_maps_to_the_protein_it_is_translated_into() -> void:
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-TERM-P12-MEM-TRA-FOOD-TERM")

	var first := draft.protein_containing(1)
	runner.check(first != null, "the enzyme belongs to no protein")
	runner.check_eq(first.kinds(), [Block.Kind.CATABOLIC_ENZYME, Block.Kind.FOOD], "first gene")

	var second := draft.protein_containing(5)
	runner.check(second != null, "the membrane domain belongs to no protein")
	runner.check_eq(
		second.kinds(),
		[Block.Kind.MEMBRANE_DOMAIN, Block.Kind.TRANSPORTER_DOMAIN, Block.Kind.FOOD],
		"second gene"
	)


func test_selecting_a_promoter_shows_the_gene_it_drives() -> void:
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-TERM")
	var protein := draft.protein_containing(0)
	runner.check(protein != null, "selecting a promoter showed nothing")
	runner.check_eq(protein.kinds(), [Block.Kind.CATABOLIC_ENZYME, Block.Kind.FOOD], "gene")


func test_punctuation_belongs_to_no_protein() -> void:
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-TERM")
	runner.check_eq(draft.protein_containing(3), null, "a terminator claimed a protein")


func test_readthrough_puts_one_block_in_two_proteins() -> void:
	# §4: an unterminated gene is transcribed by its own promoter and by the upstream
	# one, so its blocks genuinely belong to two proteins. The editor should be able to
	# say so rather than silently picking one.
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-P6-MEM-TRA")
	runner.check_eq(
		draft.proteins_containing(4).size(), 2, "readthrough block should be in two proteins"
	)


# ------------------------------------------------------------- the milestone's question

func test_moving_the_target_across_the_membrane_flips_the_arrow() -> void:
	# The done-when, stated as one test. The same four blocks, one drag apart.
	var editor := _editor("P12-MEM-TRA-FOOD-TERM")

	var importing := _preview_of(editor, 2)
	runner.check(
		importing._resolved.has_function(ProteinFunction.Kind.IMPORT),
		"the preview does not show an importer before the drag"
	)

	editor.draft.move(3, 1)  # FOOD to the cytoplasmic side of the membrane
	var exporting := _preview_of(editor, 3)
	runner.check_eq(editor.draft.notation(), "P12-FOOD-MEM-TRA-TERM", "unexpected arrangement")
	runner.check(
		exporting._resolved.has_function(ProteinFunction.Kind.EXPORT),
		"the preview still shows an importer after moving the target across the membrane"
	)


func test_a_cytoplasmic_transporter_is_shown_as_doing_nothing() -> void:
	# The other half of the done-when. §5.3 rule 3 is the constraint that makes topology
	# matter at all, so a transporter with no membrane must read as dead, not as fine.
	var editor := _editor("P12-TRA-FOOD-TERM")
	var preview := _preview_of(editor, 1)

	runner.check(preview._resolved.is_inert(), "a cytoplasmic transporter resolved as working")
	runner.check_eq(preview._resolved.membrane_index, -1, "there should be no membrane to draw")

	var inert_reasons := PackedStringArray()
	for function in preview._resolved.functions:
		if function.kind == ProteinFunction.Kind.INERT:
			inert_reasons.append(function.reason)
	runner.check(
		str(inert_reasons).contains("membrane-embedded"),
		"the preview has no reason to show the player: %s" % str(inert_reasons)
	)


# ----------------------------------------------------------------- sides of the membrane

func test_blocks_are_placed_on_the_side_the_sim_thinks_they_are_on() -> void:
	# The preview shades by the same rule the sim eats by, so an enzyme drawn outside is
	# an enzyme that really does eat from the medium (§5.1, §8).
	var draft := PlasmidDraft.from_notation("P12-CAT-FOOD-MEM-TRA-FOOD-TERM")
	var resolved := Adjacency.resolve(draft.protein_containing(1))

	runner.check_eq(resolved.membrane_index, 2, "membrane in the wrong place")
	runner.check(not resolved.is_outside(0), "the enzyme should be inside")
	runner.check(not resolved.is_outside(1), "its food target should be inside")
	runner.check(resolved.is_outside(3), "the transporter should be outside")
	runner.check(resolved.is_outside(4), "the outer food target should be outside")


func test_a_protein_with_no_membrane_is_entirely_inside() -> void:
	var resolved := Adjacency.resolve(
		PlasmidDraft.from_notation("P12-CAT-FOOD-TERM").protein_containing(1)
	)
	for i in range(2):
		runner.check(not resolved.is_outside(i), "block %d should be inside" % i)


# ------------------------------------------------------------------- the widget itself

func test_the_preview_follows_the_selection() -> void:
	var editor := _editor("P12-CAT-FOOD-TERM-P12-MEM-TRA-FOOD-TERM")

	var first := _preview_of(editor, 1)
	runner.check_eq(first._protein.length(), 2, "first gene has two domains")

	var second := _preview_of(editor, 5)
	runner.check_eq(second._protein.length(), 3, "second gene has three domains")


func test_the_preview_says_so_when_there_is_nothing_to_show() -> void:
	var editor := _editor("P12-CAT-FOOD-TERM")

	var punctuation := _preview_of(editor, 3)
	runner.check_eq(punctuation._protein, null, "a terminator produced a protein to draw")
	runner.check(
		punctuation._empty_message.contains("punctuation"),
		"unhelpful message: '%s'" % punctuation._empty_message
	)

	editor._ring.select(-1)
	editor._refresh()
	runner.check(
		editor._topology._empty_message.contains("Select"),
		"no prompt when nothing is selected: '%s'" % editor._topology._empty_message
	)


func test_the_preview_mentions_readthrough_when_a_block_is_shared() -> void:
	var editor := _editor("P12-CAT-FOOD-P6-MEM-TRA")
	var preview := _preview_of(editor, 4)
	runner.check(
		preview._note.contains("reads through"),
		"shared blocks were not explained: '%s'" % preview._note
	)


func test_the_preview_never_contradicts_the_simulation() -> void:
	# The preview resolves through Adjacency, the same call the sim compiles with, so the
	# arrow a player sees is the behaviour they will get. Checked across every
	# arrangement the grammar can reach with a membrane.
	for notation in [
		"P12-MEM-TRA-FOOD-TERM",
		"P12-TRA-MEM-FOOD-TERM",
		"P12-FOOD-TRA-MEM-TERM",
		"P12-FOOD-MEM-TRA-TERM",
		"P12-MEM-TRA-FOOD-CAT-TERM",
		"P12-CAT-FOOD-TRA-MEM-TERM",
	]:
		var draft := PlasmidDraft.from_notation(notation)
		var protein := draft.protein_containing(1)
		var from_editor := Adjacency.resolve(protein)

		var compiled := GeneExpression.compile(draft.to_plasmid())
		var from_sim: ResolvedProtein = compiled[0].products[0].resolved

		runner.check_eq(
			from_editor.compartment, from_sim.compartment, "%s: compartment" % notation
		)
		for kind in ProteinFunction.Kind.values():
			runner.check_eq(
				from_editor.has_function(kind),
				from_sim.has_function(kind),
				"%s: preview and sim disagree about %s" % [
					notation, ProteinFunction.Kind.keys()[kind]
				]
			)
