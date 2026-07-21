extends SceneTree

const EXPECTED_TRIANGLES := [54268, 27670, 10574]
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("STALLION_V3_ASSET_TEST_START")
	var start := Time.get_ticks_usec()
	var packed := load("res://scenes/visual/StallionV3VisualReview.tscn") as PackedScene
	_check(packed != null, "visual review scene did not load")
	if packed == null:
		_finish()
		return
	var review := packed.instantiate()
	root.add_child(review)
	var instantiate_ms := (Time.get_ticks_usec() - start) / 1000.0
	for _frame in 10:
		await process_frame
	var first_render_ready_ms := (Time.get_ticks_usec() - start) / 1000.0
	var v3 := review.v3 as DesertStallionV3Visual
	_check(v3 != null and bool(v3.get_meta("stallion_v3_visual", false)), "isolated V3 visual wrapper is missing")
	_check(not bool(v3.get_meta("production_integrated", true)), "V3 visual must remain outside production")
	_check(v3.lod_models.size() == 3, "manual LOD hierarchy is incomplete")
	for level in 3:
		_check(v3.wheel_pivots_valid(level), "wheel pivots invalid at LOD%d" % level)
		var metrics := _mesh_metrics(v3.lod_models[level])
		_check(abs(metrics.triangles - EXPECTED_TRIANGLES[level]) <= 8, "LOD%d triangle count changed: %d" % [level, metrics.triangles])
		_check(metrics.meshes <= 14, "LOD%d render mesh count too high: %d" % [level, metrics.meshes])
		_check(metrics.materials <= 7, "LOD%d material count too high: %d" % [level, metrics.materials])
	var aabb := _combined_aabb(v3.lod_models[0])
	_check(aabb.size.z >= 4.65 and aabb.size.z <= 4.91, "length outside approved envelope: %.3f" % aabb.size.z)
	_check(aabb.size.x >= 2.10 and aabb.size.x <= 2.22, "width outside approved envelope: %.3f" % aabb.size.x)
	_check(aabb.size.y >= 1.65 and aabb.size.y <= 1.82, "height outside approved envelope: %.3f" % aabb.size.y)
	_check(instantiate_ms < 550.0, "V3 material review instantiation exceeded 550 ms: %.2f" % instantiate_ms)
	_check(first_render_ready_ms < 650.0, "V3 first render including shader compilation exceeded 650 ms: %.2f" % first_render_ready_ms)
	_check(review.v2 != null and bool(review.v2.get_meta("blender_stallion_v2", false)), "V2 same-scale reference is missing")
	_check(review.get_node_or_null("ReviewEnvironment") != null, "review environment is missing")
	_check(review.get_node_or_null("ReviewCamera") != null, "deterministic camera is missing")
	_validate_textures()
	_check(v3.textures_loaded(), "one or more V3 review textures failed to load")
	var assignments := v3.material_assignment_counts()
	_check(assignments.size() == 7, "seven review material categories were not reconstructed")
	for category in ["paint", "metal", "rubber", "glass", "light", "accent", "dark"]:
		_check(int(assignments.get(category, 0)) > 0, "material category is unassigned: " + category)
	var rally_paint := v3._material_for("paint", "rally_sand") as StandardMaterial3D
	var night_paint := v3._material_for("paint", "night_raid") as StandardMaterial3D
	_check(rally_paint != null and rally_paint.metallic == 0.0, "painted body must remain dielectric")
	_check(rally_paint != null and rally_paint.albedo_texture != null, "sRGB base color is not bound to painted body")
	_check(rally_paint != null and rally_paint.normal_enabled and rally_paint.normal_texture != null, "linear normal data is not bound as a normal map")
	_check(rally_paint != null and rally_paint.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED, "ORM red is not assigned to AO")
	_check(rally_paint != null and rally_paint.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN, "ORM green is not assigned to roughness")
	_check(rally_paint != null and rally_paint.metallic_texture == null, "painted body must not consume ORM metallic data")
	var structure_metal := v3._material_for("metal", "rally_sand") as StandardMaterial3D
	_check(structure_metal != null and structure_metal.metallic >= 0.70 and structure_metal.metallic_texture == null, "structure metal metallic fallback is invalid")
	_check(rally_paint != null and rally_paint.albedo_color.get_luminance() > 0.70, "Rally Sand multiplier is too dark")
	_check(night_paint != null and night_paint.albedo_color.get_luminance() > 0.25, "Night Raid multiplier is near black")
	var variant_delta := Vector3(rally_paint.albedo_color.r, rally_paint.albedo_color.g, rally_paint.albedo_color.b).distance_to(Vector3(night_paint.albedo_color.r, night_paint.albedo_color.g, night_paint.albedo_color.b)) if rally_paint != null and night_paint != null else 0.0
	_check(variant_delta > 0.45, "Rally Sand and Night Raid are insufficiently distinct")
	for review_mode in ["base_color_only", "roughness", "metallic", "normal", "ao", "clay", "final_pbr"]:
		v3.set_review_mode(review_mode)
		_check(v3.active_review_mode == review_mode, "review material mode failed: " + review_mode)
	v3.set_review_mode("final_pbr")
	v3.set_variant("rally_sand")
	v3.set_variant("night_raid")
	v3.set_variant("clay")
	print("STALLION_V3_ASSET_TEST_METRICS lod0=", EXPECTED_TRIANGLES[0], " lod1=", EXPECTED_TRIANGLES[1], " lod2=", EXPECTED_TRIANGLES[2], " instantiate_ms=", snapped(instantiate_ms, 0.01), " first_render_ready_ms=", snapped(first_render_ready_ms, 0.01), " aabb=", aabb)
	review.queue_free()
	for _frame in 10:
		await process_frame
	_finish()

func _mesh_metrics(node: Node) -> Dictionary:
	var triangles := 0
	var meshes := 0
	var materials: Dictionary = {}
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		meshes += 1
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			var mat := mesh_instance.mesh.surface_get_material(surface)
			if mat != null:
				materials[mat.resource_name] = true
	return {"triangles": triangles, "meshes": meshes, "materials": materials.size()}

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

func _validate_textures() -> void:
	var expected := {
		"res://assets/textures/vehicles/stallion_v3/stallion_v3_base_color.png": Vector2i(2048, 2048),
		"res://assets/textures/vehicles/stallion_v3/stallion_v3_normal.png": Vector2i(2048, 2048),
		"res://assets/textures/vehicles/stallion_v3/stallion_v3_orm.png": Vector2i(2048, 2048),
		"res://assets/textures/vehicles/stallion_v3/stallion_v3_dirt_damage_mask.png": Vector2i(1024, 1024),
		"res://assets/textures/vehicles/stallion_v3/stallion_v3_emissive.png": Vector2i(1024, 1024),
	}
	for path in expected:
		var texture := load(path) as Texture2D
		_check(texture != null, "texture failed to load: " + path)
		if texture != null:
			_check(Vector2i(texture.get_width(), texture.get_height()) == expected[path], "texture resolution invalid: " + path)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("STALLION_V3_ASSET_TEST_RESULT PASS")
	else:
		for failure in failures:
			printerr("STALLION_V3_ASSET_FAIL ", failure)
		print("STALLION_V3_ASSET_TEST_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
