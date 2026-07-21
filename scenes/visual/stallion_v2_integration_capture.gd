extends Node3D

var player:VehicleController
var road:RoadManager
var camera:Camera3D
var environment:Environment
var platform:MeshInstance3D
var loading_ms:float=0.0
var memory_delta:int=0
var garage_fps:float=0.0
var special_stage_fps:float=0.0
var endurance_fps:float=0.0

func _ready()->void:
	if "--capture-stallion-integration" not in OS.get_cmdline_user_args():return
	_run.call_deferred()

func _run()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/stallion_v2_integration"))
	_setup_lighting()
	_setup_platform()
	var memory_before:=int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var started:=Time.get_ticks_usec()
	player=VehicleController.new();player.setup(0);player.controls_enabled=false;add_child(player)
	player.set_physics_process(false)
	loading_ms=(Time.get_ticks_usec()-started)/1000.0
	memory_delta=int(Performance.get_monitor(Performance.MEMORY_STATIC))-memory_before
	camera=Camera3D.new();camera.current=true;camera.fov=46;add_child(camera)
	await frames(8)
	await shot("01_garage_front_three_quarter",Vector3(5.7,2.35,6.6),Vector3(0,.75,0))
	await shot("02_garage_rear_three_quarter",Vector3(-5.3,2.25,-5.8),Vector3(0,.72,0))
	await shot("03_garage_side",Vector3(7.0,1.85,0),Vector3(0,.72,0))
	garage_fps=await measure_fps(60)
	platform.visible=false
	road=RoadManager.new();road.stage_mode=true;add_child(road);road.setup(player);player.road_manager=road
	player.position=Vector3(0,.05,8);player.set_physics_process(true);await frames(12)
	special_stage_fps=await measure_fps(60)
	await shot("04_gameplay_rear",player.global_position+Vector3(0,3.1,7.2),player.global_position+Vector3(0,1,-4))
	player.rotation.y=.42;player.steering=.9;player.speed=24;player._update_wheels(.12);await frames(3)
	await shot("05_curve",player.global_position+Vector3(6.4,2.7,5.1),player.global_position+Vector3(0,.8,-2.5))
	player.set_physics_process(false);player.surface="DEEP_SAND";player.speed=28;player.visual.position.y=-.035
	for emitter in player.dust_emitters:emitter.emitting=true
	await frames(18);await shot("06_sand_and_dust",player.global_position+Vector3(-5.5,1.8,5.8),player.global_position+Vector3(0,.7,-2))
	player.rotation.y=0
	await shot("07_hood_camera",player.global_position-player.global_transform.basis.z*1.40+Vector3.UP*1.16,player.global_position-player.global_transform.basis.z*12+Vector3.UP*.72)
	await shot("08_bumper_camera",player.global_position-player.global_transform.basis.z*2.62+Vector3.UP*.64,player.global_position-player.global_transform.basis.z*14+Vector3.UP*.52)
	environment.background_color=Color("293752");environment.ambient_light_color=Color("635064");environment.ambient_light_energy=.42
	$Sun.light_color=Color("ff8b4a");$Sun.light_energy=1.35;$Sun.rotation_degrees=Vector3(-18,-125,0)
	await frames(5);await shot("09_sunset_f4",player.global_position+Vector3(5.7,2.2,6.4),player.global_position+Vector3(0,.8,-1.2))
	player.damage_level=.45;spawn_sparks();await frames(2);await shot("10_collision_damage",player.global_position+Vector3(4.8,1.7,4.5),player.global_position+Vector3(0,.7,0))
	road.stage_mode=false;endurance_fps=await measure_fps(60)
	write_metrics()
	get_tree().quit()

func _setup_lighting()->void:
	environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("91a5bd");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("b9c6d4");environment.ambient_light_energy=.58;environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var world:=WorldEnvironment.new();world.environment=environment;add_child(world)
	var sun:=DirectionalLight3D.new();sun.name="Sun";sun.rotation_degrees=Vector3(-38,-132,0);sun.light_color=Color("fff2dc");sun.light_energy=1.1;sun.shadow_enabled=true;add_child(sun)
	var fill:=OmniLight3D.new();fill.position=Vector3(4,4,5);fill.light_color=Color("b6d1ff");fill.light_energy=1.2;fill.omni_range=14;add_child(fill)

func _setup_platform()->void:
	platform=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=3.6;cylinder.bottom_radius=3.6;cylinder.height=.18;platform.mesh=cylinder;platform.position.y=-.08
	var material:=StandardMaterial3D.new();material.albedo_color=Color("20252d");material.metallic=.65;material.roughness=.32;platform.material_override=material;add_child(platform)

func shot(name:String,position_:Vector3,target:Vector3)->void:
	camera.global_position=position_;camera.look_at(target,Vector3.UP);await frames(2);await RenderingServer.frame_post_draw
	var path:="res://screenshots/stallion_v2_integration/%s.png"%name
	print("INTEGRATION_CAPTURE ",path," error=",get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path)))

func frames(count:int)->void:
	for _i in count:
		await get_tree().process_frame

func measure_fps(count:int)->float:
	var total:=0.0
	for _i in count:
		await get_tree().process_frame
		var delta:=get_process_delta_time()
		if delta>0:total+=1.0/delta
	return total/maxi(1,count)

func spawn_sparks()->void:
	var sparks:=CPUParticles3D.new();sparks.one_shot=true;sparks.amount=28;sparks.lifetime=.55;sparks.explosiveness=.95;sparks.direction=Vector3(0,1,0);sparks.spread=75;sparks.initial_velocity_min=3;sparks.initial_velocity_max=7;sparks.gravity=Vector3(0,-9,0);sparks.color=Color("ffb12b");sparks.position=player.position+Vector3.UP*.7;add_child(sparks);sparks.emitting=true

func write_metrics()->void:
	var report:="Stallion V2 integration metrics\n"
	report+="loading_ms=%.3f\n"%loading_ms
	report+="memory_delta_bytes=%d\n"%memory_delta
	report+="garage_fps=%.2f\n"%garage_fps
	report+="special_stage_fps=%.2f\n"%special_stage_fps
	report+="endurance_fps=%.2f\n"%endurance_fps
	report+="draw_calls=%d\n"%int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	report+="primitives=%d\n"%int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	report+="objects=%d\n"%int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var file:=FileAccess.open("res://reports/stallion_v2_integration_metrics.txt",FileAccess.WRITE);file.store_string(report);file.close();print(report)
