extends SceneTree

var failures:Array[String]=[]

func _initialize()->void:_run.call_deferred()

func _run()->void:
	print("SEAM_TEST_START")
	var stage:=Node3D.new();root.add_child(stage);var marker:=Node3D.new();stage.add_child(marker)
	var road:=RoadManager.new();road.stage_mode=true;stage.add_child(road);road.setup(marker);await physics_frame
	for obstacle in get_nodes_in_group("obstacle"):obstacle.queue_free()
	await physics_frame
	await _test_geometry(road)
	await _test_crossings(road,stage)
	if failures.is_empty():print("SEAM_TEST_RESULT PASS")
	else:
		for failure in failures:printerr("SEAM_TEST_FAIL ",failure)
		print("SEAM_TEST_RESULT FAIL count=",failures.size())
	stage.queue_free();for _i in 6:await process_frame
	quit(0 if failures.is_empty() else 1)

func _test_geometry(road:RoadManager)->void:
	var space:=root.get_world_3d().direct_space_state
	for joint in range(road.segments.size()-1):
		var a:=road.segments[joint];var b:=road.segments[joint+1]
		var end_a:=a.to_global(Vector3(0,0,-BalanceData.SEGMENT_LENGTH*.5));var start_b:=b.to_global(Vector3(0,0,BalanceData.SEGMENT_LENGTH*.5))
		_assert(end_a.distance_to(start_b)<.015,"joint %d endpoints gap %.4f"%[joint,end_a.distance_to(start_b)])
		for lane:float in [-5.0,0.0,5.0]:
			for sample in [a.to_global(Vector3(lane,0,-BalanceData.SEGMENT_LENGTH*.5+.12)),b.to_global(Vector3(lane,0,BalanceData.SEGMENT_LENGTH*.5-.12))]:
				var query:=PhysicsRayQueryParameters3D.create(sample+Vector3.UP*3,sample+Vector3.DOWN*3,1);var hit:=space.intersect_ray(query)
				_assert(not hit.is_empty(),"joint %d lane %.1f missing floor"%[joint,lane])
				if not hit.is_empty():_assert(hit.collider is StaticBody3D and hit.collider.get_node_or_null("ContinuousDriveSurface")!=null,"joint %d unexpected collider %s"%[joint,str(hit.collider.name)])
	print("SEAM_GEOMETRY joints=",road.segments.size()-1," lanes=3 endpoint_continuity=true")

func _test_crossings(road:RoadManager,stage:Node3D)->void:
	var representative:Array[int]=[]
	for joint_index in range(road.segments.size()-1):representative.append(joint_index)
	for vehicle_index in 2:
		for speed:float in [8.0,20.0,38.0]:
			for lane:float in [-5.0,0.0,5.0]:
				for joint in representative:
					var a:=road.segments[joint];var b:=road.segments[joint+1];var probe:=CharacterBody3D.new();probe.up_direction=Vector3.UP;probe.floor_snap_length=.85;probe.safe_margin=.06;probe.floor_stop_on_slope=false;probe.floor_constant_speed=true;probe.collision_layer=2;probe.collision_mask=1
					var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2.5,1.25,4.7);shape.shape=box;shape.position.y=.7;probe.add_child(shape);stage.add_child(probe);probe.global_transform=Transform3D(a.global_transform.basis,a.to_global(Vector3(lane,.08,-BalanceData.SEGMENT_LENGTH*.5+7)))
					var initial_speed:=speed;var min_speed:=speed;var max_vertical:=0.0;var reached:=false
					for _frame in 100:
						var tangent:=road.curve_direction_near(probe.global_position);probe.velocity=tangent*speed+Vector3.DOWN*2;probe.move_and_slide();min_speed=minf(min_speed,Vector3(probe.velocity.x,0,probe.velocity.z).length());max_vertical=maxf(max_vertical,absf(probe.velocity.y));await physics_frame
						if b.to_local(probe.global_position).z<BalanceData.SEGMENT_LENGTH*.5-4:reached=true;break
					_assert(reached,"car%d joint%d lane%.0f speed%.0f stuck"%[vehicle_index,joint,lane,initial_speed]);_assert(min_speed>initial_speed*.72,"car%d joint%d abnormal speed retention %.2f"%[vehicle_index,joint,min_speed/initial_speed]);_assert(max_vertical<6.0,"car%d joint%d vertical impulse %.2f"%[vehicle_index,joint,max_vertical])
					probe.queue_free();await physics_frame
	print("SEAM_CROSSINGS cars=2 speeds=3 lanes=3 joints=8 total=144")

func _assert(condition:bool,message:String)->void:
	if not condition:failures.append(message)
