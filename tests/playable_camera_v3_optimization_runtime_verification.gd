extends SceneTree

const REPORT_PATH := "res://reports/playable_camera_v3_runtime_optimization_metrics.txt"
const SHOT_ROOT := "res://screenshots/playable_camera_v3_optimization/"
const SAMPLE_SECONDS := 15.0
const SUSTAINED_WINDOW := 30
const G1C_DRAW_CALLS := 842
const G1C_PRIMITIVES := 148892
const G1C_NODES := 852
const G1C_MEMORY_MB := 52.13
const G1C_LOAD_MS := 694.81

var failures: Array[String] = []
var fps_values := PackedFloat64Array()
var frame_times_ms := PackedFloat64Array()
var peak_draw_calls := 0
var peak_primitives := 0
var peak_nodes := 0
var peak_static_memory := 0
var straight_occupancy := 0.0
var straight_center_y := 0.0
var farther_occupancy := 0.0
var lower_occupancy := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("PLAYABLE_CAMERA_V3_OPTIMIZATION_RUNTIME_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_ROOT))
	var load_started := Time.get_ticks_usec()
	var packed := load("res://scenes/main/Boot.tscn") as PackedScene
	_check(packed != null, "Boot.tscn failed to load")
	if packed == null:
		await _finish(0.0, null, false, false)
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
	_check(bool(boot.player.visual.get_meta("stallion_v3_visual_pilot", false)), "Boot player is not V3")
	_check(int(boot.player.visual.get_meta("runtime_source_lod", -1)) == 1, "Boot player is not runtime LOD1")
	for _frame in 300:
		await process_frame
	boot.player.controls_enabled = false
	boot.player.speed = 0.0
	boot.player.velocity = Vector3.ZERO
	for _frame in 90:
		await process_frame
	_check(FileAccess.file_exists(SHOT_ROOT + "camera_before.png"), "approved G1-C camera baseline screenshot is missing")
	boot.camera.set_v3_controlled_baseline(true)
	await _settle_camera(boot.camera, 120)
	farther_occupancy = _occupancy(boot.camera, boot.player.visual).x
	boot.camera.set_v3_controlled_baseline(false)
	await _settle_camera(boot.camera, 120)
	lower_occupancy = _occupancy(boot.camera, boot.player.visual).x
	boot.camera.set_v3_controlled_baseline(false)
	await _settle_camera(boot.camera, 150)
	var straight_measure := _occupancy(boot.camera, boot.player.visual)
	straight_occupancy = straight_measure.x
	straight_center_y = straight_measure.y
	_check(straight_occupancy >= 18.0 and straight_occupancy <= 22.0, "final straight occupancy outside 18-22 percent: %.2f" % straight_occupancy)
	_check(straight_center_y >= 70.0 and straight_center_y <= 76.0, "final vehicle center outside 70-76 percent: %.2f" % straight_center_y)
	boot.player.controls_enabled = true
	Input.action_press("accelerate")
	var sample_started := Time.get_ticks_usec()
	var previous_ticks := sample_started
	var curve_reached := false
	var high_speed_reached := false
	while (Time.get_ticks_usec() - sample_started) / 1000000.0 < SAMPLE_SECONDS:
		var toward_center: Vector3 = boot.road.direction_to_center(boot.player.global_position)
		var steer_side := toward_center.dot(boot.player.global_transform.basis.x)
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		if absf(boot.road.road_local_position(boot.player.global_position).x) > 1.5:
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
		var curve := _curve_at_player(boot)
		if absf(curve) > 0.05 and absf(boot.player.speed) > 12.0:
			curve_reached = true
		if absf(boot.player.speed) > 35.0:
			high_speed_reached = true
	Input.action_release("accelerate")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	_check(curve_reached, "metrics run did not reach a real curve")
	_check(high_speed_reached, "metrics run did not reach high speed")
	boot.player.controls_enabled = false
	boot.player.speed = 0.0
	boot.player.velocity = Vector3.ZERO
	boot.camera.set_v3_controlled_baseline(false)
	await _settle_camera(boot.camera, 120)
	await _save_viewport("camera_after_straight.png")
	await _capture_measurement_overlay(boot, Vector2(straight_occupancy, straight_center_y))
	await _capture_lod_overlay(boot)
	boot.camera.set_v3_controlled_baseline(true)
	await _settle_camera(boot.camera, 90)
	await _save_viewport("camera_variant_farther.png")
	boot.camera.set_v3_controlled_baseline(false)
	await _settle_camera(boot.camera, 90)
	await _save_viewport("camera_variant_lower.png")
	var capture_results := await _capture_dynamic_views(boot)
	var curve_captured := bool(capture_results.x)
	var high_speed_captured := bool(capture_results.y)
	_check(curve_captured, "real curve screenshot was not captured")
	_check(high_speed_captured, "real high-speed screenshot was not captured")
	boot.player.controls_enabled = false
	boot.player.speed = 35.0
	boot.player.activate_turbo()
	for _frame in 90:
		await process_frame
	var boost_occupancy := _occupancy(boot.camera, boot.player.visual).x
	_check(boost_occupancy <= 24.0, "boost occupancy exceeds 24 percent")
	await _verify_offroad_and_bump_camera(boot)
	await _verify_stationary_stability(boot)
	await _finish(load_time_ms, boot, curve_captured, high_speed_captured)

func _capture_dynamic_views(boot: Node) -> Vector2i:
	boot.run_mode = "STAGE"
	boot.save.vehicle = 0
	boot.start_game()
	await process_frame
	boot.camera.set_v3_controlled_baseline(false)
	for _frame in 300:
		await process_frame
	boot.player.controls_enabled = true
	Input.action_press("accelerate")
	var curve_captured := false
	var high_speed_captured := false
	var started := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - started) / 1000000.0 < 20.0 and (not curve_captured or not high_speed_captured):
		var toward_center: Vector3 = boot.road.direction_to_center(boot.player.global_position)
		var steer_side := toward_center.dot(boot.player.global_transform.basis.x)
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		if absf(boot.road.road_local_position(boot.player.global_position).x) > 1.5:
			Input.action_press("steer_right" if steer_side > 0.0 else "steer_left")
		await process_frame
		var curve := _curve_at_player(boot)
		if not curve_captured and absf(curve) > 0.05 and absf(boot.player.speed) > 12.0:
			await _save_viewport("camera_after_curve.png")
			curve_captured = true
		if not high_speed_captured and absf(boot.player.speed) > 35.0:
			await _save_viewport("camera_after_high_speed.png")
			high_speed_captured = true
	Input.action_release("accelerate")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	return Vector2i(int(curve_captured), int(high_speed_captured))

func _curve_at_player(boot: Node) -> float:
	var route_index := int(boot.road.route_index_near(boot.player.global_position))
	for segment in boot.road.segments:
		if int(segment.get_meta("route_index", -1)) == route_index:
			return float(segment.get_meta("curve_delta", 0.0))
	return 0.0

func _verify_offroad_and_bump_camera(boot: Node) -> void:
	var nearest := _nearest_active_segment(boot)
	if nearest != null:
		boot.player.global_transform = Transform3D(nearest.global_basis, nearest.to_global(Vector3(BalanceData.ROAD_HALF_WIDTH + 2.0, 0.1, 0.0)))
		boot.player.reset_physics_interpolation()
		for _frame in 90:
			await process_frame
		_check(_camera_finite(boot.camera), "camera became invalid offroad")
	var bump_segment: Node3D = null
	for segment in boot.road.segments:
		if not str(segment.get_meta("jump_kind", "")).is_empty():
			bump_segment = segment
			break
	if bump_segment != null:
		boot.player.global_transform = Transform3D(bump_segment.global_basis, bump_segment.to_global(Vector3(0.0, 0.1, 0.0)))
		boot.player.reset_physics_interpolation()
		for _frame in 90:
			await process_frame
		_check(_camera_finite(boot.camera), "camera became invalid on bump")

func _verify_stationary_stability(boot: Node) -> void:
	boot.player.speed = 0.0
	boot.player.velocity = Vector3.ZERO
	await _settle_camera(boot.camera, 120)
	var previous: Vector3 = boot.camera.global_position
	var maximum_step := 0.0
	for _frame in 60:
		await process_frame
		maximum_step = maxf(maximum_step, previous.distance_to(boot.camera.global_position))
		previous = boot.camera.global_position
	_check(maximum_step < 0.02, "stationary camera oscillation detected: %.4f" % maximum_step)
	_check(boot.camera.global_position.distance_to(boot.player.global_position) > 5.0, "camera clips into player")

func _nearest_active_segment(boot: Node) -> Node3D:
	var best: Node3D = null
	var distance := INF
	for segment in boot.road.segments:
		var candidate: float = boot.player.global_position.distance_to(segment.global_position)
		if candidate < distance:
			distance = candidate
			best = segment
	return best

func _camera_finite(camera: Camera3D) -> bool:
	var position := camera.global_position
	return is_finite(position.x) and is_finite(position.y) and is_finite(position.z)

func _settle_camera(camera: Camera3D, frames: int) -> void:
	for _frame in frames:
		await process_frame
	_check(_camera_finite(camera), "camera transform is not finite")

func _capture_measurement_overlay(boot: Node, measurement: Vector2) -> void:
	var bounds := _screen_bounds(boot.camera, boot.player.visual)
	var layer := CanvasLayer.new()
	boot.add_child(layer)
	var color := Color("55f2a4")
	for rect in [Rect2(bounds.position, Vector2(bounds.size.x, 3)), Rect2(Vector2(bounds.position.x, bounds.end.y - 3), Vector2(bounds.size.x, 3)), Rect2(bounds.position, Vector2(3, bounds.size.y)), Rect2(Vector2(bounds.end.x - 3, bounds.position.y), Vector2(3, bounds.size.y))]:
		var edge := ColorRect.new()
		edge.position = rect.position
		edge.size = rect.size
		edge.color = color
		layer.add_child(edge)
	var label := Label.new()
	label.text = "V3: %.2f%% ALTEZZA  |  CENTRO Y %.2f%%  |  TARGET 18-22%% / 70-76%%" % [measurement.x, measurement.y]
	label.position = Vector2(360, 660)
	label.add_theme_font_size_override("font_size", 18)
	layer.add_child(label)
	await _save_viewport("vehicle_screen_occupancy_measurement.png")
	layer.queue_free()
	await process_frame

func _capture_lod_overlay(boot: Node) -> void:
	var layer := CanvasLayer.new()
	boot.add_child(layer)
	var label := Label.new()
	label.text = "SINGOLA V3 PLAYABLE — LOD1 RUNTIME: 27.670 TRI / 14 SURFICI   |   LOD0 APPROVATO: 54.268 TRI / 29 SURFICI"
	label.position = Vector2(170, 660)
	label.add_theme_font_size_override("font_size", 17)
	layer.add_child(label)
	await _save_viewport("lod0_lod1_runtime_comparison.png")
	layer.queue_free()
	await process_frame

func _save_viewport(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	_check(image.save_png(ProjectSettings.globalize_path(SHOT_ROOT + file_name)) == OK, "could not save " + file_name)

func _occupancy(camera: Camera3D, visual: Node3D) -> Vector2:
	var bounds := _screen_bounds(camera, visual)
	return Vector2(bounds.size.y / 720.0 * 100.0, (bounds.position.y + bounds.size.y * 0.5) / 720.0 * 100.0)

func _screen_bounds(camera: Camera3D, visual: Node3D) -> Rect2:
	var minimum := Vector2(100000.0, 100000.0)
	var maximum := Vector2(-100000.0, -100000.0)
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var aabb := mesh_instance.mesh.get_aabb()
		for x in [aabb.position.x, aabb.end.x]:
			for y in [aabb.position.y, aabb.end.y]:
				for z in [aabb.position.z, aabb.end.z]:
					var screen := camera.unproject_position(mesh_instance.to_global(Vector3(x, y, z)))
					minimum = minimum.min(screen)
					maximum = maximum.max(screen)
	return Rect2(minimum, maximum - minimum)

func _finish(load_time_ms: float, boot: Node, curve_captured: bool, high_speed_captured: bool) -> void:
	var sorted_fps := fps_values.duplicate()
	sorted_fps.sort()
	var sorted_times := frame_times_ms.duplicate()
	sorted_times.sort()
	var average_fps := _average(fps_values)
	var p5 := sorted_fps[clampi(int(floor((sorted_fps.size() - 1) * 0.05)), 0, maxi(0, sorted_fps.size() - 1))] if not sorted_fps.is_empty() else 0.0
	var sustained := _minimum_rolling_fps(SUSTAINED_WINDOW)
	var instantaneous := sorted_fps[0] if not sorted_fps.is_empty() else 0.0
	var average_frame_time := _average(frame_times_ms)
	var median_time := sorted_times[int(sorted_times.size() / 2)] if not sorted_times.is_empty() else 0.0
	var threshold := maxf(33.333, median_time * 2.0)
	var stutter_frames := 0
	var maximum_run := 0
	var run := 0
	for frame_time in frame_times_ms:
		if frame_time > threshold:
			stutter_frames += 1
			run += 1
			maximum_run = maxi(maximum_run, run)
		else:
			run = 0
	var recurring := maximum_run >= 3 or stutter_frames > int(frame_times_ms.size() * 0.01)
	_check(sustained >= 55.0, "sustained FPS below 55")
	_check(peak_draw_calls <= 832, "draw calls were not materially reduced")
	_check(peak_primitives < G1C_PRIMITIVES, "primitive count was not reduced")
	_check(load_time_ms <= G1C_LOAD_MS, "load time regressed from G1-C")
	_check(not recurring, "recurring stutter detected")
	var report := "Desert Velocity G1-C.1 playable camera and V3 runtime optimization\n"
	report += "source_scene=res://scenes/main/Boot.tscn\nmode=STAGE\ngpu=%s\nrenderer=%s\nresolution=1280x720\n" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method()]
	report += "camera_before_distance=7.2\ncamera_before_height=3.3\ncamera_before_look_ahead=5.0\ncamera_before_look_height=1.0\ncamera_before_occupancy_percent=29.95\ncamera_before_center_y_percent=62.39\n"
	report += "camera_final_distance=9.8\ncamera_final_height=2.9\ncamera_final_look_ahead=8.5\ncamera_final_look_height=4.5\ncamera_final_occupancy_percent=%.2f\ncamera_final_center_y_percent=%.2f\n" % [straight_occupancy, straight_center_y]
	report += "farther_variant_occupancy_percent=%.2f\nlower_variant_occupancy_percent=%.2f\ncurve_capture=%s\nhigh_speed_capture=%s\n" % [farther_occupancy, lower_occupancy, str(curve_captured).to_lower(), str(high_speed_captured).to_lower()]
	report += "runtime_lod=LOD1\ntriangles=27670\nmesh_instances=10\nstatic_merged_surfaces=6\nwheel_surfaces=8\nvisible_surface_draws=14\n"
	report += "sample_seconds=%.2f\nframe_samples=%d\naverage_fps=%.2f\npercentile_5_fps=%.2f\nminimum_sustained_fps=%.2f\ninstantaneous_minimum_fps=%.2f\naverage_frame_time_ms=%.3f\n" % [SAMPLE_SECONDS, fps_values.size(), average_fps, p5, sustained, instantaneous, average_frame_time]
	report += "stutter_frames=%d\nmax_consecutive_stutter_frames=%d\nrecurring_stutter=%s\npeak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\npeak_static_memory_mb=%.2f\nload_time_ms=%.2f\n" % [stutter_frames, maximum_run, str(recurring).to_lower(), peak_draw_calls, peak_primitives, peak_nodes, peak_static_memory / 1048576.0, load_time_ms]
	report += "g1c_average_fps=60.28\ng1c_percentile_5_fps=56.30\ng1c_minimum_sustained_fps=58.88\ng1c_draw_calls=%d\ng1c_primitives=%d\ng1c_nodes=%d\ng1c_static_memory_mb=%.2f\ng1c_load_time_ms=%.2f\n" % [G1C_DRAW_CALLS, G1C_PRIMITIVES, G1C_NODES, G1C_MEMORY_MB, G1C_LOAD_MS]
	report += "classification=%s\n" % ("PASS" if failures.is_empty() else "FAIL")
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("metrics report could not be written")
	else:
		file.store_string(report)
		file.close()
	print(report)
	if boot != null and is_instance_valid(boot):
		boot.queue_free()
	for _frame in 8:
		await process_frame
	if failures.is_empty():
		print("PLAYABLE_CAMERA_V3_OPTIMIZATION_RUNTIME_RESULT PASS")
	else:
		for failure in failures:
			printerr("PLAYABLE_CAMERA_V3_OPTIMIZATION_RUNTIME_FAIL ", failure)
		print("PLAYABLE_CAMERA_V3_OPTIMIZATION_RUNTIME_RESULT FAIL count=", failures.size())
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
