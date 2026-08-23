class_name MediumView
extends Control
## Food in the shared medium. Spec §7.1, §7.4.
##
## Drawn as discrete units rather than a number, so scarcity reads as scarcity — an empty
## strip is instantly different from a full one, where "3" and "30" are not. §7.4 makes
## delivery the primary balance lever, so how much is out there is something the player
## should feel before the growth rate tells them.
##
## One cell draws from this today; F06 puts a second one on the same strip, which is where
## §7.1's contention becomes visible.

const PIP := Vector2(9, 16)
const PIP_GAP := 3.0
const MAX_PIPS := 60
const FOOD := Color("e2c044")
const EMPTY := Color("222a33")
const MUTED := Color("8b98a5")

var _food: int = 0
var _delivery: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 54)


func show_state(state: SimState) -> void:
	_food = state.medium.food
	if state.environment != null:
		_delivery = "%s — %s food per tick" % [
			state.environment.display_name,
			Prediction.rate_text(state.environment.food_delivery_scaled),
		]
	queue_redraw()


func _draw() -> void:
	_text("Medium: %d food    %s" % [_food, _delivery], Vector2(0, 14.0), MUTED, 12)

	var shown := mini(_food, MAX_PIPS)
	for i in range(MAX_PIPS):
		var x := i * (PIP.x + PIP_GAP)
		if x + PIP.x > size.x:
			break
		draw_rect(Rect2(x, 24.0, PIP.x, PIP.y), FOOD if i < shown else EMPTY, true)

	if _food > MAX_PIPS:
		_text("+%d more" % (_food - MAX_PIPS), Vector2(0, 52.0), MUTED, 11)


func _text(text: String, position: Vector2, colour: Color, font_size: int = 13) -> void:
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)
