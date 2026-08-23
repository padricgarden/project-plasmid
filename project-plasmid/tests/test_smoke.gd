## Placeholder proving the runner works. Delete once `sim/` has real tests.
var runner: Object


func set_runner(r: Object) -> void:
	runner = r


func test_runner_is_wired_up() -> void:
	runner.check_eq(2 + 2, 4, "arithmetic still works")
