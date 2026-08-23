class_name Main
extends Control
## The loop, such as it is: build, commit, watch, go back. Spec §7.0.
##
## Deliberately thin. F08 owns the real shell — menu, run persistence, settings — and this
## exists only so the two screens that do exist can reach each other. Committing hands the
## battle screen a snapshot and nothing else; going back re-opens the editor exactly as it
## was left, since §7.0 makes the build phase the whole decision and losing it on every
## battle would make iterating unbearable.

var editor: PlasmidEditor
var battle_screen: BattleScreen


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	editor = load("res://src/ui/plasmid_editor.tscn").instantiate()
	editor.set_anchors_preset(Control.PRESET_FULL_RECT)
	editor.committed.connect(_on_committed)
	add_child(editor)

	battle_screen = BattleScreen.new()
	battle_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_screen.dismissed.connect(_on_dismissed)
	battle_screen.visible = false
	add_child(battle_screen)


func _on_committed(plasmid: Plasmid, environment: EnvironmentDef) -> void:
	editor.visible = false
	battle_screen.visible = true
	battle_screen.begin(plasmid, environment)


func _on_dismissed() -> void:
	battle_screen.visible = false
	editor.visible = true
	# The editor stays committed until the player explicitly unlocks it, so the plasmid
	# they just watched is still the plasmid on screen.
	editor.select_block(editor._ring.selected_index)
