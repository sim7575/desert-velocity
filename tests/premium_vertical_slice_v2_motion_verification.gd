extends SceneTree

const VIDEO_PATH := "res://captures/premium_vertical_slice_v2/premium_vertical_slice_v2_motion_review.avi"
const FRAME_ROOT := "res://screenshots/premium_vertical_slice_v2/motion_review"
const WIDTH := 1280.0
const HEIGHT := 720.0
const FPS := 60.0
const FRAME_COUNT := 2281

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("PREMIUM_SLICE_V2_MOTION_TEST_START")
	var packed := load("res://scenes/visual/PremiumVerticalSliceV2.tscn") as PackedScene
	_check(packed != null, "PremiumVerticalSliceV2.tscn did not load")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate() as PremiumVerticalSliceV2
	root.add_child(scene)
	for _frame in 12:
		await process_frame
	scene.capture_mode = true
	scene.set_process(false)
	scene.camera_rig.manual_capture = true
	scene.set_sequence_time(0.0)
	scene.camera_rig.snap_to_target()

	var previous_camera_position := scene.camera_rig.global_position
	var previous_forward := -scene.camera_rig.global_basis.z.normalized()
	var previous_dust := scene.dust_emitters[0].amount_ratio
	var max_camera_step := 0.0
	var max_camera_angle := 0.0
	var max_dust_step := 0.0
	var max_obstacle_coverage := 0.0
	var min_player_x := WIDTH
	var max_player_x := 0.0
	var min_player_y := HEIGHT
	var max_player_y := 0.0
	var fov_before_boost := 0.0
	var fov_peak := 0.0
	var fov_after_boost := 0.0

	for frame_index in FRAME_COUNT:
		var time := minf(float(frame_index) / FPS, PremiumVerticalSliceV2.SEQUENCE_DURATION)
		scene.set_sequence_time(time)
		scene.camera_rig.manual_capture = false
		scene.camera_rig._process(1.0 / FPS)
		scene.camera_rig.manual_capture = true
		var camera_position := scene.camera_rig.global_position
		var camera_forward := -scene.camera_rig.global_basis.z.normalized()
		if frame_index > 0:
			max_camera_step = maxf(max_camera_step, previous_camera_position.distance_to(camera_position))
			max_camera_angle = maxf(max_camera_angle, previous_forward.angle_to(camera_forward))
			max_dust_step = maxf(max_dust_step, absf(scene.dust_emitters[0].amount_ratio - previous_dust))
		previous_camera_position = camera_position
		previous_forward = camera_forward
		previous_dust = scene.dust_emitters[0].amount_ratio
		var player_screen := scene.camera_rig.unproject_position(scene.player_visual.global_position + Vector3.UP * 0.8)
		min_player_x = minf(min_player_x, player_screen.x)
		max_player_x = maxf(max_player_x, player_screen.x)
		min_player_y = minf(min_player_y, player_screen.y)
		max_player_y = maxf(max_player_y, player_screen.y)
		if time >= 21.5 and time <= 24.0:
			max_obstacle_coverage = maxf(max_obstacle_coverage, _obstacle_screen_coverage(scene))
		if absf(time - 27.8) < 0.009:
			fov_before_boost = scene.camera_rig.fov
		if time >= 30.0 and time <= 34.0:
			fov_peak = maxf(fov_peak, scene.camera_rig.fov)
		if absf(time - 37.8) < 0.009:
			fov_after_boost = scene.camera_rig.fov

	_check(max_camera_step < 0.38, "camera position has a discontinuity: %.3f m/frame" % max_camera_step)
	_check(max_camera_angle < 0.035, "camera look direction has a discontinuity: %.4f rad/frame" % max_camera_angle)
	_check(min_player_x > 180.0 and max_player_x < 1100.0, "player left the horizontal composition safe area")
	_check(min_player_y > 150.0 and max_player_y < 650.0, "player left the vertical composition safe area")
	_check(max_obstacle_coverage < 0.32, "obstacle occludes too much of the frame: %.3f" % max_obstacle_coverage)
	_check(max_dust_step < 0.035, "dust amount pops between frames: %.4f" % max_dust_step)
	_check(fov_peak > fov_before_boost + 1.5, "boost FOV does not rise progressively")
	_check(fov_peak <= 74.05, "boost FOV exceeds the approved ceiling")
	_check(fov_after_boost < fov_peak - 1.0, "boost FOV does not return smoothly")
	_verify_beats(scene)
	_verify_effects_and_hud(scene)
	_verify_capture_files()
	print("PREMIUM_SLICE_V2_MOTION_METRICS camera_step=%.3f camera_angle=%.4f dust_step=%.4f obstacle_coverage=%.3f player_screen=[%.1f,%.1f]-[%.1f,%.1f] fov=%.2f/%.2f/%.2f" % [max_camera_step, max_camera_angle, max_dust_step, max_obstacle_coverage, min_player_x, min_player_y, max_player_x, max_player_y, fov_before_boost, fov_peak, fov_after_boost])
	scene.queue_free()
	for _frame in 8:
		await process_frame
	_finish()

func _verify_beats(scene: PremiumVerticalSliceV2) -> void:
	scene.set_sequence_time(0.0)
	var opening_progress := scene.player_follow.progress
	scene.set_sequence_time(7.0)
	_check(absf(scene._steering_hint(scene.player_follow.progress)) > 0.05, "wide curve motion beat is missing")
	scene.set_sequence_time(10.0)
	var gap_before := scene.opponent_follow.progress - scene.player_follow.progress
	scene.set_sequence_time(15.0)
	var gap_after := scene.opponent_follow.progress - scene.player_follow.progress
	_check(gap_before > 0.0 and gap_after < 0.0, "overtake is not completed in motion")
	scene.set_sequence_time(18.0)
	_check(scene.player_follow.global_position.y < -5.0, "descent/canyon beat is missing")
	scene.set_sequence_time(22.7)
	_check(scene.player_visual.position.x < -1.0, "obstacle avoidance trajectory is not readable")
	scene.set_sequence_time(27.0)
	_check(scene.player_visual.position.y > 0.70, "jump beat is missing")
	scene.set_sequence_time(31.0)
	_check(scene.camera_rig.boost_strength > 0.5, "boost beat is missing")
	scene.set_sequence_time(34.0)
	_check(scene.arch_landmark.global_position.distance_to(scene.player_follow.global_position) < 90.0, "arch approach is not reached")
	scene.set_sequence_time(36.0)
	_check(scene.player_follow.progress > scene.curve.get_baked_length() * 0.94, "arch crossing is not reached")
	scene.set_sequence_time(38.0)
	_check(scene.sequence_complete and scene.player_follow.progress_ratio > 0.99, "final exit is incomplete")
	_check(opening_progress == 0.0, "sequence does not start at the route origin")

func _verify_effects_and_hud(scene: PremiumVerticalSliceV2) -> void:
	scene.set_sequence_time(31.0)
	_check(scene.boost_emitters.all(func(emitter: GPUParticles3D) -> bool: return emitter.emitting), "boost flames are not active together")
	_check(scene.boost_light.light_color.r > scene.boost_light.light_color.b, "boost accent is not warm")
	_check(scene.dust_emitters.size() == 2, "rear-wheel dust emitters changed")
	_check(scene.dust_emitters[0].amount_ratio > 0.45, "dust does not intensify during boost")
	_check(scene.hud.speed_label.text.length() == 3, "HUD speed number is unstable")
	_check(scene.hud.cue_label.position.x >= 40.0 and scene.hud.cue_label.position.x + scene.hud.cue_label.size.x <= WIDTH - 40.0, "HUD cue leaves the safe area")
	_check(scene.hud.speed_label.position.y + scene.hud.speed_label.size.y <= HEIGHT - 40.0, "HUD speed leaves the safe area")
	_check(scene.hud.boost_label.position.x + scene.hud.boost_label.size.x <= WIDTH - 40.0, "HUD boost leaves the safe area")

func _obstacle_screen_coverage(scene: PremiumVerticalSliceV2) -> float:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT))
	var max_coverage := 0.0
	for child in scene.obstacle_root.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var aabb := mesh_instance.mesh.get_aabb()
		var projected := Rect2()
		var has_point := false
		for x in [aabb.position.x, aabb.end.x]:
			for y in [aabb.position.y, aabb.end.y]:
				for z in [aabb.position.z, aabb.end.z]:
					var world_point := mesh_instance.global_transform * Vector3(x, y, z)
					if scene.camera_rig.is_position_behind(world_point):
						continue
					var screen_point := scene.camera_rig.unproject_position(world_point)
					if not has_point:
						projected = Rect2(screen_point, Vector2.ZERO)
						has_point = true
					else:
						projected = projected.expand(screen_point)
		if has_point:
			var clipped := projected.intersection(viewport_rect)
			max_coverage = maxf(max_coverage, clipped.get_area() / viewport_rect.get_area())
	return max_coverage

func _verify_capture_files() -> void:
	_check(FileAccess.file_exists(VIDEO_PATH), "motion review AVI is missing")
	if FileAccess.file_exists(VIDEO_PATH):
		var file := FileAccess.open(VIDEO_PATH, FileAccess.READ)
		_check(file.get_length() > 100_000_000, "motion review AVI is unexpectedly small")
		var riff := file.get_buffer(12)
		_check(riff.slice(0, 4).get_string_from_ascii() == "RIFF" and riff.slice(8, 12).get_string_from_ascii() == "AVI ", "motion review file is not an AVI container")
		file.close()
	var frame_names := [
		"01_start_00.8s.png", "02_curve_06.5s.png", "03_overtake_setup_10.5s.png", "04_overtake_13.5s.png",
		"05_descent_17.5s.png", "06_canyon_20.0s.png", "07_obstacle_22.7s.png", "08_jump_27.0s.png",
		"09_boost_start_29.7s.png", "10_boost_31.5s.png", "11_arch_approach_34.0s.png", "12_arch_crossing_35.5s.png",
		"13_arch_exit_36.8s.png", "14_final_37.8s.png",
	]
	for file_name in frame_names:
		var path: String = FRAME_ROOT + "/" + String(file_name)
		_check(FileAccess.file_exists(path), "motion review frame is missing: " + file_name)
		if FileAccess.file_exists(path):
			var texture := load(path) as Texture2D
			_check(texture != null and texture.get_width() == int(WIDTH) and texture.get_height() == int(HEIGHT), "motion review frame has invalid dimensions: " + file_name)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PREMIUM_SLICE_V2_MOTION_TEST_RESULT PASS")
	else:
		for failure in failures:
			printerr("PREMIUM_SLICE_V2_MOTION_FAIL ", failure)
		print("PREMIUM_SLICE_V2_MOTION_TEST_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
