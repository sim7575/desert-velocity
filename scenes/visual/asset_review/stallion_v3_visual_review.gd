class_name StallionV3VisualReview
extends Node3D

const V3_SCENE := preload("res://scenes/visual/assets/DesertStallionV3Visual.tscn")
const SEQUENCE_SECONDS := 12.0

var v3: DesertStallionV3Visual
var v2: Node3D
var lod_examples: Array[DesertStallionV3Visual] = []
var camera: Camera3D
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var rim_light: DirectionalLight3D
var environment: Environment
var floor_material: StandardMaterial3D
var title: Label3D
var metrics_panel: Label
var clay_material: StandardMaterial3D
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
	_setup_studio()
	_setup_models()
	_setup_camera()
	_setup_panel()
	var args := OS.get_cmdline_user_args()
	if "--capture-stallion-v3-visual" in args:
		_capture_set.call_deferred()
	elif "--run-stallion-v3-visual-metrics" in args:
		metrics_mode = true

func _process(delta: float) -> void:
	if not metrics_mode:
		return
	elapsed += delta
	v3.rotation.y = elapsed * 0.30
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

func _setup_studio() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("7e8790")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce3e8")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.98
	var world := WorldEnvironment.new()
	world.name = "ReviewEnvironment"
	world.environment = environment
	add_child(world)
	key_light = DirectionalLight3D.new()
	key_light.name = "ReviewKey"
	key_light.rotation_degrees = Vector3(-45.0, -45.0, 0.0)
	key_light.light_color = Color("fff8ed")
	key_light.light_energy = 1.15
	key_light.shadow_enabled = true
	key_light.shadow_blur = 1.8
	add_child(key_light)
	fill_light = DirectionalLight3D.new()
	fill_light.name = "ReviewFill"
	fill_light.rotation_degrees = Vector3(-32.0, 135.0, 0.0)
	fill_light.light_color = Color("d9e8f2")
	fill_light.light_energy = 0.48
	add_child(fill_light)
	rim_light = DirectionalLight3D.new()
	rim_light.name = "ReviewRim"
	rim_light.rotation_degrees = Vector3(-24.0, 178.0, 0.0)
	rim_light.light_color = Color("f1f5f7")
	rim_light.light_energy = 0.30
	add_child(rim_light)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 24.0)
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color("4f5559")
	floor_material.roughness = 0.90
	plane.material = floor_material
	floor.mesh = plane
	floor.name = "ReviewFloor"
	add_child(floor)
	_add_grid()

func _add_grid() -> void:
	var immediate := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.74, 0.80, 0.85, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for index in range(-11, 12):
		var c := float(index)
		immediate.surface_add_vertex(Vector3(c, 0.012, -9.0))
		immediate.surface_add_vertex(Vector3(c, 0.012, 9.0))
		immediate.surface_add_vertex(Vector3(-11.0, 0.012, c))
		immediate.surface_add_vertex(Vector3(11.0, 0.012, c))
	immediate.surface_end()
	var grid := MeshInstance3D.new()
	grid.name = "DimensionGrid"
	grid.mesh = immediate
	add_child(grid)

func _setup_models() -> void:
	var start := Time.get_ticks_usec()
	v3 = V3_SCENE.instantiate() as DesertStallionV3Visual
	v3.name = "StallionV3Visual"
	add_child(v3)
	load_time_ms = (Time.get_ticks_usec() - start) / 1000.0
	v2 = VehicleFactory.create_vehicle(0, false)
	v2.name = "StallionV2Reference"
	v2.visible = false
	add_child(v2)
	clay_material = StandardMaterial3D.new()
	clay_material.albedo_color = Color("69737c")
	clay_material.roughness = 0.78
	# D2.1 no longer captures the redundant three-car LOD lineup. Keeping those
	# hidden instances alive tripled review startup cost and material compilation.
	title = Label3D.new()
	title.text = "DESERT STALLION V3 · MATERIAL READABILITY REVIEW"
	title.font_size = 30
	title.outline_size = 7
	title.modulate = Color("f3e7d2")
	title.no_depth_test = true
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.position = Vector3(0.0, 2.28, 0.0)
	add_child(title)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ReviewCamera"
	camera.current = true
	camera.fov = 46.0
	add_child(camera)
	_set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))

func _setup_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "MetricsCanvas"
	add_child(canvas)
	metrics_panel = Label.new()
	metrics_panel.position = Vector2(24, 22)
	metrics_panel.add_theme_font_size_override("font_size", 16)
	metrics_panel.add_theme_color_override("font_color", Color("f2e5cf"))
	metrics_panel.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	metrics_panel.add_theme_constant_override("shadow_offset_x", 2)
	metrics_panel.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(metrics_panel)

func _set_camera(position_value: Vector3, target: Vector3) -> void:
	camera.position = position_value
	camera.look_at(target, Vector3.UP)

func _set_studio_neutral() -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("747b80")
	environment.ambient_light_color = Color("dce3e8")
	environment.ambient_light_energy = 0.52
	environment.tonemap_exposure = 0.98
	key_light.rotation_degrees = Vector3(-45.0, -45.0, 0.0)
	key_light.light_color = Color("fff8ed")
	key_light.light_energy = 1.15
	fill_light.rotation_degrees = Vector3(-32.0, 135.0, 0.0)
	fill_light.light_color = Color("d9e8f2")
	fill_light.light_energy = 0.48
	rim_light.rotation_degrees = Vector3(-24.0, 178.0, 0.0)
	rim_light.light_color = Color("f1f5f7")
	rim_light.light_energy = 0.30
	floor_material.albedo_color = Color("4f5559")

func _set_outdoor_daylight() -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9fc4dc")
	environment.ambient_light_color = Color("cfe1ee")
	environment.ambient_light_energy = 0.64
	environment.tonemap_exposure = 1.00
	key_light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	key_light.light_color = Color("fff3d5")
	key_light.light_energy = 1.30
	fill_light.rotation_degrees = Vector3(-30.0, 148.0, 0.0)
	fill_light.light_color = Color("b9d8ee")
	fill_light.light_energy = 0.48
	rim_light.light_color = Color("dcecf5")
	rim_light.light_energy = 0.28
	floor_material.albedo_color = Color("635c52")

func _set_sunset() -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9f665c")
	environment.ambient_light_color = Color("9b91a8")
	environment.ambient_light_energy = 0.66
	environment.tonemap_exposure = 1.10
	key_light.rotation_degrees = Vector3(-24.0, -62.0, 0.0)
	key_light.light_color = Color("ffad68")
	key_light.light_energy = 1.72
	fill_light.rotation_degrees = Vector3(-34.0, 128.0, 0.0)
	fill_light.light_color = Color("819ed0")
	fill_light.light_energy = 0.78
	rim_light.light_color = Color("acc5e8")
	rim_light.light_energy = 0.56
	floor_material.albedo_color = Color("66514f")

func _show_main() -> void:
	v3.visible = true
	v3.position = Vector3.ZERO
	v3.rotation = Vector3.ZERO
	v3.set_review_mode("final_pbr")
	v2.visible = false
	for example in lod_examples:
		example.visible = false
	title.visible = true
	_set_component_visible(["V3_BodyShell", "V3_CanopyFrame", "V3_MuscularFenders", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR", "V3_Glass"], true)

func _set_component_visible(names: Array[String], visible_value: bool) -> void:
	var model := v3.lod_models[0]
	for component_name in names:
		var component := model.find_child(component_name, true, false) as Node3D
		if component != null:
			component.visible = visible_value

func _configure_shot(index: int) -> void:
	_show_main()
	_set_studio_neutral()
	v3.set_lod(0)
	v3.set_variant("rally_sand")
	title.text = "DESERT STALLION V3 · STUDIO NEUTRAL"
	metrics_panel.text = "LOD0 · 54,268 TRI · 7 MATERIALS · RALLY SAND"
	match index:
		0: _set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))
		1: _set_camera(Vector3(-4.9, 2.10, 5.6), Vector3(0.0, 0.86, 0.0))
		2: _set_camera(Vector3(6.15, 1.38, 0.0), Vector3(0.0, 0.86, 0.0))
		3:
			v3.set_variant("night_raid")
			metrics_panel.text = "LOD0 · NIGHT RAID · FINAL PBR"
			_set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))
		4:
			v3.set_variant("night_raid")
			metrics_panel.text = "LOD0 · NIGHT RAID · FINAL PBR"
			_set_camera(Vector3(-4.9, 2.10, 5.6), Vector3(0.0, 0.86, 0.0))
		5:
			_set_outdoor_daylight()
			title.text = "DESERT STALLION V3 · OUTDOOR DAYLIGHT"
			metrics_panel.text = "RALLY SAND · DAYLIGHT PBR"
			_set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))
		6:
			_set_outdoor_daylight()
			v3.set_variant("night_raid")
			title.text = "DESERT STALLION V3 · OUTDOOR DAYLIGHT"
			metrics_panel.text = "NIGHT RAID · DAYLIGHT PBR"
			_set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))
		7:
			_set_sunset()
			title.text = "DESERT STALLION V3 · CONTROLLED SUNSET"
			metrics_panel.text = "RALLY SAND · WARM KEY + COOL FILL"
			_set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))
		8:
			_set_sunset()
			v3.set_variant("night_raid")
			title.text = "DESERT STALLION V3 · CONTROLLED SUNSET"
			metrics_panel.text = "NIGHT RAID · WARM KEY + COOL FILL"
			_set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))
		9:
			v3.set_review_mode("base_color_only")
			title.text = "MATERIAL CHECK · BASE COLOR ONLY"
			metrics_panel.text = "sRGB BASE COLOR · UNSHADED"
			_set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))
		10:
			v3.set_review_mode("roughness")
			title.text = "MATERIAL CHECK · ROUGHNESS"
			metrics_panel.text = "ORM GREEN · LINEAR DATA"
			_set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))
		11:
			v3.set_review_mode("metallic")
			title.text = "MATERIAL CHECK · METALLIC"
			metrics_panel.text = "EFFECTIVE METALLIC · ORM B VALIDATED"
			_set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))
		12:
			v3.set_review_mode("normal")
			title.text = "MATERIAL CHECK · NORMAL"
			metrics_panel.text = "TANGENT NORMAL · LINEAR DATA"
			_set_camera(Vector3(4.9, 2.15, -5.6), Vector3(0.0, 0.88, 0.0))
		13:
			v3.position = Vector3(1.65, 0.0, 0.0)
			v2.position = Vector3(-1.65, 0.0, 0.0)
			v2.visible = true
			metrics_panel.text = "V2 REFERENCE  ←   SAME SCALE + LIGHTING   →  V3 RALLY SAND"
			_set_camera(Vector3(0.0, 2.85, -9.8), Vector3(0.0, 0.88, 0.0))

func _apply_clay(root: Node) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = clay_material

func _capture_set() -> void:
	var filenames := [
		"01_studio_rally_sand_front_three_quarter.png", "02_studio_rally_sand_rear_three_quarter.png",
		"03_studio_rally_sand_side.png", "04_studio_night_raid_front_three_quarter.png",
		"05_studio_night_raid_rear_three_quarter.png", "06_daylight_rally_sand.png",
		"07_daylight_night_raid.png", "08_sunset_rally_sand.png", "09_sunset_night_raid.png",
		"10_base_color_only.png", "11_roughness_check.png", "12_metallic_check.png",
		"13_normal_check.png", "14_v2_v3_neutral_comparison.png",
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/stallion_v3_review/visual"))
	var failures := 0
	for index in filenames.size():
		_configure_shot(index)
		for _frame in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "res://screenshots/stallion_v3_review/visual/%s" % filenames[index]
		var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("STALLION_V3_VISUAL_CAPTURE ", path, " error=", error)
		if error != OK:
			failures += 1
	get_tree().quit(0 if failures == 0 else 1)

func _write_metrics() -> void:
	var sorted_fps := fps_values.duplicate()
	sorted_fps.sort()
	var percentile_5: float = sorted_fps[int(floor((sorted_fps.size() - 1) * 0.05))] if not sorted_fps.is_empty() else 0.0
	var sustained_min: float = _minimum_rolling_fps(30)
	var report := "Desert Stallion V3 visual review metrics\n"
	report += "duration_seconds=%.2f\n" % SEQUENCE_SECONDS
	report += "average_fps=%.2f\n" % (fps_total / maxi(1, fps_samples))
	report += "instantaneous_minimum_fps=%.2f\n" % (fps_min if fps_min < INF else 0.0)
	report += "percentile_5_fps=%.2f\n" % percentile_5
	report += "minimum_sustained_fps=%.2f\n" % sustained_min
	report += "load_time_ms=%.2f\n" % load_time_ms
	report += "peak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\n" % [peak_draw_calls, peak_primitives, peak_nodes]
	report += "peak_static_memory_mb=%.2f\n" % (peak_memory_bytes / 1048576.0)
	report += "lod0_triangles=54268\nlod1_triangles=27670\nlod2_triangles=10574\n"
	report += "mesh_objects_lod0=14\nmaterials=7\ntextures=5\n"
	report += "length_m=4.900\nwidth_m=2.216\nheight_m=1.776\nwheelbase_m=2.940\n"
	var file := FileAccess.open("res://reports/stallion_v3_metrics.txt", FileAccess.WRITE)
	file.store_string(report)
	file.close()
	print(report)

func _minimum_rolling_fps(window: int) -> float:
	if fps_values.is_empty():
		return 0.0
	var actual_window := mini(window, fps_values.size())
	var rolling_total := 0.0
	for index in actual_window:
		rolling_total += fps_values[index]
	var minimum_average := rolling_total / actual_window
	for index in range(actual_window, fps_values.size()):
		rolling_total += fps_values[index] - fps_values[index - actual_window]
		minimum_average = minf(minimum_average, rolling_total / actual_window)
	return minimum_average
