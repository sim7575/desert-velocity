extends Node3D
const SHOTS := [["front_three_quarter",Vector3(5.2,2.55,6.4),Vector3(0,1.0,-.2)],["rear_three_quarter",Vector3(-4.4,2.3,-3.55),Vector3(0,1.0,-.1)],["side",Vector3(6.7,2.15,0),Vector3(0,1.0,0)],["low_camera",Vector3(4.6,1.05,5.7),Vector3(0,.85,-.25)],["wide_environment",Vector3(10.5,5.8,11.5),Vector3(-.4,.8,-.7)]]
@onready var camera:Camera3D=$Camera3D
func _ready()->void:
	if "--capture-prototype" in OS.get_cmdline_user_args():capture_views.call_deferred()
func capture_views()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/visual_prototype"))
	for shot in SHOTS:
		camera.global_position=shot[1];camera.look_at(shot[2],Vector3.UP)
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		var path:="res://screenshots/visual_prototype/%s.png"%shot[0]
		print("CAPTURE ",path," error=",get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path)))
	get_tree().quit()
