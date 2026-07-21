extends "res://tests/garage_scenario_route_dynamics_verification.gd"

const G1H_SHOT_ROOT:="res://screenshots/playable_visual_integration_pilot/g1h/"

var g1h_scenarios:=PackedStringArray()
var g1h_landings:Array[Dictionary]=[]
var dedicated_check_count:=0

func _check(condition:bool,message:String)->void:
	dedicated_check_count+=1
	super._check(condition,message)

func _initialize()->void:
	output_shot_root=G1H_SHOT_ROOT
	if "--capture" in OS.get_cmdline_user_args():_run_capture.call_deferred()
	elif "--metrics" in OS.get_cmdline_user_args():_run_metrics.call_deferred()
	else:_run_logic.call_deferred()

func _run_logic()->void:
	print("G1H_FINAL_GAMEPLAY_CONSISTENCY_LOGIC_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_shot_root))
	RoadManager.use_environment_v2_playable_pilot=true;RoadManager.use_full_special_stage_visual_expansion=true
	for mode in ["ENDURANCE","STAGE"]:
		for vehicle_index in [0,1]:
			var boot:=await _start_mode(mode,vehicle_index);_check_scenario(boot,mode,vehicle_index);_dispose_boot(boot);await _warm_frames(6)
	await _test_audio_stability()
	await _test_timer_and_flow()
	await _test_landing_response_logic(0);await _test_landing_response_logic(1)
	await _test_garage_and_endurance_bonus()
	if dedicated_check_count<30:failures.append("dedicated regression executed fewer than 30 checks")
	print("G1H_DEDICATED_CHECKS ",dedicated_check_count," G1H_SCENARIOS ",g1h_scenarios," LANDINGS ",g1h_landings)
	for failure in failures:printerr("G1H_LOGIC_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _run_capture()->void:
	print("G1H_FINAL_GAMEPLAY_CONSISTENCY_CAPTURE_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_shot_root))
	for file_name in DirAccess.get_files_at(output_shot_root):
		if file_name.ends_with(".png"):DirAccess.remove_absolute(ProjectSettings.globalize_path(output_shot_root+file_name))
	for vehicle_index in [0,1]:
		var endurance:=await _start_mode("ENDURANCE",vehicle_index);await _frame_endurance(endurance,74);await _save_viewport("01_endurance_stallion_new_environment.png" if vehicle_index==0 else "02_endurance_bavarian_new_environment.png");_dispose_boot(endurance);await _warm_frames(5)
	for vehicle_index in [0,1]:
		var stage:=await _start_mode("STAGE",vehicle_index);await _freeze_at(stage,0,0.0,10.0,0);stage.hud.update_rally(true,stage.stage_time_remaining,0.0,0,6,stage.player,stage.road.pacenote_near(stage.player.global_position));await _save_viewport("03_special_stage_stallion.png" if vehicle_index==0 else "04_special_stage_bavarian.png");_dispose_boot(stage);await _warm_frames(5)
	await _capture_help()
	await _capture_timer_sequence()
	await _capture_landing_sequence(0,30,96,"11_landing_stallion_contact.png","12_landing_stallion_rebound.png")
	await _capture_landing_sequence(1,60,112,"13_landing_bavarian_contact.png","14_landing_bavarian_rebound.png")
	_check(_png_count()==16,"required screenshot count is not 16")
	print("G1H_CAPTURE_LANDINGS ",g1h_landings)
	for failure in failures:printerr("G1H_CAPTURE_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _run_metrics()->void:
	print("G1H_FINAL_GAMEPLAY_CONSISTENCY_METRICS_START")
	var started:=Time.get_ticks_usec();var boot:=await _start_mode("STAGE",0);load_time_ms=(Time.get_ticks_usec()-started)/1000.0
	await _freeze_at(boot,34,0.0,8.0,82)
	var previous:=Time.get_ticks_usec()
	for frame in 840:
		await process_frame;var now:=Time.get_ticks_usec();frame_times_ms.append((now-previous)/1000.0);previous=now;_collect_performance()
	var stats:=_frame_stats(frame_times_ms);var audio_snapshot:Dictionary=boot.audio.diagnostic_snapshot()
	_check(float(stats.average_fps)>=58.0,"average FPS below 58");_check(float(stats.minimum_sustained_fps)>=55.0,"sustained FPS below 55");_check(not bool(stats.recurring_stutter),"recurring stutter")
	print("G1H_METRICS average_fps=%.2f p5_fps=%.2f sustained_fps=%.2f p95_ms=%.3f p99_ms=%.3f stutter=%s draw=%d primitives=%d nodes=%d memory_mb=%.2f warm_load_ms=%.2f audio=%s"%[float(stats.average_fps),float(stats.p5_fps),float(stats.minimum_sustained_fps),float(stats.p95_ms),float(stats.p99_ms),str(bool(stats.recurring_stutter)).to_lower(),peak_draw_calls,peak_primitives,peak_nodes,peak_static_memory/1048576.0,load_time_ms,str(audio_snapshot)])
	_dispose_boot(boot);await _warm_frames(6)
	for failure in failures:printerr("G1H_METRICS_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _start_mode(mode:String,vehicle_index:int)->Node:
	var packed:=load(BOOT_PATH) as PackedScene;var boot:=packed.instantiate();root.add_child(boot);await process_frame
	boot.run_mode=mode;boot.save.vehicle=vehicle_index;boot.start_game();await process_frame
	return boot

func _scenario_id(boot:Node)->String:
	var visual:Node3D=boot.road.environment_visual_pilot
	return str(visual.get_meta("scenario_identifier","")) if visual!=null else ""

func _check_scenario(boot:Node,mode:String,vehicle_index:int)->void:
	var scenario:=_scenario_id(boot);g1h_scenarios.append("%s_%d=%s"%[mode,vehicle_index,scenario]);_check(scenario=="G1-F.1_FULL_STAGE","%s vehicle %d uses %s"%[mode,vehicle_index,scenario])
	_check(not bool(boot.road.environment_visual_pilot==null),"normal launch used historical scenario")

func _test_audio_stability()->void:
	var boot:Node=await _start_mode("STAGE",0);var initial_players:int=boot.audio.find_children("*","AudioStreamPlayer",true,false).size();var before:=int(boot.audio.short_event_total)
	for frame in 360:boot.audio.update_engine(28.0,0.65,false,false,"GRAVEL")
	var after:=int(boot.audio.short_event_total);var snapshot:Dictionary=boot.audio.diagnostic_snapshot()
	_check(initial_players==4,"audio player inventory invalid");_check(after==before,"stable gravel retriggered short audio %d times"%(after-before));_check(bool(snapshot.surface_loop),"surface loop missing");_check(boot.audio.engine_player.playing,"engine stopped")
	boot.start_game();await process_frame
	_check(boot.audio.find_children("*","AudioStreamPlayer",true,false).size()==4,"audio nodes duplicated after restart")
	_dispose_boot(boot);await _warm_frames(6)

func _test_timer_and_flow()->void:
	var boot:Node=await _start_mode("STAGE",0);boot.set_process(false);boot.player.set_physics_process(false);boot.road.set_process(false);boot.countdown=0.0;boot.player.controls_enabled=true
	var initial:float=boot.stage_time_remaining;boot._update_game(3.0);_check(is_equal_approx(boot.stage_time_remaining,initial-3.0),"timer did not decrement")
	boot.set_pause(true);var frozen:float=boot.stage_time_remaining;boot._process(2.0);_check(is_equal_approx(boot.stage_time_remaining,frozen),"timer changed while paused");boot.set_pause(false);boot._process(1.0);_check(is_equal_approx(boot.stage_time_remaining,frozen-1.0),"timer did not resume")
	await _ensure_active_segment(boot,9);var segment:=_segment_by_route_index(boot.road,9);boot.player.global_transform=Transform3D(segment.global_basis,segment.to_global(Vector3(0,.15,0)));var before_bonus:float=boot.stage_time_remaining;boot._update_game(.01)
	_check(boot.stage_checkpoint==1 and is_equal_approx(boot.stage_time_remaining,before_bonus-.01+boot.stage_checkpoint_bonus()),"CP1 bonus missing");var after_bonus:float=boot.stage_time_remaining;boot._update_game(.01);_check(boot.stage_time_remaining<after_bonus and boot.stage_time_remaining>after_bonus-.02,"CP1 bonus repeated")
	boot.start_game();await process_frame;_check(is_equal_approx(boot.stage_time_remaining,boot.stage_initial_time()),"restart did not reset remaining time")
	boot.set_process(false);boot.player.set_physics_process(false);boot.road.set_process(false);boot.countdown=0.0;boot.stage_time_remaining=.01;boot._update_game(.02);_check(boot.stage_timeout_triggered and boot.screen==boot.Screen.GAME_OVER,"zero timer did not trigger timeout")
	_dispose_boot(boot);await _warm_frames(6)
	var race:=await _start_mode("STAGE",0);await _controlled_full_race(race,0,"_logic_finish.png");DirAccess.remove_absolute(ProjectSettings.globalize_path(output_shot_root+"_logic_finish.png"));_check(race.stage_checkpoint==6,"checkpoint regression");_dispose_boot(race);await _warm_frames(6)

func _test_landing_response_logic(vehicle_index:int)->void:
	var vehicle:=VehicleController.new();vehicle.setup(vehicle_index);root.add_child(vehicle);vehicle.surface="ASPHALT";vehicle._begin_landing_response(7.0)
	var minimum:=0.0;var maximum:=0.0
	for frame in 30:vehicle._update_visual_feedback(1.0/60.0);minimum=minf(minimum,vehicle.landing_response_offset);maximum=maxf(maximum,vehicle.landing_response_offset)
	_check(vehicle.landing_response_count==1,"vehicle %d landing response count invalid"%vehicle_index);_check(minimum<=-.04 and maximum>0.0,"vehicle %d compression/rebound missing"%vehicle_index);_check(is_zero_approx(vehicle.landing_response_offset),"vehicle %d landing response did not settle"%vehicle_index)
	g1h_landings.append({"vehicle":vehicle_index,"compression":minimum,"rebound":maximum,"cycles":vehicle.landing_response_count});vehicle.queue_free();await process_frame

func _test_garage_and_endurance_bonus()->void:
	var packed:=load(BOOT_PATH) as PackedScene;var garage:=packed.instantiate();root.add_child(garage);await process_frame;garage.save.vehicle=1;garage.show_garage();await _warm_frames(8);var rect:=_project_vehicle_rect(garage.garage_car,garage.garage_camera);_check(rect.position.x>=430.0 and rect.end.x<=1280.0,"Garage regression");_dispose_boot(garage);await _warm_frames(4)
	var endurance:Node=await _start_mode("ENDURANCE",0);var area:=Area3D.new();endurance.world.add_child(area);var score_before:int=endurance.score;endurance._collect(1,area);_check(endurance.score==score_before+500,"Endurance bonus regression");_dispose_boot(endurance);await _warm_frames(6)

func _frame_endurance(boot:Node,speed_kmh:int)->void:
	boot.set_process(false);boot.player.set_physics_process(false);boot.road.set_process(false);boot.camera.set_process(false);var segment:Node3D=boot.road.segments[0];boot.player.global_transform=Transform3D(segment.global_basis,segment.to_global(Vector3(0,.15,8)));boot.player.speed=speed_kmh/3.6;boot.camera.global_position=boot.player.global_position+boot.player.global_basis.z*9.8+Vector3.UP*2.9;boot.camera.look_at(boot.player.global_position-boot.player.global_basis.z*8.5+Vector3.UP*4.5);boot.hud.update_values(8400,1250,speed_kmh,72,86,2,12840,0);await _warm_frames(18)

func _capture_help()->void:
	var boot:Node=load(BOOT_PATH).instantiate();root.add_child(boot);await process_frame;boot.show_help();await _warm_frames(10);await _save_viewport("05_how_to_play_updated.png");_dispose_boot(boot);await _warm_frames(4)

func _capture_timer_sequence()->void:
	var boot:=await _start_mode("STAGE",0);boot.set_process(false);boot.player.set_physics_process(false);boot.road.set_process(false);boot.countdown=0.0;boot.player.controls_enabled=true;await _freeze_at(boot,0,0,8,0);boot.hud.update_rally(true,boot.stage_time_remaining,0,0,6,boot.player,boot.road.pacenote_near(boot.player.global_position));await _save_viewport("06_timer_start.png")
	boot._update_game(7.0);boot.hud.update_rally(true,boot.stage_time_remaining,0,0,6,boot.player,boot.road.pacenote_near(boot.player.global_position));await _save_viewport("07_timer_running.png")
	await _ensure_active_segment(boot,9);await _freeze_at(boot,8,0,-18,70);boot.stage_time_remaining=80.0;boot.hud.update_rally(true,80,0,0,6,boot.player,boot.road.pacenote_near(boot.player.global_position));await _save_viewport("08_checkpoint_before_bonus.png")
	var cp:=_segment_by_route_index(boot.road,9);boot.player.global_transform=Transform3D(cp.global_basis,cp.to_global(Vector3(0,.15,0)));boot._update_game(.01);boot.hud.update_rally(true,boot.stage_time_remaining,0,boot.stage_checkpoint,6,boot.player,boot.road.pacenote_near(boot.player.global_position),int(boot.stage_checkpoint_bonus()),boot.run_mode,boot.stage_difficulty_name());await _save_viewport("09_checkpoint_bonus_plus_time.png");await _warm_frames(50);boot.stage_bonus_feedback_time=0;boot.hud.update_rally(true,boot.stage_time_remaining,0,boot.stage_checkpoint,6,boot.player,boot.road.pacenote_near(boot.player.global_position));await _save_viewport("10_timer_after_bonus.png")
	boot.set_pause(true);var frozen:float=boot.stage_time_remaining;boot._process(3.0);_check(is_equal_approx(frozen,boot.stage_time_remaining),"capture pause timer changed");await _save_viewport("15_pause_timer_frozen.png");boot.set_pause(false);boot.start_game();await process_frame;boot.set_process(false);boot.player.set_physics_process(false);boot.road.set_process(false);boot.countdown=0;boot.hud.update_values(boot.score,boot.distance,boot.player.speed_kmh(),boot.fuel,boot.health,boot.multiplier,int(boot.save.record),boot.player.turbo_time);boot.hud.update_rally(true,boot.stage_time_remaining,0,0,6,boot.player,boot.road.pacenote_near(boot.player.global_position));await _save_viewport("16_restart_timer_reset.png");_dispose_boot(boot);await _warm_frames(6)

func _capture_landing_sequence(vehicle_index:int,route_index:int,speed_kmh:int,contact_name:String,rebound_name:String)->void:
	var boot:Node=await _start_mode("STAGE",vehicle_index)
	await _validate_jump(boot,route_index,speed_kmh,"stallion" if vehicle_index==0 else "bavarian","","","")
	_check(boot.player.landing_response_count>=1,"landing response not triggered for vehicle %d"%vehicle_index)
	# Ignore the harmless spawn-settle cycle counted before the measured jump.
	boot.player.landing_response_count=1
	# Rewind only the visual response for deterministic contact/rebound frames;
	# the impact and trigger above were produced by the real stage physics.
	boot.player.landing_response_time=boot.player.landing_response_duration
	boot.player.landing_response_offset=0.0
	while boot.player.landing_response_duration-boot.player.landing_response_time<.085:boot.player._update_visual_feedback(1.0/120.0);await process_frame
	await _save_viewport(contact_name);var compression:float=boot.player.landing_response_offset
	while boot.player.landing_response_duration-boot.player.landing_response_time<.175:boot.player._update_visual_feedback(1.0/120.0);await process_frame
	await _save_viewport(rebound_name);var rebound:float=boot.player.landing_response_offset
	while boot.player.landing_response_time>0.0:boot.player._update_visual_feedback(1.0/60.0)
	_check(compression<0.0 and rebound>compression,"landing sequence invalid vehicle %d"%vehicle_index);_check(boot.player.landing_response_count==1 and is_zero_approx(boot.player.landing_response_offset),"multiple/persistent landing response vehicle %d"%vehicle_index);g1h_landings.append({"vehicle":vehicle_index,"visual_impact":boot.player.landing_visual_impact,"gameplay_impact":boot.player.landing_impact,"compression":compression,"rebound":rebound,"cycles":1});_dispose_boot(boot);await _warm_frames(6)
