class_name PremiumSliceCamera
extends Camera3D

const PREVIOUS_DISTANCE := 5.8
const PREVIOUS_HEIGHT := 2.25
const PREVIOUS_FOV := 62.0
const CHASE_DISTANCE := 4.65
const CHASE_HEIGHT := 1.78
const BASE_FOV := 62.5
const LATERAL_OFFSET := 0.48
const LOOK_AHEAD := 13.0

var target_follow: PathFollow3D
var path_curve: Curve3D
var initialized := false
var max_frame_step := 0.0
var previous_position := Vector3.ZERO
var sequence_speed_ratio := 0.0
var boost_strength := 0.0
var manual_capture := false
var elapsed := 0.0

func configure(target: PathFollow3D, curve: Curve3D) -> void:
	target_follow = target
	path_curve = curve
	fov = BASE_FOV
	current = true
	snap_to_target()

func snap_to_target() -> void:
	if target_follow == null or path_curve == null: return
	var frame := PremiumSliceGeometry.sample_frame(path_curve, target_follow.progress)
	var forward := -frame.basis.z
	var side := frame.basis.x
	global_position = target_follow.global_position - forward * CHASE_DISTANCE + Vector3.UP * CHASE_HEIGHT + side * LATERAL_OFFSET
	look_at(target_follow.global_position + forward * LOOK_AHEAD + side * -0.22 + Vector3.UP * 0.78, Vector3.UP)
	previous_position = global_position
	initialized = true

func _process(delta: float) -> void:
	if target_follow == null or path_curve == null or manual_capture: return
	elapsed += delta
	var frame := PremiumSliceGeometry.sample_frame(path_curve, target_follow.progress)
	var forward := -frame.basis.z
	var side := frame.basis.x
	var before := PremiumSliceGeometry.sample_frame(path_curve, maxf(0.0, target_follow.progress - 7.0))
	var after := PremiumSliceGeometry.sample_frame(path_curve, minf(path_curve.get_baked_length(), target_follow.progress + 7.0))
	var curve_bias := clampf((-before.basis.z).signed_angle_to(-after.basis.z, Vector3.UP) * 0.55, -0.32, 0.32)
	var boost_bob := sin(elapsed * 19.0) * 0.018 * boost_strength
	var desired := target_follow.global_position - forward * CHASE_DISTANCE + Vector3.UP * (CHASE_HEIGHT + boost_bob) + side * (LATERAL_OFFSET + curve_bias)
	if not initialized:
		global_position = desired
		initialized = true
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-7.0 * delta))
	var look_target := target_follow.global_position + forward * LOOK_AHEAD + side * (-0.22 + curve_bias * 0.35) + Vector3.UP * 0.78
	look_at(look_target, Vector3.UP)
	fov = lerpf(fov, BASE_FOV + sequence_speed_ratio * 7.0 + boost_strength * 4.0, 1.0 - exp(-3.2 * delta))
	if previous_position != Vector3.ZERO:
		max_frame_step = maxf(max_frame_step, previous_position.distance_to(global_position))
	previous_position = global_position

func structural_stability() -> Dictionary:
	return {"deterministic": true, "max_frame_step": max_frame_step, "distance": global_position.distance_to(target_follow.global_position) if target_follow != null else INF}

func composition_configuration() -> Dictionary:
	return {
		"previous_distance": PREVIOUS_DISTANCE,
		"previous_height": PREVIOUS_HEIGHT,
		"previous_fov": PREVIOUS_FOV,
		"distance": CHASE_DISTANCE,
		"height": CHASE_HEIGHT,
		"base_fov": BASE_FOV,
		"lateral_offset": LATERAL_OFFSET,
		"look_ahead": LOOK_AHEAD,
	}
