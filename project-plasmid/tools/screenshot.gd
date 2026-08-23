extends SceneTree
## Render a scene once and save it to a PNG, so UI work can actually be looked at.
##
## Headless tests can assert what a widget *knows*, never what it *shows*. This caught a
## layout that overflowed the default viewport and hid the palette entirely — something
## no assertion in the suite was ever going to notice.
##
##   scripts\screenshot.ps1 -Out shot.png [-Scene res://...] [-Select 5]
##
## Needs a real window, so it must not be run with --headless.

var _target: Node
var _frames := 0

var _scene_path := "res://src/ui/plasmid_editor.tscn"
var _out_path := "screenshot.png"
var _select := -1
## Drive the screen into its committed state before capturing, so the post-commit layout
## can be looked at too.
var _commit := false
## Frames to wait before capturing. Containers need a few passes to settle their layout,
## so capturing immediately gives a picture of a half-arranged screen.
var _settle_frames := 30


func _process(_delta: float) -> bool:
	if _target == null:
		_read_arguments()
		var scene: PackedScene = load(_scene_path)
		if scene == null:
			printerr("could not load scene: ", _scene_path)
			quit(1)
			return true
		_target = scene.instantiate()
		root.add_child(_target)
		return false

	_frames += 1
	if _frames == _settle_frames / 2:
		if _select >= 0 and _target.has_method("select_block"):
			_target.select_block(_select)
		if _commit and _target.has_method("_on_commit_pressed"):
			_target._on_commit_pressed()

	if _frames < _settle_frames:
		return false

	var error := root.get_texture().get_image().save_png(_out_path)
	if error != OK:
		printerr("could not save ", _out_path, ": ", error)
		quit(1)
		return true
	print("saved ", _out_path)
	quit(0)
	return true


func _read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"--scene":
				_scene_path = parts[1]
			"--out":
				_out_path = parts[1]
			"--select":
				_select = int(parts[1])
			"--commit":
				_commit = parts[1] == "true"
