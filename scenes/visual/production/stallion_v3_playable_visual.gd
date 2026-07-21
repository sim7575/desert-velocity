class_name StallionV3PlayableVisual
extends DesertStallionV3Visual

const RUNTIME_WHEEL_CENTERS := {
	"Wheel_FL": Vector3(-0.88, 0.47, -1.41),
	"Wheel_FR": Vector3(0.88, 0.47, -1.41),
	"Wheel_RL": Vector3(-0.88, 0.47, 1.41),
	"Wheel_RR": Vector3(0.88, 0.47, 1.41),
}
const MODEL_OFFSET := Vector3(0.0, 0.04, 0.0)
const RUNTIME_SOURCE_LOD := 1
const RUNTIME_SOURCE_ASSET_PATH := "res://assets/models/vehicles/desert_stallion_v3_lod1.glb"
const RUNTIME_OPTIMIZED_SCENE_PATH := "res://scenes/visual/production/runtime_optimized/stallion_v3_lod1_runtime_optimized.scn"
const GAMEPLAY_EFFECTS_SCENE_PATH := "res://scenes/production_visual_pilot/effects/GameplayVisualEffectsPilot.tscn"
static var use_g1e_gameplay_visual_effects := true
var runtime_visual_initialized := false

func _lod_levels_to_instantiate() -> Array[int]:
	return [RUNTIME_SOURCE_LOD]

func _lod_path_for_level(_level: int) -> String:
	return RUNTIME_OPTIMIZED_SCENE_PATH

func _ready() -> void:
	initialize_runtime_visual()

func initialize_runtime_visual() -> void:
	if runtime_visual_initialized:
		return
	runtime_visual_initialized = true
	super._ready()
	name = "DesertStallionV3RallySand"
	set_lod(0)
	set_variant("rally_sand")
	for model in lod_models:
		model.position = MODEL_OFFSET
	_align_runtime_wheel_pivots()
	set_meta("stallion_v3_visual_pilot", true)
	set_meta("stallion_v3_variant", "rally_sand")
	set_meta("visual_model_path", RUNTIME_OPTIMIZED_SCENE_PATH)
	set_meta("runtime_source_asset_path", RUNTIME_SOURCE_ASSET_PATH)
	set_meta("runtime_source_lod", RUNTIME_SOURCE_LOD)
	set_meta("runtime_static_surface_draws", 6)
	set_meta("runtime_geometry_precomputed", true)
	set_meta("production_integrated", true)
	set_meta("manual_lods", false)
	# VehicleController's unchanged wheel-animation path recognizes this legacy
	# capability marker. Identity remains unambiguous through the V3 metadata.
	set_meta("blender_stallion_v2", true)
	set_meta("wheel_animation_compatibility", "blender_v2_pivots")
	_attach_gameplay_visual_effects()

func _attach_gameplay_visual_effects() -> void:
	if not use_g1e_gameplay_visual_effects:
		return
	if not ResourceLoader.exists(GAMEPLAY_EFFECTS_SCENE_PATH):
		return
	var effects_scene := load(GAMEPLAY_EFFECTS_SCENE_PATH) as PackedScene
	if effects_scene == null:
		return
	var effects := effects_scene.instantiate()
	effects.name = "GameplayVisualEffectsG1E"
	add_child(effects)
	set_meta("g1e_gameplay_visual_effects", true)

func _align_runtime_wheel_pivots() -> void:
	for model in lod_models:
		for wheel_name in RUNTIME_WHEEL_CENTERS:
			var wheel := model.find_child(wheel_name, true, false) as Node3D
			if wheel == null:
				continue
			var desired_center: Vector3 = RUNTIME_WHEEL_CENTERS[wheel_name]
			wheel.position = Vector3(-desired_center.x, desired_center.y, -desired_center.z)
			wheel.set_meta("desired_center", desired_center)
