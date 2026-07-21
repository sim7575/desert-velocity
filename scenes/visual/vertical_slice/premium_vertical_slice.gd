class_name PremiumVerticalSlice
extends Node3D

const SEQUENCE_DURATION := 36.0

var path: Path3D
var curve: Curve3D
var player_follow: PathFollow3D
var opponent_follow: PathFollow3D
var player_visual: Node3D
var opponent_visual: Node3D
var camera_rig: PremiumSliceCamera
var hud: PremiumSliceHUD
var road_mesh: MeshInstance3D
var road_body: StaticBody3D
var dust_emitters: Array[GPUParticles3D] = []
var boost_emitters: Array[GPUParticles3D] = []
var boost_light: OmniLight3D
var sequence_time := 0.0
var sequence_complete := false
var capture_mode := false
var visual_capture_mode := false
var run_metrics := false
var fps_total := 0.0
var fps_samples := 0
var fps_min := INF
var fps_values := PackedFloat32Array()
var peak_draw_calls := 0
var peak_primitives := 0
var peak_nodes := 0
var wheel_spin := 0.0

func _ready() -> void:
	_setup_neutral_environment()
	_setup_track()
	_setup_vehicles()
	_setup_camera_and_hud()
	_setup_effects_and_vehicle_lighting()
	var args := OS.get_cmdline_user_args()
	capture_mode = "--capture-premium-structure" in args
	visual_capture_mode = "--capture-premium-visual" in args
	run_metrics = "--run-premium-structure" in args
	if capture_mode: _capture_technical.call_deferred()
	elif visual_capture_mode: _capture_visual_set.call_deferred()

func _process(delta: float) -> void:
	if capture_mode or visual_capture_mode: return
	if not sequence_complete:
		sequence_time = minf(sequence_time + delta, SEQUENCE_DURATION)
		set_sequence_time(sequence_time)
		_collect_metrics(delta)
		if sequence_time >= SEQUENCE_DURATION:
			sequence_complete = true
			if run_metrics:
				_write_metrics("complete_sequence")
				get_tree().quit()

func set_sequence_time(value: float) -> void:
	sequence_time = clampf(value, 0.0, SEQUENCE_DURATION)
	var ratio := sequence_time / SEQUENCE_DURATION
	var length := curve.get_baked_length()
	var previous_progress := player_follow.progress
	player_follow.progress = ratio * length
	opponent_follow.progress = minf(length, 62.0 + ratio * length * 0.72)
	wheel_spin += absf(player_follow.progress - previous_progress) / 0.35
	_update_vehicle_wheels(player_visual, wheel_spin, _steering_hint(player_follow.progress))
	_update_vehicle_wheels(opponent_visual, wheel_spin * 0.72, _steering_hint(opponent_follow.progress))
	var boost := smoothstep(0.70, 0.76, ratio) * (1.0 - smoothstep(0.97, 1.0, ratio))
	var turn_intensity := absf(_steering_hint(player_follow.progress)) / 0.28
	if camera_rig != null:
		camera_rig.sequence_speed_ratio = clampf(0.35 + ratio * 0.65, 0.0, 1.0)
		camera_rig.boost_strength = boost
	for emitter in dust_emitters:
		emitter.amount_ratio = clampf(0.38 + turn_intensity * 0.34 + boost * 0.28, 0.0, 1.0)
	for emitter in boost_emitters: emitter.emitting = boost > 0.08
	if boost_light != null:
		boost_light.light_energy = boost * 2.2
		boost_light.visible = boost > 0.03
	if hud != null: hud.update_visual(ratio, int(58.0 + ratio * 72.0 + boost * 18.0), boost)
	sequence_complete = sequence_time >= SEQUENCE_DURATION

func structure_metrics() -> Dictionary:
	var metrics := PremiumSliceGeometry.path_metrics(curve)
	metrics["duration"] = SEQUENCE_DURATION
	metrics["road_collision"] = road_body != null and road_body.get_child_count() > 0
	metrics["player_v2"] = player_visual != null and bool(player_visual.get_meta("blender_stallion_v2", false))
	metrics["opponent_v2"] = opponent_visual != null and bool(opponent_visual.get_meta("blender_gt_v2", false))
	metrics["camera_deterministic"] = true
	return metrics

func _setup_neutral_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("1d3554")
	sky_material.sky_horizon_color = Color("bf755c")
	sky_material.ground_bottom_color = Color("282633")
	sky_material.ground_horizon_color = Color("925d50")
	sky_material.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.72
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8da0bf")
	environment.ambient_light_energy = 0.62
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color("a56f62")
	environment.fog_light_energy = 0.62
	environment.fog_density = 0.0030
	environment.fog_sky_affect = 0.38
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.05
	environment.adjustment_contrast = 1.02
	environment.adjustment_saturation = 0.88
	var world_environment := WorldEnvironment.new()
	world_environment.name = "SunsetEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "SunsetKey"
	sun.rotation_degrees = Vector3(-16, -58, 0)
	sun.light_color = Color("ffd1a3")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)

func _setup_track() -> void:
	curve = PremiumSliceGeometry.build_curve()
	path = Path3D.new()
	path.name = "PresentationPath"
	path.curve = curve
	add_child(path)
	var road_material := _shader_material("res://materials/vertical_slice/desert_surface.gdshader", {
		"base_color": Color("454248"), "secondary_color": Color("655a51"), "detail_color": Color("a97d53"),
		"base_roughness": 0.76, "edge_sand": 0.92, "track_strength": 0.74, "micro_strength": 0.46,
	})
	road_mesh = PremiumSliceGeometry.build_road(curve, road_material)
	road_mesh.name = "RoadSurface"
	add_child(road_mesh)
	road_body = StaticBody3D.new()
	road_body.name = "RoadRaycastBody"
	var road_collision := CollisionShape3D.new()
	road_collision.name = "RoadRaycastCollision"
	road_collision.shape = road_mesh.mesh.create_trimesh_shape()
	road_body.add_child(road_collision)
	add_child(road_body)
	var terrain_material := _shader_material("res://materials/vertical_slice/desert_surface.gdshader", {
		"base_color": Color("8c5838"), "secondary_color": Color("b97943"), "detail_color": Color("d6a060"),
		"base_roughness": 0.94, "edge_sand": 0.0, "track_strength": 0.0, "micro_strength": 0.72,
	})
	var terrain := PremiumSliceGeometry.build_terrain(curve, terrain_material)
	terrain.name = "TerrainDetailed"
	add_child(terrain)
	var canyon_material := _shader_material("res://materials/vertical_slice/rock_strata.gdshader", {
		"lower_color": Color("4b2f2a"), "upper_color": Color("86503a"), "strata_color": Color("aa6b43"), "strata_scale": 2.2,
	})
	_setup_canyon_outcrops(canyon_material)
	var track_material := StandardMaterial3D.new()
	track_material.albedo_color = Color(0.08, 0.055, 0.04, 0.28)
	track_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	track_material.roughness = 0.88
	track_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for offset in [-2.0, 2.0]:
		var mark := PremiumSliceGeometry.build_track_mark(curve, offset, track_material)
		mark.name = "TireTrack_%s" % str(offset)
		add_child(mark)
	_setup_rock_obstacle()
	_setup_environment_details(canyon_material)

func _setup_canyon_outcrops(material: Material) -> void:
	var canyon_root := Node3D.new()
	canyon_root.name = "CanyonLayeredOutcrops"
	add_child(canyon_root)
	var length := curve.get_baked_length()
	for i in 14:
		var ratio := 0.035 + float(i) * 0.033
		var frame := PremiumSliceGeometry.sample_frame(curve, length * ratio)
		var cliff := MeshInstance3D.new()
		cliff.name = "CanyonMass%02d" % i
		cliff.mesh = PremiumSliceGeometry.build_rock_mesh(620 + i)
		cliff.material_override = material
		var width := 3.6 + float((i * 5) % 4) * 0.55
		var height := 6.0 + float((i * 7) % 5) * 0.68
		cliff.scale = Vector3(width, height, 4.1 + float(i % 3) * 0.65)
		cliff.position = frame.origin + frame.basis.x * (22.0 + sin(float(i) * 1.7) * 1.8) + Vector3.DOWN * 0.8
		cliff.rotation.y = float(i) * 0.47
		canyon_root.add_child(cliff)
		if i % 2 == 0:
			var buttress := MeshInstance3D.new()
			buttress.name = "CanyonButtress%02d" % i
			buttress.mesh = PremiumSliceGeometry.build_rock_mesh(710 + i)
			buttress.material_override = material
			buttress.scale = Vector3(width * 0.52, height * 0.48, 3.2)
			buttress.position = frame.origin + frame.basis.x * (18.5 + sin(float(i)) * 1.1) + Vector3.DOWN * 0.5
			buttress.rotation.y = float(i) * 0.73
			canyon_root.add_child(buttress)

func _setup_rock_obstacle() -> void:
	var frame := PremiumSliceGeometry.sample_frame(curve, curve.get_baked_length() * 0.61)
	var side := frame.basis.x
	var material := _shader_material("res://materials/vertical_slice/rock_strata.gdshader", {
		"lower_color": Color("392925"), "upper_color": Color("72503e"), "strata_color": Color("946349"), "strata_scale": 3.1,
	})
	var scales := [Vector3(2.4, 2.1, 2.0), Vector3(1.7, 1.5, 1.8), Vector3(1.25, 1.1, 1.4), Vector3(0.8, 0.7, 0.9)]
	var offsets := [side * 2.7, side * 4.3 + Vector3(1, 0, -1), side * 1.2 + Vector3(0, 0, 2.2), side * 5.3 + Vector3(0, 0, 1.6)]
	for i in scales.size():
		var rock := MeshInstance3D.new()
		rock.name = "ObstacleRock%02d" % i
		rock.mesh = PremiumSliceGeometry.build_rock_mesh(90 + i)
		rock.material_override = material
		rock.scale = scales[i]
		rock.position = frame.origin + offsets[i]
		rock.rotation.y = i * 0.83
		rock.add_to_group("premium_slice_obstacle")
		add_child(rock)

func _setup_environment_details(shared_material: Material) -> void:
	var scatter := MultiMeshInstance3D.new()
	scatter.name = "RockScatterMultiMesh"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = PremiumSliceGeometry.build_rock_mesh(212)
	multimesh.instance_count = 64
	var length := curve.get_baked_length()
	for i in multimesh.instance_count:
		var ratio := (float(i) + 0.5) / float(multimesh.instance_count)
		var frame := PremiumSliceGeometry.sample_frame(curve, ratio * length)
		var side_sign := -1.0 if i % 2 == 0 else 1.0
		var lateral := 8.8 + float((i * 7) % 17) * 0.72
		var scale_value := 0.16 + float((i * 11) % 9) * 0.075
		var origin := frame.origin + frame.basis.x * lateral * side_sign + Vector3.DOWN * 0.12
		var basis := Basis(Vector3.UP, float(i) * 0.71).scaled(Vector3(scale_value * (1.0 + float(i % 3) * 0.18), scale_value, scale_value * 0.86))
		multimesh.set_instance_transform(i, Transform3D(basis, origin))
	scatter.multimesh = multimesh
	scatter.material_override = shared_material
	add_child(scatter)
	var hero_ratios := [0.08, 0.19, 0.34, 0.47, 0.74, 0.88]
	for i in hero_ratios.size():
		var frame := PremiumSliceGeometry.sample_frame(curve, length * float(hero_ratios[i]))
		var side_sign := -1.0 if i % 2 == 0 else 1.0
		var hero := MeshInstance3D.new()
		hero.name = "HeroRock%02d" % i
		hero.mesh = PremiumSliceGeometry.build_rock_mesh(400 + i)
		hero.material_override = shared_material
		hero.scale = Vector3(1.25 + (i % 2) * 0.45, 2.15 + (i % 3) * 0.38, 1.05 + (i % 2) * 0.38)
		hero.position = frame.origin + frame.basis.x * side_sign * (13.5 + (i % 3) * 2.8) + Vector3.DOWN * 0.2
		hero.rotation.y = i * 0.91
		add_child(hero)

func _setup_vehicles() -> void:
	player_follow = PathFollow3D.new()
	player_follow.name = "PlayerFollow"
	player_follow.loop = false
	player_follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	path.add_child(player_follow)
	player_visual = VehicleFactory.create_vehicle(0, false)
	player_visual.name = "DesertStallionV2Presentation"
	player_follow.add_child(player_visual)
	opponent_follow = PathFollow3D.new()
	opponent_follow.name = "OpponentFollow"
	opponent_follow.loop = false
	opponent_follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	path.add_child(opponent_follow)
	opponent_visual = VehicleFactory.create_vehicle(1, false)
	opponent_visual.name = "BavarianGTV2Presentation"
	opponent_visual.position.x = 3.6
	opponent_visual.scale = Vector3.ONE * 0.96
	opponent_follow.add_child(opponent_visual)
	set_sequence_time(0.0)

func _setup_camera_and_hud() -> void:
	camera_rig = PremiumSliceCamera.new()
	camera_rig.name = "PremiumCamera"
	add_child(camera_rig)
	camera_rig.configure(player_follow, curve)
	hud = PremiumSliceHUD.new()
	hud.name = "StructureHUD"
	add_child(hud)

func _setup_effects_and_vehicle_lighting() -> void:
	var cool_fill := OmniLight3D.new()
	cool_fill.name = "VehicleCoolFill"
	cool_fill.position = Vector3(1.8, 3.2, 1.2)
	cool_fill.light_color = Color("8fb8e8")
	cool_fill.light_energy = 0.95
	cool_fill.omni_range = 13.0
	cool_fill.shadow_enabled = false
	player_follow.add_child(cool_fill)
	_add_contact_shadow(player_follow, Vector2(2.35, 4.75), 0.30)
	_add_contact_shadow(opponent_follow, Vector2(2.25, 4.55), 0.24)
	for x in [-0.84, 0.84]:
		var dust := GPUParticles3D.new()
		dust.name = "DustRearLeft" if x < 0.0 else "DustRearRight"
		dust.position = Vector3(x, 0.24, 1.48)
		dust.amount = 88
		dust.amount_ratio = 0.45
		dust.lifetime = 0.95
		dust.local_coords = false
		dust.visibility_aabb = AABB(Vector3(-12, -5, -12), Vector3(24, 14, 30))
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(0.18, 0.08, 0.22)
		process.direction = Vector3(0, 0.42, 1.0)
		process.spread = 31.0
		process.initial_velocity_min = 2.2
		process.initial_velocity_max = 6.8
		process.gravity = Vector3(0, -0.32, 0)
		process.scale_min = 0.32
		process.scale_max = 0.92
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.64, 1.0])
		gradient.colors = PackedColorArray([Color(0.68, 0.48, 0.34, 0.0), Color(0.70, 0.50, 0.35, 0.28), Color(0.58, 0.41, 0.31, 0.14), Color(0.52, 0.38, 0.31, 0.0)])
		var gradient_texture := GradientTexture1D.new(); gradient_texture.gradient = gradient
		process.color_initial_ramp = gradient_texture
		dust.process_material = process
		var quad := QuadMesh.new(); quad.size = Vector2(0.68, 0.68); quad.material = _effect_material(Color(0.72, 0.52, 0.37, 0.38), 0.0, true)
		dust.draw_pass_1 = quad
		dust.emitting = true
		player_follow.add_child(dust)
		dust_emitters.append(dust)
	for x in [-0.42, 0.42]:
		var boost := GPUParticles3D.new()
		boost.name = "BoostExhaustLeft" if x < 0.0 else "BoostExhaustRight"
		boost.position = Vector3(x, 0.48, 2.22)
		boost.amount = 42
		boost.lifetime = 0.22
		boost.local_coords = false
		boost.visibility_aabb = AABB(Vector3(-5, -3, -5), Vector3(10, 8, 18))
		var boost_process := ParticleProcessMaterial.new()
		boost_process.direction = Vector3(0, 0.05, 1.0)
		boost_process.spread = 12.0
		boost_process.initial_velocity_min = 8.0
		boost_process.initial_velocity_max = 14.0
		boost_process.gravity = Vector3.ZERO
		boost_process.scale_min = 0.05
		boost_process.scale_max = 0.18
		boost_process.color = Color("74e8ff")
		boost.process_material = boost_process
		var boost_quad := QuadMesh.new(); boost_quad.size = Vector2(0.12, 0.34); boost_quad.material = _effect_material(Color(0.32, 0.88, 1.0, 0.52), 2.4, true)
		boost.draw_pass_1 = boost_quad
		boost.emitting = false
		player_follow.add_child(boost)
		boost_emitters.append(boost)
	boost_light = OmniLight3D.new()
	boost_light.name = "BoostAccentLight"
	boost_light.position = Vector3(0, 0.52, 2.45)
	boost_light.light_color = Color("67dcff")
	boost_light.light_energy = 0.0
	boost_light.omni_range = 7.0
	boost_light.shadow_enabled = false
	boost_light.visible = false
	player_follow.add_child(boost_light)

func _add_contact_shadow(parent: Node3D, size: Vector2, opacity: float) -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "RuntimeContactShadow"
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = _effect_material(Color(0.015, 0.012, 0.012, opacity), 0.0, false)
	shadow.mesh = quad
	shadow.rotation_degrees.x = -90.0
	shadow.position = Vector3(0, 0.035, 0.12)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shadow)

func _update_vehicle_wheels(vehicle: Node3D, spin: float, steering_value: float) -> void:
	if vehicle == null: return
	for wheel_name in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
		var wheel := vehicle.find_child(wheel_name, true, false) as Node3D
		if wheel == null: continue
		wheel.rotation.x = fmod(spin, TAU)
		wheel.rotation.y = steering_value if wheel_name in ["Wheel_FL", "Wheel_FR"] else 0.0

func _steering_hint(progress: float) -> float:
	var before := PremiumSliceGeometry.sample_frame(curve, maxf(0.0, progress - 4.0))
	var after := PremiumSliceGeometry.sample_frame(curve, minf(curve.get_baked_length(), progress + 4.0))
	var signed_turn := (-before.basis.z).signed_angle_to(-after.basis.z, Vector3.UP)
	return clampf(signed_turn * 1.8, -0.28, 0.28)

func _collect_metrics(delta: float) -> void:
	if delta > 0.0 and sequence_time > 1.0:
		var frame_fps := 1.0 / delta
		fps_total += frame_fps
		fps_samples += 1
		fps_min = minf(fps_min, frame_fps)
		fps_values.append(frame_fps)
	peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	peak_primitives = maxi(peak_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))

func _capture_technical() -> void:
	set_sequence_time(13.0)
	camera_rig.snap_to_target()
	for _i in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/premium_vertical_slice"))
	var image := get_viewport().get_texture().get_image()
	var path_name := "res://screenshots/premium_vertical_slice/structure_technical.png"
	var error := image.save_png(ProjectSettings.globalize_path(path_name))
	_collect_metrics(maxf(get_process_delta_time(), 0.0001))
	_write_metrics("technical_capture")
	print("PREMIUM_STRUCTURE_CAPTURE ", path_name, " error=", error)
	get_tree().quit(0 if error == OK else 1)

func _capture_visual_set() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/premium_vertical_slice"))
	var shots := [
		["01_chase_curve", 8.5, false],
		["02_descent_maneuver", 15.5, false],
		["03_jump_boost", 27.5, false],
		["04_canyon_wide", 21.5, true],
	]
	var capture_errors := 0
	for shot in shots:
		var target_time := float(shot[1])
		var start_time := maxf(0.0, target_time - 0.72)
		set_sequence_time(start_time)
		camera_rig.manual_capture = false
		camera_rig.snap_to_target()
		if bool(shot[2]):
			var frame := PremiumSliceGeometry.sample_frame(curve, player_follow.progress)
			var forward := -frame.basis.z
			camera_rig.manual_capture = true
			camera_rig.global_position = player_follow.global_position - forward * 4.8 + frame.basis.x * 3.3 + Vector3.UP * 2.9
			camera_rig.look_at(player_follow.global_position + forward * 8.0 + Vector3.UP * 0.85, Vector3.UP)
		for frame_index in 44:
			set_sequence_time(minf(target_time, start_time + float(frame_index + 1) / 60.0))
			await get_tree().process_frame
			_collect_metrics(maxf(get_process_delta_time(), 0.0001))
		await RenderingServer.frame_post_draw
		var output_path := "res://screenshots/premium_vertical_slice/%s.png" % str(shot[0])
		var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(output_path))
		if error != OK: capture_errors += 1
		print("PREMIUM_VISUAL_CAPTURE ", output_path, " error=", error)
	camera_rig.manual_capture = false
	_write_metrics("visual_captures")
	get_tree().quit(0 if capture_errors == 0 else 1)

func _write_metrics(mode: String) -> void:
	var structure := structure_metrics()
	var stability := camera_rig.structural_stability()
	var report := "Premium vertical slice structure metrics\n"
	report += "mode=%s\n" % mode
	report += "duration_seconds=%.2f\n" % SEQUENCE_DURATION
	report += "path_length_m=%.2f\n" % float(structure.path_length)
	report += "wide_curve_degrees=%.2f\n" % float(structure.wide_curve_degrees)
	report += "elevation_drop_m=%.2f\n" % float(structure.elevation_drop)
	report += "bump_prominence_m=%.2f\n" % float(structure.bump_prominence)
	report += "continuity_max_gap_m=%.3f\n" % float(structure.continuity_max_gap)
	report += "average_fps=%.2f\n" % (fps_total / maxi(1, fps_samples))
	report += "minimum_fps=%.2f\n" % (fps_min if fps_min < INF else 0.0)
	report += "low_5_percentile_fps=%.2f\n" % _low_percentile_fps()
	report += "peak_draw_calls=%d\n" % peak_draw_calls
	report += "peak_primitives=%d\n" % peak_primitives
	report += "peak_nodes=%d\n" % peak_nodes
	report += "camera_max_frame_step_m=%.3f\n" % float(stability.max_frame_step)
	var camera_config := camera_rig.composition_configuration()
	report += "camera_previous_distance_m=%.2f\n" % float(camera_config.previous_distance)
	report += "camera_distance_m=%.2f\n" % float(camera_config.distance)
	report += "camera_previous_height_m=%.2f\n" % float(camera_config.previous_height)
	report += "camera_height_m=%.2f\n" % float(camera_config.height)
	report += "camera_previous_fov=%.2f\n" % float(camera_config.previous_fov)
	report += "camera_base_fov=%.2f\n" % float(camera_config.base_fov)
	report += "camera_lateral_offset_m=%.2f\n" % float(camera_config.lateral_offset)
	report += "camera_look_ahead_m=%.2f\n" % float(camera_config.look_ahead)
	var file := FileAccess.open("res://reports/premium_vertical_slice_metrics.txt", FileAccess.WRITE)
	file.store_string(report)
	file.close()
	print(report)

func _low_percentile_fps() -> float:
	if fps_values.is_empty(): return 0.0
	var sorted := fps_values.duplicate()
	sorted.sort()
	var index := clampi(int(floor(float(sorted.size() - 1) * 0.05)), 0, sorted.size() - 1)
	return sorted[index]

func _shader_material(path_name: String, parameters: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(path_name) as Shader
	for key in parameters: material.set_shader_parameter(str(key), parameters[key])
	return material

func _effect_material(color: Color, emission: float, billboard: bool) -> ShaderMaterial:
	return _shader_material("res://materials/vertical_slice/effect_billboard.gdshader", {
		"tint": color,
		"emission_strength": emission,
		"soft_edge": 0.30,
		"billboard_mode": 1.0 if billboard else 0.0,
	})
