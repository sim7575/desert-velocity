extends SceneTree

const REPORT_PATH := "res://reports/stallion_v3_runtime_optimization_repair_metrics.txt"
const SHOT_ROOT := "res://screenshots/playable_camera_v3_optimization/runtime_repair/"
const BOOT_PATH := "res://scenes/main/Boot.tscn"
const REVIEW_PATH := "res://scenes/visual/assets/DesertStallionV3Visual.tscn"
const SAMPLE_SECONDS := 30.0
const SUSTAINED_WINDOW := 30
const G1C_DRAW_CALLS := 842
const G1C_PRIMITIVES := 148892
const G1C_NODES := 852
const G1C_MEMORY_MB := 52.13
const G1C_LOAD_MS := 694.81

var failures: Array[String] = []
var cold_asset_ms := PackedFloat64Array()
var warm_asset_ms := PackedFloat64Array()
var boot_stage_ms := PackedFloat64Array()
var factory_ms := PackedFloat64Array()
var frame_times_ms := PackedFloat64Array()
var initial_frame_times_ms := PackedFloat64Array()
var peak_draw_calls := 0
var peak_primitives := 0
var peak_nodes := 0
var peak_static_memory := 0
var mesh_count := 0
var surface_count := 0
var triangle_count := 0
var material_count := 0
var lod0_cached_during_runtime := false
var lod2_cached_during_runtime := false
var v2_cached_with_v3 := false
var curve_captured := false
var high_speed_captured := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("STALLION_V3_RUNTIME_OPTIMIZATION_REPAIR_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_ROOT))
	_ensure_inputs()
	_measure_resource_loads()
	await _measure_boot_stage_loads()
	await _measure_factory_builds()
	var packed := load(BOOT_PATH) as PackedScene
	_check(packed != null, "Boot.tscn failed to load")
	if packed == null:
		await _finish(null)
		return
	var boot := packed.instantiate()
	root.add_child(boot)
	await process_frame
	boot.run_mode = "STAGE"
	boot.save.vehicle = 0
	boot.start_game()
	await process_frame
	await RenderingServer.frame_post_draw
	_validate_runtime_visual(boot.player.visual)
	for _frame in 300:
		var started := Time.get_ticks_usec()
		await process_frame
		initial_frame_times_ms.append((Time.get_ticks_usec() - started) / 1000.0)
	await _run_stable_drive(boot)
	await _verify_restart_and_boost(boot)
	await _capture_controlled_set(boot)
	_validate_performance()
	await _finish(boot)
	boot.set_process(false)
	if boot.camera != null:
		boot.camera.target = null
		boot.camera.set_process(false)
	if boot.road != null:
		boot.road.player = null
		boot.road.set_process(false)
	boot.free()
	for _frame in 8:
		await process_frame
	quit(0 if failures.is_empty() else 1)

func _ensure_inputs() -> void:
	for action_name in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_vehicle"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

func _measure_resource_loads() -> void:
	for _sample in 3:
		var started := Time.get_ticks_usec()
		var resource := ResourceLoader.load(StallionV3PlayableVisual.RUNTIME_OPTIMIZED_SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		cold_asset_ms.append((Time.get_ticks_usec() - started) / 1000.0)
		_check(resource is PackedScene, "cold optimized resource load failed")
		resource = null
	var cached := load(StallionV3PlayableVisual.RUNTIME_OPTIMIZED_SCENE_PATH) as PackedScene
	_check(cached != null, "optimized scene warmup failed")
	for _sample in 3:
		var started := Time.get_ticks_usec()
		var resource := load(StallionV3PlayableVisual.RUNTIME_OPTIMIZED_SCENE_PATH) as PackedScene
		warm_asset_ms.append((Time.get_ticks_usec() - started) / 1000.0)
		_check(resource == cached, "warm load did not reuse the optimized PackedScene")

func _measure_boot_stage_loads() -> void:
	for _sample in 3:
		var started := Time.get_ticks_usec()
		var packed := ResourceLoader.load(BOOT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		_check(packed != null, "cold Boot load failed")
		if packed == null:
			continue
		var boot := packed.instantiate()
		root.add_child(boot)
		await process_frame
		boot.run_mode = "STAGE"
		boot.save.vehicle = 0
		boot.start_game()
		await process_frame
		await RenderingServer.frame_post_draw
		boot_stage_ms.append((Time.get_ticks_usec() - started) / 1000.0)
		_check(bool(boot.player.visual.get_meta("stallion_v3_visual_pilot", false)), "cold Boot did not create V3")
		boot.set_process(false)
		boot.camera.target = null
		boot.camera.set_process(false)
		boot.road.player = null
		boot.road.set_process(false)
		boot.free()
		for _frame in 8:
			await process_frame

func _measure_factory_builds() -> void:
	for _sample in 3:
		var started := Time.get_ticks_usec()
		var visual := VehicleFactory.create_vehicle(0, false)
		root.add_child(visual)
		await process_frame
		factory_ms.append((Time.get_ticks_usec() - started) / 1000.0)
		_check(bool(visual.get_meta("runtime_geometry_precomputed", false)), "factory used non-precomputed geometry")
		visual.queue_free()
		for _frame in 4:
			await process_frame

func _validate_runtime_visual(visual: Node3D) -> void:
	_check(VehicleFactory.use_stallion_v3_visual_pilot, "V3 is not the runtime default")
	_check(bool(visual.get_meta("stallion_v3_visual_pilot", false)), "runtime player is not V3")
	_check(str(visual.get_meta("stallion_v3_variant", "")) == "rally_sand", "runtime variant is not Rally Sand")
	_check(str(visual.get_meta("visual_model_path", "")) == StallionV3PlayableVisual.RUNTIME_OPTIMIZED_SCENE_PATH, "runtime optimized path changed")
	_check(str(visual.get_meta("runtime_source_asset_path", "")) == StallionV3PlayableVisual.RUNTIME_SOURCE_ASSET_PATH, "runtime source is not approved LOD1")
	_check(int(visual.get_meta("runtime_source_lod", -1)) == 1, "runtime source LOD is not LOD1")
	_check(bool(visual.get_meta("runtime_geometry_precomputed", false)), "runtime merge path is active")
	mesh_count = visual.find_children("*", "MeshInstance3D", true, false).size()
	surface_count = _surface_count(visual)
	triangle_count = _triangle_count(visual)
	material_count = _unique_material_count(visual)
	_check(mesh_count == 10, "runtime mesh count changed: %d" % mesh_count)
	_check(surface_count == 14, "runtime surface count changed: %d" % surface_count)
	_check(triangle_count == 27670, "runtime triangle count changed: %d" % triangle_count)
	_check(material_count == 7, "approved material sharing changed: %d unique materials" % material_count)
	_check(visual.lod_models.size() == 1, "runtime wrapper loaded more than one LOD")
	_check(visual.find_child("RuntimeStatic_paint", true, false) != null, "precomputed static mesh missing")
	lod0_cached_during_runtime = ResourceLoader.has_cached(DesertStallionV3Visual.LOD_PATHS[0])
	lod2_cached_during_runtime = ResourceLoader.has_cached(DesertStallionV3Visual.LOD_PATHS[2])
	v2_cached_with_v3 = ResourceLoader.has_cached(VehicleFactory.STALLION_V2_PATH)
	_check(not lod0_cached_during_runtime, "LOD0 was loaded during normal V3 runtime")
	_check(not lod2_cached_during_runtime, "LOD2 was loaded during normal V3 runtime")
	_check(not v2_cached_with_v3, "V2 was loaded together with normal V3 runtime")
	for wheel_name in StallionV3PlayableVisual.RUNTIME_WHEEL_CENTERS:
		var wheel := visual.find_child(wheel_name, true, false) as Node3D
		_check(wheel != null and bool(wheel.get_meta("vehicle_wheel", false)), "runtime wheel pivot missing: %s" % wheel_name)

func _run_stable_drive(boot: Node) -> void:
	boot.player.controls_enabled = true
	Input.action_press("accelerate")
	var sample_started := Time.get_ticks_usec()
	var previous_ticks := sample_started
	while (Time.get_ticks_usec() - sample_started) / 1000000.0 < SAMPLE_SECONDS:
		_check(boot.player != null, "benchmark session ended unexpectedly")
		if boot.player == null:
			break
		boot.fuel = BalanceData.START_FUEL
		boot.health = BalanceData.START_HEALTH
		boot.player.invulnerability = maxf(float(boot.player.invulnerability), 0.25)
		_drive_toward_center(boot)
		await process_frame
		var now := Time.get_ticks_usec()
		var delta_ms := (now - previous_ticks) / 1000.0
		previous_ticks = now
		frame_times_ms.append(delta_ms)
		_collect_performance()
		var curve := absf(_curve_at_player(boot))
		if not curve_captured and curve > 0.05 and absf(boot.player.speed) > 12.0:
			await _save_viewport("lod1_curve_gameplay.png")
			curve_captured = true
			previous_ticks = Time.get_ticks_usec()
		if not high_speed_captured and absf(boot.player.speed) > 35.0:
			await _save_viewport("lod1_high_speed_gameplay.png")
			high_speed_captured = true
			previous_ticks = Time.get_ticks_usec()
	_release_inputs()
	_check(curve_captured, "stable drive did not reach a real curve")
	_check(high_speed_captured, "stable drive did not reach high speed")

func _verify_restart_and_boost(boot: Node) -> void:
	boot.camera.target = null
	boot.camera.set_process(false)
	boot.road.player = null
	boot.road.set_process(false)
	boot.start_game()
	await process_frame
	boot.camera.set_process(true)
	_check(bool(boot.player.visual.get_meta("stallion_v3_visual_pilot", false)), "race restart lost V3 runtime")
	_check(int(boot.player.visual.get_meta("runtime_source_lod", -1)) == 1, "race restart changed runtime LOD")
	boot.player.speed = 35.0
	boot.player.activate_turbo()
	for _frame in 90:
		await process_frame
	_check(boot.player.turbo_time > 0.0, "existing boost did not activate")

func _capture_controlled_set(boot: Node) -> void:
	boot.player.process_mode = Node.PROCESS_MODE_DISABLED
	boot.road.process_mode = Node.PROCESS_MODE_DISABLED
	boot.player.controls_enabled = false
	boot.player.speed = 0.0
	boot.player.velocity = Vector3.ZERO
	for _frame in 120:
		await process_frame
	await _save_viewport("lod1_runtime_controlled.png")
	await _save_viewport("lod1_rear_gameplay.png")
	var runtime_visual: Node3D = boot.player.visual
	var review_scene := load(REVIEW_PATH) as PackedScene
	_check(review_scene != null, "LOD0 review wrapper failed to load")
	if review_scene != null:
		var lod0 := review_scene.instantiate() as DesertStallionV3Visual
		boot.player.add_child(lod0)
		await process_frame
		lod0.set_lod(0)
		for model in lod0.lod_models:
			model.position = StallionV3PlayableVisual.MODEL_OFFSET
		lod0.transform = runtime_visual.transform
		runtime_visual.visible = false
		await process_frame
		await _save_viewport("lod0_runtime_controlled.png")
		runtime_visual.visible = true
		lod0.visible = false
		_build_split_comparison()
		lod0.queue_free()
		await process_frame
	var saved_transform: Transform3D = boot.camera.global_transform
	boot.camera.global_position = boot.player.global_position + boot.player.global_basis.x * 10.2 + Vector3.UP * 2.9
	boot.camera.look_at(boot.player.global_position + Vector3.UP * 1.1, Vector3.UP)
	await _save_viewport("lod1_side_gameplay.png")
	boot.camera.global_transform = saved_transform
	await process_frame
	await _capture_overlay(boot)

func _capture_overlay(boot: Node) -> void:
	var layer := CanvasLayer.new()
	boot.add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(20, 20)
	panel.size = Vector2(510, 116)
	panel.color = Color(0.03, 0.04, 0.05, 0.82)
	layer.add_child(panel)
	var label := Label.new()
	label.position = Vector2(38, 34)
	label.text = "V3 LOD1 PRECOMPUTED\nMeshInstance3D: %d  |  superfici: %d  |  triangoli: %d\nmateriali condivisi: %d  |  LOD0/LOD2 runtime: NO" % [mesh_count, surface_count, triangle_count, material_count]
	label.add_theme_font_size_override("font_size", 19)
	layer.add_child(label)
	await _save_viewport("runtime_node_surface_overlay.png")
	layer.queue_free()
	await process_frame

func _build_split_comparison() -> void:
	var lod0 := Image.load_from_file(ProjectSettings.globalize_path(SHOT_ROOT + "lod0_runtime_controlled.png"))
	var lod1 := Image.load_from_file(ProjectSettings.globalize_path(SHOT_ROOT + "lod1_runtime_controlled.png"))
	_check(lod0 != null and not lod0.is_empty() and lod1 != null and not lod1.is_empty(), "LOD comparison inputs missing")
	if lod0 == null or lod0.is_empty() or lod1 == null or lod1.is_empty():
		return
	lod0.resize(640, 720, Image.INTERPOLATE_LANCZOS)
	lod1.resize(640, 720, Image.INTERPOLATE_LANCZOS)
	var combined := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	combined.blit_rect(lod0, Rect2i(0, 0, 640, 720), Vector2i.ZERO)
	combined.blit_rect(lod1, Rect2i(0, 0, 640, 720), Vector2i(640, 0))
	_check(combined.save_png(ProjectSettings.globalize_path(SHOT_ROOT + "lod0_lod1_split_comparison.png")) == OK, "split comparison could not be saved")

func _validate_performance() -> void:
	var stats := _frame_stats(frame_times_ms)
	_check(float(stats.average_fps) >= 60.28, "average FPS regressed: %.2f" % float(stats.average_fps))
	_check(float(stats.p5_fps) >= 55.0, "P5 FPS below 55: %.2f" % float(stats.p5_fps))
	_check(float(stats.minimum_sustained_fps) >= 55.0, "minimum sustained FPS below 55: %.2f" % float(stats.minimum_sustained_fps))
	_check(float(stats.p99_ms) <= 33.333, "stable P99 frame time exceeds 33.333 ms: %.3f" % float(stats.p99_ms))
	_check(float(stats.stutter_percent) <= 0.5, "stable slow-frame percentage exceeds 0.5: %.3f" % float(stats.stutter_percent))
	_check(int(stats.max_consecutive_stutter) < 3, "recurring stable stutter detected")
	_check(peak_draw_calls < G1C_DRAW_CALLS, "draw calls did not improve: %d" % peak_draw_calls)
	_check(peak_primitives < G1C_PRIMITIVES, "primitive count did not improve: %d" % peak_primitives)
	_check(peak_nodes < G1C_NODES, "node count did not improve: %d" % peak_nodes)
	_check(peak_static_memory / 1048576.0 <= G1C_MEMORY_MB, "static memory exceeded G1-C: %.2f MB" % (peak_static_memory / 1048576.0))
	_check(_average(boot_stage_ms) <= G1C_LOAD_MS, "average Boot/STAGE load exceeded G1-C: %.2f ms" % _average(boot_stage_ms))

func _finish(boot: Node) -> void:
	var stats := _frame_stats(frame_times_ms)
	var initial := _frame_stats(initial_frame_times_ms)
	var report := "Desert Velocity G1-C.1B Stallion V3 runtime optimization repair\n"
	report += "checkpoint_initial=971a05f5d391d4436676622336dbd7dacb61201e\nsource_lod=LOD1\nsource_asset=%s\noptimized_scene=%s\ngeometry_precomputed=true\nruntime_surface_tool=false\n" % [StallionV3PlayableVisual.RUNTIME_SOURCE_ASSET_PATH, StallionV3PlayableVisual.RUNTIME_OPTIMIZED_SCENE_PATH]
	report += "mesh_instances=%d\nsurfaces=%d\ntriangles=%d\nunique_materials=%d\nlod0_cached_during_runtime=%s\nlod2_cached_during_runtime=%s\nv2_cached_with_v3=%s\n" % [mesh_count, surface_count, triangle_count, material_count, str(lod0_cached_during_runtime).to_lower(), str(lod2_cached_during_runtime).to_lower(), str(v2_cached_with_v3).to_lower()]
	report += _series_report("cold_optimized_asset_ms", cold_asset_ms)
	report += _series_report("warm_optimized_asset_ms", warm_asset_ms)
	report += _series_report("boot_stage_load_ms", boot_stage_ms)
	report += _series_report("vehicle_factory_build_ms", factory_ms)
	report += "stable_sample_seconds=%.2f\nstable_frame_samples=%d\naverage_fps=%.2f\np5_fps=%.2f\nminimum_sustained_fps=%.2f\nframe_time_p95_ms=%.3f\nframe_time_p99_ms=%.3f\nstutter_threshold_ms=%.3f\nstutter_frames=%d\nstutter_percent=%.3f\nmax_consecutive_stutter_frames=%d\nrecurring_stutter=%s\n" % [SAMPLE_SECONDS, frame_times_ms.size(), float(stats.average_fps), float(stats.p5_fps), float(stats.minimum_sustained_fps), float(stats.p95_ms), float(stats.p99_ms), float(stats.threshold_ms), int(stats.stutter_frames), float(stats.stutter_percent), int(stats.max_consecutive_stutter), str(bool(stats.recurring_stutter)).to_lower()]
	report += "initial_shader_warmup_frame_p99_ms=%.3f\ninitial_shader_warmup_max_ms=%.3f\npeak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\npeak_static_memory_mb=%.2f\ncurve_capture=%s\nhigh_speed_capture=%s\n" % [float(initial.p99_ms), float(initial.maximum_ms), peak_draw_calls, peak_primitives, peak_nodes, peak_static_memory / 1048576.0, str(curve_captured).to_lower(), str(high_speed_captured).to_lower()]
	report += "g1c_draw_calls=%d\ng1c_primitives=%d\ng1c_nodes=%d\ng1c_static_memory_mb=%.2f\ng1c_load_time_ms=%.2f\n" % [G1C_DRAW_CALLS, G1C_PRIMITIVES, G1C_NODES, G1C_MEMORY_MB, G1C_LOAD_MS]
	report += "failure_count=%d\nclassification=%s\n" % [failures.size(), "PASS" if failures.is_empty() else "FAIL"]
	for failure in failures:
		report += "failure=%s\n" % failure
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("final report could not be written")
	else:
		file.store_string(report)
		file.close()
	print(report)
	if failures.is_empty():
		print("STALLION_V3_RUNTIME_OPTIMIZATION_REPAIR_RESULT PASS")
	else:
		for failure in failures:
			printerr("STALLION_V3_RUNTIME_OPTIMIZATION_REPAIR_FAIL ", failure)
		print("STALLION_V3_RUNTIME_OPTIMIZATION_REPAIR_RESULT FAIL count=", failures.size())

func _frame_stats(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return {"average_fps": 0.0, "p5_fps": 0.0, "minimum_sustained_fps": 0.0, "p95_ms": 0.0, "p99_ms": 0.0, "maximum_ms": 0.0, "threshold_ms": 33.333, "stutter_frames": 0, "stutter_percent": 0.0, "max_consecutive_stutter": 0, "recurring_stutter": false}
	var sorted := values.duplicate()
	sorted.sort()
	var fps := PackedFloat64Array()
	for value in values:
		fps.append(1000.0 / maxf(value, 0.001))
	var sorted_fps := fps.duplicate()
	sorted_fps.sort()
	var median := sorted[int(sorted.size() / 2)]
	var threshold := maxf(33.333, median * 2.0)
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
	var stutter_percent := float(stutter_frames) / float(values.size()) * 100.0
	return {
		"average_fps": _average(fps),
		"p5_fps": sorted_fps[clampi(int(floor((sorted_fps.size() - 1) * 0.05)), 0, sorted_fps.size() - 1)],
		"minimum_sustained_fps": _minimum_rolling_fps(fps, SUSTAINED_WINDOW),
		"p95_ms": sorted[clampi(int(ceil((sorted.size() - 1) * 0.95)), 0, sorted.size() - 1)],
		"p99_ms": sorted[clampi(int(ceil((sorted.size() - 1) * 0.99)), 0, sorted.size() - 1)],
		"maximum_ms": sorted[sorted.size() - 1],
		"threshold_ms": threshold,
		"stutter_frames": stutter_frames,
		"stutter_percent": stutter_percent,
		"max_consecutive_stutter": maximum_run,
		"recurring_stutter": maximum_run >= 3 or stutter_percent > 0.5,
	}

func _series_report(prefix: String, values: PackedFloat64Array) -> String:
	var sorted := values.duplicate()
	sorted.sort()
	return "%s_samples=%d\n%s_min=%.3f\n%s_average=%.3f\n%s_max=%.3f\n" % [prefix, values.size(), prefix, sorted[0] if not sorted.is_empty() else 0.0, prefix, _average(values), prefix, sorted[sorted.size() - 1] if not sorted.is_empty() else 0.0]

func _surface_count(node: Node) -> int:
	var total := 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh != null:
			total += mesh_instance.mesh.get_surface_count()
	return total

func _triangle_count(node: Node) -> int:
	var total := 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			total += indices.size() / 3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total

func _unique_material_count(node: Node) -> int:
	var ids: Dictionary = {}
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface)
			if material != null:
				ids[material.get_instance_id()] = true
	return ids.size()

func _collect_performance() -> void:
	peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	peak_primitives = maxi(peak_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	peak_static_memory = maxi(peak_static_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))

func _drive_toward_center(boot: Node) -> void:
	var toward_center: Vector3 = boot.road.direction_to_center(boot.player.global_position)
	var steer_side := toward_center.dot(boot.player.global_transform.basis.x)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if absf(boot.road.road_local_position(boot.player.global_position).x) > 1.5:
		Input.action_press("steer_right" if steer_side > 0.0 else "steer_left")

func _curve_at_player(boot: Node) -> float:
	var route_index := int(boot.road.route_index_near(boot.player.global_position))
	for segment in boot.road.segments:
		if int(segment.get_meta("route_index", -1)) == route_index:
			return float(segment.get_meta("curve_delta", 0.0))
	return 0.0

func _save_viewport(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	_check(image.save_png(ProjectSettings.globalize_path(SHOT_ROOT + file_name)) == OK, "could not save %s" % file_name)

func _minimum_rolling_fps(values: PackedFloat64Array, window: int) -> float:
	if values.is_empty():
		return 0.0
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

func _release_inputs() -> void:
	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_release("handbrake")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
