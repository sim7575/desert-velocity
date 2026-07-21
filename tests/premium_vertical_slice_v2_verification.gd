extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("PREMIUM_SLICE_V2_TEST_START")
	var packed := load("res://scenes/visual/PremiumVerticalSliceV2.tscn") as PackedScene
	_assert(packed != null, "PremiumVerticalSliceV2.tscn did not load")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate() as PremiumVerticalSliceV2
	root.add_child(scene)
	for _frame in 12:
		await process_frame
	var metrics: Dictionary = scene.structure_metrics()
	_assert(float(metrics.duration) >= 30.0 and float(metrics.duration) <= 45.0, "duration is outside 30-45 seconds")
	_assert(float(metrics.path_length) > 520.0, "presentation route is too short")
	_assert(float(metrics.wide_curve_degrees) > 40.0, "wide curve is not readable")
	_assert(float(metrics.elevation_drop) > 14.0, "descent is not present")
	_assert(float(metrics.bump_prominence) > 1.5, "bump is not present")
	_assert(float(metrics.continuity_max_gap) < 1.1, "route continuity failed")
	_assert(bool(metrics.player_v3), "Rally Sand LOD0 player is missing")
	_assert(bool(metrics.opponent_v3), "Night Raid LOD1 opponent is missing")
	_assert(bool(metrics.environment_kit_v2), "approved Environment Kit V2 is not the source library")
	_assert(bool(metrics.arch_landmark), "final rock arch is missing")
	_assert(bool(metrics.obstacle), "readable obstacle group is missing")
	_assert(int(metrics.multimesh_groups) >= 5, "MultiMesh aggregation is insufficient")
	_assert(bool(metrics.dust_v2), "dual local dust emitters are missing")
	_assert(bool(metrics.boost_v2), "warm mechanical boost is missing")
	_assert(bool(metrics.hud_v2), "presentation HUD V2 is missing")
	_assert(bool(metrics.audio_local), "local non-production audio instance is missing")
	_assert(ResourceLoader.exists("res://scenes/visual/vertical_slice_v2/soft_particle_v2.gdshader"), "soft dust shader is missing")
	_assert(ResourceLoader.exists("res://scenes/visual/vertical_slice_v2/boost_particle_v2.gdshader"), "warm boost shader is missing")
	_assert(ResourceLoader.exists("res://scenes/visual/vertical_slice_v2/contact_shadow_v2.gdshader"), "soft contact shadow shader is missing")
	_assert(ResourceLoader.exists("res://assets/shaders/vertical_slice_v2/premium_slice_surface.gdshader"), "F1.1 terrain/road shader is missing")
	_assert(scene.player_follow is PathFollow3D and scene.opponent_follow is PathFollow3D, "deterministic PathFollow rigs are missing")
	_assert(_count_forbidden_physics(scene) == 0, "a vehicle physics body was added to the isolated slice")
	_assert(_count_box_meshes(scene.environment_root) == 0, "a visible BoxMesh was used in the integrated environment")
	_assert(_count_multimesh_instances(scene.multimesh_root) >= 300, "environment scatter population is too sparse")
	_assert(_lod_set(scene.environment_root) == {0: true, 1: true, 2: true}, "environment LOD0/LOD1/LOD2 coverage is incomplete")
	var road_material := scene.road_mesh.get_active_material(0) as ShaderMaterial
	var terrain_material := scene.terrain_mesh.get_active_material(0) as ShaderMaterial
	_assert(road_material != null and bool(road_material.get_meta("e2_1_base_preserved", false)), "road revision lost E2.1 provenance")
	_assert(terrain_material != null and bool(terrain_material.get_meta("e2_1_base_preserved", false)), "terrain revision lost E2.1 provenance")
	_assert(float(road_material.get_shader_parameter("surface_kind")) == 1.0, "road does not use its darker authored surface")
	_assert(float(terrain_material.get_shader_parameter("surface_kind")) == 0.0, "terrain does not use its warm authored surface")
	_assert(scene.environment_root.find_child("DustyShoulderLeft", true, false) != null and scene.environment_root.find_child("DustyShoulderRight", true, false) != null, "irregular road shoulders are missing")
	_assert(scene.camera_rig.current, "dedicated chase camera is not active")
	var stability: Dictionary = scene.camera_rig.stability()
	_assert(bool(stability.deterministic), "camera contains non-deterministic shake")
	_assert(float(stability.base_fov) >= 64.0 and float(stability.base_fov) <= 68.0, "base FOV is outside the F1.1 composition range")
	_assert(float(stability.boost_fov) <= 74.0, "boost FOV is excessive")
	_assert(float(stability.height) >= 1.9 and float(stability.height) <= 2.2, "camera height is outside the F1.1 chase range")
	_assert(PremiumSliceV2Camera.CHASE_DISTANCE >= 5.3 and PremiumSliceV2Camera.CHASE_DISTANCE <= 6.2, "camera distance is outside the F1.1 chase range")
	_assert(scene.boost_light.light_color.r > scene.boost_light.light_color.b and scene.boost_light.omni_range < 4.0, "boost accent is not warm and local")
	_assert(_count_opaque_hud_panels(scene.hud) == 0, "HUD contains an opaque panel")

	scene.set_sequence_time(0.0)
	var initial_gap: float = scene.opponent_follow.progress - scene.player_follow.progress
	scene.set_sequence_time(19.0)
	var final_gap: float = scene.opponent_follow.progress - scene.player_follow.progress
	_assert(initial_gap > 0.0 and final_gap < 0.0, "automatic overtake did not occur")
	scene.set_sequence_time(27.0)
	_assert(scene.player_visual.position.y > 0.70, "controlled scenic jump has insufficient clearance")
	scene.set_sequence_time(31.0)
	_assert(scene.boost_emitters[0].emitting and scene.boost_emitters[1].emitting, "boost is not active in its authored beat")
	_assert(scene.camera_rig.boost_strength > 0.5, "camera does not communicate boost")
	scene.set_sequence_time(38.0)
	_assert(scene.sequence_complete, "complete sequence did not reach terminal state")
	_assert(scene.player_follow.progress_ratio > 0.99, "player did not reach the final arch exit")
	_verify_screenshots()
	print("PREMIUM_SLICE_V2_STRUCTURE_METRICS ", metrics)
	scene.queue_free()
	for _frame in 8:
		await process_frame
	_finish()

func _count_forbidden_physics(node: Node) -> int:
	var count := int(node is CharacterBody3D or node is RigidBody3D or node is VehicleBody3D)
	for child in node.get_children():
		count += _count_forbidden_physics(child)
	return count

func _count_box_meshes(node: Node) -> int:
	var count := int(node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh)
	for child in node.get_children():
		count += _count_box_meshes(child)
	return count

func _count_multimesh_instances(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh != null:
			count += (child as MultiMeshInstance3D).multimesh.instance_count
	return count

func _lod_set(node: Node) -> Dictionary:
	var result := {}
	if node.has_meta("environment_lod"):
		result[int(node.get_meta("environment_lod"))] = true
	for child in node.get_children():
		for lod in _lod_set(child):
			result[lod] = true
	return result

func _count_opaque_hud_panels(node: Node) -> int:
	var count := int(node is Panel or node is ColorRect)
	for child in node.get_children():
		count += _count_opaque_hud_panels(child)
	return count

func _verify_screenshots() -> void:
	var names := [
		"01_start_revised.png", "02_curve_revised.png", "03_overtake_revised.png", "04_descent_revised.png",
		"05_obstacle_revised.png", "06_jump_revised.png", "07_boost_revised.png", "08_arch_approach_revised.png",
		"09_arch_exit_revised.png", "10_vehicle_scale.png", "11_terrain_road_detail.png", "12_dust_detail.png",
		"13_before_after_f1.png", "14_golden_hour_final.png",
	]
	for file_name in names:
		var path: String = "res://screenshots/premium_vertical_slice_v2/revision/" + String(file_name)
		_assert(FileAccess.file_exists(path), "missing real capture: " + file_name)
		if FileAccess.file_exists(path):
			var texture := load(path) as Texture2D
			_assert(texture != null and texture.get_width() == 1280 and texture.get_height() == 720, "capture is not 1280x720: " + file_name)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PREMIUM_SLICE_V2_TEST_RESULT PASS")
	else:
		for failure in failures:
			printerr("PREMIUM_SLICE_V2_FAIL ", failure)
		print("PREMIUM_SLICE_V2_TEST_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
