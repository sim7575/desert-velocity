extends "res://tests/garage_scenario_route_dynamics_verification.gd"

const RELEASE_SHOT_ROOT:="res://screenshots/playable_visual_integration_pilot/g1h_release/"
var dedicated_checks:=0
var audio_results:Array[Dictionary]=[]
var dust_results:Dictionary={}

func _check(condition:bool,message:String)->void:
	dedicated_checks+=1
	super._check(condition,message)

func _initialize()->void:
	output_shot_root=RELEASE_SHOT_ROOT
	if "--capture" in OS.get_cmdline_user_args():_run_capture.call_deferred()
	elif "--metrics" in OS.get_cmdline_user_args():_run_metrics.call_deferred()
	else:_run_logic.call_deferred()

func _run_logic()->void:
	print("FINAL_AUDIOVISUAL_RELEASE_POLISH_LOGIC_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_shot_root))
	await _test_four_mode_huds()
	await _test_f3_toggle()
	await _test_dust_systems()
	await _test_audio_profile(0)
	await _test_audio_profile(1)
	await _test_timer_checkpoint_finish()
	_check(dedicated_checks>=30,"fewer than 30 dedicated checks executed")
	print("FINAL_AUDIOVISUAL_CHECKS ",dedicated_checks," AUDIO ",audio_results," DUST ",dust_results)
	for failure in failures:printerr("FINAL_AUDIOVISUAL_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _run_capture()->void:
	print("FINAL_AUDIOVISUAL_RELEASE_POLISH_CAPTURE_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_shot_root))
	for file_name in DirAccess.get_files_at(output_shot_root):
		if file_name.ends_with(".png"):DirAccess.remove_absolute(ProjectSettings.globalize_path(output_shot_root+file_name))
	await _capture_dust(0,"GRAVEL",18,"01_stallion_gravel_dust.png")
	await _capture_dust(1,"GRAVEL",18,"02_bavarian_gravel_dust.png")
	await _capture_dust(0,"SAND",42,"03_stallion_sand_dust.png")
	await _capture_dust(1,"SAND",42,"04_bavarian_sand_dust.png")
	await _capture_dust(1,"ASPHALT",4,"05_asphalt_minimal_dust.png")
	await _capture_hud("STAGE",0,"06_hud_special_stage_stallion.png")
	await _capture_hud("STAGE",1,"07_hud_special_stage_bavarian.png")
	await _capture_hud("ENDURANCE",0,"08_hud_endurance_stallion.png")
	await _capture_hud("ENDURANCE",1,"09_hud_endurance_bavarian.png")
	await _capture_f3()
	await _capture_boost()
	_check(_png_count()==12,"required screenshot count is not 12")
	print("FINAL_AUDIOVISUAL_SCREENSHOTS count=",_png_count())
	for failure in failures:printerr("FINAL_AUDIOVISUAL_CAPTURE_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _run_metrics()->void:
	print("FINAL_AUDIOVISUAL_RELEASE_POLISH_METRICS_START")
	var started:=Time.get_ticks_usec();var boot:Node=await _start_mode("STAGE",1);load_time_ms=(Time.get_ticks_usec()-started)/1000.0
	await _freeze_at(boot,30,0.0,7.0,92);boot.player.surface="GRAVEL";boot.player.speed=25.5;boot.player._update_visual_feedback(1.0/60.0)
	var previous:=Time.get_ticks_usec()
	for frame in 840:
		boot.audio.update_engine(boot.player.speed,.72,false,false,"GRAVEL",5200.0,4,false,false,1,1.0/60.0)
		await process_frame;var now:=Time.get_ticks_usec();frame_times_ms.append((now-previous)/1000.0);previous=now;_collect_performance()
	var stats:=_frame_stats(frame_times_ms);var snapshot:Dictionary=boot.audio.diagnostic_snapshot()
	_check(float(stats.average_fps)>=58.0,"average FPS below 58");_check(float(stats.minimum_sustained_fps)>=55.0,"sustained FPS below 55");_check(not bool(stats.recurring_stutter),"recurring stutter")
	print("FINAL_AUDIOVISUAL_METRICS average_fps=%.2f p5_fps=%.2f sustained_fps=%.2f p95_ms=%.3f p99_ms=%.3f stutter=%s draw=%d primitives=%d nodes=%d memory_mb=%.2f warm_load_ms=%.2f audio=%s"%[float(stats.average_fps),float(stats.p5_fps),float(stats.minimum_sustained_fps),float(stats.p95_ms),float(stats.p99_ms),str(bool(stats.recurring_stutter)).to_lower(),peak_draw_calls,peak_primitives,peak_nodes,peak_static_memory/1048576.0,load_time_ms,str(snapshot)])
	_dispose_boot(boot);await _warm_frames(5)
	for failure in failures:printerr("FINAL_AUDIOVISUAL_METRICS_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _start_mode(mode:String,vehicle_index:int)->Node:
	var boot:Node=load(BOOT_PATH).instantiate();root.add_child(boot);await process_frame;boot.run_mode=mode;boot.save.vehicle=vehicle_index;boot.start_game();await process_frame;return boot

func _prepare_static(boot:Node,route_index:int,speed_kmh:int)->void:
	await _ensure_active_segment(boot,mini(route_index+2,63));await _freeze_at(boot,route_index,0.0,8.0,speed_kmh);boot.countdown=0.0;boot.player.controls_enabled=true;boot.player.speed=speed_kmh/3.6;boot.player.airborne=false

func _test_four_mode_huds()->void:
	for mode in ["STAGE","ENDURANCE"]:
		for vehicle_index in [0,1]:
			var boot:=await _start_mode(mode,vehicle_index);await _prepare_static(boot,4,48);boot._update_game(.016)
			var status:=boot.hud.status_panel as Panel;var pace:=boot.hud.pace_panel as Panel;var rally:=boot.hud.rally_panel as Panel
			_check(status.visible and not boot.hud.stats_label.text.strip_edges().is_empty(),"%s vehicle %d empty status panel"%[mode,vehicle_index])
			_check(pace.visible and not boot.hud.pacenote_label.text.strip_edges().is_empty(),"%s vehicle %d empty center panel"%[mode,vehicle_index])
			_check(rally.visible and not boot.hud.rally_label.text.strip_edges().is_empty(),"%s vehicle %d empty right panel"%[mode,vehicle_index])
			_check(not boot.hud.debug_label.visible,"%s vehicle %d debug visible at launch"%[mode,vehicle_index])
			if mode=="ENDURANCE":_check("ENDURANCE" in boot.hud.pacenote_label.text and "MARCIA" in boot.hud.rally_label.text,"Endurance fallback HUD content missing")
			else:_check("TEMPO" in boot.hud.rally_label.text and "CP" in boot.hud.rally_label.text,"Stage timer/checkpoint HUD missing")
			_dispose_boot(boot);await _warm_frames(4)

func _test_f3_toggle()->void:
	var boot:=await _start_mode("STAGE",0);await _prepare_static(boot,4,40);_check(not boot.hud.debug_visible and not boot.hud.debug_label.visible,"F3 default state is not off")
	Input.action_press("debug_overlay");boot.hud.update_offroad(false,false,Vector3.ZERO,boot.player);Input.action_release("debug_overlay");_check(boot.hud.debug_visible and boot.hud.debug_label.visible,"F3 did not enable telemetry")
	await process_frame;Input.action_press("debug_overlay");boot.hud.update_offroad(false,false,Vector3.ZERO,boot.player);Input.action_release("debug_overlay");_check(not boot.hud.debug_visible and not boot.hud.debug_label.visible,"F3 did not disable telemetry")
	_dispose_boot(boot);await _warm_frames(4)

func _test_dust_systems()->void:
	var bavarian:=VehicleController.new();bavarian.setup(1);root.add_child(bavarian);await process_frame;bavarian.speed=22.0;bavarian.airborne=false;bavarian.slip_angle=0.0
	var values:Dictionary={}
	for surface in ["ASPHALT","GRAVEL","SAND","DEEP_SAND"]:
		bavarian.surface=surface;bavarian._update_visual_feedback(1.0/60.0);values[surface]=bavarian.dust_emitters[2].amount_ratio
	_check(float(values.ASPHALT)<float(values.GRAVEL) and float(values.GRAVEL)<float(values.SAND) and float(values.SAND)<float(values.DEEP_SAND),"Bavarian surface dust levels are not differentiated")
	for emitter in bavarian.dust_emitters:
		var mesh:=emitter.draw_pass_1 as QuadMesh;var material:=mesh.material as StandardMaterial3D;var process:=emitter.process_material as ParticleProcessMaterial
		_check(material!=null and material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_texture!=null,"Bavarian dust uses an opaque/untextured quad")
		_check(process.color_initial_ramp!=null and process.scale_min<process.scale_max and process.angular_velocity_max>0.0,"Bavarian dust lacks alpha/scale/rotation variation")
	bavarian.queue_free();await process_frame
	var stallion:=await _start_mode("STAGE",0);var effects:=stallion.player.find_child("GameplayVisualEffectsG1E",true,false) as GameplayVisualEffectsPilot;_check(effects!=null,"Stallion soft dust pilot missing")
	if effects!=null:
		var mesh:=effects.dust_emitters[0].draw_pass_1 as QuadMesh;var process:=effects.dust_emitters[0].process_material as ParticleProcessMaterial
		_check(mesh.size.x<=1.451 and mesh.size.y<=.441,"Stallion dust billboard remains oversized: %s"%str(mesh.size))
		_check(process.color_initial_ramp!=null and process.scale_max<=.48 and process.angular_velocity_max>0.0,"Stallion dust variation/fade missing")
	dust_results=values;_dispose_boot(stallion);await _warm_frames(4)

func _test_audio_profile(vehicle_index:int)->void:
	var audio:=AudioManager.new();root.add_child(audio);await process_frame;audio.configure_vehicle(vehicle_index);audio.start_game_audio();var initial:=audio.audio_rpm
	audio.update_engine(30.0,1.0,false,false,"ASPHALT",7200.0,1,false,false,vehicle_index,1.0/60.0);_check(audio.audio_rpm<initial+350.0,"vehicle %d audio RPM jumps without inertia"%vehicle_index)
	for gear in [1,2,3,4]:
		for frame in 70:audio.update_engine(12.0+gear*7.0,.82,false,false,"ASPHALT",1800.0+gear*1250.0,gear,false,gear==4,vehicle_index,1.0/60.0)
	var high_rpm:=audio.audio_rpm;var high_pitch:=audio.last_engine_pitch
	for frame in 60:audio.update_engine(18.0,0.0,false,false,"ASPHALT",1250.0,4,false,false,vehicle_index,1.0/60.0)
	_check(audio.audio_rpm<high_rpm,"vehicle %d audio RPM does not fall on release"%vehicle_index);_check(audio.gear_shift_count>=3,"vehicle %d fewer than three audio shifts"%vehicle_index);_check(audio.peak_engine_pitch<=1.54 and high_pitch<1.54,"vehicle %d engine pitch exceeds comfort limit"%vehicle_index)
	var ground_db:=audio.engine_player.volume_db;audio.update_engine(18.0,.8,false,false,"ASPHALT",3200.0,4,true,false,vehicle_index,1.0/60.0);_check(audio.engine_player.volume_db<ground_db+1.0,"vehicle %d airborne load did not reduce"%vehicle_index)
	var snapshot:=audio.diagnostic_snapshot();audio_results.append(snapshot);_check(str(snapshot.vehicle_profile)==("STALLION_ROUGH" if vehicle_index==0 else "BAVARIAN_COMPACT"),"vehicle audio profile mismatch")
	audio.shutdown();audio.queue_free();await process_frame

func _test_timer_checkpoint_finish()->void:
	var boot:=await _start_mode("STAGE",0);boot.set_process(false);boot.player.set_physics_process(false);boot.road.set_process(false);boot.countdown=0.0;var before:float=boot.stage_time_remaining;boot._update_game(1.0);_check(is_equal_approx(boot.stage_time_remaining,before-1.0),"approved timer regressed")
	await _controlled_full_race(boot,0,"_release_logic_finish.png");DirAccess.remove_absolute(ProjectSettings.globalize_path(output_shot_root+"_release_logic_finish.png"));_check(boot.stage_checkpoint==6,"checkpoint regression");_check(boot.screen==boot.Screen.GAME_OVER,"finish regression");_dispose_boot(boot);await _warm_frames(5)

func _capture_dust(vehicle_index:int,surface:String,route_index:int,file_name:String)->void:
	var boot:=await _start_mode("STAGE",vehicle_index);await _prepare_static(boot,route_index,88);boot.player.surface=surface;boot.player.offroad=surface in ["SAND","DEEP_SAND"];boot.player.slip_angle=.28 if surface!="ASPHALT" else 0.0;boot.player.throttle_smoothed=.9;boot.player._update_visual_feedback(1.0/60.0);boot.camera.global_position=boot.player.global_position+boot.player.global_basis.z*9.5+Vector3.UP*2.8;boot.camera.look_at(boot.player.global_position-boot.player.global_basis.z*3.0+Vector3.UP*.7)
	var effects:=boot.player.find_child("GameplayVisualEffectsG1E",true,false) as GameplayVisualEffectsPilot
	if effects!=null:effects._update_dust()
	var active_emitters:Array=effects.dust_emitters if effects!=null else boot.player.dust_emitters
	for emitter:GPUParticles3D in active_emitters:emitter.preprocess=.30;emitter.restart()
	await _warm_frames(24);await _save_viewport(file_name);_dispose_boot(boot);await _warm_frames(4)

func _capture_hud(mode:String,vehicle_index:int,file_name:String)->void:
	var boot:=await _start_mode(mode,vehicle_index);await _prepare_static(boot,5,62);boot._update_game(.016);await _warm_frames(8);await _save_viewport(file_name);_dispose_boot(boot);await _warm_frames(4)

func _capture_f3()->void:
	var boot:=await _start_mode("STAGE",0);await _prepare_static(boot,12,64);boot.stage_checkpoint=1;boot.hud.update_values(0,0,64,boot.fuel,boot.health,1,int(boot.save.record),0);boot.hud.update_rally(true,boot.stage_time_remaining,0,1,6,boot.player,boot.road.pacenote_near(boot.player.global_position));await _save_viewport("10_f3_off.png");Input.action_press("debug_overlay");boot.hud.update_offroad(false,false,Vector3.ZERO,boot.player);Input.action_release("debug_overlay");await _warm_frames(4);await _save_viewport("11_f3_on.png");_dispose_boot(boot);await _warm_frames(4)

func _capture_boost()->void:
	var boot:=await _start_mode("STAGE",0);await _prepare_static(boot,18,96);boot.stage_checkpoint=1;boot.player.offroad=false;boot.player.soft_boundary=false;boot.player.turbo_time=3.2;boot.hud.update_values(boot.score,boot.distance,96,boot.fuel,boot.health,boot.multiplier,int(boot.save.record),boot.player.turbo_time);boot.hud.update_rally(true,boot.stage_time_remaining,0,1,6,boot.player,boot.road.pacenote_near(boot.player.global_position));boot.hud.update_offroad(false,false,Vector3.ZERO,boot.player);var effects:=boot.player.find_child("GameplayVisualEffectsG1E",true,false) as GameplayVisualEffectsPilot;if effects!=null:effects._update_boost();await _warm_frames(12);await _save_viewport("12_boost_visual_and_hud.png");_dispose_boot(boot);await _warm_frames(4)
