extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("PREMIUM_SLICE_STRUCTURE_TEST_START")
	var packed := load("res://scenes/visual/PremiumVerticalSlice.tscn") as PackedScene
	_assert(packed != null, "premium vertical slice scene did not load")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for _i in 8: await process_frame
	var metrics: Dictionary = scene.structure_metrics()
	_assert(float(metrics.duration) >= 30.0 and float(metrics.duration) <= 45.0, "sequence duration is outside 30-45 seconds")
	_assert(float(metrics.path_length) > 450.0, "presentation path is too short")
	_assert(float(metrics.wide_curve_degrees) > 35.0, "wide curve is not geometrically readable")
	_assert(float(metrics.elevation_drop) > 10.0, "descent is not present")
	_assert(float(metrics.bump_prominence) > 1.0, "scenic bump is not present")
	_assert(float(metrics.continuity_max_gap) < 1.1, "path continuity sampling failed")
	_assert(bool(metrics.road_collision), "local road raycast collision is missing")
	_assert(bool(metrics.player_v2), "Desert Stallion V2 wrapper is missing")
	_assert(bool(metrics.opponent_v2), "moving opponent wrapper is missing")
	_assert(scene.get_node_or_null("PresentationPath/PlayerFollow") != null, "PathFollow3D player rig is missing")
	_assert(scene.get_node_or_null("PresentationPath/OpponentFollow") != null, "PathFollow3D opponent rig is missing")
	_assert(scene.get_node_or_null("PremiumCamera") != null, "dedicated camera is missing")
	_assert(scene.get_node_or_null("StructureHUD") != null, "temporary isolated HUD is missing")
	_assert(ResourceLoader.exists("res://materials/vertical_slice/desert_surface.gdshader"), "desert surface shader is missing")
	_assert(ResourceLoader.exists("res://materials/vertical_slice/rock_strata.gdshader"), "rock strata shader is missing")
	_assert(ResourceLoader.exists("res://materials/vertical_slice/effect_billboard.gdshader"), "effect billboard shader is missing")
	var sunset_environment := scene.get_node_or_null("SunsetEnvironment") as WorldEnvironment
	_assert(sunset_environment != null and sunset_environment.environment.fog_enabled, "sunset fog environment is missing")
	var canyon_outcrops := scene.get_node_or_null("CanyonLayeredOutcrops")
	_assert(canyon_outcrops != null and canyon_outcrops.get_child_count() >= 14, "layered canyon outcrops are missing")
	_assert(scene.dust_emitters.size() == 2, "dedicated rear dust emitters are missing")
	_assert(scene.boost_emitters.size() == 2, "dedicated boost exhaust emitters are missing")
	_assert(absf(float(scene.opponent_visual.position.x)) >= 3.4, "opponent is not sufficiently lateral for the overtake")
	_assert(_count_box_meshes(scene) == 0, "visible BoxMesh found in premium slice environment")
	await physics_frame
	await _verify_road_raycasts(scene)
	scene.set_sequence_time(0.0)
	var initial_gap: float = float(scene.opponent_follow.progress) - float(scene.player_follow.progress)
	for i in 73:
		scene.set_sequence_time(float(i) * 0.5)
		await process_frame
	var final_gap: float = float(scene.opponent_follow.progress) - float(scene.player_follow.progress)
	_assert(initial_gap > 0.0 and final_gap < 0.0, "automatic overtake did not occur")
	_assert(scene.sequence_complete, "complete sequence did not reach its terminal state")
	scene.set_sequence_time(27.5)
	_assert(scene.boost_emitters[0].emitting and scene.boost_emitters[1].emitting, "boost exhaust is not active during the jump/boost beat")
	_assert(scene.camera_rig.boost_strength > 0.5, "camera boost response is missing")
	scene.set_sequence_time(18.0)
	scene.camera_rig.snap_to_target()
	for _i in 20: await process_frame
	var stability: Dictionary = scene.camera_rig.structural_stability()
	_assert(bool(stability.deterministic), "camera contains non-deterministic shake")
	_assert(float(stability.distance) > 4.0 and float(stability.distance) < 9.0, "camera distance is outside the structural safe range")
	var camera_config: Dictionary = scene.camera_rig.composition_configuration()
	_assert(float(camera_config.distance) < float(camera_config.previous_distance), "camera was not moved closer")
	_assert(float(camera_config.height) < float(camera_config.previous_height), "camera was not lowered")
	_assert(float(camera_config.lateral_offset) > 0.0, "camera lateral composition offset is missing")
	print("PREMIUM_SLICE_STRUCTURE_METRICS ", metrics)
	scene.queue_free()
	for _i in 8: await process_frame
	_finish()

func _verify_road_raycasts(scene: Node) -> void:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	for ratio in [0.18, 0.52, 0.84]:
		var point: Vector3 = scene.curve.sample_baked(scene.curve.get_baked_length() * ratio, true)
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8.0, point + Vector3.DOWN * 8.0, 1)
		var hit: Dictionary = space.intersect_ray(query)
		_assert(not hit.is_empty(), "road raycast missed at ratio %.2f" % ratio)

func _assert(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _count_box_meshes(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh: count += 1
	for child in node.get_children(): count += _count_box_meshes(child)
	return count

func _finish() -> void:
	if failures.is_empty():
		print("PREMIUM_SLICE_STRUCTURE_TEST_RESULT PASS")
	else:
		for failure in failures: printerr("PREMIUM_SLICE_STRUCTURE_FAIL ", failure)
		print("PREMIUM_SLICE_STRUCTURE_TEST_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
