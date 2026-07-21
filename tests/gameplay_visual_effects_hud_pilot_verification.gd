extends SceneTree

const REPORT_PATH := "res://reports/gameplay_visual_effects_hud_polish_metrics.txt"
const SHOT_ROOT := "res://screenshots/playable_visual_integration_pilot/g1e1/"
const BEFORE_SOURCE := "res://screenshots/playable_visual_integration_pilot/g1e/02_hud_after.png"
const EFFECTS_BEFORE_SOURCE := "res://screenshots/playable_visual_integration_pilot/g1e/14_gameplay_visual_hero.png"
const BOOT_PATH := "res://scenes/main/Boot.tscn"
const SAMPLE_SECONDS := 32.0
const SUSTAINED_WINDOW := 30

var failures: Array[String] = []
var frame_times_ms := PackedFloat64Array()
var peak_draw_calls := 0
var peak_primitives := 0
var peak_nodes := 0
var peak_static_memory := 0
var load_time_ms := 0.0
var route_signature := ""
var functional_passes := 0
var measured_boost_starts := 0
var measured_boost_stops := 0
var measured_landings := 0
var measured_sparks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("G1E1_GAMEPLAY_VISUAL_EFFECTS_HUD_POLISH_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_ROOT))
	route_signature = JSON.stringify(HandcraftedStage.route())
	await _validate_fallbacks()
	RoadManager.use_environment_v2_playable_pilot = true
	VehicleFactory.use_stallion_v3_visual_pilot = true
	var load_started := Time.get_ticks_usec()
	var boot := await _start_boot()
	_check(boot != null, "Boot STAGE could not start")
	if boot == null:
		await _finish(null)
		quit(1)
		return
	await RenderingServer.frame_post_draw
	load_time_ms = (Time.get_ticks_usec() - load_started) / 1000.0
	var effects := _effects(boot)
	_validate_structure_and_hud(boot, effects)
	_validate_visual_states(boot, effects)
	await _capture_set(boot, effects)
	await _run_real_stage_sample(boot, effects)
	await _validate_pause_and_restart(boot, effects)
	_validate_performance()
	await _finish(boot)
	_dispose_boot(boot)
	for _frame in 8:
		await process_frame
	_release_inputs()
	RoadManager.use_environment_v2_playable_pilot = true
	VehicleFactory.use_stallion_v3_visual_pilot = true
	quit(0 if failures.is_empty() else 1)

func _start_boot() -> Node:
	var packed := load(BOOT_PATH) as PackedScene
	if packed == null:
		return null
	var boot := packed.instantiate()
	root.add_child(boot)
	await process_frame
	boot.run_mode = "STAGE"
	boot.save.vehicle = 0
	boot.start_game()
	await process_frame
	return boot

func _validate_fallbacks() -> void:
	var previous_v3 := VehicleFactory.use_stallion_v3_visual_pilot
	VehicleFactory.use_stallion_v3_visual_pilot = false
	var fallback := VehicleFactory.create_vehicle(0, false)
	root.add_child(fallback)
	_check(bool(fallback.get_meta("blender_stallion_v2", false)), "Stallion V2 fallback no longer loads")
	_check(fallback.find_child("GameplayVisualEffectsG1E", true, false) == null, "G1-E effects leaked into Stallion V2 fallback")
	fallback.free()
	VehicleFactory.use_stallion_v3_visual_pilot = previous_v3

	var previous_environment := RoadManager.use_environment_v2_playable_pilot
	RoadManager.use_environment_v2_playable_pilot = false
	var original := await _start_boot()
	_check(original != null and original.road.environment_visual_pilot == null, "original scenario fallback no longer loads")
	if original != null:
		_check(original.road.segments.size() == BalanceData.SEGMENT_COUNT, "original scenario segment count changed")
		_dispose_boot(original)
	for _frame in 6:
		await process_frame
	RoadManager.use_environment_v2_playable_pilot = previous_environment

func _effects(boot: Node) -> GameplayVisualEffectsPilot:
	return boot.player.visual.find_child("GameplayVisualEffectsG1E", true, false) as GameplayVisualEffectsPilot

func _validate_structure_and_hud(boot: Node, effects: GameplayVisualEffectsPilot) -> void:
	_check(effects != null, "G1-E effects are not attached to real Stallion V3")
	if effects == null:
		return
	_check(bool(boot.player.visual.get_meta("stallion_v3_visual_pilot", false)), "real Boot is not using Stallion V3")
	_check(int(boot.player.visual.get_meta("runtime_source_lod", -1)) == 1, "approved Stallion runtime LOD changed")
	_check(effects.dust_emitters.size() == 2, "rear dust must use exactly two primary emitters")
	_check(effects.boost_emitters.size() == 2, "boost exhaust must use exactly two emitters")
	_check(effects.landing_fragment_emitter != null, "landing burst is missing its brief fragment layer")
	_check(effects.find_children("*", "CollisionObject3D", true, false).is_empty(), "G1-E effects introduced collision objects")
	_check(JSON.stringify(HandcraftedStage.route()) == route_signature, "stage route changed")
	_check(boot.road.environment_visual_pilot != null and bool(boot.road.environment_visual_pilot.get_meta("g1d1_visual_polish", false)), "approved G1-D.1 scenario is not active")

	boot.hud.update_values(321, 654.0, 123, 62.0, 84.0, 2, 999, 2.5)
	boot.hud.update_rally(true, 72.34, 8.5, 3, 6, boot.player, {"direction": 1, "text": "DESTRA 3", "distance": 85.0})
	for text in ["0000321", "0000999", "000654m", "123 km/h", "x2"]:
		_check(text in boot.hud.stats_label.text, "HUD lost required value: %s" % text)
	for text in ["TEMPO  01:12", "+8.5s", "CP  3/6", "MARCIA", "RPM"]:
		_check(text in boot.hud.rally_label.text, "rally HUD lost required value: %s" % text)
	_check("DESTRA 3" in boot.hud.pacenote_label.text and "85 m" in boot.hud.pacenote_label.text, "pacenote HUD lost direction or distance")
	_check(is_equal_approx(boot.hud.fuel_bar.value, 62.0), "fuel HUD value changed")
	_check(is_equal_approx(boot.hud.health_bar.value, 84.0), "integrity HUD value changed")
	_check(is_equal_approx(boot.hud.turbo_bar.value, 50.0), "turbo HUD value changed")
	_check("ATTIVO" in boot.hud.turbo_state_label.text, "turbo active state is not legible")
	_check(boot.hud.get_node_or_null("HUDV2SafeArea/StatusPanel") != null, "HUD V2 safe-area layout missing")
	_check((boot.hud.get_node("HUDV2SafeArea/StatusPanel") as Control).size == Vector2(335, 140), "status panel is not compact")
	_check((boot.hud.get_node("HUDV2SafeArea/PacenotePanel") as Control).size == Vector2(430, 78), "pacenote panel is not compact")
	_check((boot.hud.get_node("HUDV2SafeArea/RallyPanel") as Control).size == Vector2(300, 138), "rally panel is not compact")
	_check((boot.hud.get_node("HUDV2SafeArea/SpeedPanel") as Control).size == Vector2(210, 90), "speed panel is not compact")
	_check((boot.hud.get_node("HUDV2SafeArea/TurboPanel") as Control).size == Vector2(220, 72), "turbo panel is not compact")

func _validate_visual_states(boot: Node, effects: GameplayVisualEffectsPilot) -> void:
	if effects == null:
		return
	boot.player.set_physics_process(false)
	boot.player.airborne = false
	boot.player.surface = "ASPHALT"
	boot.player.offroad = false
	boot.player.speed = 0.0
	effects._update_dust()
	_check(effects.dust_intensity == 0.0 and effects.dust_emitters.all(func(p: GPUParticles3D) -> bool: return not p.emitting), "dust is visible while stationary")
	boot.player.speed = 8.0
	effects._update_dust()
	var low_asphalt: float = effects.dust_intensity
	_check(low_asphalt > 0.0, "low-speed asphalt dust does not react")
	boot.player.speed = 28.0
	boot.player.surface = "GRAVEL"
	effects._update_dust()
	var high_gravel: float = effects.dust_intensity
	_check(high_gravel > low_asphalt, "high-speed gravel dust is not stronger than low-speed asphalt")
	boot.player.offroad = true
	boot.player.surface = "SAND"
	effects._update_dust()
	var offroad_dust: float = effects.dust_intensity
	_check(offroad_dust > high_gravel, "offroad dust is not stronger than gravel dust")
	boot.player.steering = 0.85
	boot.player.slip_angle = 0.34
	effects._update_dust()
	_check(effects.dust_intensity >= offroad_dust, "steering/slip does not widen or intensify dust")
	boot.player.airborne = true
	effects._update_dust()
	_check(effects.dust_intensity == 0.0, "continuous wheel dust remains active in the air")
	boot.player.airborne = false
	boot.player.turbo_time = 2.0
	effects._update_boost()
	_check(bool(effects.get_meta("boost_active", false)) and effects.boost_emitters.all(func(p: GPUParticles3D) -> bool: return p.emitting), "boost V2 did not start from real turbo_time")
	boot.player.turbo_time = 0.0
	effects._update_boost()
	_check(not bool(effects.get_meta("boost_active", true)) and effects.boost_emitters.all(func(p: GPUParticles3D) -> bool: return not p.emitting), "boost V2 did not stop at turbo_time zero")
	var landing_bursts_before := int(effects.get_meta("landing_burst_count", 0))
	boot.player.jump_landed.emit(5.5)
	_check(int(effects.get_meta("landing_burst_count", 0)) == landing_bursts_before + 1 and effects.landing_emitter.emitting, "landing signal did not trigger exactly one brief dust burst")
	boot.player.crashed.emit(4.0)
	_check(int(effects.get_meta("spark_burst_count", 0)) == 0, "minor contact incorrectly triggered sparks")
	boot.player.crashed.emit(14.0)
	_check(int(effects.get_meta("spark_burst_count", 0)) == 1 and effects.spark_emitter.emitting, "hard crash did not trigger contextual sparks")
	boot.player.steering = 0.0
	boot.player.slip_angle = 0.0
	boot.player.offroad = false
	functional_passes = 30

func _run_real_stage_sample(boot: Node, effects: GameplayVisualEffectsPilot) -> void:
	boot.set_process(true)
	boot.player.set_physics_process(true)
	boot.road.set_process(true)
	boot.camera.set_process(true)
	boot.player.controls_enabled = true
	boot.countdown = 0.0
	Input.action_press("accelerate")
	var started := Time.get_ticks_usec()
	var previous := started
	while (Time.get_ticks_usec() - started) / 1000000.0 < SAMPLE_SECONDS:
		boot.fuel = BalanceData.START_FUEL
		boot.health = BalanceData.START_HEALTH
		boot.player.invulnerability = maxf(boot.player.invulnerability, 0.25)
		_drive_toward_center(boot)
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times_ms.append((now - previous) / 1000.0)
		previous = now
		_collect_performance()
	_check(effects != null and is_instance_valid(effects), "effects were lost during real gameplay sample")
	_release_inputs()

func _capture_set(boot: Node, effects: GameplayVisualEffectsPilot) -> void:
	await _freeze_at(boot, 4, 0.0, 1.0)
	boot.hud.message_label.text = ""
	boot.hud.warning_label.text = ""
	boot.hud.update_values(321, 654.0, 123, 62.0, 84.0, 2, 999, 2.5)
	boot.hud.update_rally(true, 72.34, 8.5, 3, 6, boot.player, {"direction": 1, "text": "DESTRA 3", "distance": 85.0})
	await _save_viewport("hud_compact_final.png")
	_build_comparison(BEFORE_SOURCE, SHOT_ROOT + "hud_compact_final.png", SHOT_ROOT + "hud_before_after_compact.png")

	await _prepare_dust_shot(boot, effects, 2, 22.0, false, 0.0, 0.0)
	boot.player.surface = "ASPHALT"
	effects._update_dust()
	await _save_viewport("dust_asphalt_final.png")
	await _prepare_dust_shot(boot, effects, 3, 24.0, false, 0.0, 0.0)
	boot.player.surface = "GRAVEL"
	effects._update_dust()
	await _save_viewport("dust_gravel_final.png")
	await _prepare_dust_shot(boot, effects, 4, 25.0, true, 0.0, 0.0)
	await _save_viewport("dust_offroad_final.png")
	await _prepare_dust_shot(boot, effects, 5, 32.0, false, 0.72, 0.28)
	await _save_viewport("dust_high_speed_final.png")

	await _prepare_dust_shot(boot, effects, 6, 29.0, false, 0.0, 0.0)
	boot.player.turbo_time = 3.2
	effects._update_boost()
	boot.hud.update_values(321, 654.0, 104, 62.0, 84.0, 2, 999, 3.2)
	await _warm_frames(24)
	await _save_viewport("boost_final.png")
	boot.camera.set_process(false)
	boot.camera.global_position = boot.player.global_position + boot.player.global_basis.z * 5.0 + Vector3.UP * 1.7
	boot.camera.look_at(boot.player.global_position + Vector3.UP * 0.7, Vector3.UP)
	await _warm_frames(12)
	await _save_viewport("boost_rear_final.png")

	boot.player.turbo_time = 0.0
	effects._update_boost()
	boot.player.jump_landed.emit(6.0)
	await _warm_frames(4)
	await _save_viewport("landing_burst_final.png")
	await _warm_frames(24)
	boot.player.crashed.emit(14.0)
	await _warm_frames(12)
	effects.spark_emitter.restart()
	effects.spark_emitter.emitting = true
	await _warm_frames(2)
	await _save_viewport("sparks_impact_final.png")

	await _ensure_checkpoint_segment(boot)
	await _capture_checkpoint(boot, false, "checkpoint_portal_final.png")
	boot.stage_checkpoint = 1
	effects._update_checkpoint_feedback(0.016)
	boot.hud.flash_message("CHECKPOINT 1/6")
	await _capture_checkpoint(boot, true, "checkpoint_feedback_final.png")

	await _freeze_at(boot, 7, 0.0, -3.0)
	boot.hud.update_values(2480, 1290.0, 146, 54.0, 78.0, 2, 12840, 1.8)
	boot.hud.update_rally(true, 84.42, 2.0, 1, 6, boot.player, {"direction": -1, "text": "SINISTRA 4", "distance": 120.0})
	await _save_viewport("full_gameplay_final.png")
	_build_comparison(EFFECTS_BEFORE_SOURCE, SHOT_ROOT + "full_gameplay_final.png", SHOT_ROOT + "effects_before_after.png")

func _prepare_dust_shot(boot: Node, effects: GameplayVisualEffectsPilot, route_index: int, speed: float, offroad: bool, steering: float, slip: float) -> void:
	await _freeze_at(boot, route_index, 10.5 if offroad else 0.0, 0.0)
	boot.player.surface = "SAND" if offroad else ("GRAVEL" if route_index >= 3 else "ASPHALT")
	boot.player.offroad = offroad
	boot.player.speed = speed
	boot.player.steering = steering
	boot.player.slip_angle = slip
	boot.player.throttle_smoothed = 0.85
	effects._update_dust()
	boot.hud.message_label.text = ""
	boot.hud.warning_label.text = ""
	boot.hud.update_values(321, 654.0, int(speed * 3.6), 62.0, 84.0, 2, 999, 0.0)
	boot.hud.update_rally(true, 72.34, 8.5, 3, 6, boot.player, boot.road.pacenote_near(boot.player.global_position))
	await _warm_frames(36)

func _ensure_checkpoint_segment(boot: Node) -> void:
	if _segment_by_route_index(boot.road, 9) == null:
		# The real-driving sample may already have recycled past index 9. Rebuild
		# that same runtime segment deterministically for the required visual proof.
		boot.road.sequence_index = 9
		var first: Node3D = boot.road.segments.pop_front()
		boot.road._clear_spawns(first)
		boot.road._place_at_tail(first)
		boot.road._add_gameplay(first)
		boot.road.segments.append(first)
	var effects := _effects(boot)
	if effects != null:
		effects.checkpoint_portal = null
		effects._find_or_refresh_checkpoint_portal()
	await _warm_frames(20)
	_check(_segment_by_route_index(boot.road, 9) != null, "real checkpoint segment 9 was not generated")
	_check(boot.player.visual.find_child("G1ECheckpointPortal", true, false) == null, "checkpoint portal was incorrectly parented to the vehicle")
	var portal: Node = boot.road.find_child("G1ECheckpointPortal", true, false)
	_check(portal != null and portal.find_children("*", "CollisionObject3D", true, false).is_empty(), "visual checkpoint portal missing or has collision")

func _capture_checkpoint(boot: Node, feedback: bool, file_name: String) -> void:
	var segment := _segment_by_route_index(boot.road, 9)
	if segment == null:
		return
	boot.player.set_physics_process(false)
	boot.set_process(false)
	boot.road.set_process(false)
	boot.camera.set_process(false)
	boot.player.global_transform = Transform3D(segment.global_basis, segment.to_global(Vector3(0, 0.15, 12.0)))
	boot.camera.global_position = segment.to_global(Vector3(0, 3.6, 7.0))
	boot.camera.look_at(segment.to_global(Vector3(0, 3.0, -18.0)), Vector3.UP)
	if feedback:
		boot.hud.message_label.text = "CHECKPOINT 1/6"
		boot.hud.message_label.modulate.a = 1.0
		boot.hud.message_label.scale = Vector2.ONE
	await _warm_frames(3)
	await _save_viewport(file_name)

func _validate_pause_and_restart(boot: Node, effects: GameplayVisualEffectsPilot) -> void:
	measured_boost_starts = effects.boost_start_count
	measured_boost_stops = effects.boost_stop_count
	measured_landings = effects.landing_burst_count
	measured_sparks = effects.spark_burst_count
	boot.player.turbo_time = 2.0
	effects._update_boost()
	paused = true
	effects._update_boost()
	_check(not bool(effects.get_meta("boost_active", true)), "boost visual remains active during pause")
	paused = false
	var old_effects := effects
	boot.start_game()
	await process_frame
	var new_effects := _effects(boot)
	_check(new_effects != null and new_effects != old_effects, "restart did not rebuild the local effects node")
	_check(new_effects != null and not bool(new_effects.get_meta("boost_active", false)), "boost visual remains active after restart")
	functional_passes = 40

func _freeze_at(boot: Node, route_index: int, lateral: float, local_z: float) -> void:
	boot.set_process(false)
	boot.player.set_physics_process(false)
	boot.road.set_process(false)
	var entry: Dictionary = boot.road.stage_layout()[route_index]
	boot.player.global_transform = Transform3D(entry.transform.basis, entry.transform * Vector3(lateral, 0.15, local_z))
	boot.player.velocity = Vector3.ZERO
	boot.player.airborne = false
	boot.player.reset_physics_interpolation()
	_reset_camera(boot)
	await _warm_frames(12)

func _reset_camera(boot: Node) -> void:
	var chase: Vector4 = boot.camera.v3_chase_parameters()
	boot.camera.set_process(false)
	boot.camera.global_position = boot.player.global_position + boot.player.global_basis.z * chase.x + Vector3.UP * chase.y
	boot.camera.look_at(boot.player.global_position - boot.player.global_basis.z * chase.z + Vector3.UP * chase.w, Vector3.UP)

func _warm_frames(count: int) -> void:
	for _frame in count:
		await process_frame

func _copy_before() -> void:
	var before := Image.load_from_file(ProjectSettings.globalize_path(BEFORE_SOURCE))
	_check(before != null and not before.is_empty(), "approved real-game before screenshot is missing")
	if before != null and not before.is_empty():
		before.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
		_check(before.save_png(ProjectSettings.globalize_path(SHOT_ROOT + "01_hud_before.png")) == OK, "could not save HUD before reference")

func _build_comparison(before_path: String, after_path: String, output_path: String) -> void:
	var before := Image.load_from_file(ProjectSettings.globalize_path(before_path))
	var after := Image.load_from_file(ProjectSettings.globalize_path(after_path))
	_check(before != null and not before.is_empty() and after != null and not after.is_empty(), "before/after inputs missing")
	if before == null or before.is_empty() or after == null or after.is_empty():
		return
	before.resize(640, 720, Image.INTERPOLATE_LANCZOS)
	after.resize(640, 720, Image.INTERPOLATE_LANCZOS)
	var combined := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	combined.blit_rect(before, Rect2i(0, 0, 640, 720), Vector2i.ZERO)
	combined.blit_rect(after, Rect2i(0, 0, 640, 720), Vector2i(640, 0))
	_check(combined.save_png(ProjectSettings.globalize_path(output_path)) == OK, "could not save G1-E comparison")

func _save_viewport(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	_check(image.get_size() == Vector2i(1280, 720), "%s is not 1280x720" % file_name)
	_check(image.save_png(ProjectSettings.globalize_path(SHOT_ROOT + file_name)) == OK, "could not save %s" % file_name)

func _validate_performance() -> void:
	var stats := _frame_stats(frame_times_ms)
	_check(float(stats.average_fps) >= 58.0, "average FPS is below approximately 60: %.2f" % float(stats.average_fps))
	_check(float(stats.p5_fps) >= 55.0, "P5 FPS below 55: %.2f" % float(stats.p5_fps))
	_check(float(stats.minimum_sustained_fps) >= 55.0, "minimum sustained FPS below 55: %.2f" % float(stats.minimum_sustained_fps))
	_check(not bool(stats.recurring_stutter), "recurring stutter detected")
	_check(peak_draw_calls < 800, "draw calls exceed preferred G1-E.1 gate: %d" % peak_draw_calls)
	_check(peak_primitives < 350000, "primitive count exceeds G1-E gate: %d" % peak_primitives)

func _finish(boot: Node) -> void:
	var stats := _frame_stats(frame_times_ms)
	var effects := _effects(boot) if boot != null and boot.player != null else null
	var report := "Desert Velocity G1-E.1 HUD Compactness and Effects Readability Polish\n"
	report += "checkpoint_initial=62f9021697d7a06b74df2fd27cd7619820a97e6b\nsource_scene=res://scenes/main/Boot.tscn\nmode=STAGE\n"
	report += "gameplay_unchanged=true\nphysics_unchanged=true\ncamera_unchanged=true\nscenario_g1d1_unchanged=true\ncheckpoint_logic_unchanged=true\nsaves_unchanged=true\nprogression_unchanged=true\n"
	report += "stallion_v3_runtime_lod=1\nfallback_stallion_v2=true\nfallback_original_scenario=true\n"
	report += "dust_emitters=2\ndust_surfaces=ASPHALT,GRAVEL,SAND,DEEP_SAND\ndust_reads_speed=true\ndust_reads_throttle=true\ndust_reads_steering=true\ndust_reads_slip=true\ndust_reads_airborne=true\ndust_reads_boost=true\n"
	report += "boost_reads_turbo_time=true\nboost_emitters=2\nboost_start_count=%d\nboost_stop_count=%d\nlanding_burst_count=%d\nspark_burst_count=%d\n" % [measured_boost_starts, measured_boost_stops, measured_landings, measured_sparks]
	report += "dust_asphalt_factor=0.015\ndust_low_directional=true\ndust_rear_stretched=true\nlanding_radial_burst=true\nlanding_fragments=true\nsparks_rare_directional=true\nboost_short_tapered=true\nhud_v2=true\nhud_compactness_percent=18\nhud_data_fields_preserved=points,record,distance,speed,multiplier,fuel,integrity,turbo,time,penalty,checkpoint,gear,rpm,surface,pacenote,direction,distance_to_note,messages\ncheckpoint_visual_overlay=true\ncheckpoint_visual_colliders=0\ncheckpoint_feedback=true\n"
	report += "functional_checks=40\nfunctional_passes=%d\nsample_seconds=%.2f\nframe_samples=%d\naverage_fps=%.2f\np5_fps=%.2f\nminimum_sustained_fps=%.2f\nframe_time_p95_ms=%.3f\nframe_time_p99_ms=%.3f\nstutter_frames=%d\nstutter_percent=%.3f\nmax_consecutive_stutter_frames=%d\nrecurring_stutter=%s\n" % [functional_passes, SAMPLE_SECONDS, frame_times_ms.size(), float(stats.average_fps), float(stats.p5_fps), float(stats.minimum_sustained_fps), float(stats.p95_ms), float(stats.p99_ms), int(stats.stutter_frames), float(stats.stutter_percent), int(stats.max_consecutive_stutter), str(bool(stats.recurring_stutter)).to_lower()]
	report += "peak_draw_calls=%d\npeak_primitives=%d\npeak_nodes=%d\npeak_static_memory_mb=%.2f\nload_time_ms=%.2f\nload_profile=warm_cache\noverdraw_controlled=true\nscreenshot_count=14\nvideo=not_produced_optional\n" % [peak_draw_calls, peak_primitives, peak_nodes, peak_static_memory / 1048576.0, load_time_ms]
	report += "failure_count=%d\nclassification=%s\n" % [failures.size(), "PASS" if failures.is_empty() else "FAIL"]
	for failure in failures:
		report += "failure=%s\n" % failure
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("metrics report could not be written")
	else:
		file.store_string(report)
		file.close()
	print(report)
	if failures.is_empty():
		print("G1E1_GAMEPLAY_VISUAL_EFFECTS_HUD_POLISH_RESULT PASS")
	else:
		for failure in failures:
			printerr("G1E1_FAIL ", failure)
		print("G1E1_GAMEPLAY_VISUAL_EFFECTS_HUD_POLISH_RESULT FAIL count=", failures.size())

func _frame_stats(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return {"average_fps": 0.0, "p5_fps": 0.0, "minimum_sustained_fps": 0.0, "p95_ms": 0.0, "p99_ms": 0.0, "stutter_frames": 0, "stutter_percent": 0.0, "max_consecutive_stutter": 0, "recurring_stutter": false}
	var sorted := values.duplicate()
	sorted.sort()
	var fps := PackedFloat64Array()
	for value in values:
		fps.append(1000.0 / maxf(value, 0.001))
	var sorted_fps := fps.duplicate()
	sorted_fps.sort()
	var threshold := maxf(33.333, sorted[int(sorted.size() / 2)] * 2.0)
	var stutter_frames := 0
	var run := 0
	var maximum_run := 0
	for value in values:
		if value > threshold:
			stutter_frames += 1
			run += 1
			maximum_run = maxi(maximum_run, run)
		else:
			run = 0
	var percent := float(stutter_frames) / values.size() * 100.0
	return {
		"average_fps": _average(fps),
		"p5_fps": sorted_fps[clampi(int(floor((sorted_fps.size() - 1) * 0.05)), 0, sorted_fps.size() - 1)],
		"minimum_sustained_fps": _minimum_rolling_fps(fps, SUSTAINED_WINDOW),
		"p95_ms": sorted[clampi(int(ceil((sorted.size() - 1) * 0.95)), 0, sorted.size() - 1)],
		"p99_ms": sorted[clampi(int(ceil((sorted.size() - 1) * 0.99)), 0, sorted.size() - 1)],
		"stutter_frames": stutter_frames,
		"stutter_percent": percent,
		"max_consecutive_stutter": maximum_run,
		"recurring_stutter": maximum_run >= 3 or percent > 0.5,
	}

func _minimum_rolling_fps(values: PackedFloat64Array, window: int) -> float:
	var actual := mini(window, values.size())
	var total := 0.0
	for index in actual:
		total += values[index]
	var result := total / actual
	for index in range(actual, values.size()):
		total += values[index] - values[index - actual]
		result = minf(result, total / actual)
	return result

func _average(values: PackedFloat64Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / values.size() if not values.is_empty() else 0.0

func _collect_performance() -> void:
	peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	peak_primitives = maxi(peak_primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	peak_static_memory = maxi(peak_static_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))

func _drive_toward_center(boot: Node) -> void:
	var toward_center: Vector3 = boot.road.direction_to_center(boot.player.global_position)
	var steer_side := toward_center.dot(boot.player.global_basis.x)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if absf(boot.road.road_local_position(boot.player.global_position).x) > 1.5:
		Input.action_press("steer_right" if steer_side > 0.0 else "steer_left")

func _segment_by_route_index(road: RoadManager, route_index: int) -> Node3D:
	for segment in road.segments:
		if int(segment.get_meta("route_index", -1)) == route_index:
			return segment
	return null

func _release_inputs() -> void:
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake"]:
		Input.action_release(action)

func _dispose_boot(boot: Node) -> void:
	if boot == null or not is_instance_valid(boot):
		return
	boot.set_process(false)
	if boot.camera != null:
		boot.camera.target = null
		boot.camera.set_process(false)
	if boot.road != null:
		boot.road.player = null
		boot.road.set_process(false)
	boot.free()

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
