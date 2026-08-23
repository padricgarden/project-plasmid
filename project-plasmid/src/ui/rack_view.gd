class_name RackView
extends Control
## The slot racks, drawn as racks. Spec §3, §9.2.
##
## §9.2 calls this "the single most important readout, since slot count *is* throughput".
## Drawing it as a row of filled and empty slots rather than a table of numbers is the
## whole point: §3.1's equilibrium is a shape, and a player who can see six of one gene
## and two of another can reason about promoter rates without being told the rule.

const ROW_HEIGHT := 30.0
const SLOT_GAP := 3.0
const LABEL_WIDTH := 86.0
const EMPTY := Color("222a33")
const MUTED := Color("8b98a5")

var compositions: Array = []
var capacity: int = Balance.SLOTS_PER_COMPARTMENT


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, ROW_HEIGHT * 3 + 16)


func show_racks(p_compositions: Array) -> void:
	compositions = p_compositions
	queue_redraw()


func _draw() -> void:
	if compositions.is_empty():
		return

	for compartment in range(compositions.size()):
		var y := compartment * ROW_HEIGHT + 6.0
		_draw_text(_compartment_name(compartment), Vector2(0, y + 18.0), MUTED)

		var available := size.x - LABEL_WIDTH
		var slot_width := (available - SLOT_GAP * (capacity - 1)) / float(capacity)

		# Occupants are drawn gene by gene in ring order, so the rack keeps the same
		# left-to-right arrangement between redraws and a change reads as a change.
		var filled := 0
		var composition: Dictionary = compositions[compartment]
		var keys: Array = composition.keys()
		keys.sort()
		for promoter in keys:
			for i in range(composition[promoter]):
				if filled >= capacity:
					break
				_draw_slot(LABEL_WIDTH, y, slot_width, filled, BlockStyle.gene_colour(promoter))
				filled += 1

		for i in range(filled, capacity):
			_draw_slot(LABEL_WIDTH, y, slot_width, i, EMPTY)


func _draw_slot(left: float, y: float, slot_width: float, index: int, colour: Color) -> void:
	draw_rect(
		Rect2(left + index * (slot_width + SLOT_GAP), y + 4.0, slot_width, ROW_HEIGHT - 10.0),
		colour,
		true
	)


func _compartment_name(compartment: int) -> String:
	match compartment:
		ResolvedProtein.Compartment.MEMBRANE:
			return "Membrane"
		ResolvedProtein.Compartment.EXTERNAL:
			return "External"
		_:
			return "Internal"


func _draw_text(text: String, position: Vector2, colour: Color) -> void:
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, colour)
