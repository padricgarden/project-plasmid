class_name ReadoutPanel
extends VBoxContainer
## The steady-state readout. Spec §9.2, §3.2, §7.4.
##
## Everything §9.2 asks for except the pipeline, which is its own widget: predicted gross
## metabolites/tick, upkeep/tick, net/tick, and the equilibrium rack drawn as a rack.
##
## All of it comes from [Prediction], which gets its numbers by running the cell. The
## panel does no arithmetic of its own — that is what stops it from slowly disagreeing
## with the battle it is describing.

var _rates: Label
var _verdict: Label
var _rack: RackView


func _init() -> void:
	add_theme_constant_override("separation", 4)

	_rates = Label.new()
	_rates.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_rates)

	_rack = RackView.new()
	_rack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_rack)

	_verdict = Label.new()
	_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_verdict)


func show_prediction(prediction: Prediction) -> void:
	_rates.text = (
		"Gross %s/tick    Upkeep %s/tick    Net %s/tick    Capture %d%% of the food offered"
		% [
			Prediction.rate_text(prediction.gross_scaled),
			Prediction.rate_text(prediction.upkeep_scaled),
			Prediction.rate_text(prediction.net_scaled),
			prediction.capture_percent(),
		]
	)
	_rack.show_racks(prediction.racks)
	_verdict.text = _verdict_text(prediction)


## The question a player actually has: does this build win in time?
func _verdict_text(prediction: Prediction) -> String:
	if prediction.divides_at_tick < 0:
		return (
			"Never reaches %d growth. Upkeep is eating everything this cell earns."
			% prediction.growth_target
		)
	if prediction.divides_at_tick <= Balance.BATTLE_LENGTH_TICKS:
		return "Divides on tick %d, inside the %d-tick clock." % [
			prediction.divides_at_tick, Balance.BATTLE_LENGTH_TICKS
		]
	return (
		"Would divide on tick %d — %d ticks too late. The clock runs out first."
		% [
			prediction.divides_at_tick,
			prediction.divides_at_tick - Balance.BATTLE_LENGTH_TICKS,
		]
	)
