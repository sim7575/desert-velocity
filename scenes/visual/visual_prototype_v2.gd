extends Node3D

const NEUTRAL := [
	["01_front_three_quarter",Vector3(5.7,2.45,6.8),Vector3(0,.82,-.35)],
	["02_rear_three_quarter",Vector3(-5.4,2.35,-5.7),Vector3(0,.80,-.35)],
	["03_perfect_side",Vector3(7.0,1.85,-.45),Vector3(0,.78,-.45)],
	["04_front",Vector3(0,1.70,7.4),Vector3(0,.78,-.5)],
	["05_rear",Vector3(0,1.65,-6.8),Vector3(0,.75,-.5)],
	["06_moderate_top",Vector3(5.9,5.5,6.5),Vector3(0,.65,-.45)],
	["07_low_camera",Vector3(5.0,.88,5.9),Vector3(0,.70,-.45)],
	["08_wheel_arch_detail",Vector3(3.0,1.05,3.4),Vector3(.82,.54,.85)],
	["09_cabin_detail",Vector3(3.15,2.2,.95),Vector3(.45,1.05,-.4)],
]
const AMBIENT := [
	["01_desert_road",Vector3(7.5,3.0,8.8),Vector3(0,.60,-1.6)],
	["02_canyon",Vector3(-7.2,3.5,5.8),Vector3(-1.1,1.4,-6.8)],
	["03_sunset",Vector3(5.8,2.3,6.8),Vector3(0,.78,-.4)],
	["04_dust",Vector3(-5.2,1.7,5.8),Vector3(0,.72,-.5)],
	["05_wide",Vector3(12,6.2,12.5),Vector3(0,.55,-2.2)],
]
@onready var camera:Camera3D=$Camera3D
@onready var world:WorldEnvironment=$WorldEnvironment

func _ready()->void:
	if "--capture-prototype-v2" in OS.get_cmdline_user_args():capture_all.call_deferred()

func capture_all()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/visual_prototype_v2/neutral"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/visual_prototype_v2/environment"))
	set_neutral()
	for shot in NEUTRAL: await capture("neutral",shot)
	await capture_silhouette()
	set_sunset()
	for shot in AMBIENT:
		world.environment.fog_density=.010 if shot[0]=="04_dust" else .004
		await capture("environment",shot)
	get_tree().quit()

func set_neutral()->void:
	world.environment.background_mode=Environment.BG_SKY
	world.environment.ambient_light_color=Color(.56,.61,.68)
	world.environment.ambient_light_energy=.58
	world.environment.fog_light_color=Color(.60,.64,.69)
	world.environment.fog_density=.002
	$NeutralKey.light_color=Color(1,.95,.88);$NeutralKey.light_energy=1.15
	$NeutralFill.light_color=Color(.72,.82,1);$NeutralFill.light_energy=1.45

func set_sunset()->void:
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color(.13,.20,.34)
	world.environment.ambient_light_color=Color(.40,.34,.38)
	world.environment.ambient_light_energy=.48
	world.environment.fog_light_color=Color(.64,.31,.16)
	$NeutralKey.light_color=Color(1,.62,.34);$NeutralKey.light_energy=1.28
	$NeutralFill.light_color=Color(.42,.55,.78);$NeutralFill.light_energy=.85

func capture(folder:String,shot:Array)->void:
	camera.global_position=shot[1];camera.look_at(shot[2],Vector3.UP)
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	var path:="res://screenshots/visual_prototype_v2/%s/%s.png"%[folder,shot[0]]
	print("CAPTURE_V2 ",path," error=",get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path)))

func capture_silhouette()->void:
	$EnvironmentV2.visible=false
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color.WHITE;world.environment.background_energy_multiplier=1.0;world.environment.fog_enabled=false
	var meshes:Array[MeshInstance3D]=[];collect_meshes($DesertStallion65V2,meshes)
	for mesh in meshes:mesh.material_override=load("res://scenes/visual/VisualPrototypeV2.tscn::BlackSilhouette") if false else null
	var black:=StandardMaterial3D.new();black.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;black.albedo_color=Color.BLACK
	for mesh in meshes:mesh.material_override=black
	await capture("neutral",["10_black_silhouette",Vector3(7.0,1.85,-.45),Vector3(0,.78,-.45)])
	for mesh in meshes:mesh.material_override=null
	$EnvironmentV2.visible=true;world.environment.fog_enabled=true;set_neutral()

func collect_meshes(node:Node,out:Array[MeshInstance3D])->void:
	if node is MeshInstance3D:out.append(node)
	for child in node.get_children():collect_meshes(child,out)
