extends SceneTree

const EXPECTED_COUNTS := {"hero": 3, "medium": 6, "small": 10, "arch": 1, "canyon": 2, "mesa": 2, "cactus": 3, "bush": 3, "sign": 2, "barrier": 1, "wreck": 1, "dune": 3, "road_edge": 2, "debris": 1}
const EXPECTED_TRIANGLES := [26982, 16495, 9346]
const FROZEN_ASSETS := ["HeroRock_A_SplitCrown", "HeroRock_B_LeaningStack", "HeroRock_C_BrokenButte", "CanyonWall_A_Concave", "CanyonWall_B_Stepped", "RockArch_01"]
const MATERIAL_CATEGORIES := ["rock_red", "rock_ochre", "rock_dark", "sand", "ground", "road", "vegetation", "painted_metal", "oxidized_metal"]
const EXPECTED_POLISH_SHOTS := ["01_daylight_complete_scene.png", "02_golden_hour_complete_scene.png", "03_sunset_complete_scene.png", "04_ground_blending_closeup.png", "05_rock_base_contact.png", "06_road_edge_detail.png", "07_hero_rocks_material_detail.png", "08_canyon_material_detail.png", "09_arch_golden_hour.png", "10_props_integration.png", "11_sky_atmosphere.png", "12_before_after_comparison.png", "13_complete_scene_with_stallion.png", "14_lod_material_consistency.png"]
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("ENVIRONMENT_KIT_V2_VISUAL_TEST_START")
	var start := Time.get_ticks_usec()
	var packed := load("res://scenes/visual/EnvironmentKitV2VisualReview.tscn") as PackedScene
	_check(packed != null, "visual review failed to load")
	if packed == null:
		_finish()
		return
	var review := packed.instantiate() as EnvironmentKitV2VisualReview
	root.add_child(review)
	var instantiate_ms := (Time.get_ticks_usec() - start) / 1000.0
	for _frame in 10:
		await process_frame
	var ready_ms := (Time.get_ticks_usec() - start) / 1000.0
	var kit := review.kit as EnvironmentKitV2
	_check(kit != null, "Environment Kit V2 wrapper missing")
	_check(bool(kit.get_meta("environment_kit_v2_visual", false)), "visual metadata missing")
	_check(not bool(kit.get_meta("production_integrated", true)), "visual kit must remain isolated")
	_check(kit.lod_models.size() == 3 and kit.lod_assets.size() == 3, "manual LOD hierarchy incomplete")
	for level in 3:
		var metrics := _mesh_metrics(kit.lod_models[level])
		_check(metrics.meshes == 40, "LOD%d mesh count invalid: %d" % [level, metrics.meshes])
		_check(abs(metrics.triangles - EXPECTED_TRIANGLES[level]) <= 4, "LOD%d triangles invalid: %d" % [level, metrics.triangles])
		_check(metrics.materials <= 8, "LOD%d embedded/override materials exceed eight: %d" % [level, metrics.materials])
	var counts := kit.family_counts()
	for family in EXPECTED_COUNTS:
		_check(int(counts.get(family, 0)) == EXPECTED_COUNTS[family], "%s count invalid" % family)
	_validate_frozen_silhouettes(kit)
	_validate_uvs(kit)
	_validate_textures(kit)
	var material_ids: Dictionary = {}
	for category in MATERIAL_CATEGORIES:
		var material := kit.material_for(category) as ShaderMaterial
		_check(material != null, "shared material missing: " + category)
		if material != null:
			material_ids[material.get_instance_id()] = true
			_check(material.shader == kit.POLISH_SHADER, "polish shader missing: " + category)
			_check(material.get_shader_parameter("base_map") != null and material.get_shader_parameter("normal_map") != null and material.get_shader_parameter("orm_map") != null, "PBR maps missing: " + category)
			_check(float(material.get_shader_parameter("roughness_bias")) >= 0.60, "roughness polish invalid: " + category)
	_check(material_ids.size() == 9, "expected exactly nine shared final materials, got %d" % material_ids.size())
	_check(float((kit.material_for("ground") as ShaderMaterial).get_shader_parameter("surface_mode")) == 1.0, "ground procedural blend mode missing")
	_check(float((kit.material_for("road") as ShaderMaterial).get_shader_parameter("surface_mode")) == 2.0, "road controlled-value mode missing")
	kit.set_review_mode("clay")
	_check(kit.active_review_mode == "clay", "clay review mode failed")
	kit.set_review_mode("final_pbr")
	_check(kit.active_review_mode == "final_pbr", "final PBR review mode failed")
	_check(kit.collision_root != null and kit.collision_root.get_child_count() == 9, "simple review collisions incomplete")
	_check(kit.scatter_root != null and kit.scatter_root.get_child_count() == 3, "MultiMesh scatter hierarchy incomplete")
	var scatter_instances := 0
	for child in kit.scatter_root.get_children():
		var multimesh_instance := child as MultiMeshInstance3D
		_check(multimesh_instance != null and multimesh_instance.visibility_range_end <= 105.1, "scatter visibility range invalid")
		if multimesh_instance != null:
			scatter_instances += multimesh_instance.multimesh.instance_count
	_check(scatter_instances == 70, "reduced scatter instance count invalid: %d" % scatter_instances)
	_check(review.composition_root != null and review.composition_root.get_child_count() >= 24, "complete canyon composition is too sparse")
	_check(review.get_node_or_null("EnvironmentKitV2VisualWorld") != null, "review world missing")
	_check(review.get_node_or_null("EnvironmentKitV2VisualCamera") != null, "review camera missing")
	_check(review.LIGHTING_PRESETS.size() == 3 and review.LIGHTING_PRESETS.has("Golden Hour"), "three lighting presets incomplete")
	review._set_golden_hour()
	_check(review.environment.background_mode == Environment.BG_SKY and review.environment.tonemap_exposure <= 0.90, "Golden Hour exposure/sky invalid")
	_check(review.environment.ambient_light_energy >= 0.95 and review.fill_light.light_energy >= 0.85, "Golden Hour shadow fill insufficient")
	for filename in EXPECTED_POLISH_SHOTS:
		_check(FileAccess.file_exists("res://screenshots/environment_kit_v2_review/visual_polish/" + filename), "polish screenshot missing: " + filename)
	_check(instantiate_ms < 700.0, "wrapper/review instantiation exceeded 700 ms: %.2f" % instantiate_ms)
	_check(ready_ms < 900.0, "first frame readiness exceeded 900 ms: %.2f" % ready_ms)
	_check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) < 250, "initial review node budget exceeded")
	print("ENVIRONMENT_KIT_V2_VISUAL_TEST_METRICS lod0=", EXPECTED_TRIANGLES[0], " lod1=", EXPECTED_TRIANGLES[1], " lod2=", EXPECTED_TRIANGLES[2], " instantiate_ms=", snapped(instantiate_ms, 0.01), " ready_ms=", snapped(ready_ms, 0.01), " nodes=", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	review.queue_free()
	for _frame in 8:
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
			var material := mesh_instance.get_active_material(surface)
			if material != null:
				materials[material.get_instance_id()] = true
	return {"triangles": triangles, "meshes": meshes, "materials": materials.size()}

func _validate_frozen_silhouettes(kit: EnvironmentKitV2) -> void:
	var packed := load("res://scenes/visual/assets/EnvironmentKitV2Blockout.tscn") as PackedScene
	var blockout := packed.instantiate() as EnvironmentKitV2Blockout
	root.add_child(blockout)
	for asset_name in FROZEN_ASSETS:
		var approved := blockout.asset(asset_name)
		var final := kit.asset(asset_name)
		_check(approved != null and final != null, "frozen asset missing: " + asset_name)
		if approved != null and final != null:
			var delta := approved.mesh.get_aabb().size - final.mesh.get_aabb().size
			_check(delta.length() < 0.01, "approved silhouette bounds changed: " + asset_name)
	blockout.queue_free()

func _validate_uvs(kit: EnvironmentKitV2) -> void:
	for asset_name in kit.lod_assets[0]:
		var mesh_instance := kit.asset(asset_name)
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			_check(not uvs.is_empty(), "UV missing: " + String(asset_name))
			for uv in uvs:
				if uv.x < -0.001 or uv.x > 1.001 or uv.y < -0.001 or uv.y > 1.001:
					_check(false, "UV outside atlas: " + String(asset_name))
					break

func _validate_textures(kit: EnvironmentKitV2) -> void:
	for path_key in kit.TEXTURE_PATHS:
		var path: String = kit.TEXTURE_PATHS[path_key]
		var texture := load(path) as Texture2D
		_check(texture != null, "texture failed to load: " + path)
		if texture != null:
			var expected := 2048 if path.contains("natural_") or path.contains("road_") else 1024
			_check(texture.get_width() == expected and texture.get_height() == expected, "texture resolution invalid: " + path)
	var natural_orm := load(kit.TEXTURE_PATHS["natural_orm"]) as Texture2D
	var props_orm := load(kit.TEXTURE_PATHS["props_orm"]) as Texture2D
	if natural_orm != null and props_orm != null:
		var natural_sample := natural_orm.get_image().get_pixel(100, 100)
		var props_sample := props_orm.get_image().get_pixel(100, 100)
		_check(natural_sample.b < 0.02, "natural ORM metallic channel must be zero")
		_check(props_sample.b > 0.45, "props ORM metallic channel must carry metal data")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("ENVIRONMENT_KIT_V2_VISUAL_TEST_RESULT PASS")
	else:
		for failure in failures:
			printerr("ENVIRONMENT_KIT_V2_VISUAL_FAIL ", failure)
		print("ENVIRONMENT_KIT_V2_VISUAL_TEST_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
