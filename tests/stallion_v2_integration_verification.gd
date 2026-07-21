extends SceneTree

var failures:Array[String]=[]

func _initialize()->void:_run.call_deferred()

func _run()->void:
	print("STALLION_V2_INTEGRATION_START")
	if not InputMap.has_action("camera_toggle"):InputMap.add_action("camera_toggle")
	var previous_v3:=VehicleFactory.use_stallion_v3_visual_pilot
	VehicleFactory.use_stallion_v3_visual_pilot=false
	var visual:=VehicleFactory.create_vehicle(0,false)
	root.add_child(visual)
	check(bool(visual.get_meta("blender_stallion_v2",false)),"V2 factory path not active")
	check(str(visual.get_meta("visual_model_path",""))==VehicleFactory.STALLION_V2_PATH,"wrong GLB path")
	var meshes:=visual.find_children("*","MeshInstance3D",true,false)
	check(meshes.size()>=20 and meshes.size()<=30,"V2 optimized mesh hierarchy outside expected 20-30 range: "+str(meshes.size()))
	var material_count:=0
	for mesh_node in meshes:
		var mesh_instance:=mesh_node as MeshInstance3D
		if mesh_instance.mesh!=null:
			for surface in mesh_instance.mesh.get_surface_count():
				check(mesh_instance.mesh.surface_get_material(surface)!=null,"missing imported material on "+str(mesh_instance.name))
				material_count+=1
	check(material_count>=11,"imported material hierarchy incomplete")
	for texture_name:String in ["base_color","roughness","dirt","scratches","paint_variation"]:
		check(ResourceLoader.exists("res://assets/textures/vehicles/stallion_v2_%s.png"%texture_name),"missing 1024 texture "+texture_name)
	for name:String in ["Wheel_FL","Wheel_FR","Wheel_RL","Wheel_RR"]:
		var wheel:=visual.find_child(name,true,false) as Node3D
		check(wheel!=null,"missing wheel "+name)
		if wheel!=null:
			check(bool(wheel.get_meta("vehicle_wheel",false)),"wheel pivot not prepared "+name)
			check(wheel.get_child_count()>0,"wheel geometry missing "+name)
	var controller:=VehicleController.new();controller.setup(0);root.add_child(controller)
	check(controller.visual_wheels.size()==4,"controller wheel cache incomplete")
	check(controller.dust_emitters.size()==4,"per-wheel dust emitters changed")
	var collision_nodes:=controller.find_children("*","CollisionShape3D",true,false)
	var collision:=collision_nodes[0] as CollisionShape3D if not collision_nodes.is_empty() else null
	check(collision!=null and collision.shape is BoxShape3D,"stable simplified collision missing")
	if collision!=null and collision.shape is BoxShape3D:check((collision.shape as BoxShape3D).size.is_equal_approx(Vector3(2.5,1.25,4.7)),"collision dimensions changed")
	controller.speed=18.0;controller.steering=.8;controller._update_wheels(.1)
	for wheel in controller.visual_wheels:
		check(absf(wheel.rotation.x)>.01,"wheel spin missing "+str(wheel.name))
		if bool(wheel.get_meta("front_wheel",false)):check(absf(wheel.rotation.y)>.01,"front steering missing "+str(wheel.name))
	var model:=controller.visual.find_child("BlenderStallionV2",true,false) as Node3D
	check(model!=null and is_equal_approx(absf(model.rotation.y),PI),"model forward orientation is not -Z")
	check(model!=null and is_equal_approx(model.position.y,-.10),"model ground offset changed")
	var camera:=CameraController.new();camera.target=controller;camera.view_mode=2;root.add_child(camera)
	for _i in 18:camera._process(.1)
	var hood_local:=controller.to_local(camera.global_position)
	check(hood_local.z<-.9 and hood_local.y>1.0,"hood camera offset invalid "+str(hood_local))
	camera.view_mode=3
	for _i in 18:camera._process(.1)
	var bumper_local:=controller.to_local(camera.global_position)
	check(bumper_local.z< -2.35 and bumper_local.y>.5,"bumper camera offset invalid "+str(bumper_local))
	var previous:=VehicleFactory.use_blender_stallion_v2;VehicleFactory.use_blender_stallion_v2=false
	var fallback:=VehicleFactory.create_vehicle(0,false);root.add_child(fallback)
	check(not bool(fallback.get_meta("blender_stallion_v2",false)),"procedural fallback did not activate")
	check(fallback.find_child("LowerBody",true,false)!=null,"procedural fallback geometry missing")
	VehicleFactory.use_blender_stallion_v2=previous
	var gt:=VehicleFactory.create_vehicle(1,false);root.add_child(gt)
	check(not bool(gt.get_meta("blender_stallion_v2",false)) and bool(gt.get_meta("blender_gt_v2",false)),"GT V2 integration changed Stallion path")
	VehicleFactory.use_stallion_v3_visual_pilot=previous_v3
	check(VehicleFactory.use_stallion_v3_visual_pilot==previous_v3,"V3 pilot flag was not restored")
	visual.queue_free();controller.queue_free();camera.queue_free();fallback.queue_free();gt.queue_free()
	for _i in 8:await process_frame
	if failures.is_empty():print("STALLION_V2_INTEGRATION_RESULT PASS")
	else:
		for failure in failures:printerr("STALLION_V2_FAIL ",failure)
		print("STALLION_V2_INTEGRATION_RESULT FAIL count=",failures.size())
	quit(0 if failures.is_empty() else 1)

func check(value:bool,message:String)->void:
	if not value:failures.append(message)
