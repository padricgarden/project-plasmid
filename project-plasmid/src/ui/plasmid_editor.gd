class_name PlasmidEditor
extends Control
## The build phase screen. Spec §7.0, §9.
##
## The whole decision surface of the game: there is no mid-battle input, so everything a
## player chooses, they choose here. The ring and placement are M01, the topology preview
## M02, the plain-language readout M03, and committing M04.
##
## The tree is assembled in code rather than authored in the scene file. Every part of it
## that matters is dynamic — the ring rebuilds on every edit, the palette is generated
## from the block grammar — and a hand-authored .tscn of the static chrome would be one
## more thing to keep in sync. Worth revisiting once the layout stops moving.

## Emitted when the player commits. F04 will drive its watch phase from this; until then
## the editor resolves the battle instantly and shows the result, which is §7.0's
## instant-resolve speed rather than a throwaway placeholder.
signal committed(plasmid: Plasmid, environment: EnvironmentDef)

const SIDE_PANEL_WIDTH := 330
const PALETTE_HEIGHT := 96
const TAB_HEIGHT := 232
const STARTING_NOTATION := "P12-CAT-FOOD-TERM-P12-TRA-MEM-FOOD-TERM"

var draft: PlasmidDraft
var environment: EnvironmentDef = EnvironmentDef.knife_edge()
var is_committed := false

var _ring: PlasmidRing
var _topology: TopologyPreview
var _selection_label: Label
var _function_label: Label
var _problems_label: Label
var _notation_label: Label
var _remove_button: Button
var _commit_button: Button
var _edit_button: Button
var _budget_label: Label
var _outcome_label: Label
var _environment_picker: OptionButton
var _palette_box: VBoxContainer
var _readout: ReadoutPanel
var _pipeline: PipelineView
var _sandbox: SandboxPanel

var _environments: Array[EnvironmentDef] = [
	EnvironmentDef.abundant(), EnvironmentDef.knife_edge(), EnvironmentDef.scarce()
]


func _ready() -> void:
	_build_tree()
	set_draft(PlasmidDraft.from_notation(STARTING_NOTATION))


## Install a plasmid to edit. Everything that has to happen on a swap happens here —
## reconnecting the change signal above all, since a draft replaced without it leaves the
## screen listening to a plasmid nobody is editing any more.
func set_draft(p_draft: PlasmidDraft) -> void:
	if draft != null and draft.changed.is_connected(_refresh):
		draft.changed.disconnect(_refresh)
	draft = p_draft
	draft.changed.connect(_refresh)
	_ring.bind(draft)
	_refresh()


## Select a block from outside the editor. Used by the screenshot tool so a captured
## picture can show the readouts doing their job rather than an empty prompt.
func select_block(index: int) -> void:
	_ring.select(index)
	_refresh()


# ------------------------------------------------------------------------------ layout

func _build_tree() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	column.add_child(_heading("Build phase — arrange the plasmid, then commit"))

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 16)
	column.add_child(middle)

	_ring = PlasmidRing.new()
	_ring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ring.block_picked.connect(_on_block_picked)
	middle.add_child(_ring)

	middle.add_child(_build_side_panel())

	column.add_child(_build_readout_tabs())

	column.add_child(_build_palette())

	column.add_child(_build_commit_bar())

	_notation_label = Label.new()
	_notation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notation_label.add_theme_font_size_override("font_size", 11)
	column.add_child(_notation_label)


## The four ways of looking at what you built: where it sits (M02), what it will do
## (F03-M02), where it pinches (F03-M03), and what happens tick by tick (F03-M01, M04).
## Tabbed because they answer different questions about the same plasmid and there is
## only one screen — §7.0 makes the build phase the whole decision, not a sequence of them.
func _build_readout_tabs() -> Control:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, TAB_HEIGHT)

	_topology = TopologyPreview.new()
	_topology.name = "Topology"
	tabs.add_child(_topology)

	_readout = ReadoutPanel.new()
	_readout.name = "Steady state"
	tabs.add_child(_readout)

	_pipeline = PipelineView.new()
	_pipeline.name = "Bottleneck"
	tabs.add_child(_pipeline)

	_sandbox = SandboxPanel.new()
	_sandbox.name = "Tick through"
	tabs.add_child(_sandbox)

	return tabs


func _build_side_panel() -> Control:
	# Scrolled so its wrapped text cannot dictate how tall the whole screen is. Without
	# this the side panel silently sets the minimum height of the middle row and pushes
	# the commit bar off the bottom of the window.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH - 14, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)

	panel.add_child(_heading("Selected block"))
	_selection_label = Label.new()
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_selection_label)

	_remove_button = Button.new()
	_remove_button.text = "Remove selected block"
	_remove_button.pressed.connect(_on_remove_pressed)
	panel.add_child(_remove_button)

	panel.add_child(_heading("What this protein does"))
	_function_label = Label.new()
	_function_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_function_label)

	panel.add_child(_heading("Problems"))
	_problems_label = Label.new()
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_problems_label)

	_outcome_label = Label.new()
	_outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_outcome_label)

	scroll.add_child(panel)
	return scroll


## Grouped so the three kinds of block read as three different jobs. §5.3 makes aiming a
## domain the core move, so a target must not look like just another domain.
func _build_palette() -> Control:
	# Scrolled, and capped in height, because the palette is the part of this screen that
	# grows: F05 adds Toxin, Metabolite, Sensing, TF, Anabolic, Anchor and Degron. A
	# fixed layout would quietly push the commit bar off the bottom of the window again.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, PALETTE_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	for group in BlockStyle.palette_groups():
		var label := Label.new()
		label.text = group["name"]
		label.add_theme_font_size_override("font_size", 11)
		box.add_child(label)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 5)
		for prototype in group["blocks"]:
			var button := Button.new()
			button.text = "%s  %s" % [
				BlockStyle.label_for(prototype), BlockStyle.of(prototype.kind)["name"]
			]
			button.tooltip_text = BlockStyle.of(prototype.kind)["blurb"]
			# The palette hands out clones, never the prototype itself, or every placed
			# block of a kind would be the same object.
			button.pressed.connect(_on_palette_pressed.bind(prototype))
			flow.add_child(button)
		box.add_child(flow)

	_palette_box = box
	scroll.add_child(box)
	return scroll


func _build_commit_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)

	_budget_label = Label.new()
	_budget_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_budget_label)

	# F07 owns real environment progression; this picker exists so one build can be tried
	# against §7.4's three densities without editing code.
	_environment_picker = OptionButton.new()
	for env in _environments:
		_environment_picker.add_item(env.display_name)
	_environment_picker.selected = 1
	_environment_picker.item_selected.connect(_on_environment_selected)
	bar.add_child(_environment_picker)

	_commit_button = Button.new()
	_commit_button.text = "Commit and run"
	_commit_button.pressed.connect(_on_commit_pressed)
	bar.add_child(_commit_button)

	_edit_button = Button.new()
	_edit_button.text = "Back to editing"
	_edit_button.pressed.connect(_on_edit_pressed)
	bar.add_child(_edit_button)

	return bar


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


# ----------------------------------------------------------------------------- refresh

func _refresh() -> void:
	_notation_label.text = "Notation:  %s" % (
		draft.notation() if not draft.is_empty() else "(empty)"
	)

	var problems := draft.problems()
	_problems_label.text = (
		"None — this plasmid will do something."
		if problems.is_empty()
		else "\n".join(problems)
	)

	_update_selection()
	_update_topology()
	_update_budget()
	_update_predictions()

	_remove_button.disabled = is_committed or _ring.selected_index < 0 or draft.is_empty()
	_commit_button.disabled = is_committed or not draft.is_viable()
	_edit_button.disabled = not is_committed
	_palette_box.modulate = Color(1, 1, 1, 0.4 if is_committed else 1.0)


func _update_selection() -> void:
	var index := _ring.selected_index
	if index < 0 or index >= draft.size():
		_selection_label.text = "Nothing selected. Click a block on the ring."
		_function_label.text = ""
		return

	var block := draft.at(index)
	_selection_label.text = "%s\nPosition %d of %d\n%s" % [
		BlockStyle.name_for(block), index + 1, draft.size(), BlockStyle.of(block.kind)["blurb"]
	]

	var protein := draft.protein_containing(index)
	if protein == null:
		_function_label.text = (
			"This block is punctuation — it steers transcription but is not part of any "
			+ "protein, so it does no work itself."
		)
		return
	# M03's whole point: read this and know whether the transporter imports or exports,
	# without running anything.
	_function_label.text = "\n".join(
		ProteinDescription.lines(Adjacency.resolve(protein), environment)
	)


## §10 names this preview as the one mitigation for the unified transporter, so it is
## driven from the same resolution the sim uses rather than anything the editor works out.
func _update_topology() -> void:
	var index := _ring.selected_index
	if index < 0 or index >= draft.size():
		_topology.show_nothing("Select a block to see the protein it belongs to.")
		return

	var protein := draft.protein_containing(index)
	if protein == null:
		_topology.show_nothing(
			"%s is punctuation — it directs transcription but is not part of any protein."
			% BlockStyle.name_for(draft.at(index))
		)
		return

	var shared := draft.proteins_containing(index).size()
	var note := ""
	if shared > 1:
		# Readthrough: this block is translated by more than one promoter (§4).
		note = "Part of %d proteins — an upstream gene reads through into it." % shared
	_topology.show_protein(protein, Adjacency.resolve(protein), note)


## Re-run the sandbox and the prediction against whatever the ring holds now. Both are
## full runs of a copy of the cell, which is affordable because the sim is small and is
## the only way the panel cannot drift from the battle (§9.2).
func _update_predictions() -> void:
	if draft.is_empty():
		return
	var plasmid := draft.to_plasmid()
	_readout.show_prediction(Prediction.run(plasmid, environment))
	_pipeline.show_prediction(Prediction.run(plasmid, environment))
	_sandbox.rebind(plasmid, environment)


## Block count and the burden-adjusted growth target (§4.1). Predicted throughput is
## F03-M02's readout panel, deliberately not duplicated here.
func _update_budget() -> void:
	var blocks := draft.size()
	_budget_label.text = "%d blocks  ·  needs %d growth to divide  ·  %d ticks on the clock" % [
		blocks, Burden.growth_target(blocks), Balance.BATTLE_LENGTH_TICKS
	]


# ------------------------------------------------------------------------------ actions

func _on_palette_pressed(prototype: Block) -> void:
	if is_committed:
		return
	var index := _ring.selected_index
	# Placing with a block selected inserts after it, so a player builds left to right
	# instead of having to drag every new block into position.
	if index >= 0 and index < draft.size():
		draft.insert_at(index + 1, prototype.clone())
		_ring.select(index + 1)
	else:
		draft.append(prototype.clone())
		_ring.select(draft.size() - 1)
	_refresh()


func _on_remove_pressed() -> void:
	if is_committed:
		return
	var index := _ring.selected_index
	if index < 0:
		return
	draft.remove_at(index)
	_ring.select(mini(index, draft.size() - 1))
	_refresh()


func _on_block_picked(_index: int) -> void:
	_refresh()


func _on_environment_selected(index: int) -> void:
	environment = _environments[index]
	_refresh()


## Lock the plasmid and run the battle. §7.0 makes the build phase the entire decision,
## so committing has to be a real door: nothing can be rearranged afterwards.
func _on_commit_pressed() -> void:
	if is_committed or not draft.is_viable():
		return

	is_committed = true
	_ring.set_editable(false)

	var plasmid := draft.to_plasmid()
	committed.emit(plasmid, environment)

	var outcome := Battle.new(plasmid, environment).run()
	_outcome_label.text = _describe_outcome(outcome)
	_refresh()


func _on_edit_pressed() -> void:
	is_committed = false
	_ring.set_editable(true)
	_outcome_label.text = ""
	_refresh()


func _describe_outcome(outcome: BattleOutcome) -> String:
	var headline := ""
	match outcome.kind:
		BattleOutcome.Kind.DIVIDED:
			headline = "Divided on tick %d." % outcome.ended_at_tick
		BattleOutcome.Kind.LYSED:
			headline = "Lysed on tick %d." % outcome.ended_at_tick
		_:
			headline = "Ran out of time on tick %d." % outcome.ended_at_tick

	return "%s\n%d of %d growth (%d%%), in %s." % [
		headline,
		outcome.banked_growth,
		outcome.growth_target,
		outcome.progress_percent(),
		environment.display_name,
	]
