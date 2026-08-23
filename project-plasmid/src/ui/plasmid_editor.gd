class_name PlasmidEditor
extends Control
## The build phase screen. Spec §7.0, §9.
##
## The whole decision surface of the game: there is no mid-battle input, so everything a
## player chooses, they choose here. M01 is the ring and placement; the topology preview
## (M02), the plain-language function readout (M03) and the commit flow (M04) attach to
## the side panel this builds.
##
## The tree is assembled in code rather than authored in the scene file. Every part of it
## that matters is dynamic — the ring rebuilds on every edit, the palette is generated
## from the block grammar — and a hand-authored .tscn of the static chrome would be one
## more thing to keep in sync. Worth revisiting once the layout stops moving.

const SIDE_PANEL_WIDTH := 300
const STARTING_NOTATION := "P12-CAT-FOOD-TERM-P12-TRA-MEM-FOOD-TERM"

var draft: PlasmidDraft

var _ring: PlasmidRing
var _selection_label: Label
var _problems_label: Label
var _notation_label: Label
var _remove_button: Button


func _ready() -> void:
	draft = PlasmidDraft.from_notation(STARTING_NOTATION)
	_build_tree()
	draft.changed.connect(_refresh)
	_ring.bind(draft)
	_refresh()


func _build_tree() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
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

	column.add_child(_heading("Palette"))
	column.add_child(_build_palette())

	_notation_label = Label.new()
	_notation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_notation_label)


func _build_side_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)

	panel.add_child(_heading("Selected block"))
	_selection_label = Label.new()
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_selection_label)

	_remove_button = Button.new()
	_remove_button.text = "Remove selected block"
	_remove_button.pressed.connect(_on_remove_pressed)
	panel.add_child(_remove_button)

	panel.add_child(_heading("Problems"))
	_problems_label = Label.new()
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_problems_label)

	return panel


func _build_palette() -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for prototype in BlockStyle.palette():
		var button := Button.new()
		button.text = BlockStyle.label_for(prototype)
		button.tooltip_text = "%s\n%s" % [
			BlockStyle.name_for(prototype), BlockStyle.of(prototype.kind)["blurb"]
		]
		# Bind a clone: the palette hands out copies, never the prototype itself, or
		# every placed block of a kind would be the same object.
		button.pressed.connect(_on_palette_pressed.bind(prototype))
		flow.add_child(button)
	return flow


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


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

	_update_selection_label()
	_remove_button.disabled = _ring.selected_index < 0 or draft.is_empty()


func _update_selection_label() -> void:
	var index := _ring.selected_index
	if index < 0 or index >= draft.size():
		_selection_label.text = "Nothing selected. Click a block on the ring."
		return
	var block := draft.at(index)
	_selection_label.text = "%s\nPosition %d of %d\n\n%s" % [
		BlockStyle.name_for(block), index + 1, draft.size(), BlockStyle.of(block.kind)["blurb"]
	]


func _on_palette_pressed(prototype: Block) -> void:
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
	var index := _ring.selected_index
	if index < 0:
		return
	draft.remove_at(index)
	_ring.select(mini(index, draft.size() - 1))
	_refresh()


func _on_block_picked(_index: int) -> void:
	_refresh()
