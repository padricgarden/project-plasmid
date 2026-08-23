class_name BattleScreen
extends Control
## The watch phase. Spec §7.0, §9.3.
##
## The player has already made every decision — §7.0 allows no mid-battle input — so this
## screen has exactly one job: make the next 120 ticks legible enough that the result
## reads as a consequence rather than an accident.
##
## [b]It owns no rules.[/b] It pulls ticks from a [Battle] at whatever rate [BattleClock]
## says, and everything on screen is derived from the state that comes back. The speed
## buttons cannot change an outcome because nothing here can.

signal finished(outcome: BattleOutcome)
signal dismissed

const LOG_HEIGHT := 150

var battle: Battle
var clock := BattleClock.new()

var _cell: CellView
var _growth: GrowthBar
var _medium: MediumView
var _log: RichTextLabel
var _status: Label
var _outcome_label: Label
var _speed_buttons := {}
var _back_button: Button
var _events: Array[SimEvent] = []


func _ready() -> void:
	_build_tree()
	set_process(true)


## Start watching a committed plasmid. The plasmid is already a snapshot (F02-M04), so
## nothing the editor does afterwards can reach the battle being watched.
func begin(plasmid: Plasmid, environment: EnvironmentDef) -> void:
	battle = Battle.new(plasmid, environment)
	clock.reset()
	clock.speed = BattleClock.Speed.NORMAL
	_events = []
	_cell.reset()
	_outcome_label.text = ""
	_refresh()


func _process(delta: float) -> void:
	if battle == null or battle.is_finished():
		return
	var ticks := clock.advance(delta)
	if ticks > 0:
		_consume(ticks)


## Advance the battle. Public so the speed guarantee — that 4x and instant agree with 1x —
## can be tested without waiting for real seconds to pass.
func _consume(ticks: int) -> void:
	var produced: Array[SimEvent] = []
	for i in range(ticks):
		if battle.is_finished():
			break
		produced.append_array(battle.step())
	_events.append_array(produced)
	_refresh(produced)

	if battle.is_finished():
		_outcome_label.text = _describe(battle.outcome)
		finished.emit(battle.outcome)


func run_instantly() -> void:
	if battle == null or battle.is_finished():
		return
	_consume(Balance.BATTLE_LENGTH_TICKS + 1)


# ------------------------------------------------------------------------------ layout

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

	_status = Label.new()
	column.add_child(_status)

	_growth = GrowthBar.new()
	_growth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_growth)

	_medium = MediumView.new()
	_medium.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_medium)

	_cell = CellView.new()
	_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_cell)

	column.add_child(_build_speed_bar())

	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, LOG_HEIGHT)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_log)

	_outcome_label = Label.new()
	_outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_outcome_label)


func _build_speed_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)

	for speed in [
		BattleClock.Speed.PAUSED,
		BattleClock.Speed.NORMAL,
		BattleClock.Speed.DOUBLE,
		BattleClock.Speed.QUADRUPLE,
		BattleClock.Speed.INSTANT,
	]:
		var button := Button.new()
		button.text = BattleClock.speed_name(speed)
		button.pressed.connect(_on_speed_pressed.bind(speed))
		bar.add_child(button)
		_speed_buttons[speed] = button

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_back_button = Button.new()
	_back_button.text = "Back to the plasmid"
	_back_button.pressed.connect(func() -> void: dismissed.emit())
	bar.add_child(_back_button)

	return bar


# ----------------------------------------------------------------------------- refresh

func _on_speed_pressed(speed: BattleClock.Speed) -> void:
	clock.speed = speed
	clock.reset()
	if clock.is_instant():
		run_instantly()
	_refresh()


func _refresh(new_events: Array = []) -> void:
	if battle == null:
		return

	var state := battle.state
	_status.text = "Tick %d of %d    ·    %s    ·    %s" % [
		state.tick,
		Balance.BATTLE_LENGTH_TICKS,
		BattleClock.speed_name(clock.speed),
		"finished" if battle.is_finished() else "running",
	]

	_growth.show_state(state)
	_medium.show_state(state)
	_cell.show_state(state, new_events)

	if not new_events.is_empty() or _log.text.is_empty():
		_log.text = "\n".join(EventLog.render(_events, false))

	for speed in _speed_buttons:
		_speed_buttons[speed].disabled = battle.is_finished()


func _describe(outcome: BattleOutcome) -> String:
	match outcome.kind:
		BattleOutcome.Kind.DIVIDED:
			return "Divided on tick %d with %d growth banked against a target of %d." % [
				outcome.ended_at_tick, outcome.banked_growth, outcome.growth_target
			]
		BattleOutcome.Kind.LYSED:
			return "The cell burst on tick %d." % outcome.ended_at_tick
		_:
			return (
				"Time ran out on tick %d with %d of %d growth (%d%%). Not enough."
				% [
					outcome.ended_at_tick,
					outcome.banked_growth,
					outcome.growth_target,
					outcome.progress_percent(),
				]
			)
