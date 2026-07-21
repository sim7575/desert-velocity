extends SceneTree

const BOOT_PATH := "res://scenes/main/Boot.tscn"
const EXPECTED_ZONES := "0-9,10-17,18-28,29-39,40-47,48-56,57-63"

var failures: Array[String] = []
var route_signature := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("G1F1_ZONE_IDENTITY_VERIFICATION_START")
	route_signature = JSON.stringify(HandcraftedStage.route())
	RoadManager.use_environment_v2_playable_pilot = true
	RoadManager.use_full_special_stage_visual_expansion = true
	VehicleFactory.use_stallion_v3_visual_pilot = true
	var packed := load(BOOT_PATH) as PackedScene
	_check(packed != null, "Boot scene missing")
	if packed == null:
		await _finish(null)
		return
	var boot := packed.instantiate()
	root.add_child(boot)
	await process_frame
	boot.run_mode = "STAGE"
	boot.save.vehicle = 0
	boot.start_game()
	await process_frame
	var visual := boot.road.environment_visual_pilot as FullSpecialStageVisualExpansion
	_check(visual != null, "full-stage wrapper missing")
	if visual != null:
		_validate_visual(boot, visual)
	boot.set_pause(true)
	_check(boot.paused and boot.get_tree().paused, "pause state failed")
	boot.set_pause(false)
	_check(not boot.paused and not boot.get_tree().paused, "pause resume failed")
	boot.start_game()
	await process_frame
	_check(boot.screen == boot.Screen.GAME and boot.stage_checkpoint == 0, "stage restart failed")
	_check(boot.road != null and boot.road.environment_visual_pilot != null and bool(boot.road.environment_visual_pilot.get_meta("zone_identity_polish", false)), "G1-F.1 wrapper missing after restart")
	await _finish(boot)

func _validate_visual(boot: Node, visual: FullSpecialStageVisualExpansion) -> void:
	_check(bool(visual.get_meta("zone_identity_polish", false)), "G1-F.1 identity metadata missing")
	_check(str(visual.get_meta("zone_boundaries", "")) == EXPECTED_ZONES, "zone boundaries changed")
	_check(str(visual.get_meta("start_gate_visual", "")) == "PARTENZA", "start visual metadata missing")
	_check(str(visual.get_meta("finish_gate_visual", "")) == "TRAGUARDO", "finish visual metadata missing")
	_check(bool(visual.get_meta("rock_arch_deferred", false)), "RockArch deferral changed")
	_check(str(visual.get_meta("rock_arch_alternative", "")) == "paired_canyon_fins_segments_52_54", "open-gate alternative changed")
	_check(int(visual.get_meta("collision_count", -1)) == 0, "visual wrapper introduced collision objects")
	_check(visual.find_children("*", "CollisionObject3D", true, false).is_empty(), "visual composition contains a collider")
	_check(JSON.stringify(HandcraftedStage.route()) == route_signature, "route data changed during visual build")
	_check(boot.road.stage_layout().size() == 64, "stage layout count changed")
	_check(FullSpecialStageVisualExpansion.ZONES.size() == 7, "zone count changed")
	var expected_ranges := [[0, 9], [10, 17], [18, 28], [29, 39], [40, 47], [48, 56], [57, 63]]
	for index in expected_ranges.size():
		_check(int(FullSpecialStageVisualExpansion.ZONES[index][0]) == int(expected_ranges[index][0]) and int(FullSpecialStageVisualExpansion.ZONES[index][1]) == int(expected_ranges[index][1]), "zone %d boundaries changed" % (index + 1))
	var start := visual.find_child("G1F1StartGate", true, false) as Node3D
	var finish := visual.find_child("G1F1FinishGate", true, false) as Node3D
	_validate_gate(start, "PARTENZA", "start")
	_validate_gate(finish, "TRAGUARDO", "finish")
	_check(visual.find_child("PaddockLeft", true, false) != null and visual.find_child("PaddockRight", true, false) != null, "start paddock cues missing")
	var landmark_names := [
		"HeroRock_B_LeaningStack_S15_L0", "DistantMesa_B_S18_L2",
		"DistantMesa_A_S31_L2", "NarrativeWreck_SurveyRover_S44_L1",
		"RoadSign_Direction_S50_L1", "CanyonWall_A_Concave_S61_L1",
	]
	for landmark_name in landmark_names:
		_check(visual.find_child(landmark_name, true, false) != null, "zone landmark missing: %s" % landmark_name)
	_check(visual.find_children("*LandmarkContacts", "MultiMeshInstance3D", true, false).size() == 2, "landmark contact scatter missing")
	_check(int(visual.get_meta("multimesh_instances", 0)) <= 710, "instance redistribution increased the G1-F baseline")
	_check(int(visual.get_meta("lod0_instances", 0)) > 0 and int(visual.get_meta("lod1_instances", 0)) > 0 and int(visual.get_meta("lod2_instances", 0)) > 0, "LOD allocation incomplete")
	_check(str(visual.get_meta("streaming_mode", "")) == "distance_visibility_with_margin", "visibility strategy changed")
	_check(not bool(visual.get_meta("asynchronous_loading", true)), "asynchronous loading was introduced")
	_check(bool(boot.player.visual.get_meta("stallion_v3_visual_pilot", false)), "Stallion V3 missing")
	_check(int(boot.player.visual.get_meta("runtime_source_lod", -1)) == 1, "Stallion runtime LOD changed")
	_check(boot.camera.v3_chase_parameters().is_equal_approx(Vector4(9.8, 2.9, 8.5, 4.5)), "camera parameters changed")
	_check(boot.hud.get_node_or_null("HUDV2SafeArea/StatusPanel") != null, "compact HUD missing")
	_check(boot.player.visual.find_child("GameplayVisualEffectsG1E", true, false) != null, "approved effects missing")

func _validate_gate(gate: Node3D, text: String, role: String) -> void:
	_check(gate != null, "%s gate missing" % role)
	if gate == null:
		return
	_check(bool(gate.get_meta("collision_free", false)), "%s gate is not marked collision-free" % role)
	_check(str(gate.get_meta("race_gate_role", "")) == role, "%s gate role metadata invalid" % role)
	_check(gate.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s gate contains collision" % role)
	var label := gate.get_node_or_null("RaceGateLabel") as Label3D
	_check(label != null and label.text == text, "%s gate label invalid" % role)

func _finish(boot: Node) -> void:
	if boot != null and is_instance_valid(boot):
		boot.set_process(false)
		if boot.camera != null:
			boot.camera.target = null
		if boot.road != null:
			boot.road.player = null
		boot.free()
	for _frame in 20:
		await process_frame
	print("G1F1_ZONE_IDENTITY_RESULT %s" % ("PASS" if failures.is_empty() else "FAIL"))
	for failure in failures:
		print("FAIL: %s" % failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
