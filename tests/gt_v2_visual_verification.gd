extends SceneTree

var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func run() -> void:
	print("GT_V2_VISUAL_TEST_START")
	var path := "res://assets/models/vehicles/bavarian_gt_r_v2.glb"
	check(ResourceLoader.exists(path), "GT V2 GLB missing")
	var model := load(path).instantiate() as Node3D
	root.add_child(model)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() >= 24 and meshes.size() <= 32, "unexpected optimized mesh count: " + str(meshes.size()))
	var surfaces := 0
	for node in meshes:
		var instance := node as MeshInstance3D
		if instance.mesh:
			for index in instance.mesh.get_surface_count():
				check(instance.mesh.surface_get_material(index) != null, "missing material on " + str(instance.name))
				surfaces += 1
	check(surfaces >= 12, "material surfaces incomplete")
	for wheel_name in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
		var wheel := model.find_child(wheel_name, true, false)
		check(wheel != null and wheel.get_child_count() >= 4, "wheel pivot/geometry missing: " + wheel_name)
	for texture_name in ["base_color", "roughness", "dirt", "scratches", "paint_variation", "carbon", "livery"]:
		check(ResourceLoader.exists("res://assets/textures/vehicles/gt_v2/gt_v2_%s.png" % texture_name), "texture missing: " + texture_name)
	check(ResourceLoader.exists("res://scenes/visual/VisualPrototypeGTV2.tscn"), "isolated GT V2 review scene missing")
	model.queue_free()
	for i in 3: await process_frame
	if failures.is_empty(): print("GT_V2_VISUAL_TEST_RESULT PASS")
	else:
		for failure in failures: printerr("GT_V2_FAIL ", failure)
		print("GT_V2_VISUAL_TEST_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)

func file_contains(path: String, needle: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	return file != null and needle in file.get_as_text()

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
