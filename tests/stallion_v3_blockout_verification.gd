extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("STALLION_V3_BLOCKOUT_TEST_START")
	var packed := load("res://scenes/visual/StallionV3BlockoutReview.tscn") as PackedScene
	_check(packed != null, "blockout review scene did not load")
	if packed == null:
		_finish()
		return
	var review := packed.instantiate()
	root.add_child(review)
	for _frame in 8:
		await process_frame
	var v3 := review.v3 as Node3D
	v3.rotation = Vector3.ZERO
	_check(v3 != null and bool(v3.get_meta("stallion_v3_blockout", false)), "V3 isolated wrapper is missing")
	_check(v3.wheel_pivots_valid(), "V3 wheel pivot preparation failed")
	_check(review.v2 != null and bool(review.v2.get_meta("blender_stallion_v2", false)), "V2 comparison reference is missing")
	_check(v3.find_child("V3_VisibleSuspension", true, false) != null, "visible suspension assembly is missing")
	_check(v3.find_child("V3_RollCage", true, false) != null, "structural roll cage is missing")
	_check(v3.find_child("V3_UnderbodySkid", true, false) != null, "underbody skid plate is missing")
	_check(v3.find_child("V3_FunctionalDetails", true, false) != null, "functional front/rear geometry is missing")
	var meshes := v3.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 13, "blockout mesh count changed: %d" % meshes.size())
	var triangles := 0
	var material_names: Dictionary = {}
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			triangles += mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3
			var surface_material := mesh_instance.mesh.surface_get_material(surface)
			if surface_material != null:
				material_names[surface_material.resource_name] = true
	_check(triangles >= 20000 and triangles <= 45000, "triangle count outside blockout budget: %d" % triangles)
	_check(material_names.size() <= 7, "material count exceeds blockout budget: %d" % material_names.size())
	var aabb := _combined_aabb(v3)
	_check(aabb.size.z >= 4.65 and aabb.size.z <= 4.91, "length outside target: %.3f" % aabb.size.z)
	_check(aabb.size.x >= 2.10 and aabb.size.x <= 2.22, "width outside target: %.3f" % aabb.size.x)
	_check(aabb.size.y >= 1.65 and aabb.size.y <= 1.82, "height outside target: %.3f" % aabb.size.y)
	_check(review.get_node_or_null("NeutralEnvironment") != null, "neutral review environment is missing")
	_check(review.get_node_or_null("ReviewCamera") != null, "deterministic review camera is missing")
	print("STALLION_V3_BLOCKOUT_TEST_METRICS triangles=", triangles, " meshes=", meshes.size(), " materials=", material_names.size(), " aabb=", aabb)
	review.queue_free()
	for _frame in 8:
		await process_frame
	_finish()

func _combined_aabb(node: Node3D) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := mesh_instance.global_transform * vertex
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("STALLION_V3_BLOCKOUT_TEST_RESULT PASS")
	else:
		for failure in failures:
			printerr("STALLION_V3_BLOCKOUT_FAIL ", failure)
		print("STALLION_V3_BLOCKOUT_TEST_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
