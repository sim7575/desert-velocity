extends SceneTree

var failures:Array[String]=[]

func _initialize()->void:_run.call_deferred()

func _run()->void:
	print("GT_V2_GAMEPLAY_INTEGRATION_START")
	if not InputMap.has_action("camera_toggle"):InputMap.add_action("camera_toggle")
	var controller:=VehicleController.new();controller.setup(1);root.add_child(controller)
	check(bool(controller.visual.get_meta("blender_gt_v2",false)),"GT V2 factory path not active")
	check(str(controller.visual.get_meta("visual_model_path",""))==VehicleFactory.GT_V2_PATH,"wrong GT V2 GLB path")
	check(controller.stats==VehicleData.get_vehicle(1),"GT dynamic statistics changed")
	var model:=controller.visual.find_child("BlenderGTV2",true,false) as Node3D
	check(model!=null and is_equal_approx(absf(model.rotation.y),PI),"GT V2 forward orientation invalid")
	check(model!=null and model.position.is_equal_approx(VehicleFactory.GT_V2_MODEL_OFFSET),"GT V2 visual offset invalid")
	var meshes:=controller.visual.find_children("*","MeshInstance3D",true,false)
	check(meshes.size()>=24 and meshes.size()<=32,"GT V2 mesh hierarchy invalid: "+str(meshes.size()))
	for name:String in ["Wheel_FL","Wheel_FR","Wheel_RL","Wheel_RR"]:
		var wheel:=controller.visual.find_child(name,true,false) as Node3D
		check(wheel!=null and bool(wheel.get_meta("vehicle_wheel",false)),"GT wheel pivot missing "+name)
		if wheel!=null:check(wheel.get_child_count()>0,"GT wheel geometry missing "+name)
	check(controller.visual_wheels.size()==4,"GT wheel cache incomplete")
	var collisions:=controller.find_children("*","CollisionShape3D",true,false)
	var collision:=collisions[0] as CollisionShape3D if not collisions.is_empty() else null
	check(collision!=null and collision.shape is BoxShape3D,"stable GT collision missing")
	if collision!=null and collision.shape is BoxShape3D:check((collision.shape as BoxShape3D).size.is_equal_approx(Vector3(2.5,1.25,4.7)),"GT collision dimensions changed")
	controller.speed=18.0;controller.steering=.8;controller._update_wheels(.1)
	for wheel in controller.visual_wheels:
		check(absf(wheel.rotation.x)>.01,"GT wheel spin missing "+str(wheel.name))
		if bool(wheel.get_meta("front_wheel",false)):check(absf(wheel.rotation.y)>.01,"GT front steering missing "+str(wheel.name))
	var camera:=CameraController.new();camera.target=controller;camera.view_mode=2;root.add_child(camera)
	for _i in 18:camera._process(.1)
	var hood_local:=controller.to_local(camera.global_position)
	check(hood_local.z<-.9 and hood_local.y>1.0,"GT hood camera invalid "+str(hood_local))
	camera.view_mode=3
	for _i in 18:camera._process(.1)
	var bumper_local:=controller.to_local(camera.global_position)
	check(bumper_local.z< -2.25 and bumper_local.y>.5,"GT bumper camera invalid "+str(bumper_local))
	var old_gt:=VehicleFactory.use_blender_gt_v2;VehicleFactory.use_blender_gt_v2=false
	var fallback:=VehicleFactory.create_vehicle(1,false);root.add_child(fallback)
	check(not bool(fallback.get_meta("blender_gt_v2",false)) and fallback.find_child("LowerBody",true,false)!=null,"GT procedural fallback did not activate")
	VehicleFactory.use_blender_gt_v2=old_gt
	var previous_v3:=VehicleFactory.use_stallion_v3_visual_pilot;VehicleFactory.use_stallion_v3_visual_pilot=false
	var stallion:=VehicleFactory.create_vehicle(0,false);root.add_child(stallion)
	check(bool(stallion.get_meta("blender_stallion_v2",false)),"Stallion V2 changed by GT integration")
	VehicleFactory.use_stallion_v3_visual_pilot=previous_v3
	check(VehicleFactory.use_stallion_v3_visual_pilot==previous_v3,"V3 pilot flag was not restored")
	var garage_car:=VehicleFactory.create_vehicle(1,false);garage_car.position=Vector3(2.8,.15,0);garage_car.rotation.y=-.35;root.add_child(garage_car)
	check(bool(garage_car.get_meta("blender_gt_v2",false)),"GT V2 missing from garage factory path")
	garage_car.queue_free()
	var endurance:=VehicleController.new();endurance.setup(1);root.add_child(endurance)
	check(bool(endurance.visual.get_meta("blender_gt_v2",false)),"GT V2 endurance setup invalid")
	var stage:=VehicleController.new();stage.setup(1);root.add_child(stage);stage.reset_to_safe(false)
	check(bool(stage.visual.get_meta("blender_gt_v2",false)),"GT V2 special stage/reset setup invalid")
	endurance.queue_free();stage.queue_free()
	controller.queue_free();camera.queue_free();fallback.queue_free();stallion.queue_free()
	for _i in 8:await process_frame
	if failures.is_empty():print("GT_V2_GAMEPLAY_INTEGRATION_RESULT PASS")
	else:
		for failure in failures:printerr("GT_V2_INTEGRATION_FAIL ",failure)
		print("GT_V2_GAMEPLAY_INTEGRATION_RESULT FAIL count=",failures.size())
	quit(0 if failures.is_empty() else 1)

func check(value:bool,message:String)->void:
	if not value:failures.append(message)
