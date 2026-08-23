extends SceneTree
## Headless test runner.
##
##   Godot/Godot_v4.7.2-stable_win64_console.exe \
##       --headless --path project-plasmid --script res://tests/run_tests.gd
##
## Discovers every `test_*.gd` under `res://tests/`, instantiates it, and calls
## each method named `test_*`. A test fails by calling `fail(msg)` or by letting
## an assertion push an error. Exit code is non-zero if anything failed.
##
## Runs on the first `_process` frame, not in `_init` or `_initialize`. The scene tree
## root is not yet inside the tree during either of those, so a Control added to it never
## gets its `_ready()` called and every scene test sees a half-built node. Scene-level
## tests (F02 onward) depend on running after the tree is live.

const TESTS_DIR := "res://tests"

var _failures: Array[String] = []
var _current := ""
var _assertions := 0


var _has_run := false


## Returning true ends the main loop; the exit code comes from the quit() below.
func _process(_delta: float) -> bool:
	if _has_run:
		return true
	_has_run = true
	_run_all()
	return true


func _run_all() -> void:
	var files := _discover(TESTS_DIR)
	files.sort()
	if files.is_empty():
		print("no test files found under %s" % TESTS_DIR)
		quit(0)
		return

	var ran := 0
	for path in files:
		var script: GDScript = load(path)
		if script == null:
			_failures.append("%s: failed to load" % path)
			continue
		var suite: Object = script.new()
		if suite.has_method("set_runner"):
			suite.call("set_runner", self)
		if suite.has_method("before_all"):
			suite.call("before_all")
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			_current = "%s::%s" % [path.get_file(), name]
			if suite.has_method("before_each"):
				suite.call("before_each")
			suite.call(name)
			if suite.has_method("after_each"):
				suite.call("after_each")
			ran += 1
		if suite.has_method("after_all"):
			suite.call("after_all")

	print("")
	print("%d test(s), %d assertion(s), %d failure(s)" % [ran, _assertions, _failures.size()])
	for f in _failures:
		print("  FAIL  %s" % f)
	quit(1 if _failures.size() > 0 else 0)


## Record a failure against the currently running test.
func fail(message: String) -> void:
	_failures.append("%s: %s" % [_current, message])


func check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		fail(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertions += 1
	if actual != expected:
		var suffix := "" if message.is_empty() else " (%s)" % message
		fail("expected %s, got %s%s" % [expected, actual, suffix])


func _discover(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			found.append_array(_discover(full))
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
