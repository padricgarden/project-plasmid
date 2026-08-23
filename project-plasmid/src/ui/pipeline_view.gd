class_name PipelineView
extends Control
## The pipeline, with the narrow point marked. Spec §9.2, §7.4.
##
## §9.2: "render the pipeline (food in → catabolism → metabolites → growth) as a flow
## with the bottleneck highlighted. *This one widget will teach the game better than any
## tutorial.*" The value is not the diagram — it is that a build which is going badly
## turns into one specific thing to fix.

const STAGE_HEIGHT := 44.0
const GAP := 30.0
const MUTED := Color("47535f")
const NORMAL := Color("2f3b47")
const HIGHLIGHT := Color("e06c5a")
const TEXT := Color("e8eef4")
const ARROW := Color("7d8b99")

var _prediction: Prediction = null
var _advice: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 110)

	_advice = Label.new()
	_advice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_advice.position = Vector2(0, STAGE_HEIGHT + 18.0)
	add_child(_advice)


func show_prediction(prediction: Prediction) -> void:
	_prediction = prediction
	_advice.text = prediction.bottleneck_advice()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_advice.size.x = size.x


func _draw() -> void:
	if _prediction == null:
		return

	var stages := [
		[Prediction.Stage.SUPPLY, "Food supply", "%d delivered" % _prediction.food_delivered],
		[Prediction.Stage.IMPORT, "Import", "%d captured" % _prediction.food_captured],
		[
			Prediction.Stage.DIGESTION,
			"Digestion",
			"%s/tick gross" % Prediction.rate_text(_prediction.gross_scaled),
		],
		[
			Prediction.Stage.METABOLITES,
			"Metabolites",
			"%s/tick net" % Prediction.rate_text(_prediction.net_scaled),
		],
	]

	var width := (size.x - GAP * (stages.size() - 1)) / float(stages.size())
	for i in range(stages.size()):
		var x := i * (width + GAP)
		var is_bottleneck: bool = stages[i][0] == _prediction.bottleneck
		draw_rect(
			Rect2(x, 0, width, STAGE_HEIGHT), HIGHLIGHT if is_bottleneck else NORMAL, true
		)
		_text(stages[i][1], Vector2(x + 8.0, 19.0), TEXT)
		_text(stages[i][2], Vector2(x + 8.0, 35.0), TEXT if is_bottleneck else ARROW, 11)

		if i < stages.size() - 1:
			_arrow(Vector2(x + width + 5.0, STAGE_HEIGHT * 0.5), Vector2(x + width + GAP - 5.0, STAGE_HEIGHT * 0.5))

	# Growth is the end of the pipeline rather than a stage that can pinch. Reported as
	# the tick it divides on, not as banked-against-target: the prediction deliberately
	# runs past the win to reach steady state, so its banked figure overshoots the target
	# and would read as nonsense.
	_text("→ " + _growth_text(), Vector2(0, STAGE_HEIGHT + 14.0), ARROW, 11)


func _arrow(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, ARROW, 2.0)
	var direction := (to - from).normalized()
	var side := Vector2(-direction.y, direction.x) * 4.0
	draw_colored_polygon(
		PackedVector2Array([to, to - direction * 7.0 + side, to - direction * 7.0 - side]), ARROW
	)


func _text(text: String, position: Vector2, colour: Color, font_size: int = 13) -> void:
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _growth_text() -> String:
	if _prediction.divides_at_tick < 0:
		return "never reaches the %d growth it needs to divide" % _prediction.growth_target
	if _prediction.divides_at_tick <= Balance.BATTLE_LENGTH_TICKS:
		return "reaches %d growth and divides on tick %d" % [
			_prediction.growth_target, _prediction.divides_at_tick
		]
	return "reaches %d growth on tick %d — %d ticks after the clock stops" % [
		_prediction.growth_target,
		_prediction.divides_at_tick,
		_prediction.divides_at_tick - Balance.BATTLE_LENGTH_TICKS,
	]
