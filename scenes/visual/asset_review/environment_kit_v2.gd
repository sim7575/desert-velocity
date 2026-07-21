class_name EnvironmentKitV2
extends Node3D

const LOD_SCENES := [
	preload("res://assets/models/environment/environment_v2_lod0.glb"),
	preload("res://assets/models/environment/environment_v2_lod1.glb"),
	preload("res://assets/models/environment/environment_v2_lod2.glb"),
]
const LOD_TRIANGLES := [26982, 16495, 9346]
const POLISH_SHADER := preload("res://assets/shaders/environment_v2_polish.gdshader")
const TEXTURE_ROOT := "res://assets/textures/environment/environment_v2/"
const TEXTURE_PATHS := {
	"natural_base": TEXTURE_ROOT + "natural_base_color.png",
	"natural_normal": TEXTURE_ROOT + "natural_normal.png",
	"natural_orm": TEXTURE_ROOT + "natural_orm.png",
	"road_base": TEXTURE_ROOT + "road_base_color.png",
	"road_normal": TEXTURE_ROOT + "road_normal.png",
	"road_orm": TEXTURE_ROOT + "road_orm.png",
	"props_base": TEXTURE_ROOT + "props_base_color.png",
	"props_normal": TEXTURE_ROOT + "props_normal.png",
	"props_orm": TEXTURE_ROOT + "props_orm.png",
	"vegetation_base": TEXTURE_ROOT + "vegetation_base_color.png",
	"vegetation_normal": TEXTURE_ROOT + "vegetation_normal.png",
	"vegetation_orm": TEXTURE_ROOT + "vegetation_orm.png",
}
const COLLISION_ASSETS := [
	"HeroRock_A_SplitCrown", "HeroRock_B_LeaningStack", "HeroRock_C_BrokenButte",
	"CanyonWall_A_Concave", "CanyonWall_B_Stepped", "RockArch_01",
	"DistantMesa_A", "DistantMesa_B", "NarrativeWreck_SurveyRover",
]

var lod_models: Array[Node3D] = []
var lod_assets: Array[Dictionary] = []
var active_lod := 0
var active_review_mode := "final_pbr"
var textures: Dictionary = {}
var collision_root: Node3D
var scatter_root: Node3D
static var shared_materials: Dictionary = {}
static var shared_textures: Dictionary = {}

func _ready() -> void:
	_load_textures()
	for level in LOD_SCENES.size():
		var model := LOD_SCENES[level].instantiate() as Node3D
		model.name = "LOD%d" % level
		add_child(model)
		lod_models.append(model)
		var indexed: Dictionary = {}
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := child as MeshInstance3D
			var source_name := _source_name(mesh_instance.name, level)
			indexed[source_name] = mesh_instance
			_apply_material(mesh_instance, source_name)
		lod_assets.append(indexed)
	_build_review_collisions()
	_build_scatter_preview()
	set_lod(0)
	set_meta("environment_kit_v2_visual", true)
	set_meta("production_integrated", false)
	set_meta("manual_lods", true)
	set_meta("asset_count", 40)
	set_meta("shared_material_count", 9)
	set_meta("texture_count", 12)

func _load_textures() -> void:
	if shared_textures.is_empty():
		for texture_name in TEXTURE_PATHS:
			shared_textures[texture_name] = load(TEXTURE_PATHS[texture_name]) as Texture2D
	textures = shared_textures

func _source_name(imported_name: String, level: int) -> String:
	var suffix := "_LOD%d" % level
	if level > 0 and imported_name.ends_with(suffix):
		return imported_name.trim_suffix(suffix)
	return imported_name

func asset(name: String, level := 0) -> MeshInstance3D:
	return lod_assets[clampi(level, 0, lod_assets.size() - 1)].get(name) as MeshInstance3D

func set_lod(level: int) -> void:
	active_lod = clampi(level, 0, lod_models.size() - 1)
	for index in lod_models.size():
		lod_models[index].visible = index == active_lod

func set_review_mode(mode: String) -> void:
	active_review_mode = mode
	for level in lod_assets.size():
		for asset_name in lod_assets[level]:
			_apply_material(lod_assets[level][asset_name] as MeshInstance3D, asset_name)

func show_only(prefixes: Array[String]) -> void:
	for level in lod_assets.size():
		for asset_name in lod_assets[level]:
			var visible_value := false
			for prefix in prefixes:
				if String(asset_name).begins_with(prefix):
					visible_value = true
					break
			(lod_assets[level][asset_name] as MeshInstance3D).visible = visible_value

func show_all() -> void:
	for level in lod_assets.size():
		for mesh_instance in lod_assets[level].values():
			(mesh_instance as MeshInstance3D).visible = true

func _category(asset_name: String) -> String:
	if asset_name.begins_with(("Cactus_")) or asset_name.begins_with("DryBush_"):
		return "vegetation"
	if asset_name.begins_with("RoadSign_"):
		return "painted_metal"
	if asset_name.begins_with("SafetyBarrier_") or asset_name.begins_with("NarrativeWreck_"):
		return "oxidized_metal"
	if asset_name.begins_with("Dune_") or asset_name.begins_with("RoadEdge_"):
		return "sand"
	if asset_name.begins_with("DebrisGravel"):
		return "ground"
	if asset_name in ["HeroRock_B_LeaningStack", "CanyonWall_B_Stepped"]:
		return "rock_ochre"
	if asset_name in ["HeroRock_C_BrokenButte", "DistantMesa_A"] or asset_name.begins_with("SmallRock_"):
		return "rock_dark"
	return "rock_red"

func _apply_material(mesh_instance: MeshInstance3D, asset_name: String) -> void:
	var material := material_for(_category(asset_name), active_review_mode)
	for surface in mesh_instance.mesh.get_surface_count():
		mesh_instance.set_surface_override_material(surface, material)

func material_for(category: String, mode := "final_pbr") -> Material:
	var key := "%s:%s" % [mode, category]
	if shared_materials.has(key):
		return shared_materials[key]
	if mode == "clay":
		var material := StandardMaterial3D.new()
		material.resource_name = "ENV2_%s_%s" % [category, mode]
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.albedo_color = Color("7b8182")
		material.roughness = 0.78
		shared_materials[key] = material
		return material
	var atlas := "natural"
	var tint := Color.WHITE
	var secondary := Color("89939c")
	var roughness := 0.88
	var metallic := 0.0
	var fracture := 0.18
	var normal_strength := 0.38
	var surface_mode := 0.0
	var seed := 1.0
	match category:
		"rock_red": tint = Color("f0c5b2"); secondary = Color("b8c1c7"); roughness = 0.86; fracture = 0.25; normal_strength = 0.48; seed = 2.1
		"rock_ochre": tint = Color("ead3a5"); secondary = Color("b5bec1"); roughness = 0.89; fracture = 0.22; normal_strength = 0.45; seed = 4.7
		"rock_dark": tint = Color("d4c7c6"); secondary = Color("b6c0ca"); roughness = 0.91; fracture = 0.27; normal_strength = 0.50; seed = 7.3
		"sand": tint = Color("b7a487"); secondary = Color("899499"); roughness = 0.95; normal_strength = 0.30; surface_mode = 1.0; seed = 9.4
		"ground": tint = Color("8d795f"); secondary = Color("74808a"); roughness = 0.92; normal_strength = 0.38; surface_mode = 1.0; seed = 11.6
		"road": atlas = "road"; tint = Color("716f68"); secondary = Color("7e8588"); roughness = 0.84; normal_strength = 0.34; surface_mode = 2.0; seed = 13.2
		"vegetation": atlas = "vegetation"; tint = Color("78906b"); secondary = Color("8c8266"); roughness = 0.89; normal_strength = 0.30; seed = 15.8
		"painted_metal": atlas = "props"; tint = Color("a26e52"); secondary = Color("69747b"); roughness = 0.64; metallic = 0.42; normal_strength = 0.32; seed = 18.1
		"oxidized_metal": atlas = "props"; tint = Color("846457"); secondary = Color("6e777b"); roughness = 0.84; metallic = 0.28; normal_strength = 0.34; seed = 20.7
	var material := ShaderMaterial.new()
	material.resource_name = "ENV2_%s_%s" % [category, mode]
	material.shader = POLISH_SHADER
	material.set_shader_parameter("base_map", textures.get(atlas + "_base"))
	material.set_shader_parameter("normal_map", textures.get(atlas + "_normal"))
	material.set_shader_parameter("orm_map", textures.get(atlas + "_orm"))
	material.set_shader_parameter("primary_tint", tint)
	material.set_shader_parameter("secondary_tint", secondary)
	material.set_shader_parameter("category_seed", seed)
	material.set_shader_parameter("surface_mode", surface_mode)
	material.set_shader_parameter("normal_strength", normal_strength)
	material.set_shader_parameter("roughness_bias", roughness)
	material.set_shader_parameter("metallic_strength", metallic)
	material.set_shader_parameter("fracture_strength", fracture)
	shared_materials[key] = material
	return material

func _build_review_collisions() -> void:
	collision_root = Node3D.new()
	collision_root.name = "ReviewCollisionOnly"
	add_child(collision_root)
	for asset_name in COLLISION_ASSETS:
		var source := asset(asset_name, 0)
		if source == null:
			continue
		var body := StaticBody3D.new()
		body.name = asset_name + "_ReviewCollision"
		body.transform = source.transform
		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var bounds := source.mesh.get_aabb()
		box.size = bounds.size
		shape_node.shape = box
		shape_node.position = bounds.get_center()
		body.add_child(shape_node)
		collision_root.add_child(body)

func _build_scatter_preview() -> void:
	scatter_root = Node3D.new()
	scatter_root.name = "ReducedScatterMultiMesh"
	scatter_root.visible = false
	add_child(scatter_root)
	for config in [["SmallRock_02", 28, 1201], ["SmallRock_07", 24, 1409], ["DebrisGravelCluster", 18, 1601]]:
		var source := asset(config[0], 2)
		if source == null:
			continue
		var instance := MultiMeshInstance3D.new()
		instance.name = String(config[0]) + "_MultiMesh"
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = source.mesh
		multimesh.instance_count = config[1]
		var rng := RandomNumberGenerator.new()
		rng.seed = config[2]
		for index in multimesh.instance_count:
			var side := -1.0 if index % 2 == 0 else 1.0
			var position_value := Vector3(side * rng.randf_range(5.5, 18.0), rng.randf_range(-0.18, 0.08), rng.randf_range(-8.0, 62.0))
			var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * rng.randf_range(0.35, 0.88))
			multimesh.set_instance_transform(index, Transform3D(basis, position_value))
		instance.multimesh = multimesh
		instance.visibility_range_end = 105.0
		instance.visibility_range_end_margin = 15.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		instance.material_override = material_for(_category(config[0]))
		scatter_root.add_child(instance)

func textures_loaded() -> bool:
	for texture_name in TEXTURE_PATHS:
		if textures.get(texture_name) == null:
			return false
	return true

func family_counts() -> Dictionary:
	var result := {"hero": 0, "medium": 0, "small": 0, "arch": 0, "canyon": 0, "mesa": 0, "cactus": 0, "bush": 0, "sign": 0, "barrier": 0, "wreck": 0, "dune": 0, "road_edge": 0, "debris": 0}
	for name_value in lod_assets[0]:
		var name := String(name_value)
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
		elif name.begins_with("DebrisGravel"): result.debris += 1
	return result
