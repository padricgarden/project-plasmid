class_name BlockChip
extends Control
## One block sitting on the plasmid ring.
##
## Draws itself and reports what the player did to it. It holds no editing rules — every
## insert, move and remove goes back to [PlasmidDraft], which is where those rules are
## tested. A chip that quietly reordered its own array would put game logic somewhere no
## headless test can reach.

signal picked(index: int)
signal reorder_requested(from_index: int, to_index: int)

const CHIP_SIZE := Vector2(62, 36)
const CORNER := 6.0

var block: Block
var index: int = -1
var selected: bool = false


func _init() -> void:
	custom_minimum_size = CHIP_SIZE
	size = CHIP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_block: Block, p_index: int, p_selected: bool) -> void:
	block = p_block
	index = p_index
	selected = p_selected
	tooltip_text = "%s\n%s" % [
		BlockStyle.name_for(block), BlockStyle.of(block.kind)["blurb"]
	]
	queue_redraw()


func _draw() -> void:
	if block == null:
		return

	var body := Rect2(Vector2.ZERO, size)
	draw_rect(body, BlockStyle.colour_for(block), true)
	if selected:
		draw_rect(body, Color.WHITE, false, 2.0)

	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text := BlockStyle.label_for(block)
	var font_size := 14
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		font,
		Vector2((size.x - text_size.x) * 0.5, (size.y + text_size.y * 0.6) * 0.5),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color("11161c")
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(index)
			accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	picked.emit(index)

	var preview := BlockChip.new()
	preview.setup(block, index, false)
	preview.modulate = Color(1, 1, 1, 0.75)
	set_drag_preview(preview)

	return {"plasmid_block_index": index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("plasmid_block_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	reorder_requested.emit(data["plasmid_block_index"], index)
