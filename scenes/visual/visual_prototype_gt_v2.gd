extends Node3D

func _ready() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8191a2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c8d8")
	environment.ambient_light_energy = .68
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -42, 0)
	sun.light_color = Color("ffe5c5")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(28, 28); ground.mesh = plane
	var material := StandardMaterial3D.new(); material.albedo_color = Color("434b54"); material.roughness = .82; ground.material_override = material
	add_child(ground)
	var vehicle: Node3D = load("res://assets/models/vehicles/bavarian_gt_r_v2.glb").instantiate() as Node3D
	vehicle.name = "BavarianGTRV2ReviewOnly"
	vehicle.rotation.y = PI
	add_child(vehicle)
	var camera := Camera3D.new(); camera.current = true; camera.fov = 48; camera.position = Vector3(5.8, 3.0, 6.4); add_child(camera); camera.look_at(Vector3(0, .68, 0), Vector3.UP)
	print("GT_V2_PROTOTYPE_READY meshes=", vehicle.find_children("*", "MeshInstance3D", true, false).size())
	if "--verify-gt-v2-scene" in OS.get_cmdline_user_args(): get_tree().quit()
