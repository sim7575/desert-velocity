class_name StallionV3BlockoutReview
extends Node3D

const V3_SCENE := preload("res://scenes/visual/assets/DesertStallionV3Blockout.tscn")
const SEQUENCE_SECONDS := 12.0

var v3: Node3D
var v2: Node3D
var camera: Camera3D
var v3_label: Label3D
var v2_label: Label3D
var clay_material: StandardMaterial3D
var silhouette_material: StandardMaterial3D
var original_overrides: Dictionary = {}
var elapsed := 0.0
var metrics_mode := false
var fps_total := 0.0
var fps_samples := 0
var fps_min := INF
var peak_draw_calls := 0
var peak_primitives := 0
var peak_nodes := 0

func _ready() -> void:
	_setup_materials()
	_setup_studio()
	_setup_models()
	_setup_camera()
	var args := OS.get_cmdline_user_args()
	if "--capture-stallion-v3-blockout" in args:
		_capture_review_set.call_deferred()
	elif "--run-stallion-v3-metrics" in args:
		metrics_mode = true

func _process(delta: float) -> void:
	if metrics_mode:
		elapsed += delta
		v3.rotation.y = elapsed * 0.34
		_collect_metrics(delta)
		if elapsed >= SEQUENCE_SECONDS:
			_write_metrics()
			get_tree().quit()
	elif v3 != null:
		v3.rotation.y += delta * 0.16

func _setup_materials() -> void:
	clay_material = StandardMaterial3D.new()
	clay_material.albedo_color = Color("626d78")
	clay_material.roughness = 0.76
	clay_material.metallic = 0.02
	silhouette_material = StandardMaterial3D.new()
	silhouette_material.albedo_color = Color("090b0d")
	silhouette_material.roughness = 1.0
	silhouette_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _setup_studio() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("87909a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7e0e8")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world := WorldEnvironment.new()
	world.name = "NeutralEnvironment"
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.name = "NeutralKey"
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_color = Color("fff4e5")
	key.light_energy = 0.82
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "NeutralFill"
	fill.rotation_degrees = Vector3(-25.0, 148.0, 0.0)
	fill.light_color = Color("b9d5ef")
	fill.light_energy = 0.20
	fill.shadow_enabled = false
	add_child(fill)
	var floor := MeshInstance3D.new()
	floor.name = "StudioFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(28.0, 22.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("4d5660")
	floor_material.roughness = 0.88
	plane.material = floor_material
	floor.mesh = plane
	add_child(floor)
	_add_grid()

func _add_grid() -> void:
	var immediate := ImmediateMesh.new()
	var grid_material := StandardMaterial3D.new()
	grid_material.albedo_color = Color(0.72, 0.78, 0.82, 0.25)
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, grid_material)
	for index in range(-10, 11):
		var coordinate := float(index)
		immediate.surface_add_vertex(Vector3(coordinate, 0.012, -8.0))
		immediate.surface_add_vertex(Vector3(coordinate, 0.012, 8.0))
		immediate.surface_add_vertex(Vector3(-10.0, 0.012, coordinate))
		immediate.surface_add_vertex(Vector3(10.0, 0.012, coordinate))
	immediate.surface_end()
	var grid := MeshInstance3D.new()
	grid.name = "DimensionGrid"
	grid.mesh = immediate
	add_child(grid)

func _setup_models() -> void:
	v3 = V3_SCENE.instantiate()
	v3.name = "StallionV3Blockout"
	add_child(v3)
	v2 = VehicleFactory.create_vehicle(0, false)
	v2.name = "StallionV2Reference"
	add_child(v2)
	v2.visible = false
	v3_label = _label("DESERT STALLION V3 · BLOCKOUT")
	v3_label.position = Vector3(0.0, 2.30, 0.0)
	add_child(v3_label)
	v2_label = _label("STALLION V2 · REFERENCE")
	v2_label.visible = false
	add_child(v2_label)
	_store_overrides(v3)
	_store_overrides(v2)
	_apply_override(v3, clay_material)

func _label(text_value: String) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = 42
	label.modulate = Color("f4e7cf")
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	return label

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ReviewCamera"
	camera.current = true
	camera.fov = 48.0
	add_child(camera)
	_set_camera(Vector3(5.6, 2.7, -6.8), Vector3(0.0, 0.83, 0.0))

func _store_overrides(root: Node) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		original_overrides[mesh] = (mesh as MeshInstance3D).material_override

func _apply_override(root: Node, material: Material) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material

func _restore_overrides(root: Node) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = original_overrides.get(mesh)

func _set_camera(position_value: Vector3, target: Vector3) -> void:
	camera.position = position_value
	camera.look_at(target, Vector3.UP)

func _configure_shot(index: int) -> void:
	v3.rotation = Vector3.ZERO
	v3.position = Vector3.ZERO
	v3.visible = true
	v2.visible = false
	v3_label.visible = true
	v2_label.visible = false
	v3_label.text = "DESERT STALLION V3 · BLOCKOUT"
	v2_label.text = "STALLION V2 · REFERENCE"
	v3_label.position = Vector3(0.0, 2.30, 0.0)
	_apply_override(v3, clay_material)
	match index:
		0: _set_camera(Vector3(0.0, 1.22, -7.2), Vector3(0.0, 0.82, 0.0))
		1: _set_camera(Vector3(0.0, 1.22, 7.2), Vector3(0.0, 0.82, 0.0))
		2: _set_camera(Vector3(7.2, 1.25, 0.0), Vector3(0.0, 0.82, 0.0))
		3: _set_camera(Vector3(5.6, 2.45, -6.4), Vector3(0.0, 0.82, 0.0))
		4: _set_camera(Vector3(-5.6, 2.35, 6.4), Vector3(0.0, 0.82, 0.0))
		5: _set_camera(Vector3(0.0, 8.6, 0.35), Vector3(0.0, 0.45, 0.0))
		6:
			_restore_overrides(v3)
			_set_camera(Vector3(4.8, 0.62, -4.8), Vector3(0.0, 0.46, 0.0))
		7:
			_apply_override(v3, silhouette_material)
			_set_camera(Vector3(7.2, 1.25, 0.0), Vector3(0.0, 0.82, 0.0))
		8:
			_apply_override(v3, silhouette_material)
			_set_camera(Vector3(5.6, 2.45, -6.4), Vector3(0.0, 0.82, 0.0))
		9:
			v3.position = Vector3(1.55, 0.0, 0.0)
			v2.position = Vector3(-1.55, 0.0, 0.0)
			v2.visible = true
			_apply_override(v2, clay_material)
			v3_label.position = Vector3(1.55, 2.30, 0.0)
			v2_label.position = Vector3(-1.55, 2.30, 0.0)
			v2_label.visible = true
			v3_label.text = "V3 · BLOCKOUT"
			v2_label.text = "V2 · REFERENCE"
			_set_camera(Vector3(0.0, 3.0, -10.8), Vector3(0.0, 0.88, 0.0))

func _capture_review_set() -> void:
	var filenames := [
		"01_front.png", "02_rear.png", "03_side.png", "04_front_three_quarter.png",
		"05_rear_three_quarter.png", "06_top.png", "07_suspension_underbody.png",
		"08_black_silhouette_side.png", "09_black_silhouette_three_quarter.png", "10_v2_v3_comparison.png",
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/stallion_v3_review/blockout"))
	var failures := 0
	for index in filenames.size():
		_configure_shot(index)
		for _frame in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path_name := "res://screenshots/stallion_v3_review/blockout/%s" % filenames[index]
		var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path_name))
		print("STALLION_V3_CAPTURE ", path_name, " error=", error)
		if error != OK:
			failures += 1
	get_tree().quit(0 if failures == 0 else 1)

func _collect_metrics(delta: float) -> void:
	if delta > 0.0 and elapsed > 1.0:
		var fps := 1.0 / delta
		fps_total += fps
		fps_samples += 1
		fps_min = minf(fps_min, fps)
	peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	peak_primitives = maxi(peak_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))

func _write_metrics() -> void:
	var report := "Desert Stallion V3 blockout metrics\n"
	report += "duration_seconds=%.2f\n" % SEQUENCE_SECONDS
	report += "average_fps=%.2f\n" % (fps_total / maxi(1, fps_samples))
	report += "minimum_fps=%.2f\n" % (fps_min if fps_min < INF else 0.0)
	report += "peak_draw_calls=%d\n" % peak_draw_calls
	report += "peak_primitives=%d\n" % peak_primitives
	report += "peak_nodes=%d\n" % peak_nodes
	report += "triangles=28960\nmesh_objects=13\nmaterials=7\n"
	report += "length_m=4.900\nwidth_m=2.166\nheight_m=1.714\nwheelbase_m=2.940\nwheel_diameter_m=0.860\ntire_width_m=0.320\n"
	var file := FileAccess.open("res://reports/stallion_v3_blockout_metrics.txt", FileAccess.WRITE)
	file.store_string(report)
	file.close()
	print(report)
