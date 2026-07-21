extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_setup_input()
	_run.call_deferred()

func _setup_input() -> void:
	var bindings := {"accelerate":KEY_W,"brake":KEY_S,"steer_left":KEY_A,"steer_right":KEY_D,"handbrake":KEY_SPACE,"reset_vehicle":KEY_R}
	for action: String in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event:=InputEventKey.new(); event.physical_keycode=bindings[action]; InputMap.action_add_event(action,event)

func _run() -> void:
	print("TEST_START Desert Velocity runtime verification")
	await _test_vehicle(0)
	await _test_vehicle(1)
	await _test_curves_and_spawns()
	await _test_audio()
	await _test_surfaces_and_stage()
	await _test_special_stage_flow()
	if failures.is_empty():
		print("TEST_RESULT PASS")
		await _clean_shutdown(0)
	else:
		for failure in failures: printerr("TEST_FAIL ",failure)
		print("TEST_RESULT FAIL count=",failures.size())
		await _clean_shutdown(1)

func _clean_shutdown(code:int)->void:
	Input.action_release("accelerate");Input.action_release("brake");Input.action_release("steer_left");Input.action_release("steer_right");Input.action_release("handbrake")
	for child in root.get_children():child.queue_free()
	for _i in 8:await process_frame
	quit(code)

func _test_vehicle(index: int) -> void:
	var stage:=Node3D.new(); root.add_child(stage)
	var vehicle:=VehicleController.new(); vehicle.setup(index); vehicle.position=Vector3(0,.1,8); stage.add_child(vehicle)
	var road:=RoadManager.new(); stage.add_child(road); road.setup(vehicle); vehicle.road_manager=road
	_assert(vehicle.dust_emitters.size()==4,"four per-wheel dust emitters missing")
	Input.action_press("accelerate")
	await _frames(150)
	var cruise_speed:=vehicle.speed
	Input.action_press("steer_right"); await _frames(38); Input.action_release("steer_right")
	Input.action_press("handbrake"); await _frames(28); Input.action_release("handbrake")
	await _frames(55)
	var post_drift_slip:=vehicle.slip_angle
	vehicle.global_position=road.segments[0].to_global(Vector3(BalanceData.ROAD_HALF_WIDTH+4.0,.1,-8))
	vehicle.rotation.y=road.segments[0].rotation.y
	vehicle.velocity=Vector3(8,0,-maxf(vehicle.speed,18)); vehicle.speed=maxf(vehicle.speed,18)
	await _frames(8)
	var lateral_before:=absf(vehicle.lateral_speed)
	Input.action_release("accelerate"); await _frames(25); Input.action_press("accelerate")
	var entered_road:=false
	for _step in 360:
		var toward:=road.direction_to_center(vehicle.global_position)
		var steer_side:=toward.dot(vehicle.global_transform.basis.x)
		Input.action_release("steer_left"); Input.action_release("steer_right")
		Input.action_press("steer_right" if steer_side>0 else "steer_left")
		await physics_frame
		if _step%90==0: print("RECOVERY index=",index," step=",_step," local_x=",snappedf(road.road_local_position(vehicle.global_position).x,.01)," pos=",vehicle.global_position," yaw=",snappedf(vehicle.rotation.y,.01)," toward_dot=",snappedf((-vehicle.global_transform.basis.z).dot(toward),.01)," speed=",snappedf(vehicle.speed,.01))
		if road.is_on_road(vehicle.global_position): entered_road=true; break
	Input.action_release("steer_left"); Input.action_release("steer_right"); await _frames(90)
	var lateral_after:=absf(vehicle.lateral_speed)
	var local_after:=road.road_local_position(vehicle.global_position)
	_assert(cruise_speed>15.0,"vehicle %d failed acceleration"%index)
	_assert(post_drift_slip<float(vehicle.stats.max_slip)+.03,"vehicle %d exceeded slip cap"%index)
	_assert(entered_road,"vehicle %d did not physically cross the road edge x=%.2f"%[index,local_after.x])
	_assert(lateral_after<1.5,"vehicle %d retained excessive lateral velocity after re-entry %.2f"%[index,lateral_after])
	_assert(absf(local_after.x)<BalanceData.ROAD_HALF_WIDTH,"vehicle %d crossed the road and exited opposite side x=%.2f"%[index,local_after.x])
	vehicle.speed=0.0; vehicle.velocity=Vector3.ZERO; Input.action_release("accelerate"); Input.action_press("brake"); Input.action_press("steer_right"); await _frames(90); Input.action_release("brake"); Input.action_release("steer_right")
	_assert(vehicle.speed < -2.0,"vehicle %d reverse failed offroad"%index)
	vehicle.global_position=road.segments[0].to_global(Vector3(BalanceData.HARD_WORLD_LIMIT+2.0,.1,0)); await _frames(3)
	_assert(absf(road.road_local_position(vehicle.global_position).x)<1.0,"vehicle %d hard boundary reset failed"%index)
	print("TEST_VEHICLE index=",index," cruise=",snappedf(cruise_speed,.01)," lateral=",snappedf(lateral_before,.01),"->",snappedf(lateral_after,.01)," road_x=",snappedf(local_after.x,.01)," slip=",snappedf(post_drift_slip,.001))
	Input.action_release("accelerate"); Input.action_release("brake"); Input.action_release("handbrake")
	stage.queue_free(); await process_frame

func _test_curves_and_spawns() -> void:
	var stage:=Node3D.new(); root.add_child(stage)
	var marker:=Node3D.new(); stage.add_child(marker)
	var road:=RoadManager.new(); stage.add_child(road); road.setup(marker)
	var positive_delta:=false; var negative_delta:=false
	for i in range(1,road.segments.size()):
		var delta_angle:float=wrapf(road.segments[i].rotation.y-road.segments[i-1].rotation.y,-PI,PI)
		positive_delta = positive_delta or delta_angle>.005
		negative_delta = negative_delta or delta_angle<-.005
	for planned_delta in road.curve_pattern:
		positive_delta=positive_delta or planned_delta>.005
		negative_delta=negative_delta or planned_delta<-.005
	_assert(positive_delta,"missing gradual left curve")
	_assert(negative_delta,"missing gradual right curve")
	var longest_turn:=0.0; var running_turn:=0.0
	for delta_heading in road.curve_pattern:
		if delta_heading>0: running_turn+=delta_heading; longest_turn=maxf(longest_turn,running_turn)
		else: running_turn=0.0
	_assert(longest_turn>PI*.9,"wide U curve does not accumulate enough heading")
	var transformed_spawn:=false
	for segment in road.segments:
		if absf(segment.rotation.y)>.01:
			for child in segment.get_children():
				if child.is_in_group("spawned") and child.global_position.distance_to(segment.global_position)<BalanceData.SEGMENT_LENGTH:
					transformed_spawn=true
	_assert(transformed_spawn,"no spawn followed a curved segment transform")
	print("TEST_CURVES left=",positive_delta," right=",negative_delta," transformed_spawn=",transformed_spawn)
	stage.queue_free(); await process_frame

func _test_audio() -> void:
	var audio:=AudioManager.new(); root.add_child(audio); await process_frame;audio.start_game_audio();await process_frame
	_assert(audio.engine_player.playing,"engine loop is not playing")
	_assert(audio.music_player.playing,"music loop is not playing")
	_assert((audio.engine_player.stream as AudioStreamWAV).data.size()>1000,"engine audio has no PCM data")
	audio.play("collision"); await process_frame
	_assert(audio.sfx_player.playing,"gameplay SFX is not audible/playing")
	print("TEST_AUDIO engine=",audio.engine_player.playing," music=",audio.music_player.playing," pcm=",(audio.engine_player.stream as AudioStreamWAV).data.size())
	audio.queue_free(); await process_frame

func _test_surfaces_and_stage() -> void:
	var stage:=Node3D.new(); root.add_child(stage); var marker:=Node3D.new(); stage.add_child(marker); var road:=RoadManager.new(); stage.add_child(road); road.setup(marker)
	var found_asphalt:=false;var found_gravel:=false
	for segment in road.segments:
		found_asphalt=found_asphalt or str(segment.get_meta("surface"))=="ASPHALT";found_gravel=found_gravel or str(segment.get_meta("surface"))=="GRAVEL"
	_assert(found_asphalt and found_gravel,"stage does not contain asphalt and gravel")
	var deep_point:=road.segments[0].to_global(Vector3(BalanceData.SOFT_WORLD_LIMIT+3,.1,0));_assert(road.surface_at(deep_point)=="DEEP_SAND","deep sand detection failed")
	var note:=road.pacenote_near(road.segments[2].global_position);_assert(note.has("text") and note.has("distance"),"pacenote is not linked to route geometry")
	var profile:=HandcraftedStage.route();var has_climb:=false;var has_descent:=false
	for section in profile:has_climb=has_climb or float(section.pitch)>0;has_descent=has_descent or float(section.pitch)<0
	_assert(profile.size()==64 and has_climb and has_descent,"handcrafted stage vertical profile incomplete")
	print("TEST_RALLY surfaces=",found_asphalt,"/",found_gravel," deep=",road.surface_at(deep_point)," note=",note.text)
	stage.queue_free();await process_frame

func _test_special_stage_flow() -> void:
	var manager:Node=load("res://scripts/game_manager.gd").new();root.add_child(manager);await process_frame
	manager.run_mode="STAGE";manager.start_game();await _frames(3)
	_assert(manager.countdown>0 and not manager.player.controls_enabled,"special stage did not start from countdown/standstill")
	manager.countdown=0.0;manager.player.controls_enabled=true;manager.stage_checkpoint=0
	var route_segment:Node3D=manager.road.segments[0];route_segment.set_meta("route_index",manager.stage_checkpoint_segments[0]);manager.player.global_position=route_segment.global_position+Vector3.UP*.1;manager._update_game(.016)
	_assert(manager.stage_checkpoint==1,"geometric checkpoint did not advance")
	route_segment.set_meta("route_index",63);manager.player.global_position=route_segment.global_position+Vector3.UP*.1;manager.stage_checkpoint=6;manager._update_game(.016);await process_frame
	_assert(manager.screen==manager.Screen.GAME_OVER,"finish did not open stage results")
	print("TEST_STAGE countdown=true checkpoint=true finish=true")
	manager.queue_free();await process_frame

func _frames(count: int) -> void:
	for _i in count: await physics_frame

func _assert(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
