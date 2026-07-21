class_name EnvironmentKitV2BlockoutReview
extends Node3D

const KIT_SCENE := preload("res://scenes/visual/assets/EnvironmentKitV2Blockout.tscn")
const OLD_ENV_SCENE := preload("res://assets/models/environment/desert_prototype_environment_v2.glb")
const STALLION_V3_SCENE := preload("res://scenes/visual/assets/DesertStallionV3Visual.tscn")
const SEQUENCE_SECONDS := 12.0
const TRIANGLE_COUNT := 26982

var kit: EnvironmentKitV2Blockout
var old_reference: Node3D
var old_rock: MeshInstance3D
var composition_root: Node3D
var detail_root: Node3D
var stallion_v3: Node3D
var camera: Camera3D
var environment: Environment
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var title: Label3D
var panel: Label
var floor_mesh: MeshInstance3D
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
	if "--capture-environment-kit-v2-blockout" in args:
		_capture_set.call_deferred()
	elif "--run-environment-kit-v2-blockout-metrics" in args:
		metrics_mode = true
		_configure_shot(0)

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
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("879098")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8e0e6")
	environment.ambient_light_energy = 0.56
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	var world := WorldEnvironment.new()
	world.name = "EnvironmentKitReviewWorld"
	world.environment = environment
	add_child(world)
	key_light = DirectionalLight3D.new()
	key_light.name = "ReviewKey"
	key_light.rotation_degrees = Vector3(-42, -36, 0)
	key_light.light_color = Color("fff1d8")
	key_light.light_energy = 1.18
	key_light.shadow_enabled = true
	key_light.shadow_blur = 1.4
	add_child(key_light)
	fill_light = DirectionalLight3D.new()
	fill_light.name = "ReviewFill"
	fill_light.rotation_degrees = Vector3(-30, 142, 0)
	fill_light.light_color = Color("bfd8ea")
	fill_light.light_energy = 0.42
	add_child(fill_light)
	floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "ReviewGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(130, 130)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("686f73")
	floor_material.roughness = 0.94
	plane.material = floor_material
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	black_material = StandardMaterial3D.new()
	black_material.albedo_color = Color("08090a")
	black_material.roughness = 0.82

func _setup_kit() -> void:
	var start := Time.get_ticks_usec()
	kit = KIT_SCENE.instantiate() as EnvironmentKitV2Blockout
	kit.name = "EnvironmentKitV2Blockout"
	add_child(kit)
	load_time_ms = (Time.get_ticks_usec() - start) / 1000.0
	for asset_name in kit.assets:
		original_transforms[asset_name] = (kit.assets[asset_name] as MeshInstance3D).transform
	old_reference = OLD_ENV_SCENE.instantiate() as Node3D
	old_reference.name = "EnvironmentV1Reference"
	old_reference.visible = false
	add_child(old_reference)
	for node in old_reference.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.visible = mesh_instance.name == "Rock_A"
		if mesh_instance.name == "Rock_A":
			old_rock = mesh_instance

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "EnvironmentKitReviewCamera"
	camera.current = true
	camera.fov = 48.0
	add_child(camera)
	_set_camera(Vector3(34, 24, -34), Vector3(0, 3, -5))

func _setup_overlay() -> void:
	title = Label3D.new()
	title.text = "ENVIRONMENT KIT V2 · BLOCKOUT REVIEW"
	title.font_size = 42
	title.outline_size = 8
	title.modulate = Color("f1e3cf")
	title.no_depth_test = true
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.position = Vector3(0, 10.5, -4)
	add_child(title)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	panel = Label.new()
	panel.position = Vector2(24, 22)
	panel.add_theme_font_size_override("font_size", 16)
	panel.add_theme_color_override("font_color", Color("f3e5d0"))
	panel.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	panel.add_theme_constant_override("shadow_offset_x", 2)
	panel.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(panel)

func _build_composition() -> void:
	composition_root = Node3D.new()
	composition_root.name = "ReviewCompositionOnly"
	composition_root.visible = false
	add_child(composition_root)
	var placements := [
		["DebrisGravelCluster", Vector3(7.0, -0.04, -2.0), Vector3(1.7, 0.7, 1.7), 0.20],
		["SmallRock_03", Vector3(-6.0, 0.0, 6.0), Vector3(0.48, 0.42, 0.48), -0.30],
		["HeroRock_A_SplitCrown", Vector3(-14, -0.25, 15), Vector3(0.85, 0.85, 0.85), -0.16],
		["HeroRock_B_LeaningStack", Vector3(14, -0.25, 18), Vector3(0.78, 0.78, 0.78), 0.32],
		["HeroRock_C_BrokenButte", Vector3(-15.5, -0.30, 29), Vector3(0.72, 0.72, 0.72), -0.36],
		["CanyonWall_A_Concave", Vector3(-25.0, -0.35, 49), Vector3(0.90, 0.90, 0.90), 1.08],
		["RockArch_01", Vector3(0, -0.2, 55), Vector3(1.08, 1.08, 1.08), 0.02],
		["DistantMesa_A", Vector3(-27, -0.5, 72), Vector3(1.35, 1.35, 1.35), 0.0],
		["DistantMesa_B", Vector3(24, -0.5, 78), Vector3(1.30, 1.30, 1.30), 0.0],
		["Cactus_01", Vector3(-8, 0, 7), Vector3.ONE, -0.15],
		["Cactus_02", Vector3(-10, 0, 9), Vector3(0.72, 0.72, 0.72), 0.25],
		["DryBush_01", Vector3(7, 0, 9), Vector3.ONE, 0.35],
		["DryBush_02", Vector3(9, 0, 11), Vector3(0.75, 0.75, 0.75), -0.20],
		["RoadSign_Direction", Vector3(-7, 0, 25), Vector3.ONE, 0.0],
		["SafetyBarrier_01", Vector3(7.5, 0, 27), Vector3(0.9, 0.9, 0.9), 0.0],
		["NarrativeWreck_SurveyRover", Vector3(10, 0, 14), Vector3(0.72, 0.72, 0.72), -0.25],
		["Dune_01", Vector3(-13, -0.16, 28), Vector3(1.25, 0.45, 1.25), 0.08],
		["Dune_02", Vector3(13, -0.16, 30), Vector3(1.15, 0.40, 1.15), -0.08],
		["RoadEdge_BrokenShoulder_A", Vector3(-4.8, -0.02, 27), Vector3(1.0, 0.45, 2.9), 0.0],
		["RoadEdge_BrokenShoulder_B", Vector3(4.8, -0.02, 27), Vector3(1.0, 0.45, 2.9), 0.0],
	]
	for placement in placements:
		var source := kit.asset(placement[0])
		if source == null:
			continue
		var copy := MeshInstance3D.new()
		copy.name = "Composition_" + String(placement[0])
		copy.mesh = source.mesh
		copy.position = placement[1]
		copy.scale = placement[2]
		copy.rotation.y = placement[3]
		composition_root.add_child(copy)
	var road := MeshInstance3D.new()
	road.name = "CompositionRoad"
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(8, 70)
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color("3f3e3b")
	road_mat.roughness = 0.96
	road_mesh.material = road_mat
	road.mesh = road_mesh
	road.position = Vector3(0, 0.025, 27)
	composition_root.add_child(road)
	stallion_v3 = STALLION_V3_SCENE.instantiate() as Node3D
	stallion_v3.name = "CompositionScaleStallionV3"
	stallion_v3.position = Vector3(0, 0.05, 5.5)
	stallion_v3.rotation.y = PI
	composition_root.add_child(stallion_v3)
	detail_root = Node3D.new()
	detail_root.name = "ReviewDetailOnly"
	detail_root.visible = false
	add_child(detail_root)

func _restore_review() -> void:
	kit.visible = true
	kit.show_all()
	for asset_name in original_transforms:
		var mesh_instance := kit.asset(asset_name)
		mesh_instance.transform = original_transforms[asset_name]
		mesh_instance.material_override = null
	old_reference.visible = false
	composition_root.visible = false
	detail_root.visible = false
	for child in detail_root.get_children():
		child.queue_free()
	title.visible = true
	_set_neutral()

func _detail_copy(asset_name: String, position_value: Vector3, rotation_y := 0.0, scale_value := Vector3.ONE) -> MeshInstance3D:
	var source := kit.asset(asset_name)
	if source == null:
		return null
	var copy := MeshInstance3D.new()
	copy.name = "Detail_" + asset_name
	copy.mesh = source.mesh
	copy.position = position_value
	copy.rotation.y = rotation_y
	copy.scale = scale_value
	detail_root.add_child(copy)
	return copy

func _three_quarter_views(asset_name: String) -> void:
	detail_root.visible = true
	_detail_copy(asset_name, Vector3(-11, 0, 0), -0.72, Vector3(0.72, 0.72, 0.72))
	_detail_copy(asset_name, Vector3(0, 0, 0), 0.0, Vector3(0.72, 0.72, 0.72))
	_detail_copy(asset_name, Vector3(11, 0, 0), 0.72, Vector3(0.72, 0.72, 0.72))

func _set_neutral() -> void:
	environment.background_color = Color("879098")
	environment.ambient_light_color = Color("d8e0e6")
	environment.ambient_light_energy = 0.56
	environment.tonemap_exposure = 1.0
	key_light.light_color = Color("fff1d8")
	key_light.light_energy = 1.18
	key_light.rotation_degrees = Vector3(-42, -36, 0)
	fill_light.light_color = Color("bfd8ea")
	fill_light.light_energy = 0.42

func _set_sunset() -> void:
	environment.background_color = Color("a66250")
	environment.ambient_light_color = Color("897d9a")
	environment.ambient_light_energy = 0.52
	environment.tonemap_exposure = 1.05
	key_light.light_color = Color("ff9e52")
	key_light.light_energy = 1.46
	key_light.rotation_degrees = Vector3(-23, -58, 0)
	fill_light.light_color = Color("7594c2")
	fill_light.light_energy = 0.48

func _set_camera(position_value: Vector3, target: Vector3) -> void:
	camera.position = position_value
	camera.look_at(target, Vector3.UP)

func _configure_shot(index: int) -> void:
	_restore_review()
	title.text = "ENVIRONMENT KIT V2 · BLOCKOUT REVIEW"
	panel.text = "E1.1 GEOLOGY REVISION · 26,982 TRI · 7 SHARED CLAY MATERIALS"
	match index:
		0:
			kit.show_only(["HeroRock_"])
			panel.text = "REVISED HERO ROCKS · MASS · TERRACES · BUTTRESS"
			_set_camera(Vector3(34, 16, -18), Vector3(0, 3.6, 1))
		1:
			kit.visible = false
			_three_quarter_views("HeroRock_A_SplitCrown")
			panel.text = "HERO A · LOW HEAVY MASS · COLLAPSED BLOCKS · DEEP FRACTURES"
			_set_camera(Vector3(29, 13, -20), Vector3(0, 2.7, 0))
		2:
			kit.visible = false
			_three_quarter_views("HeroRock_B_LeaningStack")
			panel.text = "HERO B · HORIZONTAL DEVELOPMENT · TWO BROAD TERRACES"
			_set_camera(Vector3(30, 13, -20), Vector3(0, 3.1, 0))
		3:
			kit.visible = false
			_three_quarter_views("HeroRock_C_BrokenButte")
			panel.text = "HERO C · BROAD BUTTRESS · BROKEN CREST · LATERAL CAVITY"
			_set_camera(Vector3(30, 15, -21), Vector3(0, 4.0, 0))
		4:
			kit.show_only(["CanyonWall_"])
			panel.text = "REVISED CANYON · CONTINUOUS PLANES · TERRACES · ERODED BASES"
			_set_camera(Vector3(38, 19, 4), Vector3(0, 4.8, 29))
		5:
			kit.visible = false
			detail_root.visible = true
			var joint_a := _detail_copy("CanyonWall_A_Concave", Vector3(-10.2, 0, 0), 0.0)
			var joint_b := _detail_copy("CanyonWall_B_Stepped", Vector3(10.2, 0, 0), 0.0)
			if joint_a != null and joint_b != null:
				joint_b.material_override = joint_a.mesh.surface_get_material(0)
			var joint_mask := _detail_copy("MediumRock_03", Vector3(0.2, -0.05, -2.4), -0.10, Vector3(2.0, 2.25, 1.65))
			if joint_a != null and joint_mask != null:
				joint_mask.material_override = joint_a.mesh.surface_get_material(0)
			_detail_copy("SmallRock_05", Vector3(-2.0, 0, -4.0), 0.4, Vector3(1.4, 1.0, 1.4))
			_detail_copy("SmallRock_07", Vector3(2.3, 0, -4.2), -0.3, Vector3(1.1, 0.8, 1.1))
			panel.text = "MODULAR JOINT · MATCHED ENDS · LATERAL MASSES MASK THE SEAM"
			_set_camera(Vector3(9, 7, -16), Vector3(0, 3.0, 0))
		6:
			kit.show_only(["RockArch_"])
			panel.text = "REVISED LANDMARK ARCH · 17 M SPAN · 10 M CREST · VARIABLE THICKNESS"
			_set_camera(Vector3(22, 11, -7), Vector3(0, 4.5, 15))
		7:
			kit.visible = false
			detail_root.visible = true
			_detail_copy("RockArch_01", Vector3(0, 0, 0))
			var scale_car := STALLION_V3_SCENE.instantiate() as Node3D
			scale_car.position = Vector3(0, 0, -1.2)
			scale_car.rotation.y = PI
			detail_root.add_child(scale_car)
			panel.text = "ARCH CLEARANCE · DESERT STALLION V3 SCALE REFERENCE"
			_set_camera(Vector3(20, 8, -14), Vector3(0, 3.6, 0))
		8:
			kit.visible = false
			detail_root.visible = true
			_detail_copy("CanyonWall_B_Stepped", Vector3(0, -0.35, 5), 0.05)
			_detail_copy("Dune_01", Vector3(-5, -0.30, -0.5), 0.1, Vector3(1.6, 0.32, 1.6))
			_detail_copy("Dune_03", Vector3(5, -0.32, 0.5), -0.15, Vector3(1.4, 0.28, 1.4))
			_detail_copy("SmallRock_02", Vector3(-3.2, 0, -1.8), 0.4, Vector3(1.2, 0.8, 1.2))
			_detail_copy("SmallRock_04", Vector3(-0.8, 0, -2.1), -0.2, Vector3(1.0, 0.7, 1.0))
			_detail_copy("SmallRock_06", Vector3(1.4, 0, -2.0), 0.7, Vector3(0.8, 0.55, 0.8))
			_detail_copy("SmallRock_08", Vector3(3.4, 0, -1.2), -0.5, Vector3(1.1, 0.7, 1.1))
			_detail_copy("DebrisGravelCluster", Vector3(0.4, -0.08, -1.2), -0.2, Vector3(1.1, 0.35, 1.1))
			panel.text = "GROUND CONTACT · TALUS · GRAVEL · BROKEN BASE LINE"
			_set_camera(Vector3(13, 4.5, -10), Vector3(0, 1.2, 3))
		9:
			kit.visible = false
			composition_root.visible = true
			title.visible = false
			panel.text = "CANYON COMPOSITION · FOREGROUND GROUPS · LANDMARK · SCALE"
			_set_camera(Vector3(17, 7.8, -17), Vector3(0, 2.7, 43))
		10:
			kit.visible = false
			composition_root.visible = true
			_set_sunset()
			title.visible = false
			panel.text = "SUNSET · FOREGROUND · CONTINUOUS CANYON · ARCH · DISTANT MESA"
			_set_camera(Vector3(17, 7.8, -17), Vector3(0, 2.7, 43))
		11:
			kit.show_only(["HeroRock_"])
			for mesh_instance in kit.assets.values():
				if (mesh_instance as MeshInstance3D).visible:
					(mesh_instance as MeshInstance3D).material_override = black_material
			panel.text = "BLACK SILHOUETTES · THREE DISTINCT GEOLOGIC LANGUAGES"
			_set_camera(Vector3(34, 15, -18), Vector3(0, 3.5, 1))
		12:
			kit.show_only(["CanyonWall_", "RockArch_"])
			for mesh_instance in kit.assets.values():
				if (mesh_instance as MeshInstance3D).visible:
					(mesh_instance as MeshInstance3D).material_override = black_material
			panel.text = "BLACK SILHOUETTES · CONTINUOUS WALLS · MONUMENTAL ARCH"
			_set_camera(Vector3(38, 17, 0), Vector3(0, 4.2, 23))
		13:
			kit.show_only(["HeroRock_A_"])
			var hero := kit.asset("HeroRock_A_SplitCrown")
			hero.position = Vector3(7, 0, 0)
			old_reference.visible = true
			if old_rock != null:
				old_rock.position = Vector3(-7, 0, 0)
				old_rock.scale = Vector3(3.2, 3.2, 3.2)
			panel.text = "V2 PROCEDURAL ROCK  ←   SAME LIGHT + SCALE   →  E1.1 HERO MASS"
			_set_camera(Vector3(24, 11, -20), Vector3(0, 3.0, 0))

func _capture_set() -> void:
	var filenames := [
		"01_hero_rocks_revised.png", "02_hero_rock_a_turntable.png",
		"03_hero_rock_b_turntable.png", "04_hero_rock_c_turntable.png",
		"05_canyon_modules_revised.png", "06_canyon_joint_closeup.png",
		"07_rock_arch_revised.png", "08_arch_with_stallion_scale.png",
		"09_ground_contact_detail.png", "10_canyon_composition_daylight.png",
		"11_canyon_composition_sunset.png", "12_black_silhouette_hero_rocks.png",
		"13_black_silhouette_canyon.png", "14_old_new_environment_comparison.png",
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/environment_kit_v2_review/blockout"))
	var failures := 0
	for index in filenames.size():
		_configure_shot(index)
		for _frame in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "res://screenshots/environment_kit_v2_review/blockout/%s" % filenames[index]
		var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("ENVIRONMENT_KIT_V2_CAPTURE ", path, " error=", error)
		if error != OK:
			failures += 1
	get_tree().quit(0 if failures == 0 else 1)

func _write_metrics() -> void:
	var sorted_fps := fps_values.duplicate()
	sorted_fps.sort()
	var p5: float = sorted_fps[int(floor((sorted_fps.size() - 1) * 0.05))] if not sorted_fps.is_empty() else 0.0
	var report := "Environment Kit V2 blockout metrics\n"
	report += "duration_seconds=%.2f\n" % SEQUENCE_SECONDS
	report += "average_fps=%.2f\n" % (fps_total / maxi(1, fps_samples))
	report += "instantaneous_minimum_fps=%.2f\n" % (fps_min if fps_min < INF else 0.0)
	report += "percentile_5_fps=%.2f\n" % p5
	report += "minimum_sustained_fps=%.2f\n" % _minimum_rolling_fps(30)
	report += "load_time_ms=%.2f\n" % load_time_ms
	report += "peak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\n" % [peak_draw_calls, peak_primitives, peak_nodes]
	report += "peak_static_memory_mb=%.2f\n" % (peak_memory_bytes / 1048576.0)
	report += "asset_count=40\ntriangles=%d\nmaterials=7\n" % TRIANGLE_COUNT
	report += "hero_a_triangles=2000\nhero_b_triangles=2184\nhero_c_triangles=2188\n"
	report += "canyon_a_triangles=5608\ncanyon_b_triangles=6204\narch_triangles=2508\n"
	report += "hero=3\nmedium=6\nsmall=10\narch=1\ncanyon=2\nmesa=2\ncactus=3\nbush=3\nsigns=2\nbarrier=1\nwreck=1\ndunes=3\nroad_edges=2\ndebris=1\n"
	var file := FileAccess.open("res://reports/environment_kit_v2_blockout_metrics.txt", FileAccess.WRITE)
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
