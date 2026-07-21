class_name EnvironmentKitV2VisualReview
extends Node3D

const KIT_SCENE := preload("res://scenes/visual/assets/EnvironmentKitV2.tscn")
const BLOCKOUT_SCENE := preload("res://scenes/visual/assets/EnvironmentKitV2Blockout.tscn")
const STALLION_SCENE := preload("res://scenes/visual/assets/DesertStallionV3Visual.tscn")
const SEQUENCE_SECONDS := 12.0
const POLISH_CAPTURE_ROOT := "res://screenshots/environment_kit_v2_review/visual_polish"
const LIGHTING_PRESETS := {
	"Daylight Neutral": {"exposure": 0.84, "ambient": 0.84, "key": 0.94, "fill": 0.74},
	"Golden Hour": {"exposure": 0.90, "ambient": 0.96, "key": 0.98, "fill": 0.88},
	"Sunset Cinematic": {"exposure": 0.88, "ambient": 1.02, "key": 0.92, "fill": 0.96},
}

var kit: EnvironmentKitV2
var blockout: EnvironmentKitV2Blockout
var stallion: Node3D
var camera: Camera3D
var environment: Environment
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var sky_material: ProceduralSkyMaterial
var title: Label3D
var panel: Label
var composition_root: Node3D
var detail_root: Node3D
var floor_mesh: MeshInstance3D
var comparison_overlay: TextureRect
var black_material: StandardMaterial3D
var original_transforms: Dictionary = {}
var metrics_mode := false
var elapsed := 0.0
var fps_total := 0.0
var fps_samples := 0
var fps_min := INF
var fps_values: Array[float] = []
var peak_draw_calls := 0
var peak_primitives := 0
var peak_nodes := 0
var peak_memory_bytes := 0
var load_time_ms := 0.0

func _ready() -> void:
	_setup_environment()
	_setup_kit()
	_setup_camera()
	_setup_overlay()
	_build_composition()
	var args := OS.get_cmdline_user_args()
	if "--capture-environment-kit-v2-polish" in args:
		_capture_polish_set.call_deferred()
	elif "--capture-environment-kit-v2-visual" in args:
		_capture_set.call_deferred()
	elif "--run-environment-kit-v2-visual-metrics" in args:
		metrics_mode = true
		_configure_polish_shot(12)

func _process(delta: float) -> void:
	if not metrics_mode:
		return
	elapsed += delta
	if elapsed > 1.0 and delta > 0.0:
		var fps := 1.0 / delta
		fps_total += fps
		fps_samples += 1
		fps_min = minf(fps_min, fps)
		fps_values.append(fps)
	peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	peak_primitives = maxi(peak_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	peak_memory_bytes = maxi(peak_memory_bytes, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	if elapsed >= SEQUENCE_SECONDS:
		_write_metrics()
		get_tree().quit()

func _setup_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky.sky_material = sky_material
	environment.sky = sky
	var world := WorldEnvironment.new()
	world.name = "EnvironmentKitV2VisualWorld"
	world.environment = environment
	add_child(world)
	key_light = DirectionalLight3D.new()
	key_light.name = "VisualReviewKey"
	key_light.rotation_degrees = Vector3(-38, -42, 0)
	key_light.light_color = Color("fff0d4")
	key_light.light_energy = 1.24
	key_light.shadow_enabled = true
	key_light.shadow_blur = 1.3
	add_child(key_light)
	fill_light = DirectionalLight3D.new()
	fill_light.name = "VisualReviewFill"
	fill_light.rotation_degrees = Vector3(-28, 136, 0)
	fill_light.light_color = Color("a9c9df")
	fill_light.light_energy = 0.52
	add_child(fill_light)
	black_material = StandardMaterial3D.new()
	black_material.albedo_color = Color("050708")
	black_material.roughness = 0.88
	_set_golden_hour()

func _setup_kit() -> void:
	var start := Time.get_ticks_usec()
	kit = KIT_SCENE.instantiate() as EnvironmentKitV2
	kit.name = "EnvironmentKitV2Visual"
	add_child(kit)
	load_time_ms = (Time.get_ticks_usec() - start) / 1000.0
	for asset_name in kit.lod_assets[0]:
		original_transforms[asset_name] = (kit.asset(asset_name) as MeshInstance3D).transform
	floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "ReviewGround"
	floor_mesh.mesh = _terrain_mesh(Vector2(150, 150), 42)
	floor_mesh.material_override = kit.material_for("ground")
	add_child(floor_mesh)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "EnvironmentKitV2VisualCamera"
	camera.current = true
	camera.fov = 47.0
	add_child(camera)
	_set_camera(Vector3(40, 24, -36), Vector3(0, 3, -5))

func _setup_overlay() -> void:
	title = Label3D.new()
	title.text = "ENVIRONMENT KIT V2 · VISUAL REVIEW"
	title.font_size = 40
	title.outline_size = 8
	title.modulate = Color("f4e5ce")
	title.no_depth_test = true
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.position = Vector3(0, 12, 0)
	add_child(title)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	comparison_overlay = TextureRect.new()
	comparison_overlay.name = "E2BeforeReference"
	comparison_overlay.position = Vector2.ZERO
	comparison_overlay.size = Vector2(640, 720)
	comparison_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	comparison_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	comparison_overlay.texture = load("res://screenshots/environment_kit_v2_review/visual/15_complete_scene_with_stallion.png") as Texture2D
	comparison_overlay.visible = false
	canvas.add_child(comparison_overlay)
	panel = Label.new()
	panel.position = Vector2(24, 22)
	panel.add_theme_font_size_override("font_size", 16)
	panel.add_theme_color_override("font_color", Color("f5e8d5"))
	panel.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.86))
	panel.add_theme_constant_override("shadow_offset_x", 2)
	panel.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(panel)

func _quad_mesh(size: Vector2, uv_min: Vector2, uv_max: Vector2) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-size.x * 0.5, 0, -size.y * 0.5), Vector3(size.x * 0.5, 0, -size.y * 0.5),
		Vector3(size.x * 0.5, 0, size.y * 0.5), Vector3(-size.x * 0.5, 0, size.y * 0.5),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(uv_min.x, uv_min.y), Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y), Vector2(uv_min.x, uv_max.y),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _terrain_mesh(size: Vector2, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for z_index in segments + 1:
		for x_index in segments + 1:
			var tx := float(x_index) / segments
			var tz := float(z_index) / segments
			var x := lerpf(-size.x * 0.5, size.x * 0.5, tx)
			var z := lerpf(-size.y * 0.5, size.y * 0.5, tz)
			var basin := sin(x * 0.071) * cos(z * 0.052) * 0.10 + sin((x + z) * 0.19) * 0.035
			vertices.append(Vector3(x, -0.10 + basin, z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(tx, tz))
	for z_index in segments:
		for x_index in segments:
			var row := segments + 1
			var index := z_index * row + x_index
			indices.append_array(PackedInt32Array([index, index + 1, index + row + 1, index, index + row + 1, index + row]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _road_mesh(width: float, length: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in segments + 1:
		var t := float(index) / segments
		var z := lerpf(-length * 0.5, length * 0.5, t)
		var edge_variation := sin(t * 19.0) * 0.14 + sin(t * 47.0) * 0.055
		var half_width := width * 0.5 + edge_variation
		var height := 0.12 + sin(t * 12.0) * 0.022
		vertices.append(Vector3(-half_width, height, z))
		vertices.append(Vector3(half_width, height, z))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0, t))
		uvs.append(Vector2(1, t))
	for index in segments:
		var base := index * 2
		indices.append_array(PackedInt32Array([base, base + 1, base + 3, base, base + 3, base + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_composition() -> void:
	composition_root = Node3D.new()
	composition_root.name = "CompleteCanyonComposition"
	composition_root.visible = false
	add_child(composition_root)
	var placements := [
		["HeroRock_A_SplitCrown", Vector3(-15, -0.25, 14), Vector3(0.82, 0.82, 0.82), -0.18],
		["HeroRock_B_LeaningStack", Vector3(14, -0.22, 19), Vector3(0.75, 0.75, 0.75), 0.28],
		["HeroRock_C_BrokenButte", Vector3(-16, -0.30, 31), Vector3(0.70, 0.70, 0.70), -0.34],
		["CanyonWall_A_Concave", Vector3(-24, -0.55, 49), Vector3(0.90, 0.90, 0.90), 1.08],
		["CanyonWall_B_Stepped", Vector3(18, -0.50, 51), Vector3(0.82, 0.82, 0.82), -1.06],
		["RockArch_01", Vector3(0, -0.30, 58), Vector3(1.08, 1.08, 1.08), 0.02],
		["DistantMesa_A", Vector3(-28, -0.8, 82), Vector3(1.45, 1.45, 1.45), 0.0],
		["DistantMesa_B", Vector3(25, -0.8, 88), Vector3(1.38, 1.38, 1.38), 0.0],
		["Dune_01", Vector3(-12, -0.26, 28), Vector3(1.7, 0.42, 1.7), 0.14],
		["Dune_02", Vector3(13, -0.25, 31), Vector3(1.5, 0.40, 1.5), -0.12],
		["Dune_03", Vector3(-17, -0.30, 43), Vector3(1.8, 0.38, 1.8), 0.18],
		["RoadEdge_BrokenShoulder_A", Vector3(-4.8, -0.02, 28), Vector3(1.0, 0.45, 3.3), 0.0],
		["RoadEdge_BrokenShoulder_B", Vector3(4.8, -0.02, 28), Vector3(1.0, 0.45, 3.3), 0.0],
		["Cactus_01", Vector3(-8.0, 0, 8), Vector3.ONE, -0.20],
		["Cactus_02", Vector3(-10.0, 0, 10), Vector3(0.72, 0.72, 0.72), 0.28],
		["Cactus_03", Vector3(10.0, 0, 23), Vector3(0.82, 0.82, 0.82), -0.42],
		["DryBush_01", Vector3(7.0, 0, 8), Vector3.ONE, 0.24],
		["DryBush_02", Vector3(8.8, 0, 10.5), Vector3(0.74, 0.74, 0.74), -0.18],
		["DryBush_03", Vector3(-9.0, 0, 25), Vector3(0.86, 0.86, 0.86), 0.40],
		["DryBush_01", Vector3(-6.2, -0.02, 23.0), Vector3(0.58, 0.58, 0.58), -0.38],
		["Cactus_02", Vector3(8.6, -0.02, 19.6), Vector3(0.54, 0.54, 0.54), 0.52],
		["RoadSign_Direction", Vector3(-7.0, 0, 24), Vector3.ONE, 0.0],
		["SafetyBarrier_01", Vector3(7.6, 0, 29), Vector3(0.92, 0.92, 0.92), 0.0],
		["NarrativeWreck_SurveyRover", Vector3(10.5, 0, 15), Vector3(0.74, 0.74, 0.74), -0.28],
	]
	for placement in placements:
		_copy_asset_to(kit, placement[0], composition_root, placement[1], placement[3], placement[2])
	var road := MeshInstance3D.new()
	road.name = "WeatheredRoad"
	road.mesh = _road_mesh(8.5, 82, 56)
	road.material_override = kit.material_for("road")
	road.position = Vector3(0, 0.035, 33)
	composition_root.add_child(road)
	_add_contact_cluster(composition_root, Vector3(-15, -0.04, 14), 1.25, 3101)
	_add_contact_cluster(composition_root, Vector3(14, -0.04, 19), 1.05, 3203)
	_add_contact_cluster(composition_root, Vector3(10.5, -0.03, 15), 0.62, 3307)
	_add_contact_cluster(composition_root, Vector3(-7.0, -0.03, 24), 0.48, 3407)
	kit.scatter_root.reparent(composition_root)
	kit.scatter_root.visible = true
	detail_root = Node3D.new()
	detail_root.name = "TechnicalDetailViews"
	detail_root.visible = false
	add_child(detail_root)

func _add_contact_cluster(parent: Node3D, center: Vector3, radius: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var source := kit.asset("SmallRock_02", 2)
	if source == null:
		return
	var instance := MultiMeshInstance3D.new()
	instance.name = "ContactTalus_%d" % seed
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source.mesh
	multimesh.instance_count = 7
	for index in 7:
		var angle := rng.randf_range(-PI, PI)
		var distance := rng.randf_range(radius * 0.35, radius)
		var scale_value := rng.randf_range(0.16, 0.42) * radius
		var position_value := center + Vector3(cos(angle) * distance, rng.randf_range(-0.06, 0.01), sin(angle) * distance)
		var basis := Basis(Vector3.UP, angle).scaled(Vector3(scale_value, scale_value * 0.62, scale_value))
		multimesh.set_instance_transform(index, Transform3D(basis, position_value))
	instance.multimesh = multimesh
	instance.material_override = kit.material_for("rock_dark")
	parent.add_child(instance)

func _copy_asset_to(source_kit: Node, asset_name: String, parent: Node3D, position_value: Vector3, rotation_y := 0.0, scale_value := Vector3.ONE, level := 0) -> MeshInstance3D:
	var source: MeshInstance3D = source_kit.asset(asset_name, level) if source_kit is EnvironmentKitV2 else source_kit.asset(asset_name)
	if source == null:
		return null
	var copy := MeshInstance3D.new()
	copy.name = "Copy_" + asset_name
	copy.mesh = source.mesh
	copy.position = position_value
	copy.rotation.y = rotation_y
	copy.scale = scale_value
	copy.material_override = source.get_active_material(0)
	parent.add_child(copy)
	return copy

func _restore_review() -> void:
	kit.visible = true
	kit.set_lod(0)
	kit.set_review_mode("final_pbr")
	kit.show_all()
	for asset_name in original_transforms:
		kit.asset(asset_name).transform = original_transforms[asset_name]
	composition_root.visible = false
	detail_root.visible = false
	for child in detail_root.get_children():
		child.queue_free()
	if blockout != null:
		blockout.visible = false
	if stallion != null:
		stallion.visible = false
	comparison_overlay.visible = false
	panel.position = Vector2(24, 22)
	title.visible = true
	floor_mesh.visible = true
	_set_golden_hour()

func _set_studio() -> void:
	_set_golden_hour()

func _set_daylight() -> void:
	_set_daylight_neutral()

func _set_sunset() -> void:
	_set_sunset_cinematic()

func _set_daylight_neutral() -> void:
	_apply_lighting("Daylight Neutral", Color("728fa6"), Color("c3d2d8"), Color("596a79"), Color("fff4df"), Color("a9c7da"), Vector3(-52, -32, 0))

func _set_golden_hour() -> void:
	_apply_lighting("Golden Hour", Color("56788f"), Color("d7b78d"), Color("4c5b69"), Color("f5c58b"), Color("88a9c2"), Vector3(-31, -48, 0))

func _set_sunset_cinematic() -> void:
	_apply_lighting("Sunset Cinematic", Color("3f586f"), Color("c48977"), Color("374553"), Color("e98c62"), Color("738fbd"), Vector3(-18, -58, 0))

func _apply_lighting(preset_name: String, sky_top: Color, horizon: Color, ground_bottom: Color, key_color: Color, fill_color: Color, key_rotation: Vector3) -> void:
	var preset: Dictionary = LIGHTING_PRESETS[preset_name]
	environment.ambient_light_color = fill_color.lerp(Color.WHITE, 0.45)
	environment.ambient_light_energy = preset.ambient
	environment.tonemap_exposure = preset.exposure
	sky_material.sky_top_color = sky_top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_bottom_color = ground_bottom
	sky_material.ground_horizon_color = horizon
	sky_material.sky_curve = 0.12
	sky_material.ground_curve = 0.18
	sky_material.sun_angle_max = 2.2
	sky_material.sun_curve = 0.055
	key_light.light_color = key_color
	key_light.light_energy = preset.key
	key_light.rotation_degrees = key_rotation
	fill_light.light_color = fill_color
	fill_light.light_energy = preset.fill

func _set_camera(position_value: Vector3, target: Vector3) -> void:
	camera.position = position_value
	camera.look_at(target, Vector3.UP)

func _ensure_stallion(parent: Node3D) -> Node3D:
	if stallion == null:
		stallion = STALLION_SCENE.instantiate() as Node3D
		stallion.name = "StallionV3ScaleReference"
		add_child(stallion)
	stallion.reparent(parent)
	stallion.visible = true
	return stallion

func _ensure_blockout() -> EnvironmentKitV2Blockout:
	if blockout == null:
		blockout = BLOCKOUT_SCENE.instantiate() as EnvironmentKitV2Blockout
		blockout.name = "ApprovedBlockoutReference"
		add_child(blockout)
	blockout.visible = true
	return blockout

func _configure_shot(index: int) -> void:
	_restore_review()
	panel.text = "40 ASSETS · 3 MANUAL LOD · 9 SHARED MATERIALS · 12 PBR MAPS"
	match index:
		0:
			kit.show_only(["HeroRock_"])
			panel.text = "HERO ROCKS · IRREGULAR STRATA · CAVITY AO · SAND ACCUMULATION"
			_set_camera(Vector3(34, 15, -18), Vector3(0, 3.5, 1))
		1:
			kit.show_only(["CanyonWall_"])
			panel.text = "CANYON MODULES · SHARED PBR · EROSION + ROUGHNESS VARIATION"
			_set_camera(Vector3(38, 18, 2), Vector3(0, 4.5, 29))
		2:
			kit.show_only(["RockArch_"])
			panel.text = "ROCK ARCH · MONUMENTAL SCALE · WORN EDGES · BROAD FRACTURES"
			_set_camera(Vector3(23, 11, -7), Vector3(0, 4.5, 15))
		3:
			kit.visible = false
			detail_root.visible = true
			_copy_asset_to(kit, "RockArch_01", detail_root, Vector3.ZERO)
			var car := _ensure_stallion(detail_root)
			car.position = Vector3(0, 0.05, -1.4)
			car.rotation.y = PI
			panel.text = "ARCH CLEARANCE · DESERT STALLION V3 SCALE REFERENCE"
			_set_camera(Vector3(20, 8, -14), Vector3(0, 3.6, 0))
		4:
			kit.visible = false
			composition_root.visible = true
			_set_daylight()
			title.visible = false
			panel.text = "COMPLETE CANYON · DAYLIGHT · ROAD + SHOULDER TRANSITIONS"
			_set_camera(Vector3(17, 7.8, -17), Vector3(0, 2.7, 44))
		5:
			kit.visible = false
			composition_root.visible = true
			_set_sunset()
			title.visible = false
			panel.text = "COMPLETE CANYON · SUNSET · THREE DEPTH PLANES"
			_set_camera(Vector3(17, 7.8, -17), Vector3(0, 2.7, 44))
		6:
			kit.visible = false
			detail_root.visible = true
			_copy_asset_to(kit, "CanyonWall_B_Stepped", detail_root, Vector3(0, -0.35, 5), 0.05)
			for placement in [["Dune_01", Vector3(-5, -0.3, -0.5), 0.1, Vector3(1.6, 0.32, 1.6)], ["SmallRock_02", Vector3(-2.5, 0, -1.7), 0.4, Vector3(1.2, 0.8, 1.2)], ["SmallRock_06", Vector3(0.4, 0, -1.9), -0.2, Vector3(0.8, 0.55, 0.8)], ["DebrisGravelCluster", Vector3(3, -0.08, -1.2), -0.2, Vector3(1.2, 0.35, 1.2)]]:
				_copy_asset_to(kit, placement[0], detail_root, placement[1], placement[2], placement[3])
			panel.text = "GROUND CONTACT · TALUS · GRAVEL · CAVITY DARKENING"
			_set_camera(Vector3(13, 4.5, -10), Vector3(0, 1.2, 3))
		7:
			kit.visible = false
			detail_root.visible = true
			var road := MeshInstance3D.new()
			road.mesh = _road_mesh(9, 30, 30)
			road.material_override = kit.material_for("road")
			road.position = Vector3(0, 0.02, 6)
			detail_root.add_child(road)
			_copy_asset_to(kit, "RoadEdge_BrokenShoulder_A", detail_root, Vector3(-4.8, 0, 6), 0, Vector3(1, 0.5, 1.8))
			_copy_asset_to(kit, "RoadEdge_BrokenShoulder_B", detail_root, Vector3(4.8, 0, 6), 0, Vector3(1, 0.5, 1.8))
			_copy_asset_to(kit, "DebrisGravelCluster", detail_root, Vector3(-5.4, 0, 1), 0.3, Vector3(1.2, 0.5, 1.2))
			panel.text = "ROAD EDGE · DUST · TRACK WEAR · IRREGULAR SHOULDERS"
			_set_camera(Vector3(12, 4.0, -9), Vector3(0, 0.4, 7))
		8:
			kit.show_only(["Cactus_", "DryBush_"])
			panel.text = "VEGETATION ATLAS · THREE CACTUS + THREE BUSH VARIANTS"
			_set_camera(Vector3(15, 6.5, -35), Vector3(0, 1.2, -25))
		9:
			kit.show_only(["RoadSign_", "SafetyBarrier_", "NarrativeWreck_"])
			panel.text = "PROPS ATLAS · PAINT WEAR · OXIDATION · SAND DEPOSITS"
			_set_camera(Vector3(22, 8, -43), Vector3(3, 1.1, -31))
		10:
			kit.show_only(["DistantMesa_"])
			panel.text = "DISTANT MESAS · PBR BACKGROUND · PRESERVED SILHOUETTES"
			_set_camera(Vector3(42, 20, 17), Vector3(0, 3.5, 42))
		11:
			kit.visible = false
			detail_root.visible = true
			var old := _ensure_blockout()
			old.show_only(["HeroRock_A_"])
			old.position = Vector3(-8, 0, 0)
			_copy_asset_to(kit, "HeroRock_A_SplitCrown", detail_root, Vector3(8, 0, 0))
			panel.text = "APPROVED BLOCKOUT  ←   SAME SCALE + LIGHT   →  FINAL PBR"
			_set_camera(Vector3(25, 11, -21), Vector3(0, 3.0, 0))
		12:
			kit.visible = false
			detail_root.visible = true
			for level in 3:
				_copy_asset_to(kit, "HeroRock_B_LeaningStack", detail_root, Vector3(-12 + level * 12, 0, 0), 0.15 * (level - 1), Vector3.ONE * 0.72, level)
			panel.text = "MANUAL LOD0 26,982 TRI  ·  LOD1 16,495  ·  LOD2 9,346"
			_set_camera(Vector3(30, 13, -21), Vector3(0, 3.0, 0))
		13:
			panel.text = "COMPLETE KIT GALLERY · FINAL PBR · 40 MODULAR ASSETS"
			_set_camera(Vector3(48, 34, -39), Vector3(0, 3, -6))
		14:
			kit.visible = false
			composition_root.visible = true
			_set_sunset()
			title.visible = false
			var scene_car := _ensure_stallion(composition_root)
			scene_car.position = Vector3(0, 0.05, 5.5)
			scene_car.rotation.y = PI
			panel.text = "COMPLETE ENVIRONMENT KIT · STALLION V3 SCALE · FINAL PBR"
			_set_camera(Vector3(16, 7.2, -16), Vector3(0, 2.5, 43))
		15:
			kit.show_only(["HeroRock_", "CanyonWall_", "RockArch_"])
			for asset_name in kit.lod_assets[0]:
				var mesh_instance := kit.asset(asset_name)
				if mesh_instance.visible:
					mesh_instance.material_override = black_material
			panel.text = "BLACK SILHOUETTES · APPROVED SHAPES PRESERVED"
			_set_camera(Vector3(38, 17, -4), Vector3(0, 4.0, 18))

func _show_complete_scene(preset_name: String) -> void:
	kit.visible = false
	composition_root.visible = true
	title.visible = false
	match preset_name:
		"Daylight Neutral": _set_daylight_neutral()
		"Sunset Cinematic": _set_sunset_cinematic()
		_: _set_golden_hour()

func _configure_polish_shot(index: int) -> void:
	_restore_review()
	panel.text = "E2.1 ENVIRONMENT POLISH · GOLDEN HOUR PRIMARY · GL COMPATIBILITY"
	match index:
		0:
			_show_complete_scene("Daylight Neutral")
			panel.text = "DAYLIGHT NEUTRAL · EXPOSURE 0.84 · COOL HORIZON FILL"
			_set_camera(Vector3(17, 7.8, -17), Vector3(0, 2.7, 44))
		1:
			_show_complete_scene("Golden Hour")
			panel.text = "GOLDEN HOUR · EXPOSURE 0.90 · PRIMARY REVIEW PRESET"
			_set_camera(Vector3(17, 7.8, -17), Vector3(0, 2.7, 44))
		2:
			_show_complete_scene("Sunset Cinematic")
			panel.text = "SUNSET CINEMATIC · EXPOSURE 0.88 · BLUE-GRAY SHADOW DETAIL"
			_set_camera(Vector3(17, 7.8, -17), Vector3(0, 2.7, 44))
		3:
			kit.visible = false
			detail_root.visible = true
			_copy_asset_to(kit, "Dune_01", detail_root, Vector3(-4.5, -0.22, 2), 0.15, Vector3(2.2, 0.32, 2.1))
			_copy_asset_to(kit, "Dune_02", detail_root, Vector3(4.0, -0.24, 4), -0.2, Vector3(1.7, 0.28, 1.8))
			_add_contact_cluster(detail_root, Vector3(-1.0, -0.03, 1.4), 2.1, 4103)
			_add_contact_cluster(detail_root, Vector3(3.2, -0.03, 4.5), 1.4, 4201)
			panel.text = "GROUND BLEND · FINE SAND · COMPACT SOIL · GRAVEL · LOCAL RELIEF"
			_set_camera(Vector3(12, 3.1, -10), Vector3(0, 0.0, 3))
		4:
			kit.visible = false
			detail_root.visible = true
			_copy_asset_to(kit, "HeroRock_A_SplitCrown", detail_root, Vector3(0, -0.18, 4), -0.12, Vector3(0.82, 0.82, 0.82))
			_copy_asset_to(kit, "Dune_03", detail_root, Vector3(0, -0.34, 3.7), 0.3, Vector3(2.4, 0.24, 1.7))
			_add_contact_cluster(detail_root, Vector3(-4.2, -0.03, 2.0), 1.5, 4303)
			_add_contact_cluster(detail_root, Vector3(4.1, -0.03, 2.4), 1.4, 4313)
			_add_contact_cluster(detail_root, Vector3(0.0, -0.03, -0.2), 1.2, 4327)
			panel.text = "ROCK BASE CONTACT · TALUS · SAND ACCUMULATION · CONTACT SHADOW"
			_set_camera(Vector3(14, 4.2, -9), Vector3(0, 1.1, 4))
		5:
			kit.visible = false
			detail_root.visible = true
			var road := MeshInstance3D.new()
			road.mesh = _road_mesh(9.0, 38.0, 38)
			road.material_override = kit.material_for("road")
			road.position = Vector3(0, 0, 8)
			detail_root.add_child(road)
			_copy_asset_to(kit, "RoadEdge_BrokenShoulder_A", detail_root, Vector3(-4.8, -0.02, 8), 0, Vector3(1, 0.45, 2.3))
			_copy_asset_to(kit, "RoadEdge_BrokenShoulder_B", detail_root, Vector3(4.8, -0.02, 8), 0, Vector3(1, 0.45, 2.3))
			_add_contact_cluster(detail_root, Vector3(-5.0, -0.03, 5), 1.25, 4409)
			panel.text = "ROAD EDGE · CONTROLLED VALUES · DUST · WEAR · SOFT SHOULDER TRANSITION"
			_set_camera(Vector3(12, 3.7, -9), Vector3(0, 0.3, 9))
		6:
			kit.show_only(["HeroRock_"])
			panel.text = "HERO MATERIAL · BROKEN STRATA · VERTICAL FRACTURES · ROUGHNESS VARIATION"
			_set_camera(Vector3(34, 14, -18), Vector3(0, 3.4, 1))
		7:
			kit.show_only(["CanyonWall_"])
			panel.text = "CANYON MATERIAL · OCHRE / RED / BROWN / GRAY SEPARATION"
			_set_camera(Vector3(38, 17, 2), Vector3(0, 4.4, 29))
		8:
			kit.visible = false
			detail_root.visible = true
			_copy_asset_to(kit, "RockArch_01", detail_root, Vector3(0, -0.16, 4))
			_copy_asset_to(kit, "Dune_02", detail_root, Vector3(0, -0.34, 4), 0.0, Vector3(2.4, 0.22, 1.9))
			_add_contact_cluster(detail_root, Vector3(-5.0, -0.03, 4), 1.8, 4507)
			_add_contact_cluster(detail_root, Vector3(5.2, -0.03, 4), 1.8, 4513)
			panel.text = "ROCK ARCH · GOLDEN HOUR · READABLE CAVITY AND SHOULDERS"
			_set_camera(Vector3(23, 9.5, -9), Vector3(0, 4.0, 4))
		9:
			kit.visible = false
			detail_root.visible = true
			_copy_asset_to(kit, "NarrativeWreck_SurveyRover", detail_root, Vector3(1.5, -0.03, 4), -0.25, Vector3(0.82, 0.82, 0.82))
			_copy_asset_to(kit, "RoadSign_Direction", detail_root, Vector3(-4.2, -0.03, 6), 0.12, Vector3.ONE)
			_copy_asset_to(kit, "Cactus_01", detail_root, Vector3(5.8, -0.02, 7), -0.3, Vector3(0.8, 0.8, 0.8))
			_copy_asset_to(kit, "DryBush_01", detail_root, Vector3(-2.8, -0.02, 3.0), 0.4, Vector3(0.72, 0.72, 0.72))
			_copy_asset_to(kit, "DryBush_02", detail_root, Vector3(4.0, -0.02, 2.5), -0.2, Vector3(0.55, 0.55, 0.55))
			_add_contact_cluster(detail_root, Vector3(1.5, -0.04, 4), 1.5, 4603)
			_add_contact_cluster(detail_root, Vector3(-4.2, -0.04, 6), 0.72, 4611)
			panel.text = "PROP INTEGRATION · GROUPED VEGETATION · SAND · GRAVEL · WEATHERING"
			_set_camera(Vector3(15, 5.5, -10), Vector3(0.5, 1.1, 4.5))
		10:
			_show_complete_scene("Golden Hour")
			panel.text = "SKY ATMOSPHERE · VERTICAL GRADIENT · SOLAR GLOW · COOL HORIZON"
			_set_camera(Vector3(12, 4.4, -13), Vector3(0, 8.2, 55))
		11:
			_show_complete_scene("Golden Hour")
			comparison_overlay.visible = true
			panel.position = Vector2(660, 22)
			panel.text = "BEFORE E2 (LEFT)  |  E2.1 POLISH (RIGHT) · SAME REVIEW CONTEXT"
			_set_camera(Vector3(17, 7.8, -17), Vector3(0, 2.7, 44))
		12:
			_show_complete_scene("Golden Hour")
			var scene_car := _ensure_stallion(composition_root)
			scene_car.position = Vector3(0, 0.05, 5.5)
			scene_car.rotation.y = PI
			panel.text = "COMPLETE SCENE · STALLION V3 SCALE REFERENCE · GOLDEN HOUR"
			_set_camera(Vector3(16, 7.2, -16), Vector3(0, 2.5, 43))
		13:
			kit.visible = false
			detail_root.visible = true
			for level in 3:
				_copy_asset_to(kit, "HeroRock_B_LeaningStack", detail_root, Vector3(-12 + level * 12, 0, 0), 0.15 * (level - 1), Vector3.ONE * 0.72, level)
			panel.text = "LOD MATERIAL CONSISTENCY · 26,982 / 16,495 / 9,346 TRIANGLES"
			_set_camera(Vector3(30, 13, -21), Vector3(0, 3.0, 0))

func _capture_polish_set() -> void:
	var filenames := [
		"01_daylight_complete_scene.png", "02_golden_hour_complete_scene.png",
		"03_sunset_complete_scene.png", "04_ground_blending_closeup.png",
		"05_rock_base_contact.png", "06_road_edge_detail.png",
		"07_hero_rocks_material_detail.png", "08_canyon_material_detail.png",
		"09_arch_golden_hour.png", "10_props_integration.png",
		"11_sky_atmosphere.png", "12_before_after_comparison.png",
		"13_complete_scene_with_stallion.png", "14_lod_material_consistency.png",
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(POLISH_CAPTURE_ROOT))
	var failures := 0
	for index in filenames.size():
		_configure_polish_shot(index)
		for _frame in 16:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s" % [POLISH_CAPTURE_ROOT, filenames[index]]
		var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("ENVIRONMENT_KIT_V2_POLISH_CAPTURE ", path, " error=", error)
		if error != OK:
			failures += 1
	get_tree().quit(0 if failures == 0 else 1)

func _capture_set() -> void:
	var filenames := [
		"01_hero_rocks_pbr.png", "02_canyon_modules_pbr.png", "03_rock_arch_pbr.png",
		"04_arch_with_stallion.png", "05_canyon_daylight.png", "06_canyon_sunset.png",
		"07_ground_contact_detail.png", "08_road_edge_detail.png", "09_cactus_bushes_pbr.png",
		"10_props_wreck_pbr.png", "11_mesas_background.png", "12_blockout_final_comparison.png",
		"13_lod_comparison.png", "14_complete_kit_gallery.png", "15_complete_scene_with_stallion.png",
		"16_black_silhouette_final.png",
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/environment_kit_v2_review/visual"))
	var failures := 0
	for index in filenames.size():
		_configure_shot(index)
		for _frame in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "res://screenshots/environment_kit_v2_review/visual/%s" % filenames[index]
		var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("ENVIRONMENT_KIT_V2_VISUAL_CAPTURE ", path, " error=", error)
		if error != OK:
			failures += 1
	get_tree().quit(0 if failures == 0 else 1)

func _write_metrics() -> void:
	var sorted_fps := fps_values.duplicate()
	sorted_fps.sort()
	var p5: float = sorted_fps[int(floor((sorted_fps.size() - 1) * 0.05))] if not sorted_fps.is_empty() else 0.0
	var report := "Environment Kit V2 visual polish metrics\n"
	report += "duration_seconds=%.2f\n" % SEQUENCE_SECONDS
	report += "average_fps=%.2f\n" % (fps_total / maxi(1, fps_samples))
	report += "instantaneous_minimum_fps=%.2f\n" % (fps_min if fps_min < INF else 0.0)
	report += "percentile_5_fps=%.2f\n" % p5
	report += "minimum_sustained_fps=%.2f\n" % _minimum_rolling_fps(30)
	report += "load_time_ms=%.2f\n" % load_time_ms
	report += "peak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\n" % [peak_draw_calls, peak_primitives, peak_nodes]
	report += "peak_static_memory_mb=%.2f\n" % (peak_memory_bytes / 1048576.0)
	report += "assets=40\nmaterials_shared=9\ntextures=12\n"
	report += "lod0_triangles=26982\nlod1_triangles=16495\nlod2_triangles=9346\n"
	report += "renderer=GL Compatibility\ngpu=NVIDIA GeForce MX150\nresolution=1280x720\n"
	report += "lighting_presets=Daylight Neutral|Golden Hour|Sunset Cinematic\nprimary_preset=Golden Hour\n"
	report += "shader=environment_v2_polish.gdshader\npolish_screenshots=14\n"
	report += "classification=AWAITING_MANUAL_VISUAL_APPROVAL\nproduction_integrated=false\n"
	var file := FileAccess.open("res://reports/environment_kit_v2_metrics.txt", FileAccess.WRITE)
	file.store_string(report)
	file.close()
	print(report)

func _minimum_rolling_fps(window: int) -> float:
	if fps_values.is_empty():
		return 0.0
	var actual_window := mini(window, fps_values.size())
	var total := 0.0
	for index in actual_window:
		total += fps_values[index]
	var result := total / actual_window
	for index in range(actual_window, fps_values.size()):
		total += fps_values[index] - fps_values[index - actual_window]
		result = minf(result, total / actual_window)
	return result
