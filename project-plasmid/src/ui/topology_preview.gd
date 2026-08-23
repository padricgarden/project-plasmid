class_name TopologyPreview
extends Control
## The selected protein, laid out flat with the membrane drawn across it. Spec §5.1,
## §5.3, §10.
##
## [b]This widget is a design requirement, not decoration.[/b] §10 lists "unified
## transporter illegible to new players" as a known risk and names exactly one mitigation:
## a topology preview with the membrane and directional arrows — followed by "do not split
## the block". The same Transporter imports, exports or does nothing depending only on
## which side of the membrane its target sits, and a player who cannot see the sides
## cannot see the rule.
##
## Draws only. Everything it shows comes from [Adjacency] via [ResolvedProtein], so the
## arrow always agrees with what the sim will actually do.

const PREFERRED_HEIGHT := 148
const PADDING := 14.0
const GAP := 4.0
const MIN_CHIP_WIDTH := 22.0
const MAX_CHIP_WIDTH := 70.0
const CHIP_HEIGHT := 34.0

const INSIDE_FILL := Color("1d2a38")
const OUTSIDE_FILL := Color("2c2419")
const MEMBRANE_FILL := Color(0.85, 0.56, 0.20, 0.35)
const ARROW := Color("e8eef4")
const MUTED := Color("8b98a5")
const ALERT := Color("e06c5a")

var _protein: ProteinDef = null
var _resolved: ResolvedProtein = null
var _note: String = ""
var _empty_message: String = "Select a block to see the protein it belongs to."


func _init() -> void:
	custom_minimum_size = Vector2(0, PREFERRED_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_protein(protein: ProteinDef, resolved: ResolvedProtein, note: String = "") -> void:
	_protein = protein
	_resolved = resolved
	_note = note
	queue_redraw()


func show_nothing(message: String) -> void:
	_protein = null
	_resolved = null
	_note = ""
	_empty_message = message
	queue_redraw()


func _draw() -> void:
	if _protein == null or _resolved == null or _protein.is_empty():
		_draw_centred(_empty_message, MUTED)
		return

	var count := _protein.length()
	var chip_width := clampf(
		(size.x - PADDING * 2.0 - GAP * (count - 1)) / float(count),
		MIN_CHIP_WIDTH,
		MAX_CHIP_WIDTH
	)
	var row_width := chip_width * count + GAP * (count - 1)
	var left := (size.x - row_width) * 0.5
	var row_top := size.y * 0.5 - CHIP_HEIGHT * 0.5

	_draw_compartments(left, chip_width, row_top)
	_draw_chips(left, chip_width, row_top)
	_draw_transport_arrows(left, chip_width, row_top)
	_draw_footnote()


## Shade the two sides of the membrane so "inside" and "outside" are places on screen
## rather than a rule to memorise. Without a membrane domain the whole protein is
## cytoplasmic, which is exactly why its transporters do nothing (§5.3 rule 3).
func _draw_compartments(left: float, chip_width: float, row_top: float) -> void:
	var band_top := row_top - 26.0
	var band_height := CHIP_HEIGHT + 52.0

	if _resolved.membrane_index < 0:
		draw_rect(Rect2(0, band_top, size.x, band_height), INSIDE_FILL, true)
		_draw_label("INSIDE — cytoplasm", Vector2(PADDING, band_top + 14.0), MUTED)
		return

	var boundary := left + (_resolved.membrane_index + 0.5) * (chip_width + GAP)
	draw_rect(Rect2(0, band_top, boundary, band_height), INSIDE_FILL, true)
	draw_rect(Rect2(boundary, band_top, size.x - boundary, band_height), OUTSIDE_FILL, true)
	draw_rect(
		Rect2(boundary - chip_width * 0.5 - GAP, band_top, chip_width + GAP * 2.0, band_height),
		MEMBRANE_FILL,
		true
	)

	_draw_label("INSIDE — cytoplasm", Vector2(PADDING, band_top + 14.0), MUTED)
	var outside_label := "OUTSIDE — medium"
	var width := _text_width(outside_label)
	_draw_label(outside_label, Vector2(size.x - PADDING - width, band_top + 14.0), MUTED)


func _draw_chips(left: float, chip_width: float, row_top: float) -> void:
	for i in range(_protein.length()):
		var block: Block = _protein.blocks[i]
		var x := left + i * (chip_width + GAP)
		draw_rect(Rect2(x, row_top, chip_width, CHIP_HEIGHT), BlockStyle.colour_for(block), true)

		var text := BlockStyle.label_for(block)
		if _text_width(text) < chip_width - 4.0:
			_draw_label(
				text,
				Vector2(x + (chip_width - _text_width(text)) * 0.5, row_top + CHIP_HEIGHT * 0.65),
				Color("11161c")
			)


func _draw_transport_arrows(left: float, chip_width: float, row_top: float) -> void:
	var inert_notes := PackedStringArray()

	for function in _resolved.functions:
		var centre_x := left + (function.effector_index + 0.5) * (chip_width + GAP)
		var y := row_top - 14.0

		match function.kind:
			# Inside is drawn on the left, so importing points left and exporting right.
			ProteinFunction.Kind.IMPORT:
				_draw_arrow(Vector2(centre_x + 26.0, y), Vector2(centre_x - 26.0, y))
				_draw_above(centre_x, y, "IMPORT")
			ProteinFunction.Kind.EXPORT:
				_draw_arrow(Vector2(centre_x - 26.0, y), Vector2(centre_x + 26.0, y))
				_draw_above(centre_x, y, "EXPORT")
			ProteinFunction.Kind.EXCHANGE:
				_draw_arrow(Vector2(centre_x + 26.0, y), Vector2(centre_x - 26.0, y))
				_draw_arrow(Vector2(centre_x - 26.0, y + 9.0), Vector2(centre_x + 26.0, y + 9.0))
				_draw_above(centre_x, y, "EXCHANGE")
			ProteinFunction.Kind.CATABOLISE:
				_draw_above(centre_x, y, "DIGESTS")
			ProteinFunction.Kind.INERT:
				# A block that occupies a slot and does nothing is the most expensive
				# mistake the build phase allows (§3.2), so it is marked, not omitted.
				draw_rect(
					Rect2(centre_x - chip_width * 0.5, row_top, chip_width, CHIP_HEIGHT),
					ALERT,
					false,
					2.0
				)
				_draw_above(centre_x, y, "INERT")
				inert_notes.append(function.reason)

	if not inert_notes.is_empty():
		_draw_label(inert_notes[0], Vector2(PADDING, size.y - 8.0), ALERT)


func _draw_footnote() -> void:
	if _note.is_empty():
		return
	var width := _text_width(_note)
	_draw_label(_note, Vector2(size.x - PADDING - width, size.y - 8.0), MUTED)


func _draw_arrow(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, ARROW, 2.0)
	var direction := (to - from).normalized()
	var side := Vector2(-direction.y, direction.x) * 5.0
	draw_colored_polygon(
		PackedVector2Array([to, to - direction * 9.0 + side, to - direction * 9.0 - side]), ARROW
	)


func _draw_above(centre_x: float, y: float, text: String) -> void:
	_draw_label(text, Vector2(centre_x - _text_width(text) * 0.5, y - 10.0), ARROW)


func _draw_label(text: String, position: Vector2, colour: Color, font_size: int = 12) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _draw_centred(text: String, colour: Color) -> void:
	_draw_label(text, Vector2((size.x - _text_width(text)) * 0.5, size.y * 0.5), colour)


func _text_width(text: String, font_size: int = 12) -> float:
	var font := ThemeDB.fallback_font
	if font == null:
		return 0.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
