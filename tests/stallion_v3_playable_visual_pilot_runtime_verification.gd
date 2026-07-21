extends SceneTree

const REPORT_PATH := "res://reports/stallion_v3_playable_visual_pilot_metrics.txt"
const SCREENSHOT_ROOT := "res://screenshots/playable_visual_integration_pilot/"
const WARMUP_SECONDS := 5.0
const SAMPLE_SECONDS := 15.0
const SUSTAINED_WINDOW := 30
const BASELINE_DRAW_CALLS := 823
const BASELINE_PRIMITIVES := 100146
const BASELINE_NODES := 860
const BASELINE_MEMORY_MB := 51.32
const BASELINE_LOAD_MS := 368.65

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
	print("STALLION_V3_PLAYABLE_RUNTIME_START")
	var load_started := Time.get_ticks_usec()
	var packed := load("res://scenes/main/Boot.tscn") as PackedScene
	_check(packed != null, "Boot.tscn failed to load")
	if packed == null:
		await _finish(0.0, null)
		return
	var boot := packed.instantiate()
	root.add_child(boot)
	await process_frame
	boot.run_mode = "STAGE"
	boot.save.vehicle = 0
	boot.start_game()
	await process_frame
	await RenderingServer.frame_post_draw
	var load_time_ms := (Time.get_ticks_usec() - load_started) / 1000.0
	_check(boot.scene_file_path == "res://scenes/main/Boot.tscn", "runtime source is not Boot.tscn")
	_check(boot.player is VehicleController and boot.road is RoadManager and boot.hud is GameHUD, "real Boot gameplay graph did not start")
	_check(bool(boot.player.visual.get_meta("stallion_v3_visual_pilot", false)), "Boot player is not Stallion V3")
	_check(str(boot.player.visual.get_meta("stallion_v3_variant", "")) == "rally_sand", "Boot player is not Rally Sand")
	var warmup_started := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - warmup_started) / 1000000.0 < WARMUP_SECONDS:
		await process_frame
	Input.action_press("accelerate")
	var sample_started := Time.get_ticks_usec()
	var previous_ticks := sample_started
	while (Time.get_ticks_usec() - sample_started) / 1000000.0 < SAMPLE_SECONDS:
		if boot.player == null:
			failures.append("production gameplay ended during runtime sample")
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
	_check(boot.screen == boot.Screen.GAME and boot.player != null, "Prova Speciale ended during sample")
	if boot.player != null:
		boot.player.controls_enabled = false
		boot.player.speed = 0.0
		boot.player.velocity = Vector3.ZERO
		var current_route_index: int = int(boot.road.route_index_near(boot.player.global_position))
		var capture_segment: Node3D = null
		for offset in range(2, 9):
			var wanted: int = current_route_index + offset
			for segment in boot.road.segments:
				if int(segment.get_meta("route_index", -1)) == wanted:
					capture_segment = segment
					break
			if capture_segment != null:
				break
		_check(capture_segment != null, "no active road segment available for screenshots")
		if capture_segment != null:
			boot.player.global_transform = Transform3D(capture_segment.global_basis, capture_segment.to_global(Vector3(0.0, 0.1, 0.0)))
			boot.player.reset_physics_interpolation()
			boot.player.offroad = false
			boot.player.surface = str(capture_segment.get_meta("surface", "ASPHALT"))
		boot.hud.message_label.text = ""
		boot.hud.warning_label.text = ""
		await _capture_runtime_views(boot)
	await _finish(load_time_ms, boot)

func _capture_runtime_views(boot: Node) -> void:
	boot.camera.set_process(false)
	await _capture(boot, "stallion_v3_runtime_rear.png", Vector3(2.3, 1.7, 4.6), Vector3(0.0, 0.9, 0.0))
	await _capture(boot, "stallion_v3_runtime_side.png", Vector3(4.7, 1.45, 0.0), Vector3(0.0, 0.82, 0.0))
	await _capture(boot, "stallion_v3_runtime_front_threequarter.png", Vector3(-3.2, 1.7, -4.4), Vector3(0.0, 0.88, 0.0))
	await _capture(boot, "stallion_v3_wheel_alignment.png", Vector3(3.7, 0.9, 0.15), Vector3(0.0, 0.47, 0.0))
	var previous_v3 := VehicleFactory.use_stallion_v3_visual_pilot
	VehicleFactory.use_stallion_v3_visual_pilot = false
	var v2 := VehicleFactory.create_vehicle(0, false)
	VehicleFactory.use_stallion_v3_visual_pilot = previous_v3
	v2.position = boot.player.position + boot.player.basis * Vector3(3.0, 0.0, 0.0)
	v2.rotation = boot.player.rotation
	boot.world.add_child(v2)
	var label := Label.new()
	label.text = "RUNTIME: V3 RALLY SAND (SINISTRA)  /  V2 FALLBACK (DESTRA)"
	label.position = Vector2(315, 660)
	label.add_theme_font_size_override("font_size", 20)
	boot.hud.add_child(label)
	await _capture(boot, "stallion_v2_v3_runtime_comparison.png", Vector3(1.5, 1.9, 5.6), Vector3(1.5, 0.85, 0.0))
	label.queue_free()
	v2.queue_free()

func _capture(boot: Node, file_name: String, local_camera: Vector3, local_target: Vector3) -> void:
	boot.hud.message_label.text = ""
	boot.hud.warning_label.text = ""
	boot.camera.global_position = boot.player.to_global(local_camera)
	boot.camera.look_at(boot.player.to_global(local_target), Vector3.UP)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(SCREENSHOT_ROOT + file_name))
	_check(error == OK, "could not save screenshot " + file_name)

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
	_check(average_fps >= 58.0, "average FPS is not approximately 60")
	_check(sustained_minimum >= 55.0, "sustained FPS is below 55")
	_check(not recurring_stutter, "recurring stutter detected")
	_check(peak_draw_calls <= BASELINE_DRAW_CALLS + 150, "draw-call regression is uncontrolled")
	_check(peak_primitives <= int(BASELINE_PRIMITIVES * 1.75), "primitive regression is uncontrolled")
	_check(peak_nodes <= BASELINE_NODES + 150, "node regression is uncontrolled")
	_check(peak_static_memory / 1048576.0 <= BASELINE_MEMORY_MB + 20.0, "memory regression is uncontrolled")
	_check(load_time_ms <= BASELINE_LOAD_MS + 500.0, "load-time regression exceeds the controlled sub-second gate")
	var viewport_size := root.get_viewport().get_visible_rect().size
	var report := "Desert Velocity G1-C Stallion V3 playable visual pilot\n"
	report += "source_scene=res://scenes/main/Boot.tscn\nproduction_gameplay=true\nmode=STAGE\nruntime_vehicle=STALLION V3 RALLY SAND\n"
	report += "factory_flag=use_stallion_v3_visual_pilot=true\nfallback=STALLION V2\nwrapper=res://scenes/visual/production/StallionV3PlayableVisual.tscn\n"
	report += "glb=res://assets/models/vehicles/desert_stallion_v3.glb\nlod=LOD0\nscale=1.0\nmodel_offset=(0.0,0.04,0.0)\nmeshes_lod0=14\nmaterials_reconstructed=7\ntriangles_lod0=54268\n"
	report += "wheel_centers=FL(-0.88,0.47,-1.41);FR(0.88,0.47,-1.41);RL(-0.88,0.47,1.41);RR(0.88,0.47,1.41)\n"
	report += "renderer=%s\ngpu=%s\nresolution=%dx%d\n" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), int(viewport_size.x), int(viewport_size.y)]
	report += "warmup_seconds=%.2f\nsample_seconds=%.2f\nframe_samples=%d\n" % [WARMUP_SECONDS, SAMPLE_SECONDS, fps_values.size()]
	report += "average_fps=%.2f\npercentile_5_fps=%.2f\nminimum_sustained_fps=%.2f\ninstantaneous_minimum_fps=%.2f\n" % [average_fps, p5, sustained_minimum, instantaneous_minimum]
	report += "average_frame_time_ms=%.3f\nmedian_frame_time_ms=%.3f\nstutter_threshold_ms=%.3f\nstutter_frames=%d\nmax_consecutive_stutter_frames=%d\nrecurring_stutter=%s\n" % [average_frame_time, median_frame_time, stutter_threshold, stutter_frames, max_stutter_run, str(recurring_stutter).to_lower()]
	report += "peak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\npeak_static_memory_mb=%.2f\nload_time_ms=%.2f\n" % [peak_draw_calls, peak_primitives, peak_nodes, peak_static_memory / 1048576.0, load_time_ms]
	report += "baseline_draw_calls=%d\nbaseline_primitives=%d\nbaseline_nodes=%d\nbaseline_static_memory_mb=%.2f\nbaseline_load_time_ms=%.2f\n" % [BASELINE_DRAW_CALLS, BASELINE_PRIMITIVES, BASELINE_NODES, BASELINE_MEMORY_MB, BASELINE_LOAD_MS]
	report += "load_time_delta_ms=%.2f\nload_time_gate_ms=%.2f\n" % [load_time_ms - BASELINE_LOAD_MS, BASELINE_LOAD_MS + 500.0]
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
		print("STALLION_V3_PLAYABLE_RUNTIME_RESULT PASS")
	else:
		for failure in failures:
			printerr("STALLION_V3_PLAYABLE_RUNTIME_FAIL ", failure)
		print("STALLION_V3_PLAYABLE_RUNTIME_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _average(values: PackedFloat64Array) -> float:
	if values.is_empty(): return 0.0
	var total := 0.0
	for value in values: total += value
	return total / values.size()

func _minimum_rolling_fps(window: int) -> float:
	if fps_values.is_empty(): return 0.0
	var actual := mini(window, fps_values.size())
	var total := 0.0
	for index in actual: total += fps_values[index]
	var result := total / actual
	for index in range(actual, fps_values.size()):
		total += fps_values[index] - fps_values[index - actual]
		result = minf(result, total / actual)
	return result

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
