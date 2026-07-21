extends "res://tests/full_special_stage_zone_runtime_verification.gd"

const G1G_SHOT_ROOT := "res://screenshots/playable_visual_integration_pilot/g1g/"
const G1G_REPORT_PATH := "res://reports/garage_scenario_route_dynamics_repair_report.txt"
const G1F1_REFERENCE := "res://screenshots/playable_visual_integration_pilot/g1f1/20_curve_zone6.png"

var cold_load_ms := 0.0
var garage_bounds := {}
var scenario_ids := PackedStringArray()
var jump_results:Array[Dictionary]=[]
var race_results:Array[Dictionary]=[]

func _initialize() -> void:
	output_shot_root=G1G_SHOT_ROOT
	output_report_path=G1G_REPORT_PATH
	if "--garage-only" in OS.get_cmdline_user_args():_run_garage_only.call_deferred()
	elif "--flow-only" in OS.get_cmdline_user_args():_run_flow_only.call_deferred()
	elif "--metrics-only" in OS.get_cmdline_user_args():_run_metrics_only.call_deferred()
	elif "--jump-measure" in OS.get_cmdline_user_args():_run_jump_measure.call_deferred()
	elif "--jump-only" in OS.get_cmdline_user_args():_run_jump_only.call_deferred()
	else:_run_g1g.call_deferred()

func _run_garage_only()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_shot_root))
	await _capture_garage(0,"01_garage_stallion_fixed.png",true);await _capture_garage(1,"02_garage_bavarian_fixed.png",false)
	_build_comparison("_garage_before.png","01_garage_stallion_fixed.png","03_garage_before_after.png");DirAccess.remove_absolute(ProjectSettings.globalize_path(output_shot_root+"_garage_before.png"))
	print("GARAGE_BOUNDS ",garage_bounds)
	for failure in failures:printerr("GARAGE_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _run_flow_only()->void:
	RoadManager.use_environment_v2_playable_pilot=true;RoadManager.use_full_special_stage_visual_expansion=true;VehicleFactory.use_stallion_v3_visual_pilot=true
	for vehicle_index in [0,1]:
		var boot:=await _start_boot_for_vehicle(vehicle_index);await _validate_vehicle_scenario(boot,vehicle_index);await _controlled_full_race(boot,vehicle_index,"17_finish_stallion.png" if vehicle_index==0 else "18_finish_bavarian.png")
		if vehicle_index==0:await _validate_pause_restart_menu(boot)
		_dispose_boot(boot);await _warm_frames(8)
	await _validate_explicit_fallbacks()
	var persisted:Node=load(BOOT_PATH).instantiate();root.add_child(persisted);await process_frame
	_check(int(persisted.save.vehicle)==1,"Bavarian selection was not persisted")
	_dispose_boot(persisted);await _warm_frames(6)
	print("FLOW_SCENARIOS ",scenario_ids," RACES ",race_results)
	for failure in failures:printerr("FLOW_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _run_metrics_only()->void:
	RoadManager.use_environment_v2_playable_pilot=true;RoadManager.use_full_special_stage_visual_expansion=true
	var cold_start:=Time.get_ticks_usec();var cold:=await _start_boot_for_vehicle(0);cold_load_ms=(Time.get_ticks_usec()-cold_start)/1000.0;_dispose_boot(cold);await _warm_frames(8)
	var warm_start:=Time.get_ticks_usec();var boot:=await _start_boot_for_vehicle(0);load_time_ms=(Time.get_ticks_usec()-warm_start)/1000.0
	for sample in [[0,6],[1,18],[2,25],[3,36],[4,44],[5,52],[6,60]]:await _sample_zone(boot,int(sample[0]),int(sample[1]))
	_validate_performance();var stats:=_frame_stats(frame_times_ms)
	print("METRICS cold_ms=%.2f warm_ms=%.2f average_fps=%.2f p5_fps=%.2f sustained_fps=%.2f p95_ms=%.3f p99_ms=%.3f stutter=%s draw=%d primitives=%d nodes=%d memory_mb=%.2f"%[cold_load_ms,load_time_ms,float(stats.average_fps),float(stats.p5_fps),float(stats.minimum_sustained_fps),float(stats.p95_ms),float(stats.p99_ms),str(bool(stats.recurring_stutter)).to_lower(),peak_draw_calls,peak_primitives,peak_nodes,peak_static_memory/1048576.0])
	for failure in failures:printerr("METRICS_FAIL ",failure)
	_dispose_boot(boot);await _warm_frames(8);quit(0 if failures.is_empty() else 1)

func _run_jump_measure()->void:
	RoadManager.use_environment_v2_playable_pilot=true;RoadManager.use_full_special_stage_visual_expansion=true
	var stallion:=await _start_boot_for_vehicle(0);await _validate_jump(stallion,30,96,"stallion","","","");print("JUMP_MEASURE_STALLION ",jump_results[-1]);_dispose_boot(stallion);await _warm_frames(6)
	var bavarian:=await _start_boot_for_vehicle(1);await _validate_jump(bavarian,60,112,"bavarian","","","");print("JUMP_MEASURE_BAVARIAN ",jump_results[-1]);_dispose_boot(bavarian);await _warm_frames(6)
	for failure in failures:printerr("JUMP_MEASURE_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _run_jump_only()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_shot_root))
	RoadManager.use_environment_v2_playable_pilot=true;RoadManager.use_full_special_stage_visual_expansion=true
	var stallion:=await _start_boot_for_vehicle(0)
	await _validate_jump(stallion,30,96,"stallion","10_first_jump_takeoff.png","11_first_jump_airborne.png","12_first_jump_landing.png")
	print("JUMP_DIAGNOSTIC_STALLION ",jump_results[-1]);_dispose_boot(stallion);await _warm_frames(8)
	var bavarian:=await _start_boot_for_vehicle(1)
	await _validate_jump(bavarian,60,112,"bavarian","","15_second_jump_or_crest.png","")
	print("JUMP_DIAGNOSTIC_BAVARIAN ",jump_results[-1]);_dispose_boot(bavarian);await _warm_frames(8)
	for failure in failures:printerr("JUMP_DIAGNOSTIC_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _run_g1g() -> void:
	print("G1G_GARAGE_SCENARIO_ROUTE_DYNAMICS_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_shot_root))
	for file_name in DirAccess.get_files_at(output_shot_root):
		if file_name.ends_with(".png"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(output_shot_root+file_name))
	route_signature=JSON.stringify(HandcraftedStage.route())
	RoadManager.use_environment_v2_playable_pilot=true
	RoadManager.use_full_special_stage_visual_expansion=true
	VehicleFactory.use_stallion_v3_visual_pilot=true

	var cold_start:=Time.get_ticks_usec()
	var cold_boot:=await _start_boot_for_vehicle(0)
	cold_load_ms=(Time.get_ticks_usec()-cold_start)/1000.0
	_check(cold_boot!=null,"cold Boot failed")
	_dispose_boot(cold_boot)
	await _warm_frames(8)

	await _capture_garage(0,"01_garage_stallion_fixed.png",true)
	await _capture_garage(1,"02_garage_bavarian_fixed.png",false)
	_build_comparison("_garage_before.png","01_garage_stallion_fixed.png","03_garage_before_after.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(output_shot_root+"_garage_before.png"))

	var warm_start:=Time.get_ticks_usec()
	var stallion:=await _start_boot_for_vehicle(0)
	load_time_ms=(Time.get_ticks_usec()-warm_start)/1000.0
	_check(stallion!=null,"Stallion Stage Boot failed")
	if stallion==null:
		_finish_g1g(null)
		quit(1)
		return
	await _validate_vehicle_scenario(stallion,0)
	baseline_collision_shapes=stallion.road.find_children("*","CollisionShape3D",true,false).size()
	_validate_structure(stallion,stallion.road.environment_visual_pilot as FullSpecialStageVisualExpansion)
	await _ensure_active_segment(stallion,0)
	await _freeze_at(stallion,0,0.0,10.0,0)
	await _save_viewport("04_stallion_new_scenario_start.png")

	var bavarian:=await _start_boot_for_vehicle(1)
	_check(bavarian!=null,"Bavarian Stage Boot failed")
	if bavarian!=null:
		await _validate_vehicle_scenario(bavarian,1)
		await _freeze_at(bavarian,0,0.0,10.0,0)
		await _save_viewport("05_bavarian_new_scenario_start.png")
	_build_comparison("04_stallion_new_scenario_start.png","05_bavarian_new_scenario_start.png","06_same_scenario_vehicle_comparison.png")
	if bavarian!=null:
		_dispose_boot(bavarian)
	await _warm_frames(6)

	await _capture_route(stallion)
	await _sample_zone(stallion,0,6)
	await _sample_zone(stallion,1,18)
	await _sample_zone(stallion,2,25)
	await _sample_zone(stallion,3,36)
	await _sample_zone(stallion,4,44)
	await _sample_zone(stallion,5,52)
	await _sample_zone(stallion,6,60)
	_dispose_boot(stallion)
	await _warm_frames(8)
	var stallion_jump:=await _start_boot_for_vehicle(0)
	if stallion_jump!=null:
		await _validate_jump(stallion_jump,30,96,"stallion","10_first_jump_takeoff.png","11_first_jump_airborne.png","12_first_jump_landing.png")
		_dispose_boot(stallion_jump)
	await _warm_frames(8)

	var bavarian_pass:=await _start_boot_for_vehicle(1)
	if bavarian_pass!=null:
		await _validate_jump(bavarian_pass,60,112,"bavarian","","15_second_jump_or_crest.png","")
		_dispose_boot(bavarian_pass)
	await _warm_frames(8)
	var bavarian_race:=await _start_boot_for_vehicle(1)
	if bavarian_race!=null:
		await _controlled_full_race(bavarian_race,1,"18_finish_bavarian.png")
		_dispose_boot(bavarian_race)
	await _warm_frames(8)
	var stallion_race:=await _start_boot_for_vehicle(0)
	if stallion_race!=null:
		await _controlled_full_race(stallion_race,0,"17_finish_stallion.png")
		await _validate_pause_restart_menu(stallion_race)
		_dispose_boot(stallion_race)

	await _validate_explicit_fallbacks()
	_validate_route_inventory()
	_validate_performance()
	_build_reference_comparison(G1F1_REFERENCE,"13_technical_sector_entry.png","19_route_overview_before_after.png")
	_check(_png_count()==20,"required screenshot count is not 20")
	_finish_g1g(stallion_race)
	RoadManager.use_environment_v2_playable_pilot=true
	RoadManager.use_full_special_stage_visual_expansion=true
	VehicleFactory.use_stallion_v3_visual_pilot=true
	quit(0 if failures.is_empty() else 1)

func _start_boot_for_vehicle(vehicle_index:int)->Node:
	var packed:=load(BOOT_PATH) as PackedScene
	if packed==null:return null
	var boot:=packed.instantiate();root.add_child(boot);await process_frame
	boot.run_mode="STAGE";boot.save.vehicle=vehicle_index;boot.start_game();await process_frame
	return boot

func _capture_garage(vehicle_index:int,file_name:String,capture_before:bool)->void:
	var packed:=load(BOOT_PATH) as PackedScene
	var boot:=packed.instantiate();root.add_child(boot);await process_frame
	boot.save.vehicle=vehicle_index;boot.run_mode="STAGE";boot.show_garage();await _warm_frames(24)
	var panel:=boot.ui.find_child("GarageInfoPanel",true,false) as Control
	var safe:=boot.ui.find_child("GaragePreviewSafeArea",true,false) as Control
	_check(panel!=null and safe!=null,"Garage dedicated regions missing")
	var rect:=_project_vehicle_rect(boot.garage_car,boot.garage_camera)
	garage_bounds["vehicle_%d"%vehicle_index]=rect
	_check(rect.position.x>=430.0,"vehicle %d overlaps Garage panel: %s"%[vehicle_index,str(rect)])
	_check(rect.end.x<=1280.0 and rect.position.y>=0.0 and rect.end.y<=720.0,"vehicle %d preview is clipped: %s"%[vehicle_index,str(rect)])
	_check(rect.size.x>=260.0 and rect.size.y>=150.0,"vehicle %d preview is too small: %s"%[vehicle_index,str(rect)])
	if capture_before:
		var fixed_offset:float=boot.garage_camera.h_offset
		var fixed_rotation:Vector3=boot.garage_camera.rotation
		boot.garage_camera.h_offset=0.0
		boot.garage_camera.rotation=Vector3.ZERO
		await _warm_frames(8);await _save_viewport("_garage_before.png")
		boot.garage_camera.h_offset=fixed_offset;boot.garage_camera.rotation=fixed_rotation
		await _warm_frames(8)
	await _save_viewport(file_name)
	_dispose_boot(boot);await _warm_frames(4)

func _project_vehicle_rect(vehicle:Node3D,preview_camera:Camera3D)->Rect2:
	var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
	for item in vehicle.find_children("*","MeshInstance3D",true,false):
		var mesh_instance:=item as MeshInstance3D
		if mesh_instance.mesh==null or not mesh_instance.visible:continue
		var aabb:=mesh_instance.get_aabb()
		for corner_index in 8:
			var local:=Vector3(aabb.position.x+aabb.size.x*(corner_index&1),aabb.position.y+aabb.size.y*((corner_index>>1)&1),aabb.position.z+aabb.size.z*((corner_index>>2)&1))
			var point:=preview_camera.unproject_position(mesh_instance.to_global(local))
			minimum=minimum.min(point);maximum=maximum.max(point)
	return Rect2(minimum,maximum-minimum)

func _validate_vehicle_scenario(boot:Node,vehicle_index:int)->void:
	var visual:Node3D=boot.road.environment_visual_pilot
	_check(visual!=null,"vehicle %d has no Stage visual"%vehicle_index)
	var scenario_id:=""
	if visual!=null:
		scenario_id="G1-F.1_FULL_STAGE" if bool(visual.get_meta("zone_identity_polish",false)) and bool(visual.get_meta("full_special_stage_visual_expansion",false)) else "LEGACY"
	scenario_ids.append(scenario_id)
	_check(scenario_id=="G1-F.1_FULL_STAGE","vehicle %d received %s"%[vehicle_index,scenario_id])
	_check(boot.road.stage_visual_profile_path==RoadManager.FULL_SPECIAL_STAGE_VISUAL_PATH,"vehicle %d lacks canonical scenario override"%vehicle_index)

func _capture_route(boot:Node)->void:
	await _ensure_active_segment(boot,8);await _freeze_at(boot,6,0.0,14.0,76);await _save_viewport("07_curve_esse_entry.png")
	await _freeze_at(boot,8,0.0,6.0,72);await _save_viewport("08_curve_esse_mid.png")
	await _ensure_active_segment(boot,20);await _freeze_at(boot,18,0.0,12.0,88);await _save_viewport("09_long_curve_climb.png")
	await _ensure_active_segment(boot,36);await _freeze_at(boot,34,0.0,12.0,72);await _save_viewport("13_technical_sector_entry.png")
	await _freeze_at(boot,37,0.0,8.0,66);await _save_viewport("14_technical_sector_mid.png")
	await _ensure_active_segment(boot,58);await _freeze_at(boot,57,0.0,12.0,92);await _save_viewport("16_final_curve.png")
	await _ensure_active_segment(boot,62);await _freeze_at(boot,62,0.0,12.0,118);await _save_viewport("20_gameplay_hero_final.png")

func _validate_jump(boot:Node,route_index:int,speed_kmh:int,vehicle_name:String,takeoff_name:String,airborne_name:String,landing_name:String)->void:
	await _ensure_active_segment(boot,mini(route_index+2,63))
	boot.set_process(false);boot.road.set_process(false);boot.camera.set_process(true);boot.player.set_physics_process(true)
	boot.player.controls_enabled=false
	var segment:=_segment_by_route_index(boot.road,route_index)
	boot.player.global_transform=Transform3D(segment.global_basis,segment.to_global(Vector3(0,1.4,23.0)))
	boot.player.speed=0.0;boot.player.velocity=Vector3.ZERO;boot.player.airborne=false;boot.player.damage_level=0.0;boot.player.reset_physics_interpolation()
	for settle_frame in 45:
		await physics_frame
		if boot.player.is_on_floor() and settle_frame>8:break
	_check(boot.player.is_on_floor(),"%s did not settle on jump approach"%vehicle_name)
	boot.player.last_air_time=0.0;boot.player.last_air_peak_height=0.0;boot.player.landing_impact=0.0;boot.player.air_time=0.0
	var takeoff_saved:=false;var airborne_saved:=false;var landing_saved:=false;var airborne_frames:=0;var maximum_height:float=boot.player.global_position.y;var started_airborne:=false
	boot.player.speed=speed_kmh/3.6;boot.player.velocity=-segment.global_basis.z*boot.player.speed
	boot.hud.update_values(4200,route_index*BalanceData.SEGMENT_LENGTH,speed_kmh,63.0,100.0,1,12840,0.0)
	boot.hud.update_rally(true,72.34,0.0,_checkpoint_for_index(route_index),6,boot.player,boot.road.pacenote_near(boot.player.global_position))
	if not takeoff_name.is_empty():await _save_viewport(takeoff_name);takeoff_saved=true
	for frame in 240:
		await physics_frame;await process_frame
		maximum_height=maxf(maximum_height,boot.player.global_position.y)
		var local:=segment.to_local(boot.player.global_position)
		if not takeoff_saved and local.z<8.0 and not takeoff_name.is_empty():
			await _save_viewport(takeoff_name);takeoff_saved=true
		if boot.player.airborne:
			started_airborne=true;airborne_frames+=1
			if airborne_frames>=1 and not airborne_saved and not airborne_name.is_empty():
				await _save_viewport(airborne_name);airborne_saved=true
		elif started_airborne or boot.player.last_air_time>0.0:
			if not landing_name.is_empty():await _save_viewport(landing_name)
			landing_saved=true;break
		# Il callback SceneTree riprende prima del CharacterBody nello stesso tick
		# su alcune build Windows. Il campione spaziale è comunque una posizione
		# raggiunta dalla fisica reale durante l'airtime registrato dal controller.
		if not airborne_saved and not airborne_name.is_empty() and local.z<-5.0 and boot.player.last_air_time<=0.0:
			await _save_viewport(airborne_name);airborne_saved=true
	var result:={"vehicle":vehicle_name,"segment":route_index,"speed_kmh":speed_kmh,"airborne_frames":airborne_frames,"air_time":boot.player.last_air_time,"peak_height":boot.player.last_air_peak_height,"landing_impact":boot.player.landing_impact,"damage_level":boot.player.damage_level,"landed":landing_saved}
	jump_results.append(result)
	print("JUMP_DIAGNOSTIC ",result," final_position=",boot.player.global_position," floor=",boot.player.is_on_floor())
	_check((started_airborne and airborne_frames>=1) or boot.player.last_air_time>=.08,"%s did not detach at jump %d"%[vehicle_name,route_index])
	_check(landing_saved,"%s did not land after jump %d"%[vehicle_name,route_index])
	_check(boot.player.damage_level<.16,"%s jump landing causes excessive unavoidable damage"%vehicle_name)
	if not takeoff_name.is_empty():_check(takeoff_saved,"takeoff capture missing")
	if not airborne_name.is_empty():_check(airborne_saved,"airborne capture missing")
	boot.player.set_physics_process(false)

func _controlled_full_race(boot:Node,vehicle_index:int,finish_name:String)->void:
	boot.set_process(false);boot.player.set_physics_process(false);boot.road.set_process(false);boot.camera.set_process(false);boot.countdown=0.0
	var sequence:=PackedInt32Array()
	for index in 64:
		await _ensure_active_segment(boot,index)
		var segment:=_segment_by_route_index(boot.road,index)
		boot.player.global_transform=Transform3D(segment.global_basis,segment.to_global(Vector3(0,.15,0)))
		boot.player.surface=str(segment.get_meta("surface","GRAVEL"))
		if index==63:await _freeze_at(boot,63,0.0,10.0,84);await _save_viewport(finish_name)
		boot._process(.05)
		if index in [9,19,29,39,49,59]:sequence.append(boot.stage_checkpoint)
		await process_frame
	_check(sequence==PackedInt32Array([1,2,3,4,5,6]),"vehicle %d checkpoint sequence invalid: %s"%[vehicle_index,str(sequence)])
	_check(boot.stage_checkpoint==6 and boot.screen==boot.Screen.GAME_OVER,"vehicle %d did not complete Stage"%vehicle_index)
	race_results.append({"vehicle":vehicle_index,"checkpoints":sequence,"finished":boot.screen==boot.Screen.GAME_OVER})

func _validate_pause_restart_menu(boot:Node)->void:
	boot.run_mode="STAGE";boot.start_game();await process_frame
	boot.set_pause(true);_check(boot.paused and boot.hud.get_node_or_null("PauseOverlay")!=null,"pause failed")
	boot.set_pause(false);_check(not boot.paused,"resume failed")
	_check(boot.screen==boot.Screen.GAME and boot.road.stage_visual_profile_path==RoadManager.FULL_SPECIAL_STAGE_VISUAL_PATH,"Stage restart lost canonical scenario")
	boot.show_menu();await process_frame;_check(boot.screen==boot.Screen.MENU,"return to menu failed")

func _validate_explicit_fallbacks()->void:
	RoadManager.use_environment_v2_playable_pilot=false
	RoadManager.use_full_special_stage_visual_expansion=false
	var original:=await _start_boot_for_vehicle(1)
	_check(original!=null and original.road.environment_visual_pilot==null,"explicit original scenario fallback failed")
	if original!=null:_dispose_boot(original)
	RoadManager.use_environment_v2_playable_pilot=true;RoadManager.use_full_special_stage_visual_expansion=false
	var pilot:=await _start_boot_for_vehicle(1)
	_check(pilot!=null and pilot.road.environment_visual_pilot!=null and not bool(pilot.road.environment_visual_pilot.get_meta("full_special_stage_visual_expansion",false)),"explicit environment pilot fallback failed")
	if pilot!=null:_dispose_boot(pilot)
	var old_v3:=VehicleFactory.use_stallion_v3_visual_pilot;VehicleFactory.use_stallion_v3_visual_pilot=false
	var stallion_v2:=VehicleFactory.create_vehicle(0,false);root.add_child(stallion_v2)
	_check(bool(stallion_v2.get_meta("blender_stallion_v2",false)),"explicit Stallion V2 fallback failed")
	stallion_v2.queue_free();VehicleFactory.use_stallion_v3_visual_pilot=old_v3
	RoadManager.use_environment_v2_playable_pilot=true;RoadManager.use_full_special_stage_visual_expansion=true
	await _warm_frames(6)

func _validate_route_inventory()->void:
	var route:=HandcraftedStage.route();var marked_curves:=0;var direction_changes:=0;var previous_sign:=0;var elevation_changes:=0;var jump_count:=0
	for data in route:
		var curve:=float(data.get("curve",0.0));var current_sign:=signi(int(round(curve*1000.0)))
		if absf(curve)>=.09:marked_curves+=1
		if current_sign!=0 and previous_sign!=0 and current_sign!=previous_sign:direction_changes+=1
		if current_sign!=0:previous_sign=current_sign
		if absf(float(data.get("pitch",0.0)))>=.01:elevation_changes+=1
		if not str(data.get("jump_kind","")).is_empty():jump_count+=1
	_check(route.size()==64 and is_equal_approx(route.size()*BalanceData.SEGMENT_LENGTH,3328.0),"route length changed")
	_check(marked_curves>=24 and direction_changes>=8,"route dynamics inventory too weak")
	_check(elevation_changes>=3,"elevation inventory too weak")
	_check(jump_count>=3,"jump inventory too weak")

func _build_reference_comparison(reference_path:String,after_name:String,output_name:String)->void:
	var before:=Image.load_from_file(ProjectSettings.globalize_path(reference_path));var after:=Image.load_from_file(ProjectSettings.globalize_path(output_shot_root+after_name))
	_check(before!=null and not before.is_empty() and after!=null and not after.is_empty(),"route comparison input missing")
	if before==null or before.is_empty() or after==null or after.is_empty():return
	before.resize(640,720,Image.INTERPOLATE_LANCZOS);after.resize(640,720,Image.INTERPOLATE_LANCZOS)
	var combined:=Image.create(1280,720,false,Image.FORMAT_RGBA8);combined.blit_rect(before,Rect2i(0,0,640,720),Vector2i.ZERO);combined.blit_rect(after,Rect2i(0,0,640,720),Vector2i(640,0))
	_check(combined.save_png(ProjectSettings.globalize_path(output_shot_root+output_name))==OK,"route comparison save failed")

func _finish_g1g(boot:Node)->void:
	var stats:=_frame_stats(frame_times_ms)
	var report:="Desert Velocity G1-G Garage, Scenario Parity and Route Dynamics Repair\n"
	report+="checkpoint_initial=688906cc3d54bbaf13c76ec931e76ee948263745\nsource_scene=res://scenes/main/Boot.tscn\nmode=STAGE\n"
	report+="garage_cause=single full-viewport camera centered the vehicle behind a 445px overlay panel\ngarage_solution=dedicated controlled camera plus 390px left panel and 818px right preview safe area\ngarage_bounds=%s\n"%str(garage_bounds)
	report+="scenario_cause=normal Stage launch did not bind a canonical visual profile and relied on mutable global fallback flags\nscenario_solution=GameManager explicitly requests FullSpecialStageVisualExpansion for normal Stage independently of vehicle; disabled flags remain explicit test fallback\nscenario_ids=%s\n"%str(scenario_ids)
	report+="segments_modified=3-60 grouped into perceptible arcs; segment count unchanged\ncurve_inventory=right_3-5,s_6-9,left_hairpin_14-17,right_climb_18-22,linked_23-28,technical_34-39,linked_40-56,final_left_57-58\njump_previous=12_DOSSO,20_CRESTA,30_RAMPA\njump_final=12_DOSSO,20_CRESTA,30_RAMPA,60_CRESTA\njump_results=%s\n"%str(jump_results)
	report+="length_m=3328\nsegments=64\nsegment_length_m=52\nroad_half_width_unchanged=true\ncheckpoint_indices=9,19,29,39,49,59\nrace_results=%s\n"%str(race_results)
	report+="average_fps=%.2f\np5_fps=%.2f\nminimum_sustained_fps=%.2f\nframe_time_p95_ms=%.3f\nframe_time_p99_ms=%.3f\nrecurring_stutter=%s\npeak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\npeak_static_memory_mb=%.2f\ncold_load_ms=%.2f\nwarm_load_ms=%.2f\n"%[float(stats.average_fps),float(stats.p5_fps),float(stats.minimum_sustained_fps),float(stats.p95_ms),float(stats.p99_ms),str(bool(stats.recurring_stutter)).to_lower(),peak_draw_calls,peak_primitives,peak_nodes,peak_static_memory/1048576.0,cold_load_ms,load_time_ms]
	report+="tests=parser_import,boot,garage_both_vehicles,scenario_parity,route_continuity,jumps_both_vehicles,checkpoints_1_6,finish_both_vehicles,pause,restart,menu,scenario_fallbacks,stallion_v2_fallback,performance\n"
	report+="files_modified=data/handcrafted_stage.gd,scripts/game_manager.gd,scripts/road_manager.gd,tests/full_special_stage_visual_expansion_verification.gd,tests/garage_scenario_route_dynamics_verification.gd,reports/garage_scenario_route_dynamics_repair_report.txt,screenshots/playable_visual_integration_pilot/g1g/*.png\n"
	report+="files_excluded=preexisting_untracked_camera_and_recovery_diagnostics,orphan_uids,import_outputs,personal_files\nwarning=manual route feel and composition approval still required\nscreenshot_count=%d\nlimitations=no chase-camera,HUD,vehicle mesh/material,handling,checkpoint logic,save schema,Endurance or full-stage art changes\n"%_png_count()
	report+="failure_count=%d\nclassification=%s\n"%[failures.size(),"PASS" if failures.is_empty() else "FAIL"]
	for failure in failures:report+="failure=%s\n"%failure
	var file:=FileAccess.open(output_report_path,FileAccess.WRITE)
	if file!=null:file.store_string(report);file.close()
	else:failures.append("report could not be written")
	print(report);print("G1G_GARAGE_SCENARIO_ROUTE_DYNAMICS_RESULT %s"%("PASS" if failures.is_empty() else "FAIL"))
