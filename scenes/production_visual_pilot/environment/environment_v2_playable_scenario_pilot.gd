class_name EnvironmentV2PlayableScenarioPilot
extends Node3D

const PILOT_START_INDEX := 0
const PILOT_END_INDEX := 9
const PILOT_LENGTH_METERS := 520.0
const PILOT_CHECKPOINT_INDEX := 9
const LOD_PATHS := [
	"res://assets/models/environment/environment_v2_lod0.glb",
	"res://assets/models/environment/environment_v2_lod1.glb",
	"res://assets/models/environment/environment_v2_lod2.glb",
]
const POLISH_SHADER := preload("res://assets/shaders/production_visual_pilot/environment_g1d1_palette.gdshader")
const SURFACE_SHADER := preload("res://assets/shaders/production_visual_pilot/environment_g1d1_surface.gdshader")
const TEXTURE_ROOT := "res://assets/textures/environment/environment_v2/"

var road_manager: RoadManager
var layout: Array[Dictionary] = []
var lod_assets: Array[Dictionary] = []
var materials: Dictionary = {}
var textures: Dictionary = {}
var surface_root: Node3D
var landmark_root: Node3D
var multimesh_root: Node3D
var pilot_mesh_instances := 0
var pilot_multimesh_groups := 0
var pilot_multimesh_instances := 0
var lod_usage := {0: 0, 1: 0, 2: 0}
var original_segment_visuals_hidden := 0

func configure(manager: RoadManager) -> void:
	road_manager = manager
	layout = manager.stage_layout()
	_load_textures()
	_index_lod_assets()
	_build_surfaces()
	_place_landmarks()
	_build_scatter()
	_apply_golden_hour()
	for segment in manager.segments:
		update_segment_visual(segment, int(segment.get_meta("route_index", -1)))
	set_meta("environment_v2_playable_pilot", true)
	set_meta("g1d1_visual_polish", true)
	set_meta("pilot_start_index", PILOT_START_INDEX)
	set_meta("pilot_end_index", PILOT_END_INDEX)
	set_meta("pilot_length_meters", PILOT_LENGTH_METERS)
	set_meta("pilot_checkpoint_index", PILOT_CHECKPOINT_INDEX)
	set_meta("rock_arch_deferred", true)
	set_meta("logical_route_unchanged", true)
	set_meta("collision_count", find_children("*", "CollisionObject3D", true, false).size())
	set_meta("mesh_instances", pilot_mesh_instances)
	set_meta("multimesh_groups", pilot_multimesh_groups)
	set_meta("multimesh_instances", pilot_multimesh_instances)
	set_meta("lod0_instances", int(lod_usage[0]))
	set_meta("lod1_instances", int(lod_usage[1]))
	set_meta("lod2_instances", int(lod_usage[2]))
	set_meta("contact_groups", 2)
	set_meta("source_materials_unchanged", true)

func update_segment_visual(segment: Node3D, route_index: int) -> void:
	var pilot_segment := route_index >= PILOT_START_INDEX and route_index <= PILOT_END_INDEX
	segment.set_meta("environment_v2_visual_pilot", pilot_segment)
	for child in segment.get_children():
		if child is CollisionObject3D:
			continue
		if child.is_in_group("route_detail") or child.is_in_group("spawned") or child.is_in_group("stage_jump_geometry"):
			continue
		if child is Node3D:
			(child as Node3D).visible = not pilot_segment
	if pilot_segment:
		original_segment_visuals_hidden += 1

func _load_textures() -> void:
	for atlas in ["natural", "props", "vegetation"]:
		textures[atlas + "_base"] = load(TEXTURE_ROOT + atlas + "_base_color.png") as Texture2D
		textures[atlas + "_normal"] = load(TEXTURE_ROOT + atlas + "_normal.png") as Texture2D
		textures[atlas + "_orm"] = load(TEXTURE_ROOT + atlas + "_orm.png") as Texture2D

func _index_lod_assets() -> void:
	for level in LOD_PATHS.size():
		var indexed: Dictionary = {}
		var packed := load(LOD_PATHS[level]) as PackedScene
		if packed == null:
			lod_assets.append(indexed)
			continue
		var model := packed.instantiate() as Node3D
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := child as MeshInstance3D
			var name_value := _source_name(mesh_instance.name, level)
			indexed[name_value] = mesh_instance.mesh
		lod_assets.append(indexed)
		model.free()

func _source_name(imported_name: String, level: int) -> String:
	var suffix := "_LOD%d" % level
	return imported_name.trim_suffix(suffix) if level > 0 and imported_name.ends_with(suffix) else imported_name

func _build_surfaces() -> void:
	surface_root = Node3D.new()
	surface_root.name = "PilotRoadTerrainF1_1"
	add_child(surface_root)
	var terrain_material := _surface_material(0.0, "LayeredTerrain")
	var road_material := _surface_material(1.0, "WeatheredRoad")
	var shoulder_material := _surface_material(2.0, "DustyShoulder")
	var terrain_underlay := MeshInstance3D.new()
	terrain_underlay.name = "ContinuousDesertUnderlay"
	terrain_underlay.mesh = _terrain_underlay_mesh()
	terrain_underlay.material_override = terrain_material
	surface_root.add_child(terrain_underlay)
	pilot_mesh_instances += 1
	for index in range(PILOT_START_INDEX, PILOT_END_INDEX + 1):
		var entry: Dictionary = layout[index]
		var segment_root := Node3D.new()
		segment_root.name = "VisualSegment_%02d" % index
		segment_root.transform = entry.transform
		surface_root.add_child(segment_root)
		var terrain := MeshInstance3D.new()
		terrain.name = "LayeredTerrain_%02d" % index
		terrain.mesh = _terrain_mesh(index)
		terrain.material_override = terrain_material
		segment_root.add_child(terrain)
		var road := MeshInstance3D.new()
		road.name = "WeatheredRoad_%02d" % index
		road.mesh = _strip_mesh(-BalanceData.ROAD_HALF_WIDTH, BalanceData.ROAD_HALF_WIDTH, 0.070)
		road.material_override = road_material
		segment_root.add_child(road)
		for side in [-1.0, 1.0]:
			var shoulder := MeshInstance3D.new()
			shoulder.name = "DustyShoulder_%s_%02d" % ["L" if side < 0.0 else "R", index]
			shoulder.mesh = _shoulder_mesh(side, index)
			shoulder.material_override = shoulder_material
			segment_root.add_child(shoulder)
			var intrusion := MeshInstance3D.new()
			intrusion.name = "SandIntrusion_%s_%02d" % ["L" if side < 0.0 else "R", index]
			intrusion.mesh = _road_edge_intrusion_mesh(side, index)
			intrusion.material_override = shoulder_material
			segment_root.add_child(intrusion)
		pilot_mesh_instances += 6

func _terrain_mesh(segment_index: int) -> ArrayMesh:
	const X_STEPS := 18
	const Z_STEPS := 10
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for z_index in range(Z_STEPS + 1):
		var z := lerpf(BalanceData.SEGMENT_LENGTH * 0.5, -BalanceData.SEGMENT_LENGTH * 0.5, float(z_index) / Z_STEPS)
		var path_distance := segment_index * BalanceData.SEGMENT_LENGTH + (BalanceData.SEGMENT_LENGTH * 0.5 - z)
		for x_index in range(X_STEPS + 1):
			var x := lerpf(-50.0, 50.0, float(x_index) / X_STEPS)
			var y := _terrain_height(x, path_distance)
			vertices.append(Vector3(x, y, z))
			var sample := 0.35
			var dx := _terrain_height(x - sample, path_distance) - _terrain_height(x + sample, path_distance)
			var dz := _terrain_height(x, path_distance - sample) - _terrain_height(x, path_distance + sample)
			normals.append(Vector3(dx, sample * 2.0, dz).normalized())
			uvs.append(Vector2(float(x_index) / X_STEPS, float(z_index) / Z_STEPS))
	for z_index in Z_STEPS:
		for x_index in X_STEPS:
			var a := z_index * (X_STEPS + 1) + x_index
			indices.append_array(PackedInt32Array([a, a + 1, a + X_STEPS + 2, a, a + X_STEPS + 2, a + X_STEPS + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _terrain_height(x: float, path_distance: float) -> float:
	var outside := smoothstep(11.5, 46.0, absf(x))
	var shoulder_berm := smoothstep(12.0, 21.0, absf(x)) * (1.0 - smoothstep(27.0, 43.0, absf(x)))
	var broad_dune := sin(x * 0.072 + path_distance * 0.021) * 0.38 + cos(path_distance * 0.034 - x * 0.026) * 0.24
	var local_undulation := sin(x * 0.19 + path_distance * 0.061) * 0.10
	var shallow_depression := -0.22 * exp(-pow((absf(x) - 31.0) / 8.0, 2.0)) * (0.5 + 0.5 * sin(path_distance * 0.027))
	var detailed_height := -0.020 + outside * (broad_dune + local_undulation + shallow_depression) + shoulder_berm * (0.20 + 0.12 * sin(path_distance * 0.045))
	return lerpf(detailed_height, -0.48, smoothstep(42.0, 50.0, absf(x)))

func _terrain_underlay_mesh() -> ArrayMesh:
	const STEPS := 24
	const EXTENT := 430.0
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for z_index in range(STEPS + 1):
		var z := lerpf(EXTENT, -EXTENT, float(z_index) / STEPS)
		for x_index in range(STEPS + 1):
			var x := lerpf(-EXTENT, EXTENT, float(x_index) / STEPS)
			var y := -0.62 + sin(x * 0.014) * 0.20 + cos(z * 0.012) * 0.17 + sin((x + z) * 0.007) * 0.10
			vertices.append(Vector3(x, y, z))
			uvs.append(Vector2(float(x_index) / STEPS, float(z_index) / STEPS) * 8.0)
	for z_index in STEPS:
		for x_index in STEPS:
			var a := z_index * (STEPS + 1) + x_index
			indices.append_array(PackedInt32Array([a, a + 1, a + STEPS + 2, a, a + STEPS + 2, a + STEPS + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _strip_mesh(left: float, right: float, height: float) -> ArrayMesh:
	var half_length := BalanceData.SEGMENT_LENGTH * 0.5 + 0.035
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(left, height, half_length), Vector3(right, height, half_length), Vector3(right, height, -half_length), Vector3(left, height, -half_length)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _shoulder_mesh(side: float, segment_index: int) -> ArrayMesh:
	const STEPS := 12
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half_length := BalanceData.SEGMENT_LENGTH * 0.5 + 0.05
	for z_index in range(STEPS + 1):
		var ratio := float(z_index) / STEPS
		var z := lerpf(half_length, -half_length, ratio)
		var path_distance := segment_index * BalanceData.SEGMENT_LENGTH + ratio * BalanceData.SEGMENT_LENGTH
		var inner := side * (BalanceData.ROAD_HALF_WIDTH - 0.22 - sin(path_distance * 0.19) * 0.28)
		var outer := side * (12.2 + sin(path_distance * 0.11 + side * 1.7) * 0.75 + sin(path_distance * 0.37) * 0.24)
		vertices.append(Vector3(inner, 0.052, z))
		vertices.append(Vector3(outer, 0.050, z))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, ratio))
		uvs.append(Vector2(1.0, ratio))
	for z_index in STEPS:
		var a := z_index * 2
		if side < 0.0:
			indices.append_array(PackedInt32Array([a, a + 3, a + 1, a, a + 2, a + 3]))
		else:
			indices.append_array(PackedInt32Array([a, a + 1, a + 3, a, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _road_edge_intrusion_mesh(side: float, segment_index: int) -> ArrayMesh:
	const STEPS := 16
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half_length := BalanceData.SEGMENT_LENGTH * 0.5 + 0.04
	for z_index in range(STEPS + 1):
		var ratio := float(z_index) / STEPS
		var z := lerpf(half_length, -half_length, ratio)
		var path_distance := segment_index * BalanceData.SEGMENT_LENGTH + ratio * BalanceData.SEGMENT_LENGTH
		var invasion := 0.32 + (sin(path_distance * 0.17 + side) * 0.5 + 0.5) * 0.72 + (sin(path_distance * 0.49) * 0.5 + 0.5) * 0.24
		var inner := side * (BalanceData.ROAD_HALF_WIDTH - invasion)
		var outer := side * (BalanceData.ROAD_HALF_WIDTH + 0.14)
		vertices.append(Vector3(inner, 0.076, z))
		vertices.append(Vector3(outer, 0.076, z))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, ratio))
		uvs.append(Vector2(1.0, ratio))
	for z_index in STEPS:
		var a := z_index * 2
		if side < 0.0:
			indices.append_array(PackedInt32Array([a, a + 3, a + 1, a, a + 2, a + 3]))
		else:
			indices.append_array(PackedInt32Array([a, a + 1, a + 3, a, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _surface_material(kind: float, label: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "G1D_F1_1_%s" % label
	material.shader = SURFACE_SHADER
	material.set_shader_parameter("surface_kind", kind)
	material.set_shader_parameter("detail_strength", 0.72)
	material.set_meta("f1_1_surface", true)
	return material

func _place_landmarks() -> void:
	landmark_root = Node3D.new()
	landmark_root.name = "EnvironmentKitV2Landmarks"
	add_child(landmark_root)
	var placements := [
		["HeroRock_A_SplitCrown", 1, -19.0, -4.0, 0, 0.82, -0.22],
		["HeroRock_B_LeaningStack", 4, 22.0, 10.0, 0, 0.78, 0.34],
		["HeroRock_C_BrokenButte", 7, -23.0, -4.0, 0, 0.76, -0.48],
		["CanyonWall_A_Concave", 3, -32.0, 7.0, 1, 0.92, 1.02],
		["CanyonWall_B_Stepped", 5, 31.0, -9.0, 1, 0.88, -1.02],
		["CanyonWall_A_Concave", 7, 34.0, 12.0, 1, 0.76, -0.92],
		["CanyonWall_B_Stepped", 8, -34.0, -7.0, 1, 0.74, 0.88],
		["DistantMesa_A", 2, -72.0, 0.0, 2, 1.55, -0.20],
		["DistantMesa_B", 6, 76.0, 5.0, 2, 1.65, 0.24],
		["NarrativeWreck_SurveyRover", 7, 13.5, 6.0, 1, 0.78, -0.38],
		["RoadSign_Direction", 2, 10.6, -12.0, 1, 0.92, -0.10],
		["RoadSign_Hazard", 5, -10.8, -10.0, 1, 0.92, 0.14],
		["SafetyBarrier_01", 6, 11.3, 8.0, 1, 0.92, -0.08],
		["Dune_01", 1, 15.0, 12.0, 1, 1.35, 0.18],
		["Dune_02", 4, -16.0, -13.0, 1, 1.42, -0.16],
		["Dune_03", 8, 17.5, 14.0, 1, 1.46, 0.12],
		["RoadEdge_BrokenShoulder_A", 3, -9.7, -5.0, 1, 1.0, 0.0],
		["RoadEdge_BrokenShoulder_B", 6, 9.8, -6.0, 1, 1.0, 0.0],
		["Dune_02", 1, -17.5, -1.0, 1, 0.92, 0.30],
		["Dune_01", 4, 19.5, 13.0, 1, 0.86, -0.20],
		["Dune_03", 7, -20.5, -1.0, 1, 0.90, 0.16],
		["Dune_02", 3, -28.0, 11.0, 1, 0.82, -0.32],
		["Dune_01", 5, 27.0, -12.0, 1, 0.84, 0.24],
	]
	for item in placements:
		_place_asset(str(item[0]), int(item[1]), float(item[2]), float(item[3]), int(item[4]), float(item[5]), float(item[6]))
	for index in 18:
		var segment_index := 1 + index % 8
		var side := -1.0 if index % 2 == 0 else 1.0
		_place_asset("MediumRock_%02d" % (1 + index % 6), segment_index, side * (13.5 + index % 4 * 2.0), -20.0 + (index * 7) % 40, 1, 0.48 + (index % 3) * 0.10, index * 0.47)

func _place_asset(asset_name: String, segment_index: int, lateral: float, local_z: float, lod: int, scale_value: float, yaw: float) -> MeshInstance3D:
	var mesh: Mesh = lod_assets[lod].get(asset_name) as Mesh
	if mesh == null:
		return null
	var entry: Dictionary = layout[segment_index]
	var copy := MeshInstance3D.new()
	copy.name = "%s_L%d" % [asset_name, lod]
	copy.mesh = mesh
	copy.material_override = _material_for(_category(asset_name))
	copy.transform = Transform3D(entry.transform.basis * Basis(Vector3.UP, yaw), entry.transform * Vector3(lateral, -0.10, local_z))
	copy.scale = Vector3.ONE * scale_value
	copy.set_meta("environment_lod", lod)
	copy.set_meta("visual_only", true)
	if lod == 0:
		copy.visibility_range_end = 130.0
		copy.visibility_range_end_margin = 18.0
	elif lod == 1:
		copy.visibility_range_end = 240.0
		copy.visibility_range_end_margin = 24.0
	landmark_root.add_child(copy)
	pilot_mesh_instances += 1
	lod_usage[lod] = int(lod_usage[lod]) + 1
	return copy

func _build_scatter() -> void:
	multimesh_root = Node3D.new()
	multimesh_root.name = "EnvironmentKitV2ScatterMultiMesh"
	add_child(multimesh_root)
	_scatter_asset("SmallRock_02", 2, 82, 1201, 10.5, 22.0, 0.20, 0.52)
	_scatter_asset("DebrisGravelCluster", 2, 78, 1301, 9.4, 18.0, 0.22, 0.56)
	_scatter_asset("Cactus_01", 2, 28, 1409, 12.0, 28.0, 0.48, 0.86)
	_scatter_asset("DryBush_01", 2, 42, 1511, 10.5, 22.0, 0.38, 0.74)
	_scatter_asset("SmallRock_07", 2, 62, 1601, 9.8, 18.0, 0.18, 0.44)
	_contact_scatter_asset("DebrisGravelCluster", 2, 42, 1709, 1.8, 7.0, 0.22, 0.50)
	_contact_scatter_asset("SmallRock_02", 2, 34, 1801, 2.2, 8.5, 0.18, 0.42)

func _scatter_asset(asset_name: String, lod: int, count: int, seed_value: int, min_side: float, max_side: float, min_scale: float, max_scale: float) -> void:
	var mesh: Mesh = lod_assets[lod].get(asset_name) as Mesh
	if mesh == null:
		return
	var instance := MultiMeshInstance3D.new()
	instance.name = asset_name + "Scatter"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in count:
		var segment_index := rng.randi_range(PILOT_START_INDEX, PILOT_END_INDEX)
		var entry: Dictionary = layout[segment_index]
		var side := -1.0 if index % 2 == 0 else 1.0
		var lateral := side * rng.randf_range(min_side, max_side)
		var local_z := rng.randf_range(-24.0, 24.0)
		var scale_value := rng.randf_range(min_scale, max_scale)
		var basis: Basis = entry.transform.basis * Basis(Vector3.UP, rng.randf_range(-PI, PI))
		basis = basis.scaled(Vector3(scale_value, scale_value * rng.randf_range(0.78, 1.08), scale_value))
		multimesh.set_instance_transform(index, Transform3D(basis, entry.transform * Vector3(lateral, -0.08, local_z)))
	instance.multimesh = multimesh
	instance.material_override = _material_for(_category(asset_name))
	instance.visibility_range_end = 150.0
	instance.visibility_range_end_margin = 20.0
	multimesh_root.add_child(instance)
	pilot_multimesh_groups += 1
	pilot_multimesh_instances += count
	lod_usage[lod] = int(lod_usage[lod]) + count

func _contact_scatter_asset(asset_name: String, lod: int, count: int, seed_value: int, min_radius: float, max_radius: float, min_scale: float, max_scale: float) -> void:
	var mesh: Mesh = lod_assets[lod].get(asset_name) as Mesh
	if mesh == null:
		return
	var anchors := [
		[1, -19.0, -4.0], [3, -32.0, 7.0], [4, 22.0, 10.0],
		[5, 31.0, -9.0], [7, -23.0, -4.0], [7, 34.0, 12.0], [8, -34.0, -7.0],
	]
	var instance := MultiMeshInstance3D.new()
	instance.name = asset_name + "ContactScatter"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in count:
		var anchor: Array = anchors[index % anchors.size()]
		var segment_index := int(anchor[0])
		var entry: Dictionary = layout[segment_index]
		var angle := rng.randf_range(-PI, PI)
		var radius := rng.randf_range(min_radius, max_radius)
		var lateral := float(anchor[1]) + cos(angle) * radius
		var local_z := float(anchor[2]) + sin(angle) * radius
		var scale_value := rng.randf_range(min_scale, max_scale)
		var basis: Basis = entry.transform.basis * Basis(Vector3.UP, rng.randf_range(-PI, PI))
		basis = basis.scaled(Vector3(scale_value, scale_value * rng.randf_range(0.72, 0.98), scale_value))
		multimesh.set_instance_transform(index, Transform3D(basis, entry.transform * Vector3(lateral, -0.06, local_z)))
	instance.multimesh = multimesh
	instance.material_override = _material_for(_category(asset_name))
	instance.visibility_range_end = 145.0
	instance.visibility_range_end_margin = 18.0
	multimesh_root.add_child(instance)
	pilot_multimesh_groups += 1
	pilot_multimesh_instances += count
	lod_usage[lod] = int(lod_usage[lod]) + count

func _category(asset_name: String) -> String:
	if asset_name.begins_with("Cactus_") or asset_name.begins_with("DryBush_"):
		return "vegetation"
	if asset_name.begins_with("RoadSign_"):
		return "painted_metal"
	if asset_name.begins_with("SafetyBarrier_") or asset_name.begins_with("NarrativeWreck_"):
		return "oxidized_metal"
	if asset_name.begins_with("Dune_") or asset_name.begins_with("RoadEdge_"):
		return "sand"
	if asset_name.begins_with("DebrisGravel"):
		return "ground"
	if asset_name == "HeroRock_A_SplitCrown" or asset_name == "DistantMesa_B":
		return "rock_ochre"
	if asset_name == "HeroRock_B_LeaningStack" or asset_name == "DistantMesa_A":
		return "rock_warmgray"
	if asset_name == "CanyonWall_A_Concave":
		return "rock_earth"
	if asset_name == "CanyonWall_B_Stepped" or asset_name == "HeroRock_C_BrokenButte":
		return "rock_muted_red"
	return "rock_warmgray" if asset_name.begins_with("SmallRock_") else "rock_burnt"

func _material_for(category: String) -> ShaderMaterial:
	if materials.has(category):
		return materials[category]
	var atlas := "natural"
	var palette_high := Color("9a765e")
	var palette_low := Color("4f4741")
	var roughness := 0.88
	var metallic := 0.0
	var fracture := 0.18
	var normal_strength := 0.38
	var surface_mode := 0.0
	var seed_value := 1.0
	var saturation := 0.52
	match category:
		"rock_burnt": palette_high = Color("9a765e"); palette_low = Color("4f4741"); roughness = 0.88; fracture = 0.30; normal_strength = 0.50; seed_value = 2.1; saturation = 0.50
		"rock_ochre": palette_high = Color("a9946c"); palette_low = Color("5b5546"); roughness = 0.90; fracture = 0.27; normal_strength = 0.47; seed_value = 4.7; saturation = 0.46
		"rock_warmgray": palette_high = Color("917d6c"); palette_low = Color("4b443e"); roughness = 0.92; fracture = 0.32; normal_strength = 0.52; seed_value = 7.3; saturation = 0.44
		"rock_earth": palette_high = Color("806957"); palette_low = Color("403d39"); roughness = 0.91; fracture = 0.31; normal_strength = 0.51; seed_value = 8.1; saturation = 0.38
		"rock_muted_red": palette_high = Color("916b59"); palette_low = Color("4c423e"); roughness = 0.89; fracture = 0.30; normal_strength = 0.50; seed_value = 8.8; saturation = 0.44
		"sand": palette_high = Color("89765f"); palette_low = Color("585147"); roughness = 0.95; normal_strength = 0.30; surface_mode = 1.0; seed_value = 9.4; saturation = 0.38
		"ground": palette_high = Color("83735d"); palette_low = Color("4d4b45"); roughness = 0.93; normal_strength = 0.40; surface_mode = 1.0; seed_value = 11.6; saturation = 0.35
		"vegetation": atlas = "vegetation"; palette_high = Color("66765a"); palette_low = Color("353b31"); roughness = 0.90; normal_strength = 0.32; seed_value = 15.8; saturation = 0.48
		"painted_metal": atlas = "props"; palette_high = Color("8d6653"); palette_low = Color("41474a"); roughness = 0.66; metallic = 0.42; normal_strength = 0.34; seed_value = 18.1; saturation = 0.50
		"oxidized_metal": atlas = "props"; palette_high = Color("765b50"); palette_low = Color("3e4243"); roughness = 0.85; metallic = 0.28; normal_strength = 0.36; seed_value = 20.7; saturation = 0.42
	var material := ShaderMaterial.new()
	material.resource_name = "G1D_ENV2_%s" % category
	material.shader = POLISH_SHADER
	material.set_shader_parameter("base_map", textures[atlas + "_base"])
	material.set_shader_parameter("normal_map", textures[atlas + "_normal"])
	material.set_shader_parameter("orm_map", textures[atlas + "_orm"])
	material.set_shader_parameter("palette_high", palette_high)
	material.set_shader_parameter("palette_low", palette_low)
	material.set_shader_parameter("category_seed", seed_value)
	material.set_shader_parameter("surface_mode", surface_mode)
	material.set_shader_parameter("normal_strength", normal_strength)
	material.set_shader_parameter("roughness_bias", roughness)
	material.set_shader_parameter("metallic_strength", metallic)
	material.set_shader_parameter("fracture_strength", fracture)
	material.set_shader_parameter("saturation_scale", saturation)
	material.set_meta("e2_1_approved_material", true)
	materials[category] = material
	return material

func _apply_golden_hour() -> void:
	var game_manager := road_manager.get_parent().get_parent()
	var environment: Environment = game_manager.get("environment_resource") as Environment
	var sun: DirectionalLight3D = game_manager.get("sun_light") as DirectionalLight3D
	if environment == null or sun == null:
		return
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("56788f")
	sky_material.sky_horizon_color = Color("d7b78d")
	sky_material.ground_bottom_color = Color("4c5b69")
	sky_material.ground_horizon_color = Color("d7b78d")
	sky_material.sky_curve = 0.12
	sky_material.ground_curve = 0.18
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cbd3d3")
	environment.ambient_light_energy = 0.88
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.86
	environment.fog_enabled = true
	environment.fog_light_color = Color("b5aea1")
	environment.fog_light_energy = 0.58
	environment.fog_density = 0.00175
	environment.fog_sky_affect = 0.28
	sun.rotation_degrees = Vector3(-31, -48, 0)
	sun.light_color = Color("e7c296")
	sun.light_energy = 0.96
	sun.shadow_enabled = true
	sun.shadow_blur = 1.35
	var fill := DirectionalLight3D.new()
	fill.name = "G1D_CoolFill"
	fill.rotation_degrees = Vector3(-25, 136, 0)
	fill.light_color = Color("8faec2")
	fill.light_energy = 0.60
	add_child(fill)
	set_meta("golden_hour_override", true)
