extends SceneTree

const SPEED_MPS := 17.3
const DURATION_SECONDS := 11.0
const RATE := 0.8
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var results := {}
	for fps in [30, 60, 120]:
		var manager: Node = load("res://scripts/game_manager.gd").new()
		manager.score = 0
		manager.score_fraction = 0.0
		manager.multiplier = 1
		for _frame in int(fps * DURATION_SECONDS):
			manager._accrue_driving_score(SPEED_MPS, 1.0 / float(fps))
		results[fps] = manager.score
		manager.audio.free()
		manager.free()
	var theoretical := SPEED_MPS * DURATION_SECONDS * RATE
	_check(int(results[30]) > 0, "driving score is still normally zero")
	for fps in [30, 60, 120]:
		_check(absf(float(results[fps]) - theoretical) < 1.0, "%d FPS result diverges from theoretical rate: %s vs %.3f" % [fps, results[fps], theoretical])
	_check(absi(int(results[30]) - int(results[60])) <= 1, "30/60 FPS score mismatch")
	_check(absi(int(results[60]) - int(results[120])) <= 1, "60/120 FPS score mismatch")
	var doubled: Node = load("res://scripts/game_manager.gd").new()
	doubled.multiplier = 2
	for _frame in 600:
		doubled._accrue_driving_score(10.0, 1.0 / 60.0)
	_check(absi(doubled.score - 160) <= 1, "existing multiplier no longer doubles theoretical driving score")
	doubled.audio.free()
	doubled.free()
	print("GAMEPLAY_SCORE_FPS_RESULTS fps30=", results[30], " fps60=", results[60], " fps120=", results[120], " theoretical=", theoretical)
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("GAMEPLAY_SCORE_FRAMERATE_RESULT PASS")
	else:
		for failure in failures:
			printerr("GAMEPLAY_SCORE_FRAMERATE_FAIL ", failure)
		print("GAMEPLAY_SCORE_FRAMERATE_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
