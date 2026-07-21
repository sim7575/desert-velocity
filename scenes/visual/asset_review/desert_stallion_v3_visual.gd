class_name DesertStallionV3Visual
extends Node3D

const LOD_PATHS := [
	"res://assets/models/vehicles/desert_stallion_v3.glb",
	"res://assets/models/vehicles/desert_stallion_v3_lod1.glb",
	"res://assets/models/vehicles/desert_stallion_v3_lod2.glb",
]
const TEXTURE_PATHS := {
	"base_color": "res://assets/textures/vehicles/stallion_v3/stallion_v3_base_color.png",
	"normal": "res://assets/textures/vehicles/stallion_v3/stallion_v3_normal.png",
	"orm": "res://assets/textures/vehicles/stallion_v3/stallion_v3_orm.png",
	"dirt_damage": "res://assets/textures/vehicles/stallion_v3/stallion_v3_dirt_damage_mask.png",
	"emissive": "res://assets/textures/vehicles/stallion_v3/stallion_v3_emissive.png",
}
# The placeholder GLB deliberately carries no materials. This table preserves the
# approved Blender slot order without changing the GLB or its geometry.
const SURFACE_CATEGORIES := {
	"V3_BodyShell": ["paint"],
	"V3_CanopyFrame": ["paint"],
	"V3_Glass": ["glass"],
	"V3_MuscularFenders": ["paint"],
	"Wheel_FL_Geometry": ["rubber", "metal"],
	"Wheel_FR_Geometry": ["rubber", "metal"],
	"Wheel_RL_Geometry": ["rubber", "metal"],
	"Wheel_RR_Geometry": ["rubber", "metal"],
	"V3_VisibleSuspension": ["metal", "light", "dark"],
	"V3_RollCage": ["metal"],
	"V3_UnderbodySkid": ["metal"],
	"V3_FunctionalDetails": ["dark", "light", "accent", "metal", "paint"],
	"V3_Interior": ["dark", "accent", "metal", "light"],
	"V3_FinalFunctionalDetail": ["paint", "metal", "dark"],
}
const WHEEL_CENTERS := {
	"Wheel_FL": Vector3(-0.94, 0.51, -1.47),
	"Wheel_FR": Vector3(0.94, 0.51, -1.47),
	"Wheel_RL": Vector3(-0.94, 0.51, 1.47),
	"Wheel_RR": Vector3(0.94, 0.51, 1.47),
}

var lod_models: Array[Node3D] = []
var active_lod := 0
var active_variant := "rally_sand"
var active_review_mode := "final_pbr"
static var shared_material_cache: Dictionary = {}
static var shared_textures: Dictionary = {}
var textures: Dictionary

func _ready() -> void:
	if shared_textures.is_empty():
		for texture_name in TEXTURE_PATHS:
			shared_textures[texture_name] = load(TEXTURE_PATHS[texture_name]) as Texture2D
	textures = shared_textures
	for level in _lod_levels_to_instantiate():
		var packed := load(_lod_path_for_level(level)) as PackedScene
		if packed == null:
			continue
		var model := packed.instantiate() as Node3D
		model.name = "LOD%d" % level
		model.rotation.y = PI
		add_child(model)
		_swap_wheel_names(model)
		_mark_wheels(model)
		lod_models.append(model)
	set_lod(0)
	set_variant("rally_sand")
	set_meta("stallion_v3_visual", true)
	set_meta("manual_lods", true)
	set_meta("production_integrated", false)

func _lod_levels_to_instantiate() -> Array[int]:
	return [0, 1, 2]

func _lod_path_for_level(level: int) -> String:
	return LOD_PATHS[level]

func set_lod(level: int) -> void:
	active_lod = clampi(level, 0, lod_models.size() - 1)
	for index in lod_models.size():
		lod_models[index].visible = index == active_lod

func set_variant(variant: String) -> void:
	active_variant = variant
	for model in lod_models:
		_apply_materials(model, variant)

func set_review_mode(mode: String) -> void:
	active_review_mode = mode
	for model in lod_models:
		_apply_materials(model, active_variant)

func _apply_materials(model: Node, variant: String) -> void:
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var category := _surface_category(mesh_instance.name, surface)
			mesh_instance.set_surface_override_material(surface, _material_for(category, variant))

func _material_for(category: String, variant: String) -> Material:
	var key := "%s:%s:%s" % [variant, category, active_review_mode]
	if shared_material_cache.has(key):
		return shared_material_cache[key]
	if active_review_mode in ["base_color_only", "roughness", "metallic", "normal", "ao"]:
		var check_material := _technical_material(category, variant, active_review_mode)
		shared_material_cache[key] = check_material
		return check_material
	var mat := StandardMaterial3D.new()
	mat.resource_name = "V3_%s_%s" % [variant, category]
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if active_review_mode == "clay" or variant == "clay":
		mat.albedo_color = Color("87919a")
		mat.roughness = 0.74
		shared_material_cache[key] = mat
		return mat
	match category:
		"paint":
			mat.albedo_color = Color("f3e2bd") if variant == "rally_sand" else Color("536f8a")
			mat.albedo_texture = textures.get("base_color")
			mat.metallic = 0.0
			mat.roughness = 0.72 if variant == "rally_sand" else 0.62
			_add_surface_maps(mat, 0.38, false)
		"metal":
			mat.albedo_color = Color("59636a") if variant == "rally_sand" else Color("566675")
			mat.metallic = 0.76
			mat.roughness = 0.48
			_add_surface_maps(mat, 0.26, false)
		"rubber":
			mat.albedo_color = Color("25292b")
			mat.metallic = 0.0
			mat.roughness = 0.91
			_add_surface_maps(mat, 0.58, false)
		"glass":
			mat.albedo_color = Color(0.16, 0.25, 0.29, 0.46) if variant == "rally_sand" else Color(0.12, 0.21, 0.29, 0.50)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.18
			mat.metallic = 0.0
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"light":
			mat.albedo_color = Color("f6d998")
			mat.emission_enabled = true
			mat.emission = Color("ffbe58")
			mat.emission_energy_multiplier = 1.45
			mat.emission_texture = textures.get("emissive")
			mat.roughness = 0.30
		"accent":
			mat.albedo_color = Color("bd4c2b") if variant == "rally_sand" else Color("e09442")
			mat.emission_enabled = true
			mat.emission = Color("d9532f") if variant == "rally_sand" else Color("f2a44f")
			mat.emission_energy_multiplier = 0.75
			mat.roughness = 0.48
		_:
			mat.albedo_color = Color("333a3e") if variant == "rally_sand" else Color("2e3944")
			mat.roughness = 0.84
			_add_surface_maps(mat, 0.20, false)
	shared_material_cache[key] = mat
	return mat

func _add_surface_maps(mat: StandardMaterial3D, normal_strength: float, use_metallic_map: bool) -> void:
	var orm := textures.get("orm") as Texture2D
	if orm != null:
		mat.ao_enabled = true
		mat.ao_texture = orm
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.roughness_texture = orm
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		if use_metallic_map:
			mat.metallic_texture = orm
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	var normal := textures.get("normal") as Texture2D
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = normal_strength

func _surface_category(mesh_name: String, surface: int) -> String:
	if mesh_name.begins_with("RuntimeStatic_"):
		return mesh_name.trim_prefix("RuntimeStatic_")
	var slots: Array = SURFACE_CATEGORIES.get(mesh_name, [])
	if surface >= 0 and surface < slots.size():
		return slots[surface]
	return "dark"

func _technical_material(category: String, variant: String, mode: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded;
uniform sampler2D base_map : source_color;
uniform sampler2D data_map;
uniform vec4 tint : source_color = vec4(1.0);
uniform int check_mode = 0;
uniform bool use_base_map = false;
uniform bool use_data_map = true;
uniform float roughness_value = 1.0;
uniform float metallic_value = 0.0;
void fragment() {
	vec3 base = tint.rgb;
	if (use_base_map) base *= texture(base_map, UV).rgb;
	vec3 data = texture(data_map, UV).rgb;
	if (check_mode == 1) ALBEDO = vec3(use_data_map ? data.g * roughness_value : roughness_value);
	else if (check_mode == 2) ALBEDO = vec3(metallic_value);
	else if (check_mode == 3) ALBEDO = use_data_map ? data : vec3(0.5, 0.5, 1.0);
	else if (check_mode == 4) ALBEDO = vec3(use_data_map ? data.r : 1.0);
	else ALBEDO = base;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var base_texture := textures.get("base_color") as Texture2D
	var data_texture := textures.get("normal" if mode == "normal" else "orm") as Texture2D
	if base_texture != null:
		mat.set_shader_parameter("base_map", base_texture)
	if data_texture != null:
		mat.set_shader_parameter("data_map", data_texture)
	var tint := _technical_tint(category, variant)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("use_base_map", category == "paint")
	mat.set_shader_parameter("use_data_map", category in ["paint", "metal", "rubber", "dark"])
	mat.set_shader_parameter("roughness_value", _category_roughness(category, variant))
	mat.set_shader_parameter("metallic_value", 0.76 if category == "metal" else 0.0)
	mat.set_shader_parameter("check_mode", ["base_color_only", "roughness", "metallic", "normal", "ao"].find(mode))
	return mat

func _category_roughness(category: String, variant: String) -> float:
	match category:
		"paint": return 0.72 if variant == "rally_sand" else 0.62
		"metal": return 0.48
		"rubber": return 0.91
		"glass": return 0.18
		"light": return 0.30
		"accent": return 0.48
		_: return 0.84

func _technical_tint(category: String, variant: String) -> Color:
	match category:
		"paint": return Color("f3e2bd") if variant == "rally_sand" else Color("536f8a")
		"metal": return Color("59636a") if variant == "rally_sand" else Color("566675")
		"rubber": return Color("25292b")
		"glass": return Color("45626d")
		"light": return Color("f6d998")
		"accent": return Color("bd4c2b") if variant == "rally_sand" else Color("e09442")
		_: return Color("333a3e") if variant == "rally_sand" else Color("2e3944")

func textures_loaded() -> bool:
	for texture_name in TEXTURE_PATHS:
		if textures.get(texture_name) == null:
			return false
	return true

func material_assignment_counts() -> Dictionary:
	var counts: Dictionary = {}
	for mesh_name in SURFACE_CATEGORIES:
		for category in SURFACE_CATEGORIES[mesh_name]:
			counts[category] = int(counts.get(category, 0)) + 1
	return counts

func _swap_wheel_names(model: Node) -> void:
	for pair in [["Wheel_FL", "Wheel_FR"], ["Wheel_RL", "Wheel_RR"]]:
		var left := model.find_child(pair[0], true, false)
		var right := model.find_child(pair[1], true, false)
		if left == null or right == null:
			continue
		left.name = pair[0] + "_Swap"
		right.name = pair[0]
		left.name = pair[1]

func _mark_wheels(model: Node) -> void:
	for wheel_name in WHEEL_CENTERS:
		var wheel := model.find_child(wheel_name, true, false) as Node3D
		if wheel == null:
			continue
		wheel.set_meta("vehicle_wheel", true)
		wheel.set_meta("front_wheel", wheel_name in ["Wheel_FL", "Wheel_FR"])

func wheel_pivots_valid(level := 0) -> bool:
	var model := lod_models[clampi(level, 0, lod_models.size() - 1)]
	for wheel_name in WHEEL_CENTERS:
		var wheel := model.find_child(wheel_name, true, false) as Node3D
		if wheel == null or not bool(wheel.get_meta("vehicle_wheel", false)):
			return false
		var expected: Vector3 = WHEEL_CENTERS[wheel_name]
		if (wheel.position - Vector3(-expected.x, expected.y, -expected.z)).length() > 0.01:
			return false
	return true
