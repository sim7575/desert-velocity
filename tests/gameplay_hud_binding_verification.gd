extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var hud := GameHUD.new()
	root.add_child(hud)
	await process_frame
	hud.update_values(321, 654.9, 123, 76.5, 42.0, 2, 999, 2.5)
	_check("0000321" in hud.stats_label.text, "score is not bound to production HUD")
	_check("0000999" in hud.stats_label.text, "record is not bound to production HUD")
	_check("000654m" in hud.stats_label.text, "distance is not bound to production HUD")
	_check("123 km/h" in hud.stats_label.text, "speed is not bound to production HUD")
	_check("x2" in hud.stats_label.text, "multiplier is not bound to production HUD")
	_check(is_equal_approx(hud.fuel_bar.value, 76.5), "fuel is not bound to production HUD")
	_check(is_equal_approx(hud.health_bar.value, 42.0), "integrity is not bound to production HUD")
	_check(is_equal_approx(hud.turbo_bar.value, 50.0), "turbo is not bound to production HUD")
	var vehicle := VehicleController.new()
	vehicle.simulated_gear = 4
	vehicle.simulated_rpm = 5432.0
	vehicle.surface = "GRAVEL"
	hud.update_rally(true, 72.34, 8.5, 3, 6, vehicle, {"text":"DESTRA 4", "distance":87.0, "direction":-1})
	_check("TEMPO  01:12" in hud.rally_label.text, "residual timer is not bound to production HUD")
	_check("+8.5s" in hud.rally_label.text, "penalty is not bound to production HUD")
	_check("CP  3/6" in hud.rally_label.text, "checkpoint is not bound to production HUD")
	_check("MARCIA  4" in hud.rally_label.text, "gear is not bound to production HUD")
	_check("RPM 5432" in hud.rally_label.text, "RPM is not bound to production HUD")
	_check("GRAVEL" in hud.rally_label.text, "surface is not bound to production HUD")
	_check("DESTRA 4" in hud.pacenote_label.text and "87 m" in hud.pacenote_label.text, "pacenote is not bound to production HUD")
	vehicle.free()
	hud.queue_free()
	for _frame in 3:
		await process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("GAMEPLAY_HUD_BINDING_RESULT PASS")
	else:
		for failure in failures:
			printerr("GAMEPLAY_HUD_BINDING_FAIL ", failure)
		print("GAMEPLAY_HUD_BINDING_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
