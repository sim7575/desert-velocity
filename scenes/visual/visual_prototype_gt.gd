extends Node3D

var camera: Camera3D
var vehicle: Node3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/gt_v1"))
	setup_world()
	vehicle = load("res://assets/models/vehicles/bavarian_gt_r_v1.glb").instantiate()
	vehicle.rotation.y = PI
	add_child(vehicle)
	await frames(4)
	await shot("gt_neutral_front", Vector3(5.7, 3.6, 6.2), Vector3(0, .65, 0))
	await shot("gt_neutral_rear", Vector3(-5.6, 3.1, -5.7), Vector3(0, .62, 0))
	var env := load("res://assets/models/environment/desert_prototype_environment_v2.glb").instantiate()
	env.position = Vector3(0, -.02, -2.0)
	add_child(env)
	await frames(4)
	await shot("gt_ambient_front", Vector3(6.6, 3.1, 7.2), Vector3(0, .62, 0))
	await shot("gt_ambient_wide", Vector3(-9.0, 5.0, 10.5), Vector3(0, .75, 0))
	print("GT_VISUAL_CAPTURE_OK")
	get_tree().quit()

func setup_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("d39a62")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa5b2")
	environment.ambient_light_energy = .72
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = Color("ffd19a")
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(35, 35); ground.mesh = plane
	var material := StandardMaterial3D.new(); material.albedo_color = Color("8a512c"); material.roughness = .92; ground.material_override = material
	add_child(ground)
	camera = Camera3D.new(); camera.fov = 48; add_child(camera)

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func shot(name: String, position_: Vector3, target: Vector3) -> void:
	camera.global_position = position_
	camera.look_at(target, Vector3.UP)
	await frames(2)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screenshots/gt_v1/%s.png" % name))
