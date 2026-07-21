class_name VehicleFactory
extends RefCounted

static var use_blender_stallion_v2: bool = true
static var use_blender_gt_v2: bool = true
static var use_stallion_v3_visual_pilot: bool = true
const STALLION_V3_VISUAL_PILOT_PATH := "res://scenes/visual/production/StallionV3PlayableVisual.tscn"
const STALLION_V2_PATH := "res://assets/models/vehicles/desert_stallion_65_v2.glb"
const STALLION_V2_MODEL_OFFSET := Vector3(0.0, -0.10, 0.0)
const GT_V2_PATH := "res://assets/models/vehicles/bavarian_gt_r_v2.glb"
const GT_V2_MODEL_OFFSET := Vector3(0.0, -0.08, 0.0)

static func material(color: Color, metallic: float = 0.0, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.42
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 2.2
	return mat

static func box_part(parent: Node3D, name_: String, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation = rot
	node.material_override = mat
	parent.add_child(node)
	return node

static func prism_part(parent:Node3D,name_:String,size:Vector3,pos:Vector3,mat:Material,rot:Vector3=Vector3.ZERO)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=name_;var mesh:=PrismMesh.new();mesh.size=size;node.mesh=mesh;node.position=pos;node.rotation=rot;node.material_override=mat;parent.add_child(node);return node

static func create_vehicle(index: int, with_collision: bool = false) -> Node3D:
	if index == 0 and use_stallion_v3_visual_pilot:
		var stallion_v3 := _create_stallion_v3_visual_pilot()
		if stallion_v3 != null:
			if with_collision: _add_stable_collision(stallion_v3)
			return stallion_v3
		push_warning("Desert Stallion V3 visual pilot non disponibile: provo Stallion V2")
	if index == 0 and use_blender_stallion_v2:
		var blender_vehicle := _create_blender_stallion_v2()
		if blender_vehicle != null:
			if with_collision: _add_stable_collision(blender_vehicle)
			return blender_vehicle
		push_warning("Desert Stallion V2 non disponibile: uso fallback procedurale")
	if index == 1 and use_blender_gt_v2:
		var blender_gt := _create_blender_gt_v2()
		if blender_gt != null:
			if with_collision: _add_stable_collision(blender_gt)
			return blender_gt
		push_warning("Bavarian GT-R V2 non disponibile: uso fallback procedurale")
	return _create_procedural_vehicle(index, with_collision)

static func _create_stallion_v3_visual_pilot() -> Node3D:
	if not ResourceLoader.exists(STALLION_V3_VISUAL_PILOT_PATH): return null
	var packed := load(STALLION_V3_VISUAL_PILOT_PATH) as PackedScene
	if packed == null: return null
	var visual := packed.instantiate() as StallionV3PlayableVisual
	if visual == null: return null
	visual.initialize_runtime_visual()
	return visual

static func _create_blender_stallion_v2() -> Node3D:
	if not ResourceLoader.exists(STALLION_V2_PATH): return null
	var packed := load(STALLION_V2_PATH) as PackedScene
	if packed == null: return null
	var model := packed.instantiate() as Node3D
	if model == null: return null
	var root := Node3D.new()
	root.name = "DesertStallion65"
	root.set_meta("blender_stallion_v2", true)
	root.set_meta("visual_model_path", STALLION_V2_PATH)
	model.name = "BlenderStallionV2"
	model.position = STALLION_V2_MODEL_OFFSET
	model.rotation.y = PI
	root.add_child(model)
	_swap_wheel_names_for_model_rotation(model)
	_prepare_wheel_pivot(model, "Wheel_FL", Vector3(-0.88, 0.47, -1.41), true)
	_prepare_wheel_pivot(model, "Wheel_FR", Vector3(0.88, 0.47, -1.41), true)
	_prepare_wheel_pivot(model, "Wheel_RL", Vector3(-0.88, 0.47, 1.41), false)
	_prepare_wheel_pivot(model, "Wheel_RR", Vector3(0.88, 0.47, 1.41), false)
	return root

static func _create_blender_gt_v2() -> Node3D:
	if not ResourceLoader.exists(GT_V2_PATH): return null
	var packed := load(GT_V2_PATH) as PackedScene
	if packed == null: return null
	var model := packed.instantiate() as Node3D
	if model == null: return null
	var root := Node3D.new()
	root.name = "BavarianGTR"
	root.set_meta("blender_gt_v2", true)
	root.set_meta("visual_model_path", GT_V2_PATH)
	model.name = "BlenderGTV2"
	model.position = GT_V2_MODEL_OFFSET
	model.rotation.y = PI
	root.add_child(model)
	_swap_wheel_names_for_model_rotation(model)
	_prepare_wheel_pivot(model, "Wheel_FL", Vector3(-0.90, 0.43, -1.43), true)
	_prepare_wheel_pivot(model, "Wheel_FR", Vector3(0.90, 0.43, -1.43), true)
	_prepare_wheel_pivot(model, "Wheel_RL", Vector3(-0.91, 0.43, 1.43), false)
	_prepare_wheel_pivot(model, "Wheel_RR", Vector3(0.91, 0.43, 1.43), false)
	return root

static func _swap_wheel_names_for_model_rotation(model: Node3D) -> void:
	var wheel_pairs:Array[Array]=[["Wheel_FL", "Wheel_FR"], ["Wheel_RL", "Wheel_RR"]]
	for pair:Array in wheel_pairs:
		var left := model.find_child(pair[0], true, false)
		var right := model.find_child(pair[1], true, false)
		if left == null or right == null: continue
		left.name = pair[0] + "_Swap"
		right.name = pair[0]
		left.name = pair[1]

static func _prepare_wheel_pivot(model: Node3D, wheel_name: String, desired_center: Vector3, front: bool) -> void:
	var wheel := model.find_child(wheel_name, true, false) as Node3D
	if wheel == null: return
	# The Blender empty is at model origin. Move it to the wheel center and
	# compensate direct children so steering/spin occur around the axle.
	var source_center := Vector3(-desired_center.x, desired_center.y, -desired_center.z)
	wheel.position = source_center
	for child in wheel.get_children():
		if child is Node3D: (child as Node3D).position -= source_center
	wheel.set_meta("vehicle_wheel", true)
	wheel.set_meta("front_wheel", front)
	wheel.set_meta("desired_center", desired_center)

static func _add_stable_collision(root: Node3D) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.5, 1.25, 4.7)
	shape.shape = box
	shape.position.y = 0.9
	root.add_child(shape)

static func _create_procedural_vehicle(index: int, with_collision: bool = false) -> Node3D:
	var data := VehicleData.get_vehicle(index)
	var root := Node3D.new()
	root.name = str(data.name).replace(" ", "")
	var body_mat := material(data.color, 0.45)
	var accent_mat := material(data.accent, 0.25)
	var glass_mat := material(Color(0.05, 0.12, 0.16, 0.88), 0.6)
	var rubber := material(Color("101114"))
	var light_mat := material(Color("fff2b0"), 0.1, Color("ffd86b"))
	var rear_mat := material(Color("7a1114"), 0.1, Color("e32930"))
	box_part(root, "LowerBody", Vector3(2.65, 0.48, 5.0), Vector3(0, 0.72, 0), body_mat)
	box_part(root, "Hood", Vector3(2.42, 0.26, 1.75), Vector3(0, 1.04, -1.35), body_mat, Vector3(-0.05, 0, 0))
	prism_part(root,"SculptedHood",Vector3(2.25,.34,1.55),Vector3(0,1.13,-1.45),body_mat,Vector3(0,PI/2,0))
	box_part(root, "Cabin", Vector3(1.9, 0.68, 1.9), Vector3(0, 1.34, 0.3), body_mat)
	box_part(root, "Windshield", Vector3(1.74, 0.55, 0.08), Vector3(0, 1.48, -0.68), glass_mat, Vector3(-0.28, 0, 0))
	box_part(root, "RearGlass", Vector3(1.72, 0.5, 0.08), Vector3(0, 1.45, 1.28), glass_mat, Vector3(0.3, 0, 0))
	for x:float in [-.72,.72]: box_part(root,"RollBar",Vector3(.09,.95,.09),Vector3(x,1.43,.35),accent_mat,Vector3(0,0,x*.35))
	box_part(root,"RollBarTop",Vector3(1.55,.09,.09),Vector3(0,1.82,.35),accent_mat)
	box_part(root, "FrontBumper", Vector3(2.75, 0.22, 0.25), Vector3(0, 0.55, -2.55), accent_mat)
	box_part(root, "RearBumper", Vector3(2.7, 0.22, 0.25), Vector3(0, 0.55, 2.55), accent_mat)
	box_part(root, "LeftHeadlight", Vector3(0.5, 0.22, 0.08), Vector3(-0.75, 0.87, -2.54), light_mat)
	box_part(root, "RightHeadlight", Vector3(0.5, 0.22, 0.08), Vector3(0.75, 0.87, -2.54), light_mat)
	box_part(root, "LeftTail", Vector3(0.48, 0.2, 0.08), Vector3(-0.72, 0.86, 2.54), rear_mat)
	box_part(root, "RightTail", Vector3(0.48, 0.2, 0.08), Vector3(0.72, 0.86, 2.54), rear_mat)
	if index == 0:
		box_part(root, "HoodScoop", Vector3(0.72, 0.28, 0.72), Vector3(0, 1.28, -1.35), accent_mat)
		box_part(root, "LeftExhaust", Vector3(0.12, 0.12, 1.2), Vector3(-1.4, 0.43, 0.7), accent_mat)
		box_part(root, "RightExhaust", Vector3(0.12, 0.12, 1.2), Vector3(1.4, 0.43, 0.7), accent_mat)
		box_part(root,"RearLip",Vector3(2.25,.16,.45),Vector3(0,1.08,2.3),accent_mat,Vector3(-.12,0,0))
	else:
		box_part(root, "Splitter", Vector3(2.9, 0.10, 0.65), Vector3(0, 0.34, -2.52), accent_mat)
		box_part(root, "Wing", Vector3(2.7, 0.13, 0.55), Vector3(0, 1.65, 2.05), accent_mat)
		box_part(root, "WingLeft", Vector3(0.12, 0.75, 0.25), Vector3(-0.85, 1.28, 2.05), accent_mat)
		box_part(root, "WingRight", Vector3(0.12, 0.75, 0.25), Vector3(0.85, 1.28, 2.05), accent_mat)
		prism_part(root,"RearDiffuser",Vector3(2.4,.32,.75),Vector3(0,.42,2.25),accent_mat,Vector3(0,-PI/2,0))
	for x:float in [-.78,-.26,.26,.78]:
		var lamp:=MeshInstance3D.new();var lamp_mesh:=CylinderMesh.new();lamp_mesh.height=.16;lamp_mesh.top_radius=.22;lamp_mesh.bottom_radius=.22;lamp.mesh=lamp_mesh;lamp.rotation.x=PI/2;lamp.position=Vector3(x,.82,-2.7);lamp.material_override=light_mat;root.add_child(lamp)
	for x:float in [-1.25,1.25]:
		box_part(root,"MudFlapFront",Vector3(.38,.55,.08),Vector3(x,.28,-1.15),accent_mat,Vector3(.12,0,0));box_part(root,"MudFlapRear",Vector3(.42,.62,.08),Vector3(x,.25,2.05),accent_mat,Vector3(-.12,0,0))
	for x: float in [-1.38, 1.38]:
		for z: float in [-1.55, 1.55]:
			var pivot := Node3D.new()
			pivot.name = "WheelFront" if z < 0 else "WheelRear"
			pivot.position = Vector3(x, 0.55, z)
			root.add_child(pivot)
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.height = 0.42
			cylinder.top_radius = 0.48
			cylinder.bottom_radius = 0.48
			wheel.mesh = cylinder
			wheel.rotation.z = PI / 2.0
			wheel.material_override = rubber
			pivot.add_child(wheel)
			var rim:=MeshInstance3D.new(); var rim_mesh:=CylinderMesh.new(); rim_mesh.height=.44; rim_mesh.top_radius=.25; rim_mesh.bottom_radius=.25; rim.mesh=rim_mesh; rim.rotation.z=PI/2; rim.material_override=material(Color("b8bcc3"),.8); pivot.add_child(rim)
	if with_collision:
		_add_stable_collision(root)
	return root
