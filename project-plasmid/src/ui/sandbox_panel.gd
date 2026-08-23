class_name SandboxPanel
extends VBoxContainer
## Tick-through, and the log of what happened. Spec §9.1, §9.3.
##
## §9.1 asks for the build phase to be steppable one tick at a time — "watch proteins get
## built, slots fill, the membrane populate". This is that, plus §9.3's plain-language log
## of the same run, because the two answer the same question from different sides: the
## rack shows *what* the cell is now, the log shows *why* it got there.
##
## The sandbox runs a copy, so nothing here can affect the plasmid being edited.

signal stepped

var sandbox: Sandbox

var _status: Label
var _rack: RackView
var _log: RichTextLabel
var _step_buttons: Array[Button] = []
var _show_everything := false


func _init() -> void:
	add_theme_constant_override("separation", 4)
	add_child(_build_controls())

	_status = Label.new()
	add_child(_status)

	_rack = RackView.new()
	_rack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_rack)

	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, 90)
	add_child(_log)


func _build_controls() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)

	for count in [1, 10, 30]:
		var button := Button.new()
		button.text = "+%d tick%s" % [count, "" if count == 1 else "s"]
		button.pressed.connect(_on_step.bind(count))
		bar.add_child(button)
		_step_buttons.append(button)

	var finish := Button.new()
	finish.text = "Run to the end"
	finish.pressed.connect(_on_run_to_end)
	bar.add_child(finish)
	_step_buttons.append(finish)

	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(_on_reset)
	bar.add_child(reset)

	# Off by default: §9.3's log is a record of turning points, and a line for every
	# maturation would bury the eviction that actually decided the battle.
	var verbose := CheckBox.new()
	verbose.text = "Show every event"
	verbose.toggled.connect(_on_verbose_toggled)
	bar.add_child(verbose)

	return bar


## Point the sandbox at a plasmid. Called whenever the edited plasmid changes, which
## discards any run in progress — a half-stepped sandbox of a plasmid that no longer
## exists would be showing a cell nobody is building.
func rebind(plasmid: Plasmid, environment: EnvironmentDef) -> void:
	sandbox = Sandbox.new(plasmid, environment)
	_refresh()


func _on_step(count: int) -> void:
	if sandbox == null:
		return
	sandbox.step(count)
	_refresh()
	stepped.emit()


func _on_run_to_end() -> void:
	if sandbox == null:
		return
	sandbox.run_to_end()
	_refresh()
	stepped.emit()


func _on_reset() -> void:
	if sandbox == null:
		return
	rebind(sandbox.battle.state.plasmid, sandbox.battle.state.environment)


func _on_verbose_toggled(pressed: bool) -> void:
	_show_everything = pressed
	_refresh()


func _refresh() -> void:
	if sandbox == null:
		return

	var state := sandbox.state()
	_status.text = "Tick %d of %d    ·    %d growth banked of %d    ·    %d food in the medium" % [
		state.tick,
		Balance.BATTLE_LENGTH_TICKS,
		state.banked_growth,
		state.growth_target(),
		state.medium.food,
	]

	var racks := []
	for rack in state.racks:
		racks.append(rack.composition())
	_rack.show_racks(racks)

	_log.text = "\n".join(EventLog.render(sandbox.events, _show_everything))

	var finished := sandbox.is_finished()
	for button in _step_buttons:
		button.disabled = finished
