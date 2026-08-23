class_name CellView
extends Control
## The cell's slot racks, live. Spec §3, §3.4, §9.

##
## Draws individual slots rather than a summary, because §3.4 requires eviction to be
## "always visible": a protein vanishing silently is the most confusing thing this game
## can do. A slot that has just been filled is outlined, and the last eviction in each
## compartment is named underneath, so the answer to "where did my enzyme go" is on
## screen rather than only in the log.

## Ticks a newly racked protein stays highlighted. Long enough to catch at 1x, short
## enough that a busy rack is not permanently lit up.
const FRESH_TICKS := 3

const ROW_HEIGHT := 52.0
const SLOT_GAP := 4.0
const LABEL_WIDTH := 92.0
const EMPTY := Color("222a33")
const FRESH := Color("ffffff")
const MUTED := Color("8b98a5")
const ALERT := Color("e06c5a")

var _state: SimState = null
## Most recent eviction per compartment, as plain text. Cleared on reset.
var _evictions := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, ROW_HEIGHT * 3 + 12)


func reset() -> void:
	_evictions.clear()
	queue_redraw()


func show_state(state: SimState, events: Array) -> void:
	_state = state
	for event in events:
		if event.type == SimEvent.Type.PROTEIN_EVICTED:
			_evictions[event.data["compartment"]] = (
				"tick %d — gene %d pushed out gene %d"
				% [
					event.tick,
					event.data["evicted_by_promoter"],
					event.data["evicted_promoter"],
				]
			)
	queue_redraw()


func _draw() -> void:
	if _state == null:
		return

	for compartment in range(_state.racks.size()):
		var rack: SlotRack = _state.racks[compartment]
		var y := compartment * ROW_HEIGHT + 4.0

		_text(_compartment_name(compartment), Vector2(0, y + 20.0), MUTED)
		_text("%d/%d" % [rack.count(), rack.capacity], Vector2(0, y + 36.0), MUTED, 11)

		var available := size.x - LABEL_WIDTH
		var slot_width := (available - SLOT_GAP * (rack.capacity - 1)) / float(rack.capacity)
		var occupants := rack.occupants()

		for i in range(rack.capacity):
			var x := LABEL_WIDTH + i * (slot_width + SLOT_GAP)
			var box := Rect2(x, y + 4.0, slot_width, ROW_HEIGHT - 26.0)
			if i >= occupants.size():
				draw_rect(box, EMPTY, true)
				continue

			var occupant: SlotOccupant = occupants[i]
			draw_rect(box, BlockStyle.gene_colour(occupant.product.source_promoter_index), true)
			if _state.tick - occupant.racked_at_tick <= FRESH_TICKS:
				draw_rect(box, FRESH, false, 2.0)

		if _evictions.has(compartment):
			_text(_evictions[compartment], Vector2(LABEL_WIDTH, y + ROW_HEIGHT - 6.0), ALERT, 11)


func _compartment_name(compartment: int) -> String:
	match compartment:
		ResolvedProtein.Compartment.MEMBRANE:
			return "Membrane"
		ResolvedProtein.Compartment.EXTERNAL:
			return "External"
		_:
			return "Internal"


func _text(text: String, position: Vector2, colour: Color, font_size: int = 13) -> void:
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
