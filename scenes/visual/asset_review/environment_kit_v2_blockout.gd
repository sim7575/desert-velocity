class_name EnvironmentKitV2Blockout
extends Node3D

const KIT_SCENE := preload("res://assets/models/environment/environment_kit_v2_blockout.glb")

var kit_model: Node3D
var assets: Dictionary = {}

func _ready() -> void:
	kit_model = KIT_SCENE.instantiate() as Node3D
	kit_model.name = "EnvironmentKitV2Library"
	add_child(kit_model)
	_index_assets(kit_model)
	set_meta("environment_kit_v2_blockout", true)
	set_meta("production_integrated", false)
	set_meta("asset_count", assets.size())
	set_meta("triangle_count", 10474)
	set_meta("material_count", 7)

func _index_assets(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		assets[mesh_instance.name] = mesh_instance

func asset(name: String) -> MeshInstance3D:
	return assets.get(name) as MeshInstance3D

func set_family_visible(prefixes: Array[String], visible_value: bool) -> void:
	for asset_name in assets:
		var matches := false
		for prefix in prefixes:
			if String(asset_name).begins_with(prefix):
				matches = true
				break
		(assets[asset_name] as MeshInstance3D).visible = visible_value if matches else not visible_value

func show_only(prefixes: Array[String]) -> void:
	for asset_name in assets:
		var show := false
		for prefix in prefixes:
			if String(asset_name).begins_with(prefix):
				show = true
				break
		(assets[asset_name] as MeshInstance3D).visible = show

func show_all() -> void:
	for mesh_instance in assets.values():
		(mesh_instance as MeshInstance3D).visible = true

func family_counts() -> Dictionary:
	var result := {
		"hero": 0, "medium": 0, "small": 0, "arch": 0, "canyon": 0,
		"mesa": 0, "cactus": 0, "bush": 0, "sign": 0, "barrier": 0,
		"wreck": 0, "dune": 0, "road_edge": 0, "debris": 0,
	}
	for asset_name in assets:
		var name := String(asset_name)
		if name.begins_with("HeroRock_"): result.hero += 1
		elif name.begins_with("MediumRock_"): result.medium += 1
		elif name.begins_with("SmallRock_"): result.small += 1
		elif name.begins_with("RockArch_"): result.arch += 1
		elif name.begins_with("CanyonWall_"): result.canyon += 1
		elif name.begins_with("DistantMesa_"): result.mesa += 1
		elif name.begins_with("Cactus_"): result.cactus += 1
		elif name.begins_with("DryBush_"): result.bush += 1
		elif name.begins_with("RoadSign_"): result.sign += 1
		elif name.begins_with("SafetyBarrier_"): result.barrier += 1
		elif name.begins_with("NarrativeWreck_"): result.wreck += 1
		elif name.begins_with("Dune_"): result.dune += 1
		elif name.begins_with("RoadEdge_"): result.road_edge += 1
		elif name.begins_with("DebrisGravelCluster"): result.debris += 1
	return result
