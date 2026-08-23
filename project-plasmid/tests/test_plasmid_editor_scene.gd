## F02-M01 — the editor scene, driven headlessly.
##
## The scene layer is meant to be thin: it draws a [PlasmidDraft] and forwards input.
## These tests exist to prove that is true — that clicking through the editor produces a
## plasmid the simulation runs, and that the scene has not quietly grown rules of its own.
var runner: Object

var _opened: Array = []


func set_runner(r: Object) -> void:
	runner = r


func after_all() -> void:
	for editor in _opened:
		if is_instance_valid(editor):
			editor.free()
	_opened.clear()


func _open() -> PlasmidEditor:
	var scene: PackedScene = load("res://src/ui/plasmid_editor.tscn")
	runner.check(scene != null, "the main scene failed to load")
	var editor: PlasmidEditor = scene.instantiate()
	runner.root.add_child(editor)
	_opened.append(editor)
	return editor


func _press_palette(editor: PlasmidEditor, kind: Block.Kind, period: int = 0) -> void:
	for prototype in BlockStyle.palette():
		if prototype.kind == kind and (kind != Block.Kind.PROMOTER or prototype.period == period):
			editor._on_palette_pressed(prototype)
			return
	runner.fail("the palette has no button for %s" % Block.Kind.keys()[kind])


func test_the_editor_opens_with_a_runnable_plasmid() -> void:
	var editor := _open()

	runner.check(editor.draft != null, "the editor opened with no draft")
	runner.check(not editor.draft.is_empty(), "the editor opened with an empty ring")
	runner.check(
		editor.draft.is_viable(),
		"the starting plasmid reports problems: %s" % str(editor.draft.problems())
	)


func test_the_ring_shows_one_chip_per_block() -> void:
	var editor := _open()
	runner.check_eq(
		editor._ring._chips.size(), editor.draft.size(), "chips and blocks disagree"
	)

	_press_palette(editor, Block.Kind.RBS)
	runner.check_eq(
		editor._ring._chips.size(), editor.draft.size(), "the ring did not follow the edit"
	)


func test_chips_are_spread_around_the_ring_rather_than_stacked() -> void:
	var editor := _open()
	var seen := {}
	for chip in editor._ring._chips:
		var key := "%d,%d" % [roundi(chip.position.x), roundi(chip.position.y)]
		runner.check(not seen.has(key), "two chips landed on the same spot: %s" % key)
		seen[key] = true


func test_placing_from_the_palette_inserts_after_the_selection() -> void:
	# Building left to right without having to drag every new block into place.
	var editor := _open()
	editor.draft = PlasmidDraft.from_notation("P12-CAT-TERM")
	editor._ring.bind(editor.draft)
	editor._ring.select(1)

	_press_palette(editor, Block.Kind.FOOD)
	runner.check_eq(editor.draft.notation(), "P12-CAT-FOOD-TERM", "insert after selection")
	runner.check_eq(editor._ring.selected_index, 2, "selection did not follow the new block")


func test_placing_with_nothing_selected_appends() -> void:
	var editor := _open()
	editor.draft = PlasmidDraft.from_notation("P12-CAT")
	editor._ring.bind(editor.draft)
	editor._ring.select(-1)

	_press_palette(editor, Block.Kind.FOOD)
	runner.check_eq(editor.draft.notation(), "P12-CAT-FOOD", "append with no selection")


func test_removing_the_selected_block_keeps_the_selection_in_range() -> void:
	var editor := _open()
	editor.draft = PlasmidDraft.from_notation("P12-CAT-FOOD-TERM")
	editor._ring.bind(editor.draft)
	editor._ring.select(3)

	editor._on_remove_pressed()
	runner.check_eq(editor.draft.notation(), "P12-CAT-FOOD", "removal")
	runner.check(
		editor._ring.selected_index < editor.draft.size(),
		"selection pointed past the end of the ring after a removal"
	)


func test_a_plasmid_built_through_the_editor_runs_a_battle() -> void:
	# M01's acceptance condition: §5.4's starting protein built by hand, accepted and run
	# by F01 with nothing edited outside the editor.
	var editor := _open()
	editor.draft = PlasmidDraft.new()
	editor._ring.bind(editor.draft)
	editor._ring.select(-1)

	_press_palette(editor, Block.Kind.PROMOTER, 12)
	_press_palette(editor, Block.Kind.CATABOLIC_ENZYME)
	_press_palette(editor, Block.Kind.FOOD)
	_press_palette(editor, Block.Kind.TERMINATOR)
	_press_palette(editor, Block.Kind.PROMOTER, 12)
	_press_palette(editor, Block.Kind.TRANSPORTER_DOMAIN)
	_press_palette(editor, Block.Kind.MEMBRANE_DOMAIN)
	_press_palette(editor, Block.Kind.FOOD)
	_press_palette(editor, Block.Kind.TERMINATOR)

	runner.check_eq(
		editor.draft.notation(),
		"P12-CAT-FOOD-TERM-P12-TRA-MEM-FOOD-TERM",
		"clicking the palette did not build the intended plasmid"
	)

	var outcome := Battle.new(editor.draft.to_plasmid(), EnvironmentDef.knife_edge()).run()
	runner.check(outcome.divided(), "the hand-built plasmid failed to win its battle")


func test_dragging_a_block_reorders_the_ring() -> void:
	# The drop path a chip takes, without a mouse: chip 3 dropped onto chip 1.
	var editor := _open()
	editor.draft = PlasmidDraft.from_notation("P12-MEM-TRA-FOOD-TERM")
	editor._ring.bind(editor.draft)

	editor._ring._on_reorder_requested(3, 1)
	runner.check_eq(editor.draft.notation(), "P12-FOOD-MEM-TRA-TERM", "drag reorder")
	runner.check_eq(editor._ring.selected_index, 1, "selection did not travel with the block")


func test_the_editor_reports_problems_it_can_see() -> void:
	var editor := _open()
	editor.draft = PlasmidDraft.from_notation("P12-TRA-FOOD-TERM")
	editor._ring.bind(editor.draft)
	editor._refresh()

	runner.check(
		editor._problems_label.text.contains("inert"),
		"the panel did not surface an all-inert plasmid: '%s'" % editor._problems_label.text
	)


func test_the_notation_readout_tracks_the_ring() -> void:
	var editor := _open()
	editor.draft = PlasmidDraft.from_notation("P12-CAT-FOOD-TERM")
	editor._ring.bind(editor.draft)
	editor._refresh()

	runner.check(
		editor._notation_label.text.contains("P12-CAT-FOOD-TERM"),
		"notation readout is stale: '%s'" % editor._notation_label.text
	)
