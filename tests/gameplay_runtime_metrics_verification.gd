extends SceneTree

const REPORT_PATH := "res://reports/gameplay_runtime_baseline_before_visual_integration.txt"
const WARMUP_SECONDS := 5.0
const SAMPLE_SECONDS := 15.0
const SUSTAINED_WINDOW := 30

var failures: Array[String] = []
var fps_values := PackedFloat64Array()
var frame_times_ms := PackedFloat64Array()
var peak_draw_calls := 0
var peak_primitives := 0
var peak_nodes := 0
var peak_static_memory := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var load_started := Time.get_ticks_usec()
	var packed := load("res://scenes/main/Boot.tscn") as PackedScene
	_check(packed != null, "Boot.tscn failed to load")
	if packed == null:
		await _finish(0.0, null)
		return
	var boot: Node = packed.instantiate()
	root.add_child(boot)
	await process_frame
	boot.run_mode = "STAGE"
	boot.start_game()
	await process_frame
	await RenderingServer.frame_post_draw
	var load_time_ms := (Time.get_ticks_usec() - load_started) / 1000.0
	_check(boot.scene_file_path == "res://scenes/main/Boot.tscn", "metrics source is not Boot.tscn")
	_check(boot.player is VehicleController and boot.road is RoadManager and boot.hud is GameHUD, "real production gameplay graph did not start")
	var warmup_started := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - warmup_started) / 1000000.0 < WARMUP_SECONDS:
		await process_frame
	Input.action_press("accelerate")
	var sample_started := Time.get_ticks_usec()
	var previous_ticks := sample_started
	while (Time.get_ticks_usec() - sample_started) / 1000000.0 < SAMPLE_SECONDS:
		if boot.player == null:
			failures.append("production gameplay ended before metrics sample completed")
			break
		var toward_center: Vector3 = boot.road.direction_to_center(boot.player.global_position)
		var steer_side := toward_center.dot(boot.player.global_transform.basis.x)
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		if absf(boot.road.road_local_position(boot.player.global_position).x) > 2.0:
			Input.action_press("steer_right" if steer_side > 0.0 else "steer_left")
		await process_frame
		var now := Time.get_ticks_usec()
		var delta := maxf((now - previous_ticks) / 1000000.0, 0.000001)
		previous_ticks = now
		fps_values.append(1.0 / delta)
		frame_times_ms.append(delta * 1000.0)
		peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		peak_primitives = maxi(peak_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_static_memory = maxi(peak_static_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	Input.action_release("accelerate")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	_check(fps_values.size() > 300, "runtime sample is too short")
	_check(boot.screen == boot.Screen.GAME, "gameplay ended before metrics sample completed")
	_check(boot.player != null and boot.player.speed > 5.0 and boot.distance > 100.0, "sample did not contain real driving")
	await _finish(load_time_ms, boot)

func _finish(load_time_ms: float, boot: Node) -> void:
	var sorted_fps := fps_values.duplicate()
	sorted_fps.sort()
	var sorted_frame_times := frame_times_ms.duplicate()
	sorted_frame_times.sort()
	var average_fps := _average(fps_values)
	var p5 := sorted_fps[clampi(int(floor((sorted_fps.size() - 1) * 0.05)), 0, maxi(0, sorted_fps.size() - 1))] if not sorted_fps.is_empty() else 0.0
	var instantaneous_minimum := sorted_fps[0] if not sorted_fps.is_empty() else 0.0
	var sustained_minimum := _minimum_rolling_fps(SUSTAINED_WINDOW)
	var average_frame_time := _average(frame_times_ms)
	var median_frame_time := sorted_frame_times[int(sorted_frame_times.size() / 2)] if not sorted_frame_times.is_empty() else 0.0
	var stutter_threshold := maxf(33.333, median_frame_time * 2.0)
	var stutter_frames := 0
	var max_stutter_run := 0
	var current_stutter_run := 0
	for frame_time in frame_times_ms:
		if frame_time > stutter_threshold:
			stutter_frames += 1
			current_stutter_run += 1
			max_stutter_run = maxi(max_stutter_run, current_stutter_run)
		else:
			current_stutter_run = 0
	var recurring_stutter := max_stutter_run >= 3 or stutter_frames > int(frame_times_ms.size() * 0.01)
	var viewport_size := root.get_viewport().get_visible_rect().size
	var report := "Desert Velocity gameplay runtime baseline before visual integration\n"
	report += "source_scene=res://scenes/main/Boot.tscn\nproduction_gameplay=true\nmode=STAGE\n"
	report += "renderer=%s\ngpu=%s\nresolution=%dx%d\n" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), int(viewport_size.x), int(viewport_size.y)]
	report += "warmup_seconds=%.2f\nsample_seconds=%.2f\nframe_samples=%d\n" % [WARMUP_SECONDS, SAMPLE_SECONDS, fps_values.size()]
	report += "average_fps=%.2f\npercentile_5_fps=%.2f\nminimum_sustained_fps=%.2f\ninstantaneous_minimum_fps=%.2f\n" % [average_fps, p5, sustained_minimum, instantaneous_minimum]
	report += "average_frame_time_ms=%.3f\nmedian_frame_time_ms=%.3f\nstutter_threshold_ms=%.3f\nstutter_frames=%d\nmax_consecutive_stutter_frames=%d\nrecurring_stutter=%s\n" % [average_frame_time, median_frame_time, stutter_threshold, stutter_frames, max_stutter_run, str(recurring_stutter).to_lower()]
	report += "peak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\npeak_static_memory_mb=%.2f\nload_time_ms=%.2f\n" % [peak_draw_calls, peak_primitives, peak_nodes, peak_static_memory / 1048576.0, load_time_ms]
	if boot != null and is_instance_valid(boot) and boot.player != null:
		report += "driving_distance_m=%.2f\nfinal_speed_kmh=%d\nscore=%d\ncheckpoint=%d/6\n" % [boot.distance, boot.player.speed_kmh(), boot.score, boot.stage_checkpoint]
	report += "classification=%s\n" % ("PASS" if failures.is_empty() else "FAIL")
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("runtime metrics report could not be written")
	else:
		file.store_string(report)
		file.close()
	print(report)
	if boot != null and is_instance_valid(boot):
		boot.queue_free()
	for _frame in 8:
		await process_frame
	if failures.is_empty():
		print("GAMEPLAY_RUNTIME_METRICS_RESULT PASS")
	else:
		for failure in failures:
			printerr("GAMEPLAY_RUNTIME_METRICS_FAIL ", failure)
		print("GAMEPLAY_RUNTIME_METRICS_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _average(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()

func _minimum_rolling_fps(window: int) -> float:
	if fps_values.is_empty():
		return 0.0
	var actual := mini(window, fps_values.size())
	var total := 0.0
	for index in actual:
		total += fps_values[index]
	var result := total / actual
	for index in range(actual, fps_values.size()):
		total += fps_values[index] - fps_values[index - actual]
		result = minf(result, total / actual)
	return result

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
