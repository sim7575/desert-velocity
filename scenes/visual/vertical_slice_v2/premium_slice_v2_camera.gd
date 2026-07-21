class_name PremiumSliceV2Camera
extends Camera3D

const CHASE_DISTANCE := 6.2
const CHASE_HEIGHT := 2.15
const BASE_FOV := 68.0
const BOOST_FOV_DELTA := 3.0
const LOOK_AHEAD := 18.0
const LATERAL_OFFSET := 0.34

var target: PathFollow3D
var curve: Curve3D
var boost_strength := 0.0
var speed_ratio := 0.0
var manual_capture := false
var initialized := false
var previous_position := Vector3.ZERO
var max_frame_step := 0.0
var elapsed := 0.0

func configure(target_follow: PathFollow3D, path_curve: Curve3D) -> void:
	target = target_follow
	curve = path_curve
	fov = BASE_FOV
	current = true
	snap_to_target()

func snap_to_target() -> void:
	if target == null: return
	var frame := PremiumSliceV2Geometry.sample_frame(curve, target.progress)
	var forward := -frame.basis.z
	global_position = target.global_position - forward * CHASE_DISTANCE + Vector3.UP * CHASE_HEIGHT + frame.basis.x * LATERAL_OFFSET
	look_at(target.global_position + forward * LOOK_AHEAD + Vector3.UP * 0.82, Vector3.UP)
	previous_position = global_position
	initialized = true

func _process(delta: float) -> void:
	if target == null or manual_capture: return
	elapsed += delta
	var frame := PremiumSliceV2Geometry.sample_frame(curve, target.progress)
	var forward := -frame.basis.z
	var before := PremiumSliceV2Geometry.sample_frame(curve, maxf(0.0, target.progress - 8.0))
	var after := PremiumSliceV2Geometry.sample_frame(curve, minf(curve.get_baked_length(), target.progress + 8.0))
	var curve_bias := clampf((-before.basis.z).signed_angle_to(-after.basis.z, Vector3.UP) * 0.42, -0.30, 0.30)
	var boost_vibration := sin(elapsed * 23.0) * 0.012 * boost_strength
	var boost_lateral := sin(elapsed * 17.0 + 0.7) * 0.007 * boost_strength
	var desired := target.global_position - forward * CHASE_DISTANCE + Vector3.UP * (CHASE_HEIGHT + boost_vibration) + frame.basis.x * (LATERAL_OFFSET + curve_bias + boost_lateral)
	global_position = desired if not initialized else global_position.lerp(desired, 1.0 - exp(-7.5 * delta))
	var look_target := target.global_position + forward * LOOK_AHEAD + frame.basis.x * curve_bias * 0.28 + Vector3.UP * 0.82
	look_at(look_target, Vector3.UP)
	fov = lerpf(fov, BASE_FOV + speed_ratio * 3.0 + boost_strength * BOOST_FOV_DELTA, 1.0 - exp(-3.8 * delta))
	if previous_position != Vector3.ZERO: max_frame_step = maxf(max_frame_step, previous_position.distance_to(global_position))
	previous_position = global_position
	initialized = true

func stability() -> Dictionary:
	return {"deterministic": true, "max_frame_step": max_frame_step, "distance": global_position.distance_to(target.global_position) if target != null else INF, "base_fov": BASE_FOV, "boost_fov": BASE_FOV + 3.0 + BOOST_FOV_DELTA, "height": CHASE_HEIGHT, "look_ahead": LOOK_AHEAD}
