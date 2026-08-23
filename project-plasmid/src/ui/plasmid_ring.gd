class_name PlasmidRing
extends Control
## The plasmid drawn as a ring of blocks. Spec §4.
##
## Circular because transcription wraps: an unterminated gene at the end of the ring
## reads straight into the first (§4). Drawing it as a line would make that rule
## something a player only discovers by losing, so the ring is drawn as a ring and the
## wrap point is marked.
##
## Holds no editing rules. Every reorder is handed to [PlasmidDraft], where it is tested.

signal block_picked(index: int)

const MIN_RADIUS := 96.0
const EDGE_MARGIN := 52.0
const BACKBONE := Color("2c3742")
const WRAP_MARK := Color("7d8b99")

var draft: PlasmidDraft
var selected_index: int = -1

var _chips: Array[BlockChip] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(300, 300)


func _ready() -> void:
	resized.connect(_layout_chips)


func bind(p_draft: PlasmidDraft) -> void:
	if draft != null and draft.changed.is_connected(rebuild):
		draft.changed.disconnect(rebuild)
	draft = p_draft
	if draft != null:
		draft.changed.connect(rebuild)
	rebuild()


func select(index: int) -> void:
	selected_index = index
	for chip in _chips:
		chip.selected = chip.index == index
		chip.queue_redraw()


func rebuild() -> void:
	for chip in _chips:
		chip.queue_free()
	_chips.clear()

	if draft != null:
		if selected_index >= draft.size():
			selected_index = draft.size() - 1
		for i in range(draft.size()):
			var chip := BlockChip.new()
			add_child(chip)
			chip.setup(draft.at(i), i, i == selected_index)
			chip.picked.connect(_on_chip_picked)
			chip.reorder_requested.connect(_on_reorder_requested)
			_chips.append(chip)

	_layout_chips()
	queue_redraw()


func _layout_chips() -> void:
	var count := _chips.size()
	if count == 0:
		queue_redraw()
		return

	var centre := size * 0.5
	var radius := _radius()
	for i in range(count):
		# Index 0 sits at the top and the ring reads clockwise, so the wrap point is
		# always in the same place no matter how long the plasmid grows.
		var angle := -PI * 0.5 + TAU * float(i) / float(count)
		var chip := _chips[i]
		chip.position = centre + Vector2(cos(angle), sin(angle)) * radius - chip.size * 0.5
	queue_redraw()


func _radius() -> float:
	return maxf(MIN_RADIUS, minf(size.x, size.y) * 0.5 - EDGE_MARGIN)


func _draw() -> void:
	var centre := size * 0.5
	var radius := _radius()
	draw_arc(centre, radius, 0.0, TAU, 96, BACKBONE, 6.0, true)

	# The wrap point, marked so that "the last gene reads into the first" is visible
	# rather than a rule to be surprised by.
	var top := centre + Vector2(0, -radius)
	draw_line(top + Vector2(0, -14), top + Vector2(0, -4), WRAP_MARK, 2.0)

	if draft == null or draft.is_empty():
		_draw_hint(centre)


func _draw_hint(centre: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text := "Empty plasmid — add blocks from the palette below"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(
		font,
		centre - Vector2(text_size.x * 0.5, 0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		WRAP_MARK
	)


func _on_chip_picked(index: int) -> void:
	select(index)
	block_picked.emit(index)


func _on_reorder_requested(from_index: int, to_index: int) -> void:
	if draft == null:
		return
	draft.move(from_index, to_index)
	# The block keeps the selection as it travels, so the player can drag it again
	# without hunting for it.
	select(to_index)
	block_picked.emit(to_index)
