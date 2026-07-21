class_name EnduranceG1F1VisualAdapter
extends Node3D

const PILOT_SCENE:=preload("res://scenes/production_visual_pilot/environment/EnvironmentV2PlayableScenarioPilot.tscn")

var road_manager:RoadManager
var kit:EnvironmentV2PlayableScenarioPilot
var terrain_material:ShaderMaterial
var road_material:ShaderMaterial
var shoulder_material:ShaderMaterial
var visual_updates:=0

func configure(manager:RoadManager)->void:
	road_manager=manager
	kit=PILOT_SCENE.instantiate() as EnvironmentV2PlayableScenarioPilot
	add_child(kit)
	kit.visible=false
	kit._load_textures();kit._index_lod_assets()
	terrain_material=kit._surface_material(0.0,"EnduranceLayeredTerrain")
	road_material=kit._surface_material(1.0,"EnduranceWeatheredRoad")
	shoulder_material=kit._surface_material(2.0,"EnduranceDustyShoulder")
	for segment in manager.segments:update_segment_visual(segment,int(segment.get_meta("route_index",-1)))
	set_meta("environment_v2_playable_pilot",true)
	set_meta("g1d1_visual_polish",true)
	set_meta("full_special_stage_visual_expansion",true)
	set_meta("zone_identity_polish",true)
	set_meta("scenario_identifier","G1-F.1_FULL_STAGE")
	set_meta("endurance_visual_adapter",true)
	set_meta("logical_route_unchanged",true)
	set_meta("collision_count",0)

func update_segment_visual(segment:Node3D,route_index:int)->void:
	var old:=segment.get_node_or_null("EnduranceG1F1SegmentVisual")
	if old!=null:old.queue_free()
	var visual:=Node3D.new();visual.name="EnduranceG1F1SegmentVisual";visual.add_to_group("g1f1_endurance_visual");segment.add_child(visual)
	_add_mesh(visual,"LayeredTerrain",kit._terrain_mesh(posmod(route_index,10)),terrain_material,Vector3.ZERO)
	_add_mesh(visual,"WeatheredRoad",kit._strip_mesh(-BalanceData.ROAD_HALF_WIDTH,BalanceData.ROAD_HALF_WIDTH,.070),road_material,Vector3.ZERO)
	for side in [-1.0,1.0]:
		_add_mesh(visual,"DustyShoulder",kit._shoulder_mesh(side,posmod(route_index,10)),shoulder_material,Vector3.ZERO)
		_add_mesh(visual,"SandIntrusion",kit._road_edge_intrusion_mesh(side,posmod(route_index,10)),shoulder_material,Vector3.ZERO)
	_add_landmark(visual,route_index)
	for child in segment.get_children():
		if child==visual or child is CollisionObject3D:continue
		if child.is_in_group("spawned") or child.is_in_group("route_detail") or child.is_in_group("stage_jump_geometry"):continue
		if child is Node3D:(child as Node3D).visible=false
	segment.set_meta("full_stage_visual_expansion",true)
	segment.set_meta("scenario_identifier","G1-F.1_FULL_STAGE")
	visual_updates+=1;set_meta("visual_updates",visual_updates)

func _add_mesh(parent:Node3D,label:String,mesh:Mesh,material:Material,position:Vector3)->void:
	var instance:=MeshInstance3D.new();instance.name=label;instance.mesh=mesh;instance.material_override=material;instance.position=position;parent.add_child(instance)

func _add_landmark(parent:Node3D,route_index:int)->void:
	var choices:=["MediumRock_%02d"%(1+posmod(route_index,6)),"Dune_%02d"%(1+posmod(route_index,3)),"DryBush_01"]
	var asset_name:String=choices[posmod(route_index,choices.size())]
	var lod:=1 if asset_name.begins_with("Dune_") else 2
	var mesh:Mesh=kit.lod_assets[lod].get(asset_name) as Mesh
	if mesh==null:return
	for side in [-1.0,1.0]:
		var instance:=MeshInstance3D.new();instance.name=asset_name;instance.mesh=mesh;instance.material_override=kit._material_for(kit._category(asset_name));instance.position=Vector3(side*(16.0+posmod(route_index,4)*2.2),-.08,-10.0+posmod(route_index*7,20));instance.rotation.y=route_index*.47+side;instance.scale=Vector3.ONE*(.55 if lod==2 else .9);instance.visibility_range_end=180.0;instance.visibility_range_end_margin=22.0;parent.add_child(instance)
