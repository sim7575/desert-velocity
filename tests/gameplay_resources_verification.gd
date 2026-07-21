extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _test_fuel_health_turbo_multiplier()
	await _test_timer_and_penalties()
	await _test_checkpoints_finish_and_restart()
	await _test_landing_damage_characterization()
	for child in root.get_children():
		child.queue_free()
	for _frame in 8:
		await process_frame
	_finish()

func _make_manager(mode: String) -> Node:
	var manager: Node = load("res://scripts/game_manager.gd").new()
	root.add_child(manager)
	await process_frame
	manager.run_mode = mode
	manager.start_game()
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.road.set_process(false)
	for _frame in 3:
		await process_frame
	return manager

func _dispose(manager: Node) -> void:
	if is_instance_valid(manager):
		manager.queue_free()
	for _frame in 5:
		await process_frame

func _test_fuel_health_turbo_multiplier() -> void:
	var manager := await _make_manager("ENDURANCE")
	_check(is_equal_approx(manager.fuel, BalanceData.START_FUEL), "initial fuel changed")
	_check(is_equal_approx(manager.health, BalanceData.START_HEALTH), "initial integrity changed")
	_check(manager.score == 0 and manager.multiplier == 1 and is_zero_approx(manager.player.turbo_time), "initial score/multiplier/turbo changed")
	manager.player.speed = 20.0
	manager._update_game(1.0)
	var expected_fuel := 100.0 - BalanceData.FUEL_DRAIN * (0.3 + 20.0 / 40.0)
	_check(is_equal_approx(manager.fuel, expected_fuel), "fuel drain formula changed")
	var without_turbo: float = manager.fuel
	manager.fuel = 100.0
	manager.player.turbo_time = 5.0
	manager._update_game(1.0)
	_check(is_equal_approx(manager.fuel, expected_fuel), "turbo directly changed fuel drain at equal speed")
	_check(not is_equal_approx(without_turbo, 100.0), "fuel did not drain while driving")
	manager.player.activate_turbo()
	_check(is_equal_approx(manager.player.turbo_time, 5.0), "turbo activation duration changed")
	manager.player.speed = float(manager.player.stats.max_speed)
	Input.action_press("accelerate")
	manager.player._physics_process(0.1)
	Input.action_release("accelerate")
	_check(manager.player.speed > float(manager.player.stats.max_speed), "turbo no longer exposes increased speed ceiling")
	manager.player.controls_enabled = false
	manager.player._physics_process(2.0)
	_check(is_equal_approx(manager.player.turbo_time, 2.9), "turbo countdown changed")
	manager.player._physics_process(3.0)
	_check(is_zero_approx(manager.player.turbo_time), "turbo did not deactivate at zero")
	manager.player._physics_process(1.0)
	_check(is_zero_approx(manager.player.turbo_time), "turbo recharged without an activation event")
	manager.player.turbo_time = 2.5
	manager.player.speed = 0.0
	manager._update_game(0.0)
	_check(is_equal_approx(manager.hud.turbo_bar.value, 50.0), "turbo is not exposed to HUD")
	manager._on_crash(15.0)
	_check(is_equal_approx(manager.health, 85.0), "collision damage changed")
	manager.health = 90.0
	var repair := Area3D.new()
	root.add_child(repair)
	manager._collect(2, repair)
	_check(is_equal_approx(manager.health, 100.0), "repair cap changed")
	manager.health = 42.0
	manager._update_game(0.0)
	_check(is_equal_approx(manager.hud.health_bar.value, 42.0), "integrity is not exposed to HUD")
	manager.multiplier = 1
	manager.score = 0
	manager.score_fraction = 0.0
	var multiplier_pickup := Area3D.new()
	root.add_child(multiplier_pickup)
	manager._collect(4, multiplier_pickup)
	_check(manager.multiplier == 2 and is_equal_approx(manager.multiplier_time, 10.0), "multiplier activation changed")
	manager.player.speed = 10.0
	manager._update_game(1.0)
	_check(manager.score == 16, "multiplier no longer doubles driving score")
	manager.multiplier_time = 0.0
	manager.player.speed = 0.0
	manager._update_game(0.0)
	_check(manager.multiplier == 1, "multiplier reset changed")
	manager.fuel = 0.1
	manager.player.speed = 20.0
	manager._update_game(1.0)
	_check(manager.screen == manager.Screen.GAME_OVER and is_zero_approx(manager.fuel), "fuel exhaustion consequence changed")
	manager.run_mode = "ENDURANCE"
	manager.start_game()
	await process_frame
	_check(is_equal_approx(manager.fuel, 100.0) and is_equal_approx(manager.health, 100.0), "new race did not reset fuel/integrity")
	_check(manager.score == 0 and is_zero_approx(manager.score_fraction) and manager.multiplier == 1, "new race did not reset score state")
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.health = 0.0
	manager._update_game(0.0)
	_check(manager.screen == manager.Screen.GAME_OVER, "zero integrity consequence changed")
	await _dispose(manager)

func _test_timer_and_penalties() -> void:
	var manager := await _make_manager("STAGE")
	for fps in [30, 60, 120]:
		manager.stage_time = 0.0
		manager.stage_penalty = 0.0
		manager.countdown = 0.0
		manager.player.controls_enabled = true
		manager.player.speed = 0.0
		manager.player.offroad = false
		for _frame in fps * 2:
			manager._update_game(1.0 / float(fps))
		_check(absf(manager.stage_time - 2.0) < 0.0001, "stage timer depends on %d FPS" % fps)
	manager.stage_time = 0.0
	manager.stage_penalty = 0.0
	manager.countdown = 2.0
	Input.action_press("accelerate")
	manager._update_game(1.0)
	Input.action_release("accelerate")
	_check(is_zero_approx(manager.stage_time) and is_equal_approx(manager.stage_penalty, 0.5), "countdown penalty changed")
	manager.countdown = 0.0
	manager.player.offroad = true
	manager.player.offroad_duration = 4.0
	manager._update_game(2.0)
	_check(is_equal_approx(manager.stage_penalty, 1.2), "off-road penalty changed")
	manager._on_crash(14.0)
	_check(is_equal_approx(manager.stage_penalty, 3.2), "collision penalty changed")
	manager.score = 500
	manager._on_repositioned(false)
	_check(is_equal_approx(manager.stage_penalty, 8.2), "reposition penalty changed")
	_check(manager.score == 250 and is_equal_approx(manager.health, 78.0), "reposition score/integrity consequences changed")
	manager.player.offroad = false
	manager.player.speed = 0.0
	manager._update_game(0.0)
	_check("+8.2s" in manager.hud.rally_label.text, "penalty is not exposed to HUD")
	manager.start_game()
	await process_frame
	_check(is_zero_approx(manager.stage_time) and is_zero_approx(manager.stage_penalty), "new stage did not reset timer/penalties")
	await _dispose(manager)

func _test_checkpoints_finish_and_restart() -> void:
	var manager := await _make_manager("STAGE")
	manager.countdown = 0.0
	manager.player.controls_enabled = true
	var segment: Node3D = manager.road.segments[0]
	segment.set_meta("route_index", 8)
	manager.player.global_position = segment.global_position + Vector3.UP * 0.1
	manager._update_game(0.0)
	_check(manager.stage_checkpoint == 0, "checkpoint advanced before its ordered route threshold")
	segment.set_meta("route_index", 9)
	manager.player.global_position = segment.to_global(Vector3(BalanceData.ROAD_HALF_WIDTH + 2.0, 0.1, 0.0))
	manager._update_game(0.0)
	_check(manager.stage_checkpoint == 0, "off-road checkpoint was accepted")
	manager.player.global_position = segment.global_position + Vector3.UP * 0.1
	manager._update_game(0.0)
	_check(manager.stage_checkpoint == 1, "first ordered checkpoint did not advance")
	segment.set_meta("route_index", 19)
	manager._update_game(0.0)
	_check(manager.stage_checkpoint == 2, "second ordered checkpoint did not advance")
	manager.stage_checkpoint = 4
	segment.set_meta("route_index", 63)
	manager._update_game(0.0)
	_check(manager.stage_checkpoint == 5 and manager.screen == manager.Screen.GAME, "race completed without all checkpoints")
	manager._update_game(0.0)
	await process_frame
	_check(manager.screen == manager.Screen.GAME_OVER, "finish did not complete after sixth checkpoint")
	manager.run_mode = "STAGE"
	manager.start_game()
	await process_frame
	_check(manager.screen == manager.Screen.GAME and manager.stage_checkpoint == 0 and manager.countdown > 0.0, "stage restart state changed")
	await _dispose(manager)

func _test_landing_damage_characterization() -> void:
	var manager := await _make_manager("STAGE")
	var vehicle: VehicleController = manager.player
	var initial_health: float = manager.health
	vehicle.controls_enabled = false
	vehicle.damage_level = 0.0
	vehicle.global_transform = manager.road.safe_transform_near(manager.road.segments[0].global_position)
	vehicle.global_position.y += 3.0
	vehicle.velocity = Vector3(0.0, -12.0, 0.0)
	vehicle.airborne = true
	vehicle.air_time = 0.25
	vehicle.air_start_height = vehicle.global_position.y
	for _frame in 180:
		vehicle._physics_process(1.0 / 60.0)
		await physics_frame
		if vehicle.last_air_time > 0.0:
			break
	_check(vehicle.last_air_time > 0.0, "landing characterization did not reach the ground")
	var expected_damage_level := clampf(maxf(0.0, vehicle.landing_impact - 5.0) * 0.018, 0.0, 1.0)
	_check(is_equal_approx(vehicle.damage_level, expected_damage_level), "landing damage_level formula changed")
	_check(is_equal_approx(manager.health, initial_health), "landing unexpectedly changed GameManager integrity")
	print("GAMEPLAY_LANDING_CHARACTERIZATION impact=", vehicle.landing_impact, " damage_level=", vehicle.damage_level, " health=", manager.health)
	await _dispose(manager)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	Input.action_release("accelerate")
	if failures.is_empty():
		print("GAMEPLAY_RESOURCES_RESULT PASS")
	else:
		for failure in failures:
			printerr("GAMEPLAY_RESOURCES_FAIL ", failure)
		print("GAMEPLAY_RESOURCES_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
