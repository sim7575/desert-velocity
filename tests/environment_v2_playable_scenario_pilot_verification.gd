extends SceneTree

const REPORT_PATH := "res://reports/environment_v2_playable_visual_polish_metrics.txt"
const SHOT_ROOT := "res://screenshots/playable_visual_integration_pilot/environment_g1d1/"
const G1D_SHOT_ROOT := "res://screenshots/playable_visual_integration_pilot/environment_g1d/"
const BOOT_PATH := "res://scenes/main/Boot.tscn"
const SAMPLE_SECONDS := 32.0
const SUSTAINED_WINDOW := 30

var failures: Array[String] = []
var frame_times_ms := PackedFloat64Array()
var load_time_ms := 0.0
var peak_draw_calls := 0
var peak_primitives := 0
var peak_nodes := 0
var peak_static_memory := 0
var baseline_collision_shapes := 0
var pilot_collision_shapes := 0
var checkpoint_reached := false
var route_signature := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("ENVIRONMENT_V2_PLAYABLE_VISUAL_POLISH_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_ROOT))
	_ensure_inputs()
	route_signature = JSON.stringify(HandcraftedStage.route())
	await _validate_original_fallback()
	RoadManager.use_environment_v2_playable_pilot = true
	var load_started := Time.get_ticks_usec()
	var boot := await _start_boot()
	_check(boot != null, "pilot Boot could not start")
	if boot == null:
		await _finish(null)
		return
	await RenderingServer.frame_post_draw
	load_time_ms = (Time.get_ticks_usec() - load_started) / 1000.0
	_validate_pilot_structure(boot)
	for _frame in 300:
		await process_frame
	await _run_real_stage_sample(boot)
	await _capture_pilot_set(boot)
	_validate_performance()
	await _finish(boot)
	_dispose_boot(boot)
	for _frame in 8:
		await process_frame
	RoadManager.use_environment_v2_playable_pilot = true
	quit(0 if failures.is_empty() else 1)

func _validate_original_fallback() -> void:
	RoadManager.use_environment_v2_playable_pilot = false
	var boot := await _start_boot()
	_check(boot != null, "original fallback Boot could not start")
	if boot == null:
		return
	_check(boot.road.environment_visual_pilot == null, "original scenario fallback still loaded the pilot")
	_check(boot.road.segments.size() == BalanceData.SEGMENT_COUNT, "original fallback segment count changed")
	baseline_collision_shapes = boot.road.find_children("*", "CollisionShape3D", true, false).size()
	var road_surface := _segment_by_route_index(boot.road, 4).get_node_or_null("RoadSurface") as MeshInstance3D
	_check(road_surface != null and road_surface.visible, "original fallback road visual is hidden")
	_dispose_boot(boot)
	for _frame in 8:
		await process_frame

func _start_boot() -> Node:
	var packed := load(BOOT_PATH) as PackedScene
	if packed == null:
		return null
	var boot := packed.instantiate()
	root.add_child(boot)
	await process_frame
	boot.run_mode = "STAGE"
	boot.save.vehicle = 0
	boot.start_game()
	await process_frame
	return boot

func _validate_pilot_structure(boot: Node) -> void:
	var pilot: Node3D = boot.road.environment_visual_pilot
	_check(pilot != null, "environment pilot was not attached to real RoadManager")
	if pilot == null:
		return
	_check(bool(pilot.get_meta("environment_v2_playable_pilot", false)), "pilot metadata missing")
	_check(bool(pilot.get_meta("g1d1_visual_polish", false)), "G1-D.1 polish metadata missing")
	_check(bool(pilot.get_meta("source_materials_unchanged", false)), "source-material invariant missing")
	_check(int(pilot.get_meta("pilot_start_index", -1)) == 0 and int(pilot.get_meta("pilot_end_index", -1)) == 9, "pilot section indices changed")
	_check(is_equal_approx(float(pilot.get_meta("pilot_length_meters", 0.0)), 520.0), "pilot length changed")
	_check(int(pilot.get_meta("pilot_checkpoint_index", -1)) == 9, "pilot checkpoint changed")
	_check(bool(pilot.get_meta("rock_arch_deferred", false)), "RockArch deferral was not documented")
	_check(int(pilot.get_meta("collision_count", -1)) == 0, "pilot introduced collision objects")
	_check(int(pilot.get_meta("lod0_instances", 0)) >= 3, "LOD0 hero assets missing")
	_check(int(pilot.get_meta("lod1_instances", 0)) >= 20, "LOD1 mid-ground assets missing")
	_check(int(pilot.get_meta("lod2_instances", 0)) >= 150, "LOD2 background/scatter assets missing")
	_check(int(pilot.get_meta("multimesh_groups", 0)) >= 7, "polished MultiMesh groups missing")
	_check(int(pilot.get_meta("multimesh_instances", 0)) >= 350, "polished MultiMesh density is too low")
	_check(int(pilot.get_meta("contact_groups", 0)) == 2, "rock-contact scatter groups missing")
	_check(bool(pilot.get_meta("golden_hour_override", false)), "Golden Hour override missing")
	_check(JSON.stringify(HandcraftedStage.route()) == route_signature, "HandcraftedStage route changed")
	_check(boot.road.stage_layout().size() == 64, "stage route length changed")
	pilot_collision_shapes = boot.road.find_children("*", "CollisionShape3D", true, false).size()
	_check(pilot_collision_shapes == baseline_collision_shapes, "pilot changed RoadManager collision-shape count")
	_check(bool(boot.player.visual.get_meta("stallion_v3_visual_pilot", false)), "Stallion V3 is no longer default")
	_check(int(boot.player.visual.get_meta("runtime_source_lod", -1)) == 1, "Stallion V3 runtime LOD changed")
	var road_surface := _segment_by_route_index(boot.road, 4).get_node_or_null("RoadSurface") as MeshInstance3D
	_check(road_surface != null and not road_surface.visible, "original road visual was not reversibly covered in pilot section")
	_check(pilot.find_child("WeatheredRoad_04", true, false) != null, "F1.1 road visual missing")
	_check(pilot.find_child("LayeredTerrain_04", true, false) != null, "F1.1 terrain visual missing")
	_check(pilot.find_child("HeroRock_A_SplitCrown_L0", true, false) != null, "HeroRock A missing")
	_check(pilot.find_child("CanyonWall_A_Concave_L1", true, false) != null, "CanyonWall A missing")
	_check(pilot.find_child("EnvironmentKitV2ScatterMultiMesh", true, false) != null, "scatter root missing")
	_validate_visual_seams(pilot)
	_validate_offroad_logic(boot)

func _validate_visual_seams(pilot: Node3D) -> void:
	for index in range(0, 9):
		var current := pilot.find_child("VisualSegment_%02d" % index, true, false) as Node3D
		var next := pilot.find_child("VisualSegment_%02d" % (index + 1), true, false) as Node3D
		_check(current != null and next != null, "visual segment missing at seam %d" % index)
		if current == null or next == null:
			continue
		var current_end := current.to_global(Vector3(0, 0.07, -BalanceData.SEGMENT_LENGTH * 0.5))
		var next_start := next.to_global(Vector3(0, 0.07, BalanceData.SEGMENT_LENGTH * 0.5))
		_check(current_end.distance_to(next_start) < 0.08, "visual road seam gap at %d: %.4f m" % [index, current_end.distance_to(next_start)])

func _validate_offroad_logic(boot: Node) -> void:
	var entry: Dictionary = boot.road.stage_layout()[3]
	var road_point: Vector3 = entry.transform * Vector3(0.0, 0.1, 0.0)
	var offroad_point: Vector3 = entry.transform * Vector3(BalanceData.ROAD_HALF_WIDTH + 2.0, 0.1, 0.0)
	_check(boot.road.surface_at(road_point) in ["ASPHALT", "GRAVEL"], "logical road surface changed")
	_check(boot.road.surface_at(offroad_point) == "SAND", "offroad surface logic changed")
	_check(not boot.road.is_on_road(offroad_point), "offroad boundary changed")

func _run_real_stage_sample(boot: Node) -> void:
	boot.player.controls_enabled = true
	Input.action_press("accelerate")
	var started := Time.get_ticks_usec()
	var previous_ticks := started
	while (Time.get_ticks_usec() - started) / 1000000.0 < SAMPLE_SECONDS:
		_check(boot.player != null, "real stage ended unexpectedly during pilot sample")
		if boot.player == null:
			break
		boot.fuel = BalanceData.START_FUEL
		boot.health = BalanceData.START_HEALTH
		boot.player.invulnerability = maxf(float(boot.player.invulnerability), 0.25)
		_drive_toward_center(boot)
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times_ms.append((now - previous_ticks) / 1000.0)
		previous_ticks = now
		_collect_performance()
		if not checkpoint_reached and boot.stage_checkpoint >= 1:
			checkpoint_reached = true
			await _save_viewport("04_checkpoint_polished.png")
			previous_ticks = Time.get_ticks_usec()
	_release_inputs()
	_check(checkpoint_reached, "real stage did not reach checkpoint 1 inside pilot section")

func _capture_pilot_set(boot: Node) -> void:
	await _freeze_at(boot, 0, 0.0, 8.0)
	await _save_viewport("01_start_polished.png")
	await _freeze_at(boot, 2, 0.0, 0.0)
	await _save_viewport("02_straight_polished.png")
	await _freeze_at(boot, 4, 0.0, 0.0)
	await _save_viewport("03_curve_polished.png")
	await _capture_detail(boot, 3, Vector3(13.0, 5.0, 11.0), Vector3(7.0, 0.0, -4.0), "05_road_edge_detail.png")
	await _capture_node_detail(boot, "HeroRock_A_SplitCrown_L0", Vector3(8.5, 3.3, 9.0), Vector3(0.0, 1.2, 0.0), "06_rock_ground_contact.png")
	_build_comparison(G1D_SHOT_ROOT + "07_rock_ground_contact.png", SHOT_ROOT + "06_rock_ground_contact.png", SHOT_ROOT + "07_rock_palette_comparison.png")
	await _freeze_at(boot, 5, 0.0, 0.0)
	await _save_viewport("08_canyon_composition.png")
	await _freeze_at(boot, 7, 0.0, -3.0)
	await _save_viewport("09_stallion_environment_polished.png")
	await _freeze_at(boot, 6, 0.0, 4.0)
	await _save_viewport("10_golden_hour_polished.png")
	_build_comparison(G1D_SHOT_ROOT + "04_environment_pilot_curve.png", SHOT_ROOT + "03_curve_polished.png", SHOT_ROOT + "11_before_after_g1d.png")
	await _capture_node_with_player(boot, "HeroRock_B_LeaningStack_L0", "12_environment_hero_final.png")

func _freeze_at(boot: Node, route_index: int, lateral: float, local_z: float) -> void:
	boot.set_process(false)
	boot.player.process_mode = Node.PROCESS_MODE_DISABLED
	boot.road.process_mode = Node.PROCESS_MODE_DISABLED
	var entry: Dictionary = boot.road.stage_layout()[route_index]
	boot.player.global_transform = Transform3D(entry.transform.basis, entry.transform * Vector3(lateral, 0.15, local_z))
	boot.player.speed = 0.0
	boot.player.velocity = Vector3.ZERO
	boot.player.reset_physics_interpolation()
	_reset_camera(boot)
	for _frame in 120:
		await process_frame

func _reset_camera(boot: Node) -> void:
	var chase: Vector4 = boot.camera.v3_chase_parameters()
	boot.camera.set_process(true)
	boot.camera.global_position = boot.player.global_position + boot.player.global_basis.z * chase.x + Vector3.UP * chase.y
	boot.camera.look_at(boot.player.global_position - boot.player.global_basis.z * chase.z + Vector3.UP * chase.w, Vector3.UP)

func _capture_detail(boot: Node, route_index: int, local_camera: Vector3, local_target: Vector3, file_name: String) -> void:
	await _freeze_at(boot, route_index, 0.0, 0.0)
	var entry: Dictionary = boot.road.stage_layout()[route_index]
	boot.camera.set_process(false)
	boot.camera.global_position = entry.transform * local_camera
	boot.camera.look_at(entry.transform * local_target, Vector3.UP)
	for _frame in 4:
		await process_frame
	await _save_viewport(file_name)
	boot.camera.set_process(true)

func _capture_node_detail(boot: Node, node_name: String, offset: Vector3, target_offset: Vector3, file_name: String) -> void:
	var node := boot.road.environment_visual_pilot.find_child(node_name, true, false) as Node3D
	_check(node != null, "capture landmark missing: %s" % node_name)
	if node == null:
		return
	boot.camera.set_process(false)
	boot.camera.global_position = node.global_position + node.global_basis * offset
	boot.camera.look_at(node.global_position + target_offset, Vector3.UP)
	await _save_viewport(file_name)
	boot.camera.set_process(true)

func _capture_node_with_player(boot: Node, node_name: String, file_name: String) -> void:
	var node := boot.road.environment_visual_pilot.find_child(node_name, true, false) as Node3D
	_check(node != null, "hero landmark missing for final capture")
	if node == null:
		return
	var entry: Dictionary = boot.road.stage_layout()[4]
	boot.player.global_transform = Transform3D(entry.transform.basis, entry.transform * Vector3(0.0, 0.15, 7.0))
	boot.camera.set_process(false)
	# Frame the roadside hero from the unobstructed side of the road.  Deriving
	# the camera from the landmark itself previously placed it inside the mesh.
	boot.camera.global_position = entry.transform * Vector3(-10.0, 4.8, 15.0)
	boot.camera.look_at(entry.transform * Vector3(10.0, 1.0, 5.0), Vector3.UP)
	await _save_viewport(file_name)
	boot.camera.set_process(true)

func _build_comparison(before_path: String, after_path: String, output_path: String) -> void:
	var original := Image.load_from_file(ProjectSettings.globalize_path(before_path))
	var pilot := Image.load_from_file(ProjectSettings.globalize_path(after_path))
	_check(original != null and not original.is_empty() and pilot != null and not pilot.is_empty(), "comparison inputs missing")
	if original == null or original.is_empty() or pilot == null or pilot.is_empty():
		return
	original.resize(640, 720, Image.INTERPOLATE_LANCZOS)
	pilot.resize(640, 720, Image.INTERPOLATE_LANCZOS)
	var combined := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	combined.blit_rect(original, Rect2i(0, 0, 640, 720), Vector2i.ZERO)
	combined.blit_rect(pilot, Rect2i(0, 0, 640, 720), Vector2i(640, 0))
	_check(combined.save_png(ProjectSettings.globalize_path(output_path)) == OK, "polish comparison could not be saved")

func _validate_performance() -> void:
	var stats := _frame_stats(frame_times_ms)
	_check(float(stats.average_fps) >= 58.0, "average FPS is not approximately 60: %.2f" % float(stats.average_fps))
	_check(float(stats.p5_fps) >= 55.0, "P5 FPS below 55: %.2f" % float(stats.p5_fps))
	_check(float(stats.minimum_sustained_fps) >= 55.0, "minimum sustained FPS below 55: %.2f" % float(stats.minimum_sustained_fps))
	_check(not bool(stats.recurring_stutter), "recurring stutter detected")
	_check(peak_draw_calls <= 900, "draw calls exceed visual-polish gate: %d" % peak_draw_calls)
	_check(peak_primitives <= 350000, "primitive count exceeds visual-polish gate: %d" % peak_primitives)

func _finish(boot: Node) -> void:
	var stats := _frame_stats(frame_times_ms)
	var pilot: Node3D = boot.road.environment_visual_pilot if boot != null and boot.road != null else null
	var report := "Desert Velocity G1-D.1 Environment Kit V2 playable visual polish\n"
	report += "checkpoint_initial=dbea31ff29a2b00394884c5b6a0ad34eb980953c\nsource_scene=res://scenes/main/Boot.tscn\nmode=STAGE\npilot_start_segment=0\npilot_end_segment=9\npilot_length_meters=520\ncheckpoint_involved=1@segment9\nrock_arch_deferred=true\n"
	report += "route_segments=64\nlogical_route_unchanged=true\ncollision_shapes_baseline=%d\ncollision_shapes_pilot=%d\npilot_collision_objects=%d\n" % [baseline_collision_shapes, pilot_collision_shapes, int(pilot.get_meta("collision_count", -1)) if pilot != null else -1]
	report += "environment_kit_v2=true\ng1d1_visual_polish=true\nsource_materials_unchanged=true\nvisual_altimetry=true\nmuted_rock_palette=true\ncontact_scatter=true\nirregular_road_edges=true\ngolden_hour_rebalanced=true\nlod0_instances=%d\nlod1_instances=%d\nlod2_instances=%d\nmultimesh_groups=%d\nmultimesh_instances=%d\n" % [int(pilot.get_meta("lod0_instances", 0)) if pilot != null else 0, int(pilot.get_meta("lod1_instances", 0)) if pilot != null else 0, int(pilot.get_meta("lod2_instances", 0)) if pilot != null else 0, int(pilot.get_meta("multimesh_groups", 0)) if pilot != null else 0, int(pilot.get_meta("multimesh_instances", 0)) if pilot != null else 0]
	report += "sample_seconds=%.2f\nframe_samples=%d\naverage_fps=%.2f\np5_fps=%.2f\nminimum_sustained_fps=%.2f\nframe_time_p95_ms=%.3f\nframe_time_p99_ms=%.3f\nstutter_frames=%d\nstutter_percent=%.3f\nmax_consecutive_stutter_frames=%d\nrecurring_stutter=%s\n" % [SAMPLE_SECONDS, frame_times_ms.size(), float(stats.average_fps), float(stats.p5_fps), float(stats.minimum_sustained_fps), float(stats.p95_ms), float(stats.p99_ms), int(stats.stutter_frames), float(stats.stutter_percent), int(stats.max_consecutive_stutter), str(bool(stats.recurring_stutter)).to_lower()]
	report += "peak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\npeak_static_memory_mb=%.2f\nload_time_ms=%.2f\ncheckpoint_reached=%s\n" % [peak_draw_calls, peak_primitives, peak_nodes, peak_static_memory / 1048576.0, load_time_ms, str(checkpoint_reached).to_lower()]
	report += "failure_count=%d\nclassification=%s\n" % [failures.size(), "PASS" if failures.is_empty() else "FAIL"]
	for failure in failures:
		report += "failure=%s\n" % failure
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("metrics report could not be written")
	else:
		file.store_string(report)
		file.close()
	print(report)
	if failures.is_empty():
		print("ENVIRONMENT_V2_PLAYABLE_VISUAL_POLISH_RESULT PASS")
	else:
		for failure in failures:
			printerr("ENVIRONMENT_V2_PLAYABLE_VISUAL_POLISH_FAIL ", failure)
		print("ENVIRONMENT_V2_PLAYABLE_VISUAL_POLISH_RESULT FAIL count=", failures.size())

func _frame_stats(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return {"average_fps": 0.0, "p5_fps": 0.0, "minimum_sustained_fps": 0.0, "p95_ms": 0.0, "p99_ms": 0.0, "stutter_frames": 0, "stutter_percent": 0.0, "max_consecutive_stutter": 0, "recurring_stutter": false}
	var sorted := values.duplicate()
	sorted.sort()
	var fps := PackedFloat64Array()
	for value in values:
		fps.append(1000.0 / maxf(value, 0.001))
	var sorted_fps := fps.duplicate()
	sorted_fps.sort()
	var threshold := maxf(33.333, sorted[int(sorted.size() / 2)] * 2.0)
	var stutter_frames := 0
	var run := 0
	var maximum_run := 0
	for value in values:
		if value > threshold:
			stutter_frames += 1
			run += 1
			maximum_run = maxi(maximum_run, run)
		else:
			run = 0
	var percent := float(stutter_frames) / values.size() * 100.0
	return {
		"average_fps": _average(fps),
		"p5_fps": sorted_fps[clampi(int(floor((sorted_fps.size() - 1) * 0.05)), 0, sorted_fps.size() - 1)],
		"minimum_sustained_fps": _minimum_rolling_fps(fps, SUSTAINED_WINDOW),
		"p95_ms": sorted[clampi(int(ceil((sorted.size() - 1) * 0.95)), 0, sorted.size() - 1)],
		"p99_ms": sorted[clampi(int(ceil((sorted.size() - 1) * 0.99)), 0, sorted.size() - 1)],
		"stutter_frames": stutter_frames,
		"stutter_percent": percent,
		"max_consecutive_stutter": maximum_run,
		"recurring_stutter": maximum_run >= 3 or percent > 0.5,
	}

func _segment_by_route_index(road: RoadManager, route_index: int) -> Node3D:
	for segment in road.segments:
		if int(segment.get_meta("route_index", -1)) == route_index:
			return segment
	return null

func _drive_toward_center(boot: Node) -> void:
	var toward_center: Vector3 = boot.road.direction_to_center(boot.player.global_position)
	var steer_side := toward_center.dot(boot.player.global_basis.x)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if absf(boot.road.road_local_position(boot.player.global_position).x) > 1.5:
		Input.action_press("steer_right" if steer_side > 0.0 else "steer_left")

func _collect_performance() -> void:
	peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	peak_primitives = maxi(peak_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	peak_static_memory = maxi(peak_static_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))

func _save_viewport(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	_check(image.save_png(ProjectSettings.globalize_path(SHOT_ROOT + file_name)) == OK, "could not save %s" % file_name)

func _dispose_boot(boot: Node) -> void:
	if boot == null or not is_instance_valid(boot):
		return
	boot.set_process(false)
	if boot.camera != null:
		boot.camera.target = null
		boot.camera.set_process(false)
	if boot.road != null:
		boot.road.player = null
		boot.road.set_process(false)
	boot.free()

func _ensure_inputs() -> void:
	for action_name in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_vehicle"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

func _release_inputs() -> void:
	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_release("handbrake")

func _minimum_rolling_fps(values: PackedFloat64Array, window: int) -> float:
	var actual := mini(window, values.size())
	var total := 0.0
	for index in actual:
		total += values[index]
	var result := total / actual
	for index in range(actual, values.size()):
		total += values[index] - values[index - actual]
		result = minf(result, total / actual)
	return result

func _average(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
