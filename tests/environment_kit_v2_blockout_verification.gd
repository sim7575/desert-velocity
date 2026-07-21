extends SceneTree

const EXPECTED_COUNTS := {
	"hero": 3, "medium": 6, "small": 10, "arch": 1, "canyon": 2,
	"mesa": 2, "cactus": 3, "bush": 3, "sign": 2, "barrier": 1,
	"wreck": 1, "dune": 3, "road_edge": 2, "debris": 1,
}
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("ENVIRONMENT_KIT_V2_BLOCKOUT_TEST_START")
	var start := Time.get_ticks_usec()
	var packed := load("res://scenes/visual/EnvironmentKitV2BlockoutReview.tscn") as PackedScene
	_check(packed != null, "review scene failed to load")
	if packed == null:
		_finish()
		return
	var review := packed.instantiate() as EnvironmentKitV2BlockoutReview
	root.add_child(review)
	var instantiate_ms := (Time.get_ticks_usec() - start) / 1000.0
	for _frame in 8:
		await process_frame
	var ready_ms := (Time.get_ticks_usec() - start) / 1000.0
	var kit := review.kit as EnvironmentKitV2Blockout
	_check(kit != null, "kit wrapper missing")
	_check(bool(kit.get_meta("environment_kit_v2_blockout", false)), "kit metadata missing")
	_check(not bool(kit.get_meta("production_integrated", true)), "blockout must remain outside production")
	_check(kit.assets.size() == 40, "expected 40 modular mesh assets, got %d" % kit.assets.size())
	var counts := kit.family_counts()
	for family in EXPECTED_COUNTS:
		_check(int(counts.get(family, 0)) == EXPECTED_COUNTS[family], "%s count invalid: %d" % [family, counts.get(family, 0)])
	var metrics := _mesh_metrics(kit.kit_model)
	_check(metrics.triangles == 26982, "triangle count changed: %d" % metrics.triangles)
	_check(metrics.meshes == 40, "render mesh count changed: %d" % metrics.meshes)
	_check(metrics.materials == 7, "shared material count changed: %d" % metrics.materials)
	var hero_minimums := {
		"HeroRock_A_SplitCrown": 1900,
		"HeroRock_B_LeaningStack": 2100,
		"HeroRock_C_BrokenButte": 2100,
	}
	for hero_name in hero_minimums:
		var hero := kit.asset(hero_name)
		_check(hero != null, "hero formation missing: " + hero_name)
		if hero != null:
			_check(_mesh_triangles(hero) >= int(hero_minimums[hero_name]), "hero topology too simple: " + hero_name)
			_check(hero.mesh.get_aabb().size.x >= 10.0, "hero base/width too narrow: " + hero_name)
	var hero_a := kit.asset("HeroRock_A_SplitCrown")
	var hero_b := kit.asset("HeroRock_B_LeaningStack")
	var hero_c := kit.asset("HeroRock_C_BrokenButte")
	_check(hero_a.mesh.get_aabb().size.x > hero_a.mesh.get_aabb().size.y * 1.55, "Hero A must remain low and wide")
	_check(hero_b.mesh.get_aabb().size.x > hero_b.mesh.get_aabb().size.y * 1.45, "Hero B must develop horizontally")
	_check(hero_c.mesh.get_aabb().size.x > hero_c.mesh.get_aabb().size.y, "Hero C buttress base is too narrow")
	for canyon_name in ["CanyonWall_A_Concave", "CanyonWall_B_Stepped"]:
		var canyon := kit.asset(canyon_name)
		_check(canyon != null and _mesh_triangles(canyon) >= 5500, "canyon topology incomplete: " + canyon_name)
		if canyon != null:
			_check(canyon.mesh.get_aabb().size.x >= 21.5, "canyon modular length invalid: " + canyon_name)
	var arch := kit.asset("RockArch_01")
	_check(arch != null and _mesh_triangles(arch) >= 2400, "rock arch topology incomplete")
	if arch != null:
		_check(arch.mesh.get_aabb().size.x >= 16.0, "rock arch span is not monumental")
		_check(arch.mesh.get_aabb().size.y >= 9.5, "rock arch height is insufficient")
	_check(review.old_reference != null, "V2 environment comparison reference missing")
	_check(review.get_node_or_null("EnvironmentKitReviewWorld") != null, "neutral review environment missing")
	_check(review.get_node_or_null("EnvironmentKitReviewCamera") != null, "deterministic review camera missing")
	_check(review.composition_root != null and review.composition_root.get_child_count() >= 20, "depth composition is incomplete")
	_check(review.stallion_v3 != null, "Stallion V3 scale reference missing from isolated review")
	_check(instantiate_ms < 500.0, "review instantiation exceeded 500 ms: %.2f" % instantiate_ms)
	_check(ready_ms < 700.0, "review first-frame readiness exceeded 700 ms: %.2f" % ready_ms)
	print("ENVIRONMENT_KIT_V2_BLOCKOUT_TEST_METRICS triangles=", metrics.triangles, " meshes=", metrics.meshes, " materials=", metrics.materials, " instantiate_ms=", snapped(instantiate_ms, 0.01), " ready_ms=", snapped(ready_ms, 0.01))
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
		triangles += _mesh_triangles(mesh_instance)
		for surface in mesh_instance.mesh.get_surface_count():
			var mat := mesh_instance.mesh.surface_get_material(surface)
			if mat != null:
				materials[mat.resource_name] = true
	return {"triangles": triangles, "meshes": meshes, "materials": materials.size()}

func _mesh_triangles(mesh_instance: MeshInstance3D) -> int:
	var triangles := 0
	for surface in mesh_instance.mesh.get_surface_count():
		var arrays := mesh_instance.mesh.surface_get_arrays(surface)
		triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	return triangles

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("ENVIRONMENT_KIT_V2_BLOCKOUT_TEST_RESULT PASS")
	else:
		for failure in failures:
			printerr("ENVIRONMENT_KIT_V2_BLOCKOUT_FAIL ", failure)
		print("ENVIRONMENT_KIT_V2_BLOCKOUT_TEST_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
