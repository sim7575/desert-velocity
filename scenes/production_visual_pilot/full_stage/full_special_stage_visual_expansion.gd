class_name FullSpecialStageVisualExpansion
extends Node3D

const PILOT_SCENE := preload("res://scenes/production_visual_pilot/environment/EnvironmentV2PlayableScenarioPilot.tscn")
const ROAD_SHADER := preload("res://assets/shaders/production_visual_pilot/full_stage/full_stage_road.gdshader")
const CHECKPOINT_SEGMENTS := [9, 19, 29, 39, 49, 59]
const ZONES := [
	[0, 9, "DesertStartOpenFlats"], [10, 17, "ErodedRockCorridor"],
	[18, 28, "CanyonApproach"], [29, 39, "HighPlateau"],
	[40, 47, "DunesAndWreck"], [48, 56, "TechnicalGravelPass"],
	[57, 63, "FinalGoldenRun"],
]

var road_manager: RoadManager
var pilot: EnvironmentV2PlayableScenarioPilot
var layout: Array[Dictionary] = []
var surface_root: Node3D
var landmark_root: Node3D
var scatter_root: Node3D
var checkpoint_root: Node3D
var checkpoint_portals: Array[Node3D] = []
var start_gate: Node3D
var finish_gate: Node3D
var last_checkpoint := 0
var finish_pulsed := false
var mesh_instances := 0
var multimesh_groups := 0
var multimesh_instances := 0
var lod_usage := {0: 0, 1: 0, 2: 0}
var zone_materials: Dictionary = {}

func configure(manager: RoadManager) -> void:
	road_manager = manager
	layout = manager.stage_layout()
	pilot = PILOT_SCENE.instantiate() as EnvironmentV2PlayableScenarioPilot
	add_child(pilot)
	pilot.configure(manager)
	_build_extension_surfaces()
	_build_landmarks()
	_build_scatter()
	_build_start_finish_visuals()
	_build_checkpoint_portals()
	for segment in manager.segments:
		update_segment_visual(segment, int(segment.get_meta("route_index", -1)))
	set_process(true)
	_set_metadata()

func update_segment_visual(segment: Node3D, route_index: int) -> void:
	var full_segment := route_index >= 0 and route_index < layout.size()
	segment.set_meta("full_stage_visual_expansion", full_segment)
	for child in segment.get_children():
		if child is CollisionObject3D:
			continue
		if child.is_in_group("route_detail") or child.is_in_group("spawned") or child.is_in_group("stage_jump_geometry"):
			continue
		if child is Node3D:
			(child as Node3D).visible = not full_segment
	_hide_original_endpoint_arch(segment, route_index)

func _process(delta: float) -> void:
	var game_manager := road_manager.get_parent().get_parent() if road_manager != null else null
	if game_manager == null:
		return
	var checkpoint_value: Variant = game_manager.get("stage_checkpoint")
	var current := int(checkpoint_value) if checkpoint_value is int else 0
	if current > last_checkpoint and current >= 2 and current <= checkpoint_portals.size() + 1:
		checkpoint_portals[current - 2].set_meta("pulse_time", 0.48)
	last_checkpoint = current
	if current >= 6 and not finish_pulsed and finish_gate != null:
		finish_gate.set_meta("pulse_time", 0.62)
		finish_pulsed = true
	for portal in checkpoint_portals:
		_update_portal_pulse(portal, delta, 0.48, 0.045)
	if finish_gate != null:
		_update_portal_pulse(finish_gate, delta, 0.62, 0.055)

func _update_portal_pulse(portal: Node3D, delta: float, duration: float, strength: float) -> void:
	var time := maxf(0.0, float(portal.get_meta("pulse_time", 0.0)) - delta)
	portal.set_meta("pulse_time", time)
	portal.scale = Vector3.ONE * (1.0 + sin((1.0 - time / duration) * PI) * strength if time > 0.0 else 1.0)

func _hide_original_endpoint_arch(segment: Node3D, route_index: int) -> void:
	if route_index not in [0, 63]:
		return
	for child in segment.get_children():
		if child is Node3D and child.is_in_group("route_detail"):
			(child as Node3D).visible = false
			(child as Node3D).set_meta("replaced_by_g1f1_visual", true)
			break

func _build_extension_surfaces() -> void:
	surface_root = Node3D.new()
	surface_root.name = "FullStageRoadTerrain"
	add_child(surface_root)
	var terrain_material: Material = pilot._surface_material(0.0, "FullStageTerrain")
	var shoulder_material: Material = pilot._surface_material(2.0, "FullStageShoulder")
	_build_underlay(terrain_material)
	for zone_index in range(1, ZONES.size()):
		var zone: Array = ZONES[zone_index]
		var start := int(zone[0])
		var finish := int(zone[1])
		var zone_root := Node3D.new()
		zone_root.name = "Zone%02d_%s" % [zone_index + 1, str(zone[2])]
		surface_root.add_child(zone_root)
		_add_combined_surface(zone_root, "Terrain", start, finish, "terrain", 0.0, terrain_material)
		_add_combined_surface(zone_root, "ShoulderL", start, finish, "shoulder", -1.0, shoulder_material)
		_add_combined_surface(zone_root, "ShoulderR", start, finish, "shoulder", 1.0, shoulder_material)
		_add_combined_surface(zone_root, "IntrusionL", start, finish, "intrusion", -1.0, shoulder_material)
		_add_combined_surface(zone_root, "IntrusionR", start, finish, "intrusion", 1.0, shoulder_material)
		_add_combined_road(zone_root, start, finish, "ASPHALT", zone_index)
		_add_combined_road(zone_root, start, finish, "GRAVEL", zone_index)

func _add_combined_surface(parent: Node3D, label: String, start: int, finish: int, kind: String, side: float, material: Material) -> void:
	var tool := SurfaceTool.new()
	var appended := false
	for index in range(start, finish + 1):
		var mesh: ArrayMesh
		match kind:
			"terrain": mesh = pilot._terrain_mesh(index)
			"shoulder": mesh = pilot._shoulder_mesh(side, index)
			_: mesh = pilot._road_edge_intrusion_mesh(side, index)
		tool.append_from(mesh, 0, layout[index].transform)
		appended = true
	if not appended:
		return
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = tool.commit()
	instance.material_override = material
	parent.add_child(instance)
	mesh_instances += 1

func _add_combined_road(parent: Node3D, start: int, finish: int, surface: String, zone_index: int) -> void:
	var route := HandcraftedStage.route()
	var tool := SurfaceTool.new()
	var appended := false
	for index in range(start, finish + 1):
		if str(route[index].get("surface", "GRAVEL")) != surface or not str(route[index].get("jump_kind", "")).is_empty():
			continue
		tool.append_from(pilot._strip_mesh(-BalanceData.ROAD_HALF_WIDTH, BalanceData.ROAD_HALF_WIDTH, 0.070), 0, layout[index].transform)
		appended = true
	if not appended:
		return
	var material := ShaderMaterial.new()
	material.shader = ROAD_SHADER
	material.set_shader_parameter("surface_variant", 0.0 if surface == "ASPHALT" else 1.0)
	material.set_shader_parameter("zone_seed", float(zone_index))
	material.set_meta("g1d1_derived_full_stage", true)
	var instance := MeshInstance3D.new()
	instance.name = "WeatheredRoad%s" % surface.capitalize()
	instance.mesh = tool.commit()
	instance.material_override = material
	parent.add_child(instance)
	mesh_instances += 1

func _build_underlay(material: Material) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(112.0, 55.0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = plane
	multimesh.instance_count = 54
	for offset in 54:
		var entry: Dictionary = layout[offset + 10]
		multimesh.set_instance_transform(offset, Transform3D(entry.transform.basis, entry.transform.origin - entry.transform.basis.y * 0.56))
	var instance := MultiMeshInstance3D.new()
	instance.name = "FullStageAntiGapUnderlay"
	instance.multimesh = multimesh
	instance.material_override = material
	instance.visibility_range_end = 300.0
	instance.visibility_range_end_margin = 30.0
	surface_root.add_child(instance)
	multimesh_groups += 1
	multimesh_instances += 54

func _build_landmarks() -> void:
	landmark_root = Node3D.new()
	landmark_root.name = "FullStageLandmarks"
	add_child(landmark_root)
	var placements := [
		# Zone 2: progressive eroded corridor, dominant left wall and broken right wall.
		["CanyonWall_A_Concave", 10, -35.0, 12.0, 1, 0.82, 0.88], ["CanyonWall_B_Stepped", 12, 31.0, -8.0, 1, 0.72, -0.84],
		["CanyonWall_A_Concave", 14, -28.0, 7.0, 1, 0.94, 0.96], ["HeroRock_B_LeaningStack", 15, 27.0, -8.0, 0, 0.76, -0.35],
		["CanyonWall_B_Stepped", 17, 30.0, 10.0, 1, 0.88, -0.88], ["MediumRock_03", 16, -20.0, 14.0, 1, 0.74, 0.31],
		# Zone 3: distant announcement followed by asymmetric canyon fins.
		["DistantMesa_B", 18, 78.0, -8.0, 2, 1.62, 0.18], ["CanyonWall_B_Stepped", 20, 33.0, 11.0, 1, 0.78, -0.78],
		["CanyonWall_A_Concave", 22, -31.0, -9.0, 1, 0.88, 0.86], ["CanyonWall_B_Stepped", 24, 27.0, 8.0, 1, 0.92, -0.82],
		["CanyonWall_A_Concave", 26, -29.0, -10.0, 1, 0.96, 0.90], ["DistantMesa_A", 28, -74.0, 3.0, 2, 1.70, -0.16],
		# Zone 4: low, broad plateau edges and a deliberately open panorama.
		["DistantMesa_A", 31, -82.0, 5.0, 2, 1.66, -0.18], ["MediumRock_04", 33, 26.0, -4.0, 1, 0.82, 0.42],
		["DistantMesa_A", 34, -46.0, -8.0, 2, 0.96, -0.12], ["MediumRock_01", 35, -27.0, 12.0, 1, 0.68, 0.22],
		["DistantMesa_B", 37, 49.0, 9.0, 2, 0.92, 0.16], ["MediumRock_06", 37, 28.0, -11.0, 1, 0.64, -0.26],
		["DistantMesa_B", 36, 88.0, 7.0, 2, 1.54, 0.20], ["MediumRock_02", 38, -23.0, -10.0, 1, 0.74, -0.28], ["RoadSign_Hazard", 39, 11.5, 8.0, 1, 0.92, -0.08],
		# Zone 5: readable dune field and a single survey-wreck story cluster.
		["Dune_01", 40, -20.0, 10.0, 1, 1.42, 0.18], ["Dune_02", 42, 22.0, -9.0, 1, 1.55, -0.16],
		["NarrativeWreck_SurveyRover", 44, 13.0, -5.0, 1, 1.78, -0.35], ["Dune_03", 44, 17.0, -2.0, 1, 1.58, -0.18],
		["RoadSign_Hazard", 43, 10.8, 11.0, 1, 1.04, -0.10], ["DebrisGravelCluster", 45, 14.5, 7.0, 1, 1.34, 0.26], ["Dune_01", 47, -24.0, 12.0, 1, 1.35, 0.20],
		# Zone 6: unequal walls, directional signs and two open technical gates.
		["CanyonWall_A_Concave", 49, -30.0, 13.0, 1, 0.76, 0.82], ["RoadSign_Direction", 50, 11.0, 8.0, 1, 0.96, -0.12],
		["CanyonWall_B_Stepped", 52, 27.0, -10.0, 1, 0.82, -0.86], ["SafetyBarrier_01", 53, -11.4, 9.0, 1, 0.94, 0.10],
		["CanyonWall_A_Concave", 54, -25.0, 11.0, 1, 0.72, 0.78], ["MediumRock_05", 55, 20.0, -8.0, 1, 0.86, -0.24], ["CanyonWall_B_Stepped", 56, 31.0, 9.0, 1, 0.76, -0.82],
		# Zone 7: warm distant mesas, open natural gate and clean finish axis.
		["DistantMesa_B", 57, -78.0, 4.0, 2, 1.78, 0.22], ["DistantMesa_A", 59, 76.0, -3.0, 2, 1.70, -0.18],
		["CanyonWall_A_Concave", 61, -29.0, -9.0, 1, 0.94, 0.78], ["CanyonWall_B_Stepped", 61, 31.0, -12.0, 1, 0.88, -0.80],
		["RoadSign_Direction", 62, -11.2, 8.0, 1, 1.00, 0.08], ["SafetyBarrier_01", 63, 11.4, 10.0, 1, 0.96, -0.06],
	]
	for item in placements:
		_place_asset(str(item[0]), int(item[1]), float(item[2]), float(item[3]), int(item[4]), float(item[5]), float(item[6]))

func _place_asset(asset_name: String, segment_index: int, lateral: float, local_z: float, lod: int, scale_value: float, yaw: float) -> void:
	var mesh: Mesh = pilot.lod_assets[lod].get(asset_name) as Mesh
	if mesh == null:
		return
	var entry: Dictionary = layout[segment_index]
	var copy := MeshInstance3D.new()
	copy.name = "%s_S%02d_L%d" % [asset_name, segment_index, lod]
	copy.mesh = mesh
	copy.material_override = _zone_material_for(asset_name, _zone_index_for_segment(segment_index))
	copy.transform = Transform3D(entry.transform.basis * Basis(Vector3.UP, yaw), entry.transform * Vector3(lateral, -0.10, local_z))
	copy.scale = Vector3.ONE * scale_value
	copy.visibility_range_end = 140.0 if lod == 0 else (245.0 if lod == 1 else 380.0)
	copy.visibility_range_end_margin = 22.0
	copy.set_meta("visual_only", true)
	copy.set_meta("zone_identity", int(_zone_index_for_segment(segment_index)) + 1)
	landmark_root.add_child(copy)
	mesh_instances += 1
	lod_usage[lod] = int(lod_usage[lod]) + 1

func _build_scatter() -> void:
	scatter_root = Node3D.new()
	scatter_root.name = "FullStageScatterMultiMesh"
	add_child(scatter_root)
	var density := [[18, 18, 4], [16, 18, 3], [10, 12, 2], [12, 16, 2], [18, 20, 3], [14, 16, 2]]
	for zone_index in range(1, ZONES.size()):
		var zone: Array = ZONES[zone_index]
		var counts: Array = density[zone_index - 1]
		_scatter_zone("SmallRock_02", 2, int(zone[0]), int(zone[1]), int(counts[0]), 4100 + zone_index * 101, 12.5, 25.0, 0.20, 0.48)
		_scatter_zone("DebrisGravelCluster", 2, int(zone[0]), int(zone[1]), int(counts[1]), 5100 + zone_index * 101, 10.5, 20.0, 0.20, 0.52)
		_scatter_zone("DryBush_01", 2, int(zone[0]), int(zone[1]), int(counts[2]), 6100 + zone_index * 101, 13.0, 27.0, 0.36, 0.68)
	_scatter_landmark_contacts("DebrisGravelCluster", 32, 7201)
	_scatter_landmark_contacts("SmallRock_02", 32, 7301)

func _scatter_zone(asset_name: String, lod: int, start: int, finish: int, count: int, seed_value: int, min_side: float, max_side: float, min_scale: float, max_scale: float) -> void:
	var mesh: Mesh = pilot.lod_assets[lod].get(asset_name) as Mesh
	if mesh == null:
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in count:
		var segment_index := rng.randi_range(start, finish)
		var entry: Dictionary = layout[segment_index]
		var side := -1.0 if index % 2 == 0 else 1.0
		var scale_value := rng.randf_range(min_scale, max_scale)
		var basis: Basis = entry.transform.basis * Basis(Vector3.UP, rng.randf_range(-PI, PI))
		basis = basis.scaled(Vector3(scale_value, scale_value * rng.randf_range(0.76, 1.08), scale_value))
		multimesh.set_instance_transform(index, Transform3D(basis, entry.transform * Vector3(side * rng.randf_range(min_side, max_side), -0.08, rng.randf_range(-23.0, 23.0))))
	var instance := MultiMeshInstance3D.new()
	instance.name = "%s_%02d_%02d" % [asset_name, start, finish]
	instance.multimesh = multimesh
	instance.material_override = _zone_material_for(asset_name, _zone_index_for_segment(start))
	instance.visibility_range_end = 155.0
	instance.visibility_range_end_margin = 24.0
	scatter_root.add_child(instance)
	multimesh_groups += 1
	multimesh_instances += count
	lod_usage[lod] = int(lod_usage[lod]) + count

func _scatter_landmark_contacts(asset_name: String, count: int, seed_value: int) -> void:
	var mesh: Mesh = pilot.lod_assets[2].get(asset_name) as Mesh
	if mesh == null:
		return
	var anchors := [[14, -28.0, 7.0], [17, 30.0, 10.0], [22, -31.0, -9.0], [24, 27.0, 8.0], [31, -68.0, 5.0], [44, 18.5, -5.0], [52, 27.0, -10.0], [54, -25.0, 11.0], [61, -29.0, -9.0], [61, 31.0, -12.0]]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in count:
		var anchor: Array = anchors[index % anchors.size()]
		var entry: Dictionary = layout[int(anchor[0])]
		var angle := rng.randf_range(-PI, PI)
		var radius := rng.randf_range(2.2, 7.2)
		var scale_value := rng.randf_range(0.20, 0.48)
		var basis: Basis = entry.transform.basis * Basis(Vector3.UP, rng.randf_range(-PI, PI))
		basis = basis.scaled(Vector3(scale_value, scale_value * rng.randf_range(0.68, 0.96), scale_value))
		var local := Vector3(float(anchor[1]) + cos(angle) * radius, -0.08, float(anchor[2]) + sin(angle) * radius)
		multimesh.set_instance_transform(index, Transform3D(basis, entry.transform * local))
	var instance := MultiMeshInstance3D.new()
	instance.name = asset_name + "LandmarkContacts"
	instance.multimesh = multimesh
	instance.material_override = pilot._material_for(pilot._category(asset_name))
	instance.visibility_range_end = 165.0
	instance.visibility_range_end_margin = 28.0
	scatter_root.add_child(instance)
	multimesh_groups += 1
	multimesh_instances += count
	lod_usage[2] = int(lod_usage[2]) + count

func _zone_index_for_segment(segment_index: int) -> int:
	for index in ZONES.size():
		if segment_index >= int(ZONES[index][0]) and segment_index <= int(ZONES[index][1]):
			return index
	return 0

func _zone_material_for(asset_name: String, zone_index: int) -> Material:
	var category := pilot._category(asset_name)
	if category in ["painted_metal", "oxidized_metal"] or zone_index == 0:
		return pilot._material_for(category)
	var key := "%s:%d" % [category, zone_index]
	if zone_materials.has(key):
		return zone_materials[key]
	var material := pilot._material_for(category).duplicate() as ShaderMaterial
	var palettes := [
		[Color("9a765e"), Color("4f4741"), 0.48],
		[Color("98684b"), Color("493a32"), 0.54],
		[Color("956654"), Color("3d3d45"), 0.50],
		[Color("a08d72"), Color("59544d"), 0.38],
		[Color("aa8049"), Color("5b4935"), 0.50],
		[Color("786b5d"), Color("35383d"), 0.36],
		[Color("ad783f"), Color("5e3d29"), 0.58],
	]
	var palette: Array = palettes[clampi(zone_index, 0, palettes.size() - 1)]
	material.set_shader_parameter("palette_high", palette[0])
	material.set_shader_parameter("palette_low", palette[1])
	material.set_shader_parameter("saturation_scale", palette[2])
	material.resource_name = "G1F1_%s_Zone%d" % [category, zone_index + 1]
	material.set_meta("g1f1_zone_palette", zone_index + 1)
	zone_materials[key] = material
	return material

func _build_start_finish_visuals() -> void:
	var root_node := Node3D.new()
	root_node.name = "FullStageStartFinishVisuals"
	add_child(root_node)
	start_gate = _race_gate("PARTENZA", false)
	start_gate.name = "G1F1StartGate"
	start_gate.transform = Transform3D(layout[0].transform.basis, layout[0].transform * Vector3(0, 0, -18.0))
	root_node.add_child(start_gate)
	finish_gate = _race_gate("TRAGUARDO", true)
	finish_gate.name = "G1F1FinishGate"
	finish_gate.transform = Transform3D(layout[63].transform.basis, layout[63].transform * Vector3(0, 0, -18.0))
	root_node.add_child(finish_gate)
	# Three lightweight paddock cues; all remain outside the driving corridor.
	_build_paddock_marker(root_node, 0, -15.5, 5.0, "PaddockLeft")
	_build_paddock_marker(root_node, 0, 15.5, 2.0, "PaddockRight")
	_place_asset("RoadSign_Hazard", 1, -11.5, 11.0, 1, 0.92, 0.08)
	_place_asset("SafetyBarrier_01", 62, 11.6, -8.0, 1, 0.96, -0.05)

func _race_gate(title: String, is_finish: bool) -> Node3D:
	var gate := Node3D.new()
	gate.set_meta("visual_only", true)
	gate.set_meta("collision_free", true)
	gate.set_meta("pulse_time", 0.0)
	gate.set_meta("race_gate_role", "finish" if is_finish else "start")
	var dark := pilot._surface_material(0.0, "%sGateDark" % title)
	var amber := pilot._material_for("painted_metal")
	var warm_white := StandardMaterial3D.new()
	warm_white.albedo_color = Color("f5e4be")
	warm_white.roughness = 0.78
	for x in [-9.8, 9.8]:
		_add_box(gate, Vector3(0.78, 6.2, 0.78), Vector3(x, 3.1, 0), dark)
		_add_box(gate, Vector3(1.05, 0.26, 1.05), Vector3(x, 0.38, 0), amber)
		_add_box(gate, Vector3(1.65, 2.20, 0.34), Vector3(x, 2.45, -0.54), warm_white if is_finish else amber)
	_add_box(gate, Vector3(20.4, 0.78, 0.78), Vector3(0, 6.0, 0), dark)
	_add_box(gate, Vector3(11.2, 1.05, 0.26), Vector3(0, 5.92, -0.52), dark)
	for x in [-6.4, 6.4]:
		_add_box(gate, Vector3(2.1, 0.24, 0.30), Vector3(x, 5.90, -0.65), warm_white if is_finish else amber)
	if is_finish:
		for x in [-4.2, -1.4, 1.4, 4.2]:
			_add_box(gate, Vector3(1.35, 0.28, 0.32), Vector3(x, 6.03, -0.66), warm_white if absf(x) > 2.0 else amber)
	var label := Label3D.new()
	label.name = "RaceGateLabel"
	label.text = title
	label.position = Vector3(0, 5.86, -0.70)
	label.font_size = 76
	label.pixel_size = 0.019
	label.outline_size = 18
	label.modulate = Color("fff0ce")
	label.outline_modulate = Color("211b14")
	label.no_depth_test = true
	gate.add_child(label)
	return gate

func _build_paddock_marker(parent: Node3D, segment_index: int, lateral: float, local_z: float, label: String) -> void:
	var entry: Dictionary = layout[segment_index]
	var marker := Node3D.new()
	marker.name = label
	marker.transform = Transform3D(entry.transform.basis, entry.transform * Vector3(lateral, 0, local_z))
	marker.set_meta("visual_only", true)
	var fabric := pilot._material_for("painted_metal")
	var dark := pilot._surface_material(0.0, label + "Dark")
	_add_box(marker, Vector3(4.8, 0.28, 3.4), Vector3(0, 2.65, 0), fabric)
	for x in [-2.1, 2.1]:
		for z in [-1.45, 1.45]:
			_add_box(marker, Vector3(0.16, 2.7, 0.16), Vector3(x, 1.35, z), dark)
	_add_box(marker, Vector3(4.5, 0.18, 0.65), Vector3(0, 0.24, -1.45), dark)
	parent.add_child(marker)

func _build_checkpoint_portals() -> void:
	checkpoint_root = Node3D.new()
	checkpoint_root.name = "FullStageCheckpointVisuals"
	add_child(checkpoint_root)
	for checkpoint_number in range(2, 7):
		var segment_index: int = int(CHECKPOINT_SEGMENTS[checkpoint_number - 1])
		var entry: Dictionary = layout[segment_index]
		var portal := _checkpoint_portal(checkpoint_number)
		portal.transform = Transform3D(entry.transform.basis, entry.transform * Vector3(0, 0, -18.0))
		checkpoint_root.add_child(portal)
		checkpoint_portals.append(portal)

func _checkpoint_portal(number: int) -> Node3D:
	var portal := Node3D.new()
	portal.name = "FullStageCheckpoint%02d" % number
	portal.set_meta("collision_free", true)
	portal.set_meta("pulse_time", 0.0)
	var dark := pilot._surface_material(0.0, "CheckpointDark%02d" % number)
	var amber := pilot._material_for("painted_metal")
	for x in [-8.8, 8.8]:
		_add_box(portal, Vector3(0.72, 5.1, 0.72), Vector3(x, 2.55, 0), dark)
		_add_box(portal, Vector3(0.84, 0.24, 0.84), Vector3(x, 0.48, 0), amber)
		_add_box(portal, Vector3(0.84, 0.24, 0.84), Vector3(x, 3.95, 0), amber)
	_add_box(portal, Vector3(18.3, 0.68, 0.72), Vector3(0, 5.0, 0), dark)
	_add_box(portal, Vector3(7.8, 0.78, 0.20), Vector3(0, 4.96, -0.46), dark)
	for x in [-4.65, 4.65]:
		_add_box(portal, Vector3(1.35, 0.22, 0.24), Vector3(x, 4.96, -0.58), amber)
	var label := Label3D.new()
	label.name = "CheckpointNumber"
	label.text = "CP %02d" % number
	label.position = Vector3(0, 4.91, -0.61)
	label.font_size = 72
	label.pixel_size = 0.020
	label.outline_size = 16
	label.modulate = Color("fff0ce")
	label.outline_modulate = Color("211b14")
	label.no_depth_test = true
	portal.add_child(label)
	return portal

func _add_box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	mesh_instances += 1

func _set_metadata() -> void:
	set_meta("environment_v2_playable_pilot", true)
	set_meta("g1d1_visual_polish", true)
	set_meta("full_special_stage_visual_expansion", true)
	set_meta("pilot_start_index", 0)
	set_meta("pilot_end_index", 9)
	set_meta("pilot_length_meters", 520.0)
	set_meta("pilot_checkpoint_index", 9)
	set_meta("full_stage_start_index", 0)
	set_meta("full_stage_end_index", 63)
	set_meta("full_stage_length_meters", 3328.0)
	set_meta("zone_count", 7)
	set_meta("checkpoint_visual_count", 6)
	set_meta("rock_arch_deferred", true)
	set_meta("rock_arch_alternative", "paired_canyon_fins_segments_52_54")
	set_meta("zone_identity_polish", true)
	set_meta("scenario_identifier", "G1-F.1_FULL_STAGE")
	set_meta("zone_boundaries", "0-9,10-17,18-28,29-39,40-47,48-56,57-63")
	set_meta("zone_landmarks", "start_gate,eroded_double_wall,canyon_fins,panoramic_mesas,wreck_dunes,technical_gates,natural_gate_finish")
	set_meta("start_gate_visual", "PARTENZA")
	set_meta("finish_gate_visual", "TRAGUARDO")
	set_meta("collision_count", find_children("*", "CollisionObject3D", true, false).size())
	set_meta("mesh_instances", mesh_instances + int(pilot.get_meta("mesh_instances", 0)))
	set_meta("multimesh_groups", multimesh_groups + int(pilot.get_meta("multimesh_groups", 0)))
	set_meta("multimesh_instances", multimesh_instances + int(pilot.get_meta("multimesh_instances", 0)))
	set_meta("lod0_instances", int(lod_usage[0]) + int(pilot.get_meta("lod0_instances", 0)))
	set_meta("lod1_instances", int(lod_usage[1]) + int(pilot.get_meta("lod1_instances", 0)))
	set_meta("lod2_instances", int(lod_usage[2]) + int(pilot.get_meta("lod2_instances", 0)))
	set_meta("contact_groups", 2)
	set_meta("golden_hour_override", true)
	set_meta("source_materials_unchanged", true)
	set_meta("logical_route_unchanged", true)
	set_meta("streaming_mode", "distance_visibility_with_margin")
	set_meta("asynchronous_loading", false)
