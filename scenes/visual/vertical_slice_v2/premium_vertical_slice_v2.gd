class_name PremiumVerticalSliceV2
extends Node3D

const SEQUENCE_DURATION := 38.0
const KIT_SCENE := preload("res://scenes/visual/assets/EnvironmentKitV2.tscn")
const STALLION_SCENE := preload("res://scenes/visual/assets/DesertStallionV3Visual.tscn")
const SCREENSHOT_ROOT := "res://screenshots/premium_vertical_slice_v2"
const REVISION_SCREENSHOT_ROOT := "res://screenshots/premium_vertical_slice_v2/revision"
const SLICE_SURFACE_SHADER := preload("res://assets/shaders/vertical_slice_v2/premium_slice_surface.gdshader")
const SOFT_PARTICLE_SHADER := preload("res://scenes/visual/vertical_slice_v2/soft_particle_v2.gdshader")
const BOOST_PARTICLE_SHADER := preload("res://scenes/visual/vertical_slice_v2/boost_particle_v2.gdshader")
const CONTACT_SHADOW_SHADER := preload("res://scenes/visual/vertical_slice_v2/contact_shadow_v2.gdshader")

var curve: Curve3D
var path: Path3D
var player_follow: PathFollow3D
var opponent_follow: PathFollow3D
var player_visual: DesertStallionV3Visual
var opponent_visual: DesertStallionV3Visual
var environment_library: EnvironmentKitV2
var camera_rig: PremiumSliceV2Camera
var hud: PremiumSliceV2HUD
var environment_root: Node3D
var road_mesh: MeshInstance3D
var terrain_mesh: MeshInstance3D
var arch_landmark: MeshInstance3D
var obstacle_root: Node3D
var multimesh_root: Node3D
var dust_emitters: Array[GPUParticles3D] = []
var boost_emitters: Array[GPUParticles3D] = []
var boost_light: OmniLight3D
var local_audio: AudioManager
var sequence_time := 0.0
var sequence_complete := false
var capture_mode := false
var metrics_mode := false
var boost_triggered := false
var load_time_ms := 0.0
var fps_total := 0.0
var fps_samples := 0
var fps_values := PackedFloat32Array()
var instantaneous_minimum_fps := INF
var peak_draw_calls := 0
var peak_primitives := 0
var peak_nodes := 0
var peak_memory := 0
var wheel_spin := 0.0
var comparison_overlay: TextureRect
var comparison_caption: Label

func _ready() -> void:
	var start := Time.get_ticks_usec()
	_setup_golden_hour()
	_setup_path_and_surfaces()
	_setup_environment_kit()
	_setup_vehicles()
	_setup_camera_hud_and_comparison()
	_setup_dust_and_boost()
	_setup_local_audio()
	load_time_ms = (Time.get_ticks_usec() - start) / 1000.0
	var args := OS.get_cmdline_user_args()
	capture_mode = "--capture-premium-vertical-slice-v2" in args
	metrics_mode = "--run-premium-vertical-slice-v2-metrics" in args
	if capture_mode:
		_capture_set.call_deferred()
	else:
		set_sequence_time(0.0)

func _process(delta: float) -> void:
	if capture_mode or sequence_complete:
		return
	sequence_time = minf(sequence_time + delta, SEQUENCE_DURATION)
	set_sequence_time(sequence_time)
	_collect_metrics(delta)
	if sequence_time >= SEQUENCE_DURATION:
		sequence_complete = true
		_write_metrics("complete_sequence")
		get_tree().quit()

func set_sequence_time(value: float) -> void:
	sequence_time = clampf(value, 0.0, SEQUENCE_DURATION)
	var ratio := sequence_time / SEQUENCE_DURATION
	var length := curve.get_baked_length()
	var previous_progress := player_follow.progress
	player_follow.progress = ratio * length
	opponent_follow.progress = minf(length, 70.0 + ratio * length * 0.70)
	var overtake_lane := -1.35 * smoothstep(0.20, 0.29, ratio) * (1.0 - smoothstep(0.43, 0.50, ratio))
	var obstacle_lane := -1.75 * smoothstep(0.53, 0.58, ratio) * (1.0 - smoothstep(0.66, 0.70, ratio))
	player_visual.position.x = -0.22 + overtake_lane + obstacle_lane
	player_visual.position.y = 0.06 + _jump_height(ratio)
	player_visual.position.z = -0.25
	opponent_visual.position.x = 3.10
	opponent_visual.position.y = 0.05
	wheel_spin += absf(player_follow.progress - previous_progress) / 0.36
	_update_wheels(player_visual, wheel_spin, _steering_hint(player_follow.progress))
	_update_wheels(opponent_visual, wheel_spin * 0.70, _steering_hint(opponent_follow.progress))
	var boost := smoothstep(0.74, 0.79, ratio) * (1.0 - smoothstep(0.91, 0.96, ratio))
	var turn := absf(_steering_hint(player_follow.progress)) / 0.30
	var jump := clampf(_jump_height(ratio) / 0.82, 0.0, 1.0)
	camera_rig.speed_ratio = clampf(0.38 + ratio * 0.62, 0.0, 1.0)
	camera_rig.boost_strength = boost
	for emitter in dust_emitters:
		emitter.amount_ratio = clampf(0.34 + turn * 0.38 + jump * 0.24 + boost * 0.24, 0.0, 0.92)
	for emitter in boost_emitters:
		emitter.emitting = boost > 0.06
	boost_light.visible = boost > 0.04
	boost_light.light_energy = boost * 1.35
	var speed := int(72.0 + ratio * 58.0 + boost * 24.0)
	hud.update_hud(ratio, speed, boost)
	if local_audio != null:
		local_audio.update_engine(speed / 3.6, 0.72 + boost * 0.28, true, turn > 0.45, "GRAVEL")
		if boost > 0.55 and not boost_triggered:
			boost_triggered = true
			local_audio.play("turbo")
	sequence_complete = sequence_time >= SEQUENCE_DURATION

func structure_metrics() -> Dictionary:
	var result := PremiumSliceV2Geometry.path_metrics(curve)
	result["duration"] = SEQUENCE_DURATION
	result["player_v3"] = player_visual != null and player_visual.active_variant == "rally_sand" and player_visual.active_lod == 0
	result["opponent_v3"] = opponent_visual != null and opponent_visual.active_variant == "night_raid" and opponent_visual.active_lod == 1
	result["environment_kit_v2"] = environment_library != null and bool(environment_library.get_meta("environment_kit_v2_visual", false))
	result["arch_landmark"] = arch_landmark != null
	result["obstacle"] = obstacle_root != null and obstacle_root.get_child_count() >= 3
	result["multimesh_groups"] = multimesh_root.get_child_count() if multimesh_root != null else 0
	result["camera_deterministic"] = true
	result["dust_v2"] = dust_emitters.size() == 2
	result["boost_v2"] = boost_emitters.size() == 2 and boost_light != null
	result["hud_v2"] = hud != null
	result["audio_local"] = local_audio != null
	return result

func _setup_golden_hour() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("56788f")
	sky_material.sky_horizon_color = Color("d7b78d")
	sky_material.ground_bottom_color = Color("4c5b69")
	sky_material.ground_horizon_color = Color("d7b78d")
	sky_material.sky_curve = 0.12
	sky_material.ground_curve = 0.18
	sky_material.sun_angle_max = 2.2
	sky_material.sun_curve = 0.055
	var sky := Sky.new(); sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d6d6cf")
	environment.ambient_light_energy = 0.91
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.86
	environment.fog_enabled = true
	environment.fog_light_color = Color("c3ad91")
	environment.fog_light_energy = 0.48
	environment.fog_density = 0.00125
	environment.fog_sky_affect = 0.20
	var world := WorldEnvironment.new(); world.name = "GoldenHourEnvironment"; world.environment = environment; add_child(world)
	var key := DirectionalLight3D.new()
	key.name = "GoldenHourKey"; key.rotation_degrees = Vector3(-31, -48, 0); key.light_color = Color("f2b66f"); key.light_energy = 1.02
	key.shadow_enabled = true; key.shadow_blur = 1.35; key.directional_shadow_max_distance = 190.0; add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "CoolFill"; fill.rotation_degrees = Vector3(-25, 136, 0); fill.light_color = Color("8faec2"); fill.light_energy = 0.78; add_child(fill)

func _setup_path_and_surfaces() -> void:
	curve = PremiumSliceV2Geometry.build_curve()
	path = Path3D.new(); path.name = "CinematicPath"; path.curve = curve; add_child(path)

func _setup_environment_kit() -> void:
	environment_library = KIT_SCENE.instantiate() as EnvironmentKitV2
	environment_library.name = "EnvironmentKitV2Library"
	add_child(environment_library)
	environment_library.visible = false
	environment_root = Node3D.new(); environment_root.name = "IntegratedEnvironmentV2"; add_child(environment_root)
	road_mesh = PremiumSliceV2Geometry.build_road(curve, _slice_surface_material(1.0, "road")); road_mesh.name = "WeatheredRoadV2"; environment_root.add_child(road_mesh)
	terrain_mesh = PremiumSliceV2Geometry.build_terrain(curve, _slice_surface_material(0.0, "ground")); terrain_mesh.name = "LayeredTerrainV2"; environment_root.add_child(terrain_mesh)
	for side in [-1.0, 1.0]:
		var shoulder := PremiumSliceV2Geometry.build_shoulder(curve, side, _slice_surface_material(2.0, "shoulder"))
		shoulder.name = "DustyShoulderLeft" if side < 0.0 else "DustyShoulderRight"
		environment_root.add_child(shoulder)
	var mark_material := StandardMaterial3D.new(); mark_material.albedo_color = Color(0.12, 0.105, 0.09, 0.24); mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mark_material.roughness = 0.96; mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for offset in [-1.65, 1.65]:
		var mark := PremiumSliceV2Geometry.build_track_mark(curve, offset, mark_material); mark.name = "WornTrack"; environment_root.add_child(mark)
	_place_environment_modules()
	_build_multimesh_scatter()

func _slice_surface_material(kind: float, label: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "F1_1_%s_E2_1_Derivative" % label
	material.shader = SLICE_SURFACE_SHADER
	material.set_shader_parameter("surface_kind", kind)
	material.set_shader_parameter("detail_strength", 0.72)
	material.set_meta("environment_kit_v2_source", true)
	material.set_meta("e2_1_base_preserved", true)
	return material

func _place_environment_modules() -> void:
	var placements := [
		["HeroRock_A_SplitCrown", 0.10, -13.5, -0.28, Vector3(0.85, 0.85, 0.85), -0.18, 0],
		["HeroRock_B_LeaningStack", 0.25, 14.0, -0.24, Vector3(0.78, 0.78, 0.78), 0.24, 0],
		["HeroRock_C_BrokenButte", 0.47, -14.8, -0.32, Vector3(0.76, 0.76, 0.76), -0.31, 0],
		["CanyonWall_A_Concave", 0.43, 17.0, -0.62, Vector3(0.92, 0.92, 0.92), -1.04, 0],
		["CanyonWall_B_Stepped", 0.55, -16.0, -0.58, Vector3(0.86, 0.86, 0.86), 1.02, 0],
		["CanyonWall_A_Concave", 0.64, 14.5, -0.55, Vector3(0.78, 0.78, 0.78), -1.11, 1],
		["CanyonWall_B_Stepped", 0.69, -13.8, -0.55, Vector3(0.74, 0.74, 0.74), 1.08, 1],
		["DistantMesa_A", 0.42, -54.0, -2.2, Vector3(1.65, 1.65, 1.65), 0.18, 2],
		["DistantMesa_B", 0.68, 57.0, -2.0, Vector3(1.72, 1.72, 1.72), -0.20, 2],
		["NarrativeWreck_SurveyRover", 0.34, -9.2, -0.10, Vector3(0.80, 0.80, 0.80), 0.38, 1],
		["RoadSign_Direction", 0.19, 7.0, -0.06, Vector3.ONE, -0.12, 1],
		["RoadSign_Hazard", 0.54, -6.8, -0.06, Vector3.ONE, 0.10, 1],
		["SafetyBarrier_01", 0.31, 6.4, -0.06, Vector3(0.94, 0.94, 0.94), -0.05, 1],
		["Dune_01", 0.16, -8.5, -0.28, Vector3(1.8, 0.34, 1.8), 0.22, 1],
		["Dune_02", 0.39, 9.0, -0.30, Vector3(1.7, 0.30, 1.7), -0.18, 1],
		["Dune_03", 0.58, -9.5, -0.30, Vector3(1.9, 0.30, 1.9), 0.12, 1],
		["HeroRock_B_LeaningStack", 0.76, 15.2, -0.30, Vector3(0.72, 0.72, 0.72), -0.92, 1],
		["CanyonWall_A_Concave", 0.80, -17.5, -0.58, Vector3(0.76, 0.76, 0.76), 0.96, 1],
		["HeroRock_C_BrokenButte", 0.85, 17.2, -0.34, Vector3(0.68, 0.68, 0.68), -0.74, 1],
		["CanyonWall_B_Stepped", 0.89, -16.4, -0.62, Vector3(0.74, 0.74, 0.74), 0.88, 1],
		["DistantMesa_A", 0.83, 62.0, -2.4, Vector3(1.55, 1.55, 1.55), -0.24, 2],
		["DistantMesa_B", 0.91, -60.0, -2.4, Vector3(1.62, 1.62, 1.62), 0.22, 2],
		["Dune_02", 0.78, -10.0, -0.30, Vector3(1.8, 0.32, 1.8), 0.16, 1],
		["Dune_01", 0.88, 9.5, -0.30, Vector3(1.7, 0.30, 1.7), -0.15, 1],
		["NarrativeWreck_SurveyRover", 0.72, 8.6, -0.12, Vector3(0.72, 0.72, 0.72), -0.42, 1],
		["RoadSign_Hazard", 0.73, -6.9, -0.06, Vector3(0.92, 0.92, 0.92), 0.12, 1],
		["SafetyBarrier_01", 0.82, 6.6, -0.06, Vector3(0.88, 0.88, 0.88), -0.08, 1],
		["RoadEdge_BrokenShoulder_A", 0.74, -5.9, -0.10, Vector3(0.90, 0.40, 2.1), 0.0, 1],
		["RoadEdge_BrokenShoulder_B", 0.86, 5.9, -0.10, Vector3(0.90, 0.40, 2.1), 0.0, 1],
		["RoadEdge_BrokenShoulder_A", 0.23, -5.7, -0.10, Vector3(0.92, 0.42, 2.3), 0.0, 1],
		["RoadEdge_BrokenShoulder_B", 0.49, 5.7, -0.10, Vector3(0.92, 0.42, 2.3), 0.0, 1],
	]
	for item in placements:
		_place_asset(item[0], item[1], item[2], item[3], item[4], item[5], item[6], environment_root)
	for index in 18:
		var ratio := 0.045 + index * 0.051
		var side := -1.0 if index % 2 == 0 else 1.0
		_place_asset("MediumRock_%02d" % (1 + index % 6), ratio, side * (7.6 + index % 4 * 1.45), -0.12, Vector3.ONE * (0.48 + index % 3 * 0.11), index * 0.51, 1, environment_root)
	obstacle_root = Node3D.new(); obstacle_root.name = "ReadableObstacleGroup"; environment_root.add_child(obstacle_root)
	# Keep the authored avoidance beat while leaving a clean chase-camera corridor.
	# The F1.2 motion capture showed the former 1.7 m placement crossing the lens.
	_place_asset("MediumRock_02", 0.59, 4.4, -0.02, Vector3(1.00, 0.96, 1.00), 0.3, 0, obstacle_root)
	_place_asset("MediumRock_05", 0.59, 5.2, -0.06, Vector3(0.86, 0.78, 0.86), -0.4, 0, obstacle_root)
	_place_asset("SmallRock_04", 0.595, 5.8, -0.04, Vector3(0.70, 0.58, 0.70), 0.8, 1, obstacle_root)
	arch_landmark = _place_asset("RockArch_01", 0.945, 0.0, -0.34, Vector3(0.92, 0.92, 0.92), 0.0, 0, environment_root)
	arch_landmark.name = "RockArchFinalLandmark"

func _place_asset(asset_name: String, ratio: float, lateral: float, vertical: float, scale_value: Vector3, yaw: float, lod: int, parent: Node3D) -> MeshInstance3D:
	var source := environment_library.asset(asset_name, lod)
	if source == null: return null
	var frame := PremiumSliceV2Geometry.sample_frame(curve, curve.get_baked_length() * ratio)
	var copy := MeshInstance3D.new(); copy.name = "%s_L%d" % [asset_name, lod]; copy.mesh = source.mesh; copy.material_override = source.get_active_material(0)
	copy.transform = Transform3D(frame.basis * Basis(Vector3.UP, yaw), frame.origin + frame.basis.x * lateral + Vector3.UP * vertical)
	copy.scale = scale_value
	copy.set_meta("environment_lod", lod)
	parent.add_child(copy)
	return copy

func _build_multimesh_scatter() -> void:
	multimesh_root = Node3D.new(); multimesh_root.name = "EnvironmentScatterMultiMesh"; environment_root.add_child(multimesh_root)
	_scatter_asset("SmallRock_02", 2, 82, 1201, 0.02, 0.96, 5.9, 13.5, 0.18, 0.52)
	_scatter_asset("DebrisGravelCluster", 2, 66, 1301, 0.04, 0.94, 5.6, 10.5, 0.20, 0.54)
	_scatter_asset("Cactus_01", 2, 24, 1409, 0.05, 0.92, 8.2, 16.0, 0.46, 0.84)
	_scatter_asset("DryBush_01", 2, 44, 1511, 0.03, 0.95, 6.8, 13.0, 0.36, 0.72)
	_scatter_asset("SmallRock_07", 2, 54, 1601, 0.30, 0.94, 5.6, 10.0, 0.16, 0.42)
	_scatter_asset("MediumRock_01", 2, 22, 1709, 0.12, 0.92, 7.0, 14.0, 0.24, 0.48)
	_scatter_asset("Dune_03", 2, 18, 1801, 0.08, 0.94, 10.0, 24.0, 0.42, 0.80)

func _scatter_asset(asset_name: String, lod: int, count: int, seed: int, min_ratio: float, max_ratio: float, min_side: float, max_side: float, min_scale: float, max_scale: float) -> void:
	var source := environment_library.asset(asset_name, lod)
	if source == null: return
	var instance := MultiMeshInstance3D.new(); instance.name = asset_name + "Scatter"
	var multimesh := MultiMesh.new(); multimesh.transform_format = MultiMesh.TRANSFORM_3D; multimesh.mesh = source.mesh; multimesh.instance_count = count
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	for index in count:
		var ratio := rng.randf_range(min_ratio, max_ratio)
		var frame := PremiumSliceV2Geometry.sample_frame(curve, curve.get_baked_length() * ratio)
		var side := -1.0 if index % 2 == 0 else 1.0
		var position_value := frame.origin + frame.basis.x * side * rng.randf_range(min_side, max_side) + Vector3.UP * rng.randf_range(-0.15, -0.02)
		var scale_value := rng.randf_range(min_scale, max_scale)
		var basis := frame.basis * Basis(Vector3.UP, rng.randf_range(-PI, PI)); basis = basis.scaled(Vector3(scale_value, scale_value * rng.randf_range(0.75, 1.1), scale_value))
		multimesh.set_instance_transform(index, Transform3D(basis, position_value))
	instance.multimesh = multimesh; instance.material_override = source.get_active_material(0); instance.visibility_range_end = 115.0; instance.visibility_range_end_margin = 18.0
	multimesh_root.add_child(instance)

func _setup_vehicles() -> void:
	player_follow = PathFollow3D.new(); player_follow.name = "PlayerFollowV3"; player_follow.loop = false; player_follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED; path.add_child(player_follow)
	player_visual = STALLION_SCENE.instantiate() as DesertStallionV3Visual; player_visual.name = "DesertStallionV3RallySand"; player_visual.set_variant("rally_sand"); player_visual.set_lod(0); player_follow.add_child(player_visual)
	opponent_follow = PathFollow3D.new(); opponent_follow.name = "OpponentFollowV3"; opponent_follow.loop = false; opponent_follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED; path.add_child(opponent_follow)
	opponent_visual = STALLION_SCENE.instantiate() as DesertStallionV3Visual; opponent_visual.name = "DesertStallionV3NightRaidOpponent"; opponent_visual.set_variant("night_raid"); opponent_visual.set_lod(1); opponent_follow.add_child(opponent_visual)
	_apply_vehicle_configuration.call_deferred()

func _apply_vehicle_configuration() -> void:
	# The wrapper initializes its approved defaults in _ready; apply the isolated
	# presentation choices afterward without changing the wrapper itself.
	player_visual.set_variant("rally_sand")
	player_visual.set_lod(0)
	opponent_visual.set_variant("night_raid")
	opponent_visual.set_lod(1)

func _setup_camera_hud_and_comparison() -> void:
	camera_rig = PremiumSliceV2Camera.new(); camera_rig.name = "CinematicChaseCameraV2"; add_child(camera_rig); camera_rig.configure(player_follow, curve)
	hud = PremiumSliceV2HUD.new(); hud.name = "PremiumHUDV2"; add_child(hud)
	var canvas := CanvasLayer.new(); canvas.layer = 50; add_child(canvas)
	comparison_overlay = TextureRect.new(); comparison_overlay.position = Vector2.ZERO; comparison_overlay.size = Vector2(640, 720); comparison_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; comparison_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; comparison_overlay.texture = load("res://screenshots/premium_vertical_slice_v2/01_start_chase.png") as Texture2D; comparison_overlay.visible = false; canvas.add_child(comparison_overlay)
	comparison_caption = Label.new(); comparison_caption.position = Vector2(300, 682); comparison_caption.size = Vector2(680, 24); comparison_caption.text = "F1 BEFORE  |  F1.1 REVISION"; comparison_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; comparison_caption.add_theme_font_size_override("font_size", 14); comparison_caption.add_theme_color_override("font_color", Color.WHITE); comparison_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82)); comparison_caption.add_theme_constant_override("shadow_offset_x", 2); comparison_caption.add_theme_constant_override("shadow_offset_y", 2); comparison_caption.visible = false; canvas.add_child(comparison_caption)

func _setup_dust_and_boost() -> void:
	_add_contact_shadow(player_follow, Vector2(2.30, 4.72), 0.28)
	_add_contact_shadow(opponent_follow, Vector2(2.26, 4.68), 0.23)
	for x in [-0.82, 0.82]:
		var dust := GPUParticles3D.new(); dust.name = "DustV2RearLeft" if x < 0 else "DustV2RearRight"; dust.position = Vector3(x, 0.20, 1.48); dust.amount = 112; dust.lifetime = 1.02; dust.local_coords = false; dust.visibility_aabb = AABB(Vector3(-12, -5, -12), Vector3(24, 13, 30))
		var process := ParticleProcessMaterial.new(); process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; process.emission_box_extents = Vector3(0.20, 0.06, 0.24); process.direction = Vector3(0, 0.24, 1.0); process.spread = 34.0; process.initial_velocity_min = 1.7; process.initial_velocity_max = 4.8; process.gravity = Vector3(0, -0.16, 0); process.scale_min = 0.20; process.scale_max = 0.62
		var gradient := Gradient.new(); gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.58, 1.0]); gradient.colors = PackedColorArray([Color(0.78, 0.63, 0.43, 0.0), Color(0.76, 0.61, 0.43, 0.40), Color(0.63, 0.50, 0.36, 0.17), Color(0.51, 0.43, 0.35, 0.0)]); var gradient_texture := GradientTexture1D.new(); gradient_texture.gradient = gradient; process.color_initial_ramp = gradient_texture; dust.process_material = process
		var quad := QuadMesh.new(); quad.size = Vector2(0.58, 0.58); quad.material = _particle_material(Color(0.82, 0.68, 0.47, 0.86), false); dust.draw_pass_1 = quad; dust.emitting = true; player_follow.add_child(dust); dust_emitters.append(dust)
	for x in [-0.38, 0.38]:
		var flame := GPUParticles3D.new(); flame.name = "BoostV2FlameLeft" if x < 0 else "BoostV2FlameRight"; flame.position = Vector3(x, 0.47, 2.16); flame.amount = 34; flame.lifetime = 0.18; flame.local_coords = true; flame.visibility_aabb = AABB(Vector3(-3, -2, -2), Vector3(6, 5, 10))
		var process := ParticleProcessMaterial.new(); process.direction = Vector3(0, 0.02, 1.0); process.spread = 8.0; process.initial_velocity_min = 6.0; process.initial_velocity_max = 9.5; process.gravity = Vector3.ZERO; process.scale_min = 0.12; process.scale_max = 0.26; process.color = Color("ff9f3f"); flame.process_material = process
		var quad := QuadMesh.new(); quad.size = Vector2(0.18, 0.48); quad.material = _particle_material(Color("ff7f2f"), true); flame.draw_pass_1 = quad; flame.emitting = false; player_follow.add_child(flame); boost_emitters.append(flame)
	boost_light = OmniLight3D.new(); boost_light.name = "BoostV2RearAccent"; boost_light.position = Vector3(0, 0.52, 2.35); boost_light.light_color = Color("ff9b4d"); boost_light.light_energy = 0.0; boost_light.omni_range = 3.4; boost_light.shadow_enabled = false; boost_light.visible = false; player_follow.add_child(boost_light)

func _particle_material(color: Color, additive: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BOOST_PARTICLE_SHADER if additive else SOFT_PARTICLE_SHADER
	material.set_shader_parameter("tint", color)
	return material

func _add_contact_shadow(parent: Node3D, size: Vector2, opacity: float) -> void:
	var shadow := MeshInstance3D.new(); shadow.name = "ContactShadowV2"; var quad := QuadMesh.new(); quad.size = size
	var material := ShaderMaterial.new(); material.shader = CONTACT_SHADOW_SHADER; material.set_shader_parameter("opacity", opacity); quad.material = material
	shadow.mesh = quad; shadow.rotation_degrees.x = -90; shadow.position = Vector3(0, 0.025, 0.10); shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(shadow)

func _setup_local_audio() -> void:
	local_audio = AudioManager.new(); local_audio.name = "LocalSliceV2Audio"; add_child(local_audio); local_audio.start_game_audio()

func _jump_height(ratio: float) -> float:
	var phase := clampf((ratio - 0.685) / 0.075, 0.0, 1.0)
	return sin(phase * PI) * 0.82 if ratio >= 0.685 and ratio <= 0.76 else 0.0

func _steering_hint(progress: float) -> float:
	var before := PremiumSliceV2Geometry.sample_frame(curve, maxf(0.0, progress - 4.0))
	var after := PremiumSliceV2Geometry.sample_frame(curve, minf(curve.get_baked_length(), progress + 4.0))
	return clampf((-before.basis.z).signed_angle_to(-after.basis.z, Vector3.UP) * 1.7, -0.30, 0.30)

func _update_wheels(vehicle: Node3D, spin: float, steering: float) -> void:
	for wheel_name in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
		var wheel := vehicle.find_child(wheel_name, true, false) as Node3D
		if wheel == null: continue
		wheel.rotation.x = fmod(spin, TAU); wheel.rotation.y = steering if wheel_name in ["Wheel_FL", "Wheel_FR"] else 0.0

func _collect_metrics(delta: float) -> void:
	if delta > 0.0 and sequence_time > 1.0:
		var fps := 1.0 / delta; fps_total += fps; fps_samples += 1; fps_values.append(fps); instantaneous_minimum_fps = minf(instantaneous_minimum_fps, fps)
	peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	peak_primitives = maxi(peak_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	peak_memory = maxi(peak_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))

func _capture_set() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVISION_SCREENSHOT_ROOT))
	var shots := [
		["01_start_revised.png", 2.5, "chase"], ["02_curve_revised.png", 7.5, "chase"],
		["03_overtake_revised.png", 12.2, "chase"], ["04_descent_revised.png", 18.2, "chase"],
		["05_obstacle_revised.png", 22.8, "chase"], ["06_jump_revised.png", 27.1, "chase"],
		["07_boost_revised.png", 30.2, "chase"], ["08_arch_approach_revised.png", 34.0, "chase"],
		["09_arch_exit_revised.png", 35.7, "exit"], ["10_vehicle_scale.png", 10.0, "chase"],
		["11_terrain_road_detail.png", 20.0, "detail"], ["12_dust_detail.png", 27.0, "chase"],
		["13_before_after_f1.png", 8.0, "comparison"], ["14_golden_hour_final.png", 31.5, "hero"],
	]
	var failures := 0
	for shot in shots:
		var target_time := float(shot[1]); var start_time := maxf(0.0, target_time - 0.75)
		set_sequence_time(start_time); camera_rig.manual_capture = false; camera_rig.snap_to_target(); comparison_overlay.visible = false; comparison_caption.visible = false; hud.visible = true
		for emitter in dust_emitters + boost_emitters:
			emitter.restart()
		for frame_index in 45:
			set_sequence_time(minf(target_time, start_time + float(frame_index + 1) / 60.0)); await get_tree().process_frame; _collect_metrics(maxf(get_process_delta_time(), 0.0001))
		var mode := String(shot[2])
		if mode in ["wide", "close", "hero", "exit", "detail", "comparison"]:
			_configure_manual_camera(mode)
		if mode == "comparison": comparison_overlay.visible = true; comparison_caption.visible = true; hud.visible = false
		for _frame in 10: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path_name := "%s/%s" % [REVISION_SCREENSHOT_ROOT, shot[0]]
		var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path_name)); if error != OK: failures += 1
		print("PREMIUM_SLICE_V2_CAPTURE ", path_name, " error=", error)
	comparison_overlay.visible = false; comparison_caption.visible = false; camera_rig.manual_capture = false; hud.visible = true
	_write_metrics("visual_captures")
	get_tree().quit(0 if failures == 0 else 1)

func _configure_manual_camera(mode: String) -> void:
	var frame := PremiumSliceV2Geometry.sample_frame(curve, player_follow.progress); var forward := -frame.basis.z
	camera_rig.manual_capture = true
	if mode == "wide": camera_rig.global_position = player_follow.global_position - forward * 10.0 + frame.basis.x * 7.0 + Vector3.UP * 5.0
	elif mode == "close": camera_rig.global_position = player_follow.global_position - forward * 5.2 + frame.basis.x * 2.0 + Vector3.UP * 2.0
	elif mode == "exit": camera_rig.global_position = player_follow.global_position - forward * 9.0 + frame.basis.x * 4.2 + Vector3.UP * 3.55
	elif mode == "detail": camera_rig.global_position = player_follow.global_position - forward * 5.5 + frame.basis.x * 8.6 + Vector3.UP * 3.25
	elif mode == "comparison": camera_rig.global_position = player_follow.global_position - forward * 6.2 - frame.basis.x * 2.5 + Vector3.UP * 2.2
	else: camera_rig.global_position = player_follow.global_position - forward * 8.0 - frame.basis.x * 5.0 + Vector3.UP * 3.6
	var look_target := player_follow.global_position + forward * 11.0 + Vector3.UP * 0.72
	if mode in ["exit", "detail"]: camera_rig.fov = 64.0
	camera_rig.look_at(look_target, Vector3.UP)

func _write_metrics(mode: String) -> void:
	var structure := structure_metrics(); var stability := camera_rig.stability(); var sorted := fps_values.duplicate(); sorted.sort()
	var p5 := sorted[clampi(int(floor((sorted.size() - 1) * 0.05)), 0, maxi(0, sorted.size() - 1))] if not sorted.is_empty() else 0.0
	var report := "Premium vertical slice V2 metrics\nmode=%s\nduration_seconds=%.2f\n" % [mode, SEQUENCE_DURATION]
	report += "path_length_m=%.2f\nwide_curve_degrees=%.2f\nelevation_drop_m=%.2f\nbump_prominence_m=%.2f\ncontinuity_max_gap_m=%.3f\n" % [structure.path_length, structure.wide_curve_degrees, structure.elevation_drop, structure.bump_prominence, structure.continuity_max_gap]
	report += "average_fps=%.2f\ninstantaneous_minimum_fps=%.2f\npercentile_5_fps=%.2f\nminimum_sustained_fps=%.2f\n" % [fps_total / maxi(1, fps_samples), instantaneous_minimum_fps if instantaneous_minimum_fps < INF else 0.0, p5, _minimum_rolling_fps(30)]
	report += "peak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\npeak_static_memory_mb=%.2f\nload_time_ms=%.2f\n" % [peak_draw_calls, peak_primitives, peak_nodes, peak_memory / 1048576.0, load_time_ms]
	report += "player=Desert Stallion V3 Rally Sand LOD0\nopponent=Desert Stallion V3 Night Raid LOD1\nenvironment=Environment Kit V2 E2.1\nmultimesh_groups=%d\n" % int(structure.multimesh_groups)
	report += "camera_base_fov=%.2f\ncamera_boost_fov=%.2f\ncamera_distance_m=%.2f\ncamera_height_m=%.2f\ncamera_max_frame_step_m=%.3f\n" % [stability.base_fov, stability.boost_fov, PremiumSliceV2Camera.CHASE_DISTANCE, stability.height, stability.max_frame_step]
	report += "renderer=GL Compatibility\ngpu=NVIDIA GeForce MX150\nresolution=1280x720\nscreenshots=14\nmotion_review_video=res://captures/premium_vertical_slice_v2/premium_vertical_slice_v2_motion_review.avi\nmotion_review_frames=2281\nclassification=AWAITING_MANUAL_MOTION_APPROVAL\nproduction_integrated=false\n"
	var file := FileAccess.open("res://reports/premium_vertical_slice_v2_metrics.txt", FileAccess.WRITE); file.store_string(report); file.close(); print(report)

func _minimum_rolling_fps(window: int) -> float:
	if fps_values.is_empty(): return 0.0
	var actual := mini(window, fps_values.size()); var total := 0.0
	for index in actual: total += fps_values[index]
	var result := total / actual
	for index in range(actual, fps_values.size()): total += fps_values[index] - fps_values[index - actual]; result = minf(result, total / actual)
	return result
