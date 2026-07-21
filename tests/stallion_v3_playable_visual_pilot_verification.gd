extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("STALLION_V3_PLAYABLE_VISUAL_PILOT_START")
	for action_name in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_vehicle"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	_check(VehicleFactory.use_stallion_v3_visual_pilot, "V3 pilot is not the runtime default")
	var visual := VehicleFactory.create_vehicle(0, false)
	root.add_child(visual)
	await process_frame
	_check(bool(visual.get_meta("stallion_v3_visual_pilot", false)), "factory did not instantiate the V3 pilot")
	_check(str(visual.get_meta("stallion_v3_variant", "")) == "rally_sand", "runtime variant is not Rally Sand")
	_check(str(visual.get_meta("visual_model_path", "")) == StallionV3PlayableVisual.RUNTIME_OPTIMIZED_SCENE_PATH, "optimized runtime scene path changed")
	_check(str(visual.get_meta("runtime_source_asset_path", "")) == StallionV3PlayableVisual.RUNTIME_SOURCE_ASSET_PATH, "runtime source is not approved LOD1")
	_check(visual is StallionV3PlayableVisual and int(visual.get_meta("runtime_source_lod", -1)) == 1, "runtime pilot is not using source LOD1")
	_check(bool(visual.get_meta("runtime_geometry_precomputed", false)), "runtime geometry is not precomputed")
	_check(visual.scale.is_equal_approx(Vector3.ONE), "runtime scale is not 1:1")
	_check(visual.position.is_equal_approx(Vector3.ZERO), "physics-independent wrapper root offset changed")
	for model in visual.lod_models:
		_check(model.position.is_equal_approx(StallionV3PlayableVisual.MODEL_OFFSET), "runtime model ground offset changed")
	var mesh_count := visual.find_children("*", "MeshInstance3D", true, false).size()
	_check(mesh_count == 10, "optimized production hierarchy changed: %d meshes" % mesh_count)
	_check(visual.lod_models.size() == 1 and not bool(visual.get_meta("manual_lods", true)), "production wrapper loaded unused LODs")
	_check(visual.find_child("RuntimeStatic_paint", true, false) != null, "precomputed static runtime surfaces are missing")
	_check(int(visual.get_meta("runtime_static_surface_draws", -1)) == 6, "static material draw budget changed")
	for wheel_name in StallionV3PlayableVisual.RUNTIME_WHEEL_CENTERS:
		var wheel := visual.lod_models[0].find_child(wheel_name, true, false) as Node3D
		_check(wheel != null, "missing runtime wheel " + wheel_name)
		if wheel != null:
			var desired: Vector3 = StallionV3PlayableVisual.RUNTIME_WHEEL_CENTERS[wheel_name]
			_check((wheel.position - Vector3(-desired.x, desired.y, -desired.z)).length() < 0.001, "runtime wheel center changed " + wheel_name)
	var controller := VehicleController.new()
	controller.setup(0)
	root.add_child(controller)
	await process_frame
	_check(bool(controller.visual.get_meta("stallion_v3_visual_pilot", false)), "VehicleController did not receive V3")
	_check(controller.visual_wheels.size() == 4, "V3 wheel animation cache incomplete")
	controller.speed = 18.0
	controller.steering = 0.8
	controller._update_wheels(0.1)
	for wheel in controller.visual_wheels:
		_check(absf(wheel.rotation.x) > 0.01, "V3 wheel spin missing " + str(wheel.name))
		if bool(wheel.get_meta("front_wheel", false)):
			_check(absf(wheel.rotation.y) > 0.01, "V3 front steering missing " + str(wheel.name))
	var previous_v3 := VehicleFactory.use_stallion_v3_visual_pilot
	VehicleFactory.use_stallion_v3_visual_pilot = false
	var fallback := VehicleFactory.create_vehicle(0, false)
	root.add_child(fallback)
	_check(bool(fallback.get_meta("blender_stallion_v2", false)), "V2 fallback did not activate")
	_check(not bool(fallback.get_meta("stallion_v3_visual_pilot", false)), "fallback still identifies as V3")
	_check(str(fallback.get_meta("visual_model_path", "")) == VehicleFactory.STALLION_V2_PATH, "fallback V2 path changed")
	VehicleFactory.use_stallion_v3_visual_pilot = previous_v3
	_check(VehicleFactory.use_stallion_v3_visual_pilot, "V3 default flag was not restored")
	visual.queue_free()
	controller.queue_free()
	fallback.queue_free()
	for _frame in 8:
		await process_frame
	if failures.is_empty():
		print("STALLION_V3_PLAYABLE_VISUAL_PILOT_RESULT PASS")
	else:
		for failure in failures:
			printerr("STALLION_V3_PLAYABLE_VISUAL_PILOT_FAIL ", failure)
		print("STALLION_V3_PLAYABLE_VISUAL_PILOT_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
