extends "res://tests/garage_scenario_route_dynamics_verification.gd"

const DIFFICULTY_SHOT_ROOT:="res://screenshots/release_difficulty/"
const EXPECTED_NAMES:=["FACILE","NORMALE","DIFFICILE"]
const EXPECTED_TIMES:=[105.0,90.0,75.0]
const EXPECTED_BONUSES:=[18.0,15.0,12.0]
var dedicated_checks:=0
var level_results:Array[Dictionary]=[]

func _check(condition:bool,message:String)->void:
	dedicated_checks+=1
	super._check(condition,message)

func _initialize()->void:
	output_shot_root=DIFFICULTY_SHOT_ROOT
	if "--capture" in OS.get_cmdline_user_args():_run_capture.call_deferred()
	else:_run_logic.call_deferred()

func _run_logic()->void:
	print("RELEASE_DIFFICULTY_SELECTOR_LOGIC_START")
	await _test_selector_controls()
	for difficulty_index in 3:
		for vehicle_index in 2:await _test_stage_level(difficulty_index,vehicle_index)
		await _test_timeout_and_menu(difficulty_index)
	await _test_endurance_unchanged()
	_check(dedicated_checks>=70,"fewer than 70 dedicated checks executed")
	print("RELEASE_DIFFICULTY_RESULTS checks=",dedicated_checks," levels=",level_results)
	for failure in failures:printerr("RELEASE_DIFFICULTY_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _run_capture()->void:
	print("RELEASE_DIFFICULTY_SELECTOR_CAPTURE_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_shot_root))
	for file_name in DirAccess.get_files_at(output_shot_root):
		if file_name.ends_with(".png"):DirAccess.remove_absolute(ProjectSettings.globalize_path(output_shot_root+file_name))
	for difficulty_index in 3:
		await _capture_menu(difficulty_index,"0%d_menu_difficulty_%s.png"%[difficulty_index+1,EXPECTED_NAMES[difficulty_index].to_lower()])
	for difficulty_index in 3:
		await _capture_hud(difficulty_index,"0%d_hud_difficulty_%s.png"%[difficulty_index+4,EXPECTED_NAMES[difficulty_index].to_lower()])
	_check(_png_count()==6,"required screenshot count is not 6")
	for file_name in DirAccess.get_files_at(output_shot_root):
		if not file_name.ends_with(".png"):continue
		var image:=Image.load_from_file(ProjectSettings.globalize_path(output_shot_root+file_name))
		_check(image!=null and image.get_width()==1280 and image.get_height()==720,"invalid screenshot dimensions: "+file_name)
	print("RELEASE_DIFFICULTY_SCREENSHOTS count=",_png_count())
	for failure in failures:printerr("RELEASE_DIFFICULTY_CAPTURE_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _new_boot()->Node:
	var boot:Node=load(BOOT_PATH).instantiate();root.add_child(boot);await process_frame;return boot

func _start_stage(difficulty_index:int,vehicle_index:int)->Node:
	var boot:=await _new_boot();boot.run_mode="STAGE";boot.stage_difficulty_index=difficulty_index;boot.save.vehicle=vehicle_index;boot.start_game();await process_frame
	boot.set_process(false);boot.player.set_physics_process(false);boot.road.set_process(false);boot.countdown=0.0;boot.player.controls_enabled=true
	return boot

func _test_selector_controls()->void:
	var boot:=await _new_boot();_check(boot.stage_difficulty_index==1 and boot.stage_difficulty_name()=="NORMALE","Normal is not the default difficulty")
	boot.run_mode="STAGE";boot.show_garage();await process_frame
	var value:=boot.ui.find_child("DifficultyValue",true,false) as Label;var previous:=boot.ui.find_child("DifficultyPrevious",true,false) as Button;var next:=boot.ui.find_child("DifficultyNext",true,false) as Button
	_check(value!=null and previous!=null and next!=null,"difficulty selector controls missing")
	_check("NORMALE" in value.text,"garage does not display Normal by default")
	next.pressed.emit();_check(boot.stage_difficulty_index==2 and "DIFFICILE" in value.text,"mouse next selector failed")
	previous.pressed.emit();_check(boot.stage_difficulty_index==1 and "NORMALE" in value.text,"mouse previous selector failed")
	var right:=InputEventKey.new();right.physical_keycode=KEY_RIGHT;right.pressed=true;boot._unhandled_input(right);_check(boot.stage_difficulty_index==2 and "DIFFICILE" in value.text,"keyboard right selector failed")
	var left:=InputEventKey.new();left.physical_keycode=KEY_LEFT;left.pressed=true;boot._unhandled_input(left);_check(boot.stage_difficulty_index==1 and "NORMALE" in value.text,"keyboard left selector failed")
	_dispose_boot(boot);await _warm_frames(4)
	var endurance:=await _new_boot();endurance.run_mode="ENDURANCE";endurance.show_garage();await process_frame;_check(endurance.ui.find_child("DifficultyValue",true,false)==null,"difficulty selector leaked into Endurance garage");_dispose_boot(endurance);await _warm_frames(4)

func _test_stage_level(difficulty_index:int,vehicle_index:int)->void:
	var boot:=await _start_stage(difficulty_index,vehicle_index);var expected_time:=float(EXPECTED_TIMES[difficulty_index]);var expected_bonus:=float(EXPECTED_BONUSES[difficulty_index]);var name:String=EXPECTED_NAMES[difficulty_index]
	_check(is_equal_approx(boot.stage_time_remaining,expected_time),"%s vehicle %d initial time mismatch"%[name,vehicle_index])
	_check(is_equal_approx(boot.stage_initial_time(),expected_time) and is_equal_approx(boot.stage_checkpoint_bonus(),expected_bonus),"%s configuration mismatch"%name)
	boot._update_game(1.25);_check(is_equal_approx(boot.stage_time_remaining,expected_time-1.25),"%s vehicle %d timer decrement mismatch"%[name,vehicle_index])
	boot.hud.update_rally(true,boot.stage_time_remaining,0,0,6,boot.player,{},0,"STAGE",name);_check("DIFFICOLTÀ "+name in boot.hud.rally_label.text,"%s HUD label missing"%name)
	if vehicle_index==0:
		boot.set_pause(true);var frozen:float=boot.stage_time_remaining;boot._process(2.0);_check(is_equal_approx(boot.stage_time_remaining,frozen),"%s timer changed while paused"%name);boot.set_pause(false)
		boot.start_game();await process_frame;boot.set_process(false);boot.player.set_physics_process(false);boot.road.set_process(false);boot.countdown=0.0;_check(boot.stage_difficulty_index==difficulty_index and is_equal_approx(boot.stage_time_remaining,expected_time),"%s restart did not preserve difficulty"%name)
	for checkpoint_index in 5:
		var route_index:int=boot.stage_checkpoint_segments[checkpoint_index];await _ensure_active_segment(boot,route_index);var segment:=_segment_by_route_index(boot.road,route_index);boot.player.global_transform=Transform3D(segment.global_basis,segment.to_global(Vector3(0,.15,0)));var before:float=boot.stage_time_remaining;boot._update_game(.01)
		_check(boot.stage_checkpoint==checkpoint_index+1,"%s vehicle %d CP%d not registered"%[name,vehicle_index,checkpoint_index+1])
		_check(is_equal_approx(boot.stage_time_remaining,before-.01+expected_bonus),"%s vehicle %d CP%d bonus mismatch"%[name,vehicle_index,checkpoint_index+1])
	var cp6_index:int=boot.stage_checkpoint_segments[5];await _ensure_active_segment(boot,cp6_index);var cp6:=_segment_by_route_index(boot.road,cp6_index);boot.player.global_transform=Transform3D(cp6.global_basis,cp6.to_global(Vector3(0,.15,0)));var before_cp6:float=boot.stage_time_remaining;boot._update_game(.01)
	_check(boot.stage_checkpoint==6,"%s vehicle %d CP6 not registered"%[name,vehicle_index]);_check(is_equal_approx(boot.stage_time_remaining,before_cp6-.01),"%s vehicle %d CP6 incorrectly added time"%[name,vehicle_index])
	await _ensure_active_segment(boot,63);var finish:=_segment_by_route_index(boot.road,63);boot.player.global_transform=Transform3D(finish.global_basis,finish.to_global(Vector3(0,.15,0)));boot._update_game(.01);_check(boot.screen==boot.Screen.GAME_OVER,"%s vehicle %d finish failed"%[name,vehicle_index])
	level_results.append({"difficulty":name,"vehicle":vehicle_index,"initial":expected_time,"cp_bonus":expected_bonus,"cp6_bonus":0,"finish":"PASS"});_dispose_boot(boot);await _warm_frames(4)

func _test_timeout_and_menu(difficulty_index:int)->void:
	var boot:=await _start_stage(difficulty_index,0);boot.stage_time_remaining=.01;boot._update_game(.02);_check(boot.stage_timeout_triggered and boot.screen==boot.Screen.GAME_OVER,"%s timeout failed"%EXPECTED_NAMES[difficulty_index]);boot.show_menu();_check(boot.stage_difficulty_index==1 and boot.stage_difficulty_name()=="NORMALE","main menu did not reset difficulty to Normal");_dispose_boot(boot);await _warm_frames(4)

func _test_endurance_unchanged()->void:
	for vehicle_index in 2:
		var boot:=await _new_boot();boot.run_mode="ENDURANCE";boot.stage_difficulty_index=0 if vehicle_index==0 else 2;boot.save.vehicle=vehicle_index;boot.start_game();await process_frame;boot.set_process(false);boot.player.set_physics_process(false);boot.road.set_process(false);var timer_before:float=boot.stage_time_remaining;boot._update_game(1.0)
		_check(not boot.road.stage_mode,"Endurance vehicle %d entered Stage route"%vehicle_index);_check(is_equal_approx(boot.stage_time_remaining,timer_before),"Endurance vehicle %d used Stage timer"%vehicle_index);_check("DIFFICOLTÀ" not in boot.hud.rally_label.text,"difficulty leaked into Endurance HUD vehicle %d"%vehicle_index);_check(boot.audio.engine_player.playing,"Endurance vehicle %d audio did not start"%vehicle_index);_dispose_boot(boot);await _warm_frames(4)

func _capture_menu(difficulty_index:int,file_name:String)->void:
	var boot:=await _new_boot();boot.run_mode="STAGE";boot.stage_difficulty_index=difficulty_index;boot.show_garage();await _warm_frames(20);_check(EXPECTED_NAMES[difficulty_index] in (boot.ui.find_child("DifficultyValue",true,false) as Label).text,"menu capture selector mismatch");await _save_viewport(file_name);_dispose_boot(boot);await _warm_frames(4)

func _capture_hud(difficulty_index:int,file_name:String)->void:
	var boot:=await _start_stage(difficulty_index,difficulty_index%2);await _ensure_active_segment(boot,4);await _freeze_at(boot,4,0.0,8.0,58);boot.hud.update_values(boot.score,boot.distance,58,boot.fuel,boot.health,boot.multiplier,int(boot.save.record),boot.player.turbo_time);boot.hud.update_rally(true,boot.stage_time_remaining,0,0,6,boot.player,boot.road.pacenote_near(boot.player.global_position),0,"STAGE",EXPECTED_NAMES[difficulty_index]);await _warm_frames(12);_check("DIFFICOLTÀ "+EXPECTED_NAMES[difficulty_index] in boot.hud.rally_label.text,"HUD capture label mismatch");await _save_viewport(file_name);_dispose_boot(boot);await _warm_frames(4)
