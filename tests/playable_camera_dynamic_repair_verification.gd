extends SceneTree

const REPORT_PATH := "res://reports/playable_camera_dynamic_repair_metrics.txt"
const SHOT_ROOT := "res://screenshots/playable_camera_v3_optimization/dynamic_repair/"
const SUSTAINED_WINDOW := 30
const DYNAMIC_MIN_OCCUPANCY := 17.0
const DYNAMIC_MAX_OCCUPANCY := 26.0
const DYNAMIC_MIN_CENTER := 68.0
const DYNAMIC_MAX_CENTER := 78.0
const MAX_OUT_OF_RANGE_SECONDS := 0.5
const MAX_FOLLOW_ERROR := 0.90
const BASELINE_DRAW_CALLS := 772
const BASELINE_MEMORY_MB := 51.18
const BASELINE_LOAD_MS := 798.21

var failures: Array[String] = []
var fps_values := PackedFloat64Array()
var frame_times_ms := PackedFloat64Array()
var condition_stats: Dictionary = {}
var peak_draw_calls := 0
var peak_primitives := 0
var peak_nodes := 0
var peak_static_memory := 0
var load_time_ms := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("PLAYABLE_CAMERA_DYNAMIC_REPAIR_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_ROOT))
	_ensure_inputs()
	var load_started := Time.get_ticks_usec()
	var packed := load("res://scenes/main/Boot.tscn") as PackedScene
	_check(packed != null, "Boot.tscn failed to load")
	if packed == null:
		await _finish()
		return
	var boot := packed.instantiate()
	root.add_child(boot)
	await process_frame
	boot.run_mode = "STAGE"
	boot.save.vehicle = 0
	boot.start_game()
	await process_frame
	await RenderingServer.frame_post_draw
	load_time_ms = (Time.get_ticks_usec() - load_started) / 1000.0
	_check(bool(boot.player.visual.get_meta("stallion_v3_visual_pilot", false)), "Boot player is not the existing V3")
	for _frame in 300:
		await process_frame
	await _capture_controlled_static_pair(boot)
	await _run_dynamic_conditions(boot)
	await _run_boost_condition(boot)
	await _run_offroad_condition(boot)
	_validate_conditions()
	_validate_performance()
	_release_inputs()
	await _finish()
	if is_instance_valid(boot):
		boot.queue_free()
	for _frame in 8:
		await process_frame
	quit(0 if failures.is_empty() else 1)

func _ensure_inputs() -> void:
	for action_name in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_vehicle"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

func _capture_controlled_static_pair(boot: Node) -> void:
	boot.player.process_mode = Node.PROCESS_MODE_DISABLED
	boot.set_process(false)
	var controlled_transform: Transform3D = boot.road.safe_transform_near(boot.player.global_position)
	_prepare_vehicle(boot.player, controlled_transform, 0.0, false)
	boot.stage_time = 10.0
	boot.camera.set_v3_controlled_baseline(true)
	_reset_camera_to_profile(boot.camera, boot.player)
	await _settle_camera(boot.camera, 120)
	var baseline := _measurement(boot.camera, boot.player.visual)
	_record_single("static_baseline", baseline, boot.camera)
	await _save_viewport("camera_static_baseline_controlled.png")
	_prepare_vehicle(boot.player, controlled_transform, 0.0, false)
	boot.stage_time = 10.0
	boot.camera.set_v3_controlled_baseline(false)
	_reset_camera_to_profile(boot.camera, boot.player)
	await _settle_camera(boot.camera, 120)
	var final_measure := _measurement(boot.camera, boot.player.visual)
	_record_single("static_final", final_measure, boot.camera)
	_check(final_measure.x >= 18.0 and final_measure.x <= 22.0, "static final occupancy outside 18-22 percent: %.2f" % final_measure.x)
	_check(final_measure.y >= 70.0 and final_measure.y <= 76.0, "static final center outside 70-76 percent: %.2f" % final_measure.y)
	await _save_viewport("camera_static_final_controlled.png")
	await _capture_occupancy_overlay(boot, final_measure)
	_build_before_after()
	boot.set_process(true)

func _run_dynamic_conditions(boot: Node) -> void:
	for condition_name in ["straight", "high_speed", "curve", "bump"]:
		condition_stats[condition_name] = _new_stats()
	boot.player.process_mode = Node.PROCESS_MODE_DISABLED
	boot.road.process_mode = Node.PROCESS_MODE_DISABLED
	boot.player.controls_enabled = false
	await _run_single_segment_condition(boot, "straight", 1, 14.0, 180, 0.0, "camera_dynamic_straight.png", false)
	await _run_layout_condition(boot, "high_speed", [0, 1, 2], 52.0, 180, 0.0, "camera_dynamic_high_speed.png", false)
	await _run_layout_condition(boot, "curve", [3, 4, 5], 52.0, 180, 0.0, "camera_dynamic_curve.png", false)
	await _run_bump_condition(boot)

func _run_boost_condition(boot: Node) -> void:
	condition_stats["boost"] = _new_stats()
	await _run_layout_condition(boot, "boost", [0, 1, 2], 60.0, 180, 0.0, "camera_dynamic_boost.png", true)

func _run_offroad_condition(boot: Node) -> void:
	condition_stats["offroad"] = _new_stats()
	await _run_single_segment_condition(boot, "offroad", 1, 18.0, 180, BalanceData.ROAD_HALF_WIDTH + 2.0, "camera_dynamic_offroad.png", false)

func _run_single_segment_condition(boot: Node, condition_name: String, layout_index: int, speed: float, frames: int, lateral_offset: float, capture_name: String, boost: bool) -> void:
	var layout: Array[Dictionary] = boot.road.stage_layout()
	var entry: Dictionary = layout[layout_index]
	var segment_transform: Transform3D = entry.transform
	var start_z := 20.0
	var first_transform := Transform3D(segment_transform.basis, segment_transform * Vector3(lateral_offset, 0.15, start_z))
	_prepare_controlled_condition(boot, first_transform, speed, boost)
	var previous_ticks := Time.get_ticks_usec()
	for frame in frames:
		var z := start_z - speed * float(frame) / 60.0
		var transform_value := Transform3D(segment_transform.basis, segment_transform * Vector3(lateral_offset, 0.15, z))
		_set_controlled_vehicle(boot.player, transform_value, speed, boost)
		await process_frame
		var now := Time.get_ticks_usec()
		var delta := maxf((now - previous_ticks) / 1000000.0, 0.000001)
		previous_ticks = now
		_collect_performance(delta)
		_sample_condition(condition_name, boot.camera, boot.player.visual, delta)
		if frame == 60:
			await _save_viewport(capture_name)
			previous_ticks = Time.get_ticks_usec()

func _run_layout_condition(boot: Node, condition_name: String, layout_indices: Array, speed: float, frames: int, lateral_offset: float, capture_name: String, boost: bool) -> void:
	var layout: Array[Dictionary] = boot.road.stage_layout()
	var first_entry: Dictionary = layout[int(layout_indices[0])]
	var first_segment: Transform3D = first_entry.transform
	var first_transform := Transform3D(first_segment.basis, first_segment * Vector3(lateral_offset, 0.15, BalanceData.SEGMENT_LENGTH * 0.45))
	_prepare_controlled_condition(boot, first_transform, speed, boost)
	var previous_ticks := Time.get_ticks_usec()
	for frame in frames:
		var route_progress := float(frame) / float(maxi(frames - 1, 1)) * float(layout_indices.size())
		var path_slot := mini(int(floor(route_progress)), layout_indices.size() - 1)
		var local_ratio := route_progress - float(path_slot)
		var entry: Dictionary = layout[int(layout_indices[path_slot])]
		var segment_transform: Transform3D = entry.transform
		var z := lerpf(BalanceData.SEGMENT_LENGTH * 0.45, -BalanceData.SEGMENT_LENGTH * 0.45, local_ratio)
		var transform_value := Transform3D(segment_transform.basis, segment_transform * Vector3(lateral_offset, 0.15, z))
		_set_controlled_vehicle(boot.player, transform_value, speed, boost)
		await process_frame
		var now := Time.get_ticks_usec()
		var delta := maxf((now - previous_ticks) / 1000000.0, 0.000001)
		previous_ticks = now
		_collect_performance(delta)
		_sample_condition(condition_name, boot.camera, boot.player.visual, delta)
		if frame == 60:
			await _save_viewport(capture_name)
			previous_ticks = Time.get_ticks_usec()

func _run_bump_condition(boot: Node) -> void:
	var segment := boot.road.segments[1] as Node3D
	segment.set_meta("jump_kind", "DOSSO")
	boot.road._configure_stage_jump_profile(segment, "DOSSO", str(segment.get_meta("surface", "ASPHALT")))
	var profile: PackedVector2Array = boot.road._jump_profile("DOSSO")
	var first_transform := Transform3D(segment.global_basis, segment.to_global(Vector3(0.0, _profile_height(profile, 20.0) + 0.15, 20.0)))
	_prepare_controlled_condition(boot, first_transform, 24.0, false)
	var previous_ticks := Time.get_ticks_usec()
	for frame in 120:
		var z := lerpf(20.0, -20.0, float(frame) / 119.0)
		var y := _profile_height(profile, z) + 0.15
		var transform_value := Transform3D(segment.global_basis, segment.to_global(Vector3(0.0, y, z)))
		_set_controlled_vehicle(boot.player, transform_value, 24.0, false)
		await process_frame
		var now := Time.get_ticks_usec()
		var delta := maxf((now - previous_ticks) / 1000000.0, 0.000001)
		previous_ticks = now
		_collect_performance(delta)
		_sample_condition("bump", boot.camera, boot.player.visual, delta)
		if frame == 60:
			await _save_viewport("camera_dynamic_bump.png")
			previous_ticks = Time.get_ticks_usec()

func _profile_height(profile: PackedVector2Array, z: float) -> float:
	for index in range(profile.size() - 1):
		var a := profile[index]
		var b := profile[index + 1]
		if z >= a.x and z <= b.x:
			return lerpf(a.y, b.y, inverse_lerp(a.x, b.x, z))
	return 0.0

func _prepare_controlled_condition(boot: Node, transform_value: Transform3D, speed: float, boost: bool) -> void:
	boot.camera.set_v3_controlled_baseline(false)
	_set_controlled_vehicle(boot.player, transform_value, speed, boost)
	_reset_camera_to_profile(boot.camera, boot.player)
	await _settle_camera(boot.camera, 30)

func _set_controlled_vehicle(player: VehicleController, transform_value: Transform3D, speed: float, boost: bool) -> void:
	player.global_transform = transform_value
	player.speed = speed
	player.velocity = -transform_value.basis.z * speed
	player.turbo_time = 5.0 if boost else 0.0

func _new_stats() -> Dictionary:
	return {
		"samples": 0,
		"min_occupancy": INF,
		"max_occupancy": 0.0,
		"min_center": INF,
		"max_center": 0.0,
		"min_distance": INF,
		"max_distance": 0.0,
		"max_follow_error": 0.0,
		"current_small_seconds": 0.0,
		"longest_small_seconds": 0.0,
		"current_center_seconds": 0.0,
		"longest_center_seconds": 0.0,
		"previous_follow_error": -1.0,
		"max_follow_error_step": 0.0,
		"previous_occupancy": -1.0,
		"max_occupancy_step": 0.0,
		"previous_center": -1.0,
		"max_center_step": 0.0,
	}

func _sample_condition(condition_name: String, camera: CameraController, visual: Node3D, delta: float) -> void:
	var stats: Dictionary = condition_stats[condition_name]
	var measure := _measurement(camera, visual)
	var distance := camera.v3_camera_distance()
	var follow_error := camera.v3_follow_error()
	stats.samples = int(stats.samples) + 1
	stats.min_occupancy = minf(float(stats.min_occupancy), measure.x)
	stats.max_occupancy = maxf(float(stats.max_occupancy), measure.x)
	stats.min_center = minf(float(stats.min_center), measure.y)
	stats.max_center = maxf(float(stats.max_center), measure.y)
	stats.min_distance = minf(float(stats.min_distance), distance)
	stats.max_distance = maxf(float(stats.max_distance), distance)
	stats.max_follow_error = maxf(float(stats.max_follow_error), follow_error)
	if measure.x < DYNAMIC_MIN_OCCUPANCY:
		stats.current_small_seconds = float(stats.current_small_seconds) + delta
		stats.longest_small_seconds = maxf(float(stats.longest_small_seconds), float(stats.current_small_seconds))
	else:
		stats.current_small_seconds = 0.0
	if measure.y < DYNAMIC_MIN_CENTER or measure.y > DYNAMIC_MAX_CENTER:
		stats.current_center_seconds = float(stats.current_center_seconds) + delta
		stats.longest_center_seconds = maxf(float(stats.longest_center_seconds), float(stats.current_center_seconds))
	else:
		stats.current_center_seconds = 0.0
	if float(stats.previous_follow_error) >= 0.0:
		stats.max_follow_error_step = maxf(float(stats.max_follow_error_step), absf(follow_error - float(stats.previous_follow_error)))
	stats.previous_follow_error = follow_error
	if float(stats.previous_occupancy) >= 0.0:
		stats.max_occupancy_step = maxf(float(stats.max_occupancy_step), absf(measure.x - float(stats.previous_occupancy)))
	stats.previous_occupancy = measure.x
	if float(stats.previous_center) >= 0.0:
		stats.max_center_step = maxf(float(stats.max_center_step), absf(measure.y - float(stats.previous_center)))
	stats.previous_center = measure.y

func _record_single(condition_name: String, measure: Vector2, camera: CameraController) -> void:
	var stats := _new_stats()
	condition_stats[condition_name] = stats
	_sample_condition(condition_name, camera, camera.target.visual, 0.0)

func _validate_conditions() -> void:
	for condition_name in ["straight", "high_speed", "curve", "boost", "bump", "offroad"]:
		_check(condition_stats.has(condition_name), "missing dynamic condition " + condition_name)
		if not condition_stats.has(condition_name):
			continue
		var stats: Dictionary = condition_stats[condition_name]
		_check(int(stats.samples) >= 20, "%s has insufficient samples: %d" % [condition_name, int(stats.samples)])
		_check(float(stats.longest_small_seconds) <= MAX_OUT_OF_RANGE_SECONDS, "%s vehicle stayed below 17 percent for %.3f seconds" % [condition_name, float(stats.longest_small_seconds)])
		_check(float(stats.longest_center_seconds) <= MAX_OUT_OF_RANGE_SECONDS, "%s center stayed outside 68-78 percent for %.3f seconds" % [condition_name, float(stats.longest_center_seconds)])
		_check(float(stats.max_occupancy) <= DYNAMIC_MAX_OCCUPANCY, "%s exceeded 26 percent occupancy: %.2f" % [condition_name, float(stats.max_occupancy)])
		_check(float(stats.max_follow_error) <= MAX_FOLLOW_ERROR, "%s follow error exceeded %.2f m: %.3f" % [condition_name, MAX_FOLLOW_ERROR, float(stats.max_follow_error)])
		_check(float(stats.min_distance) >= 5.0, "%s camera clipped into the vehicle: %.3f m" % [condition_name, float(stats.min_distance)])
		_check(float(stats.max_distance) <= 11.5, "%s camera distance exceeded 11.5 m: %.3f" % [condition_name, float(stats.max_distance)])
		_check(float(stats.max_occupancy_step) <= 2.5, "%s occupancy changed abruptly: %.3f percent/frame" % [condition_name, float(stats.max_occupancy_step)])
		_check(float(stats.max_center_step) <= 2.5, "%s center changed abruptly: %.3f percent/frame" % [condition_name, float(stats.max_center_step)])

func _collect_performance(delta: float) -> void:
	fps_values.append(1.0 / delta)
	frame_times_ms.append(delta * 1000.0)
	peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	peak_primitives = maxi(peak_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	peak_static_memory = maxi(peak_static_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))

func _validate_performance() -> void:
	var average_fps := _average(fps_values)
	var sustained := _minimum_rolling_fps(SUSTAINED_WINDOW)
	var stutter := _stutter_summary()
	_check(average_fps >= 58.0, "average FPS is not approximately 60: %.2f" % average_fps)
	_check(sustained >= 55.0, "minimum sustained FPS below 55: %.2f" % sustained)
	_check(int(stutter.max_consecutive) < 3, "recurring stutter detected: %d consecutive frames" % int(stutter.max_consecutive))
	_check(peak_draw_calls <= int(BASELINE_DRAW_CALLS * 1.05) + 1, "camera increased draw calls significantly: %d" % peak_draw_calls)
	_check(peak_static_memory / 1048576.0 <= BASELINE_MEMORY_MB + 2.0, "camera increased static memory significantly")
	_check(load_time_ms <= BASELINE_LOAD_MS + 500.0, "camera load time exceeded the existing controlled sub-second tolerance: %.2f ms" % load_time_ms)

func _prepare_vehicle(player: VehicleController, transform_value: Transform3D, speed_value: float, controls: bool) -> void:
	player.global_transform = transform_value
	player.reset_physics_interpolation()
	player.speed = speed_value
	player.velocity = -player.global_transform.basis.z * speed_value
	player.controls_enabled = controls

func _reset_camera_to_profile(camera: CameraController, player: VehicleController) -> void:
	var chase := camera.v3_chase_parameters()
	camera.global_position = player.global_position + player.global_transform.basis.z * chase.x + Vector3.UP * chase.y
	camera.fov = 70.0
	var look_point := player.global_position - player.global_transform.basis.z * chase.z + Vector3.UP * chase.w
	camera.look_at(look_point, Vector3.UP)
	camera.reset_physics_interpolation()

func _settle_camera(camera: CameraController, frames: int) -> void:
	for _frame in frames:
		await process_frame
		_check(_camera_finite(camera), "camera transform became invalid")

func _camera_finite(camera: Camera3D) -> bool:
	var position := camera.global_position
	return is_finite(position.x) and is_finite(position.y) and is_finite(position.z)

func _measurement(camera: Camera3D, visual: Node3D) -> Vector2:
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

func _capture_occupancy_overlay(boot: Node, measure: Vector2) -> void:
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
	label.text = "V3 STATIC FINAL %.2f%%  |  CENTER Y %.2f%%  |  FOLLOW ERROR %.3f m" % [measure.x, measure.y, boot.camera.v3_follow_error()]
	label.position = Vector2(330, 660)
	label.add_theme_font_size_override("font_size", 18)
	layer.add_child(label)
	await _save_viewport("camera_occupancy_overlay.png")
	layer.queue_free()
	await process_frame

func _save_viewport(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	_check(image.save_png(ProjectSettings.globalize_path(SHOT_ROOT + file_name)) == OK, "could not save " + file_name)

func _build_before_after() -> void:
	var baseline := Image.load_from_file(ProjectSettings.globalize_path(SHOT_ROOT + "camera_static_baseline_controlled.png"))
	var final_image := Image.load_from_file(ProjectSettings.globalize_path(SHOT_ROOT + "camera_static_final_controlled.png"))
	_check(baseline != null and not baseline.is_empty(), "controlled baseline image could not be loaded")
	_check(final_image != null and not final_image.is_empty(), "controlled final image could not be loaded")
	if baseline == null or baseline.is_empty() or final_image == null or final_image.is_empty():
		return
	baseline.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	final_image.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	var combined := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	combined.fill(Color("1c2024"))
	combined.blit_rect(baseline, Rect2i(0, 0, 640, 360), Vector2i(0, 180))
	combined.blit_rect(final_image, Rect2i(0, 0, 640, 360), Vector2i(640, 180))
	_check(combined.save_png(ProjectSettings.globalize_path(SHOT_ROOT + "camera_before_after_controlled.png")) == OK, "could not save controlled before/after")

func _finish() -> void:
	var average_fps := _average(fps_values)
	var sustained := _minimum_rolling_fps(SUSTAINED_WINDOW)
	var stutter := _stutter_summary()
	var report := "Desert Velocity G1-C.1A dynamic playable camera repair\n"
	report += "source_scene=res://scenes/main/Boot.tscn\nmode=STAGE\nresolution=1280x720\n"
	report += "camera_previous_method=unbounded exponential position lerp response 6.5\n"
	report += "camera_final_method=frame-time-independent bounded follow plus independent rotation damping\n"
	report += "camera_baseline_distance=7.2\ncamera_baseline_height=3.3\ncamera_baseline_look_ahead=5.0\ncamera_baseline_look_height=1.0\n"
	report += "camera_final_distance=9.8\ncamera_final_height=2.9\ncamera_final_look_ahead=8.5\ncamera_final_look_height=4.5\n"
	report += "position_response=%.2f\nrotation_response=%.2f\nmax_follow_error_setting=%.2f\nmin_camera_distance=%.2f\nmax_camera_distance=%.2f\nboost_chase_distance=%.2f\nboost_min_camera_distance=%.2f\nboost_max_camera_distance=%.2f\n" % [CameraController.V3_POSITION_RESPONSE, CameraController.V3_ROTATION_RESPONSE, CameraController.V3_MAX_FOLLOW_ERROR, CameraController.V3_MIN_CAMERA_DISTANCE, CameraController.V3_MAX_CAMERA_DISTANCE, CameraController.V3_BOOST_CHASE_DISTANCE, CameraController.V3_BOOST_MIN_CAMERA_DISTANCE, CameraController.V3_BOOST_MAX_CAMERA_DISTANCE]
	for condition_name in ["static_baseline", "static_final", "straight", "high_speed", "curve", "boost", "bump", "offroad"]:
		if not condition_stats.has(condition_name):
			report += "%s_missing=true\n" % condition_name
			continue
		var stats: Dictionary = condition_stats[condition_name]
		report += "%s_samples=%d\n%s_occupancy_min=%.2f\n%s_occupancy_max=%.2f\n%s_center_min=%.2f\n%s_center_max=%.2f\n%s_distance_min=%.3f\n%s_distance_max=%.3f\n%s_follow_error_max=%.3f\n%s_small_longest_seconds=%.3f\n%s_center_out_longest_seconds=%.3f\n%s_follow_error_step_max=%.3f\n%s_occupancy_step_max=%.3f\n%s_center_step_max=%.3f\n" % [condition_name, int(stats.samples), condition_name, float(stats.min_occupancy), condition_name, float(stats.max_occupancy), condition_name, float(stats.min_center), condition_name, float(stats.max_center), condition_name, float(stats.min_distance), condition_name, float(stats.max_distance), condition_name, float(stats.max_follow_error), condition_name, float(stats.longest_small_seconds), condition_name, float(stats.longest_center_seconds), condition_name, float(stats.max_follow_error_step), condition_name, float(stats.max_occupancy_step), condition_name, float(stats.max_center_step)]
	report += "frame_samples=%d\naverage_fps=%.2f\nminimum_sustained_fps=%.2f\nstutter_frames=%d\nmax_consecutive_stutter_frames=%d\npeak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\npeak_static_memory_mb=%.2f\nload_time_ms=%.2f\n" % [fps_values.size(), average_fps, sustained, int(stutter.frames), int(stutter.max_consecutive), peak_draw_calls, peak_primitives, peak_nodes, peak_static_memory / 1048576.0, load_time_ms]
	report += "failure_count=%d\nclassification=%s\n" % [failures.size(), "PASS" if failures.is_empty() else "FAIL"]
	if not failures.is_empty():
		for failure in failures:
			report += "failure=%s\n" % failure
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("dynamic repair metrics report could not be written")
	else:
		file.store_string(report)
		file.close()
	print(report)
	if failures.is_empty():
		print("PLAYABLE_CAMERA_DYNAMIC_REPAIR_RESULT PASS")
	else:
		for failure in failures:
			printerr("PLAYABLE_CAMERA_DYNAMIC_REPAIR_FAIL ", failure)
		print("PLAYABLE_CAMERA_DYNAMIC_REPAIR_RESULT FAIL count=", failures.size())

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

func _stutter_summary() -> Dictionary:
	if frame_times_ms.is_empty():
		return {"frames": 0, "max_consecutive": 0}
	var sorted := frame_times_ms.duplicate()
	sorted.sort()
	var median := sorted[int(sorted.size() / 2)]
	var threshold := maxf(33.333, median * 2.0)
	var frames := 0
	var run := 0
	var maximum_run := 0
	for frame_time in frame_times_ms:
		if frame_time > threshold:
			frames += 1
			run += 1
			maximum_run = maxi(maximum_run, run)
		else:
			run = 0
	return {"frames": frames, "max_consecutive": maximum_run}

func _release_steering() -> void:
	Input.action_release("steer_left")
	Input.action_release("steer_right")

func _release_inputs() -> void:
	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_release("handbrake")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
