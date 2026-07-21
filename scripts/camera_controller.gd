class_name CameraController
extends Camera3D

const V3_CHASE_BASELINE := Vector4(7.2, 3.3, 5.0, 1.0)
const V3_CHASE_FINAL := Vector4(9.8, 2.9, 8.5, 4.5)
const V3_POSITION_RESPONSE := 10.0
const V3_ROTATION_RESPONSE := 12.0
const V3_MAX_FOLLOW_ERROR := 0.60
const V3_MIN_CAMERA_DISTANCE := 9.80
const V3_MAX_CAMERA_DISTANCE := 10.70
const V3_BOOST_CHASE_DISTANCE := 8.60
const V3_BOOST_MIN_CAMERA_DISTANCE := 8.80
const V3_BOOST_MAX_CAMERA_DISTANCE := 9.60

var target: Node3D
var view_mode: int = 0
var shake: float = 0.0
var road_manager: RoadManager
var v3_controlled_baseline := false
var v3_last_desired_position := Vector3.ZERO
var v3_last_follow_error := 0.0

func set_v3_controlled_baseline(enabled: bool) -> void:
	v3_controlled_baseline = enabled

func v3_chase_parameters() -> Vector4:
	return V3_CHASE_BASELINE if v3_controlled_baseline else V3_CHASE_FINAL

func v3_follow_error() -> float:
	return v3_last_follow_error

func v3_camera_distance() -> float:
	return global_position.distance_to(target.global_position) if target != null else 0.0

func _process(delta: float) -> void:
	if target == null: return
	shake = move_toward(shake, 0.0, delta * 2.8)
	if Input.is_action_just_pressed("camera_toggle"): view_mode=(view_mode+1)%4
	var stallion_v2:bool=false
	var gt_v2:bool=false
	var stallion_v3:bool=false
	var target_stats:Variant=target.get("stats")
	var target_visual:Variant=target.get("visual")
	if target_visual is Node3D:
		stallion_v3=bool((target_visual as Node3D).get_meta("stallion_v3_visual_pilot",false))
	if target_stats is Dictionary:
		stallion_v2=str((target_stats as Dictionary).get("name",""))=="Desert Stallion 65" and VehicleFactory.use_blender_stallion_v2
		gt_v2=str((target_stats as Dictionary).get("name",""))=="Bavarian GT-R" and VehicleFactory.use_blender_gt_v2
	var distances:Array[float]=[7.2,11.5,1.2,.15]
	var heights:Array[float]=[3.3,5.2,1.75,1.05]
	if stallion_v2:
		distances=[7.2,11.5,-1.40,-2.62]
		heights=[3.3,5.2,1.16,.64]
	elif gt_v2:
		distances=[7.2,11.5,-1.45,-2.46]
		heights=[3.3,5.2,1.10,.62]
	var look_ahead:=5.0
	var look_height:=1.0
	if stallion_v3 and view_mode==0:
		var chase:=v3_chase_parameters()
		distances[0]=chase.x
		heights[0]=chase.y
		look_ahead=chase.z
		look_height=chase.w
	var turbo: bool = target.get("turbo_time") > 0.0
	var distance:float=distances[view_mode]; var height:float=heights[view_mode]
	if stallion_v3 and view_mode == 0 and turbo and not v3_controlled_baseline:
		distance = V3_BOOST_CHASE_DISTANCE
	var chase_forward := -target.global_transform.basis.z
	if stallion_v3 and view_mode == 0:
		var target_velocity: Variant = target.get("velocity")
		if target_velocity is Vector3:
			var planar_velocity := Vector3(target_velocity.x, 0.0, target_velocity.z)
			if planar_velocity.length() > 2.0:
				chase_forward = chase_forward.lerp(planar_velocity.normalized(), 0.55).normalized()
		if road_manager != null:
			chase_forward = chase_forward.lerp(road_manager.curve_direction_near(target.global_position), 0.35).normalized()
	var desired := target.global_position - chase_forward * distance + Vector3.UP * height
	if get_world_3d()!=null and view_mode<2:
		var query:=PhysicsRayQueryParameters3D.create(target.global_position+Vector3.UP*1.2,desired,1)
		if target is CollisionObject3D:query.exclude=[(target as CollisionObject3D).get_rid()]
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():desired=hit.position+hit.normal*.45
	desired += Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0.0)
	if stallion_v3 and view_mode == 0:
		v3_last_desired_position = desired
		var position_blend := 1.0 - exp(-V3_POSITION_RESPONSE * delta)
		var filtered_position := global_position.lerp(desired, position_blend)
		var remaining_error := filtered_position.distance_to(desired)
		if remaining_error > V3_MAX_FOLLOW_ERROR:
			filtered_position = desired + desired.direction_to(filtered_position) * V3_MAX_FOLLOW_ERROR
		if not v3_controlled_baseline:
			var target_offset := filtered_position - target.global_position
			var camera_distance := target_offset.length()
			var minimum_distance := V3_BOOST_MIN_CAMERA_DISTANCE if turbo else V3_MIN_CAMERA_DISTANCE
			var maximum_distance := V3_BOOST_MAX_CAMERA_DISTANCE if turbo else V3_MAX_CAMERA_DISTANCE
			if camera_distance > maximum_distance:
				filtered_position = target.global_position + target_offset.normalized() * maximum_distance
			elif camera_distance < minimum_distance:
				var horizontal_offset := Vector3(target_offset.x, 0.0, target_offset.z)
				var minimum_vertical := sqrt(maxf(minimum_distance * minimum_distance - horizontal_offset.length_squared(), 0.0))
				filtered_position.y = target.global_position.y + maxf(target_offset.y, minimum_vertical)
		global_position = filtered_position
		v3_last_follow_error = global_position.distance_to(desired)
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-(6.5 if view_mode<2 else 12.0) * delta))
		v3_last_follow_error = 0.0
	var forward_hint := -target.global_transform.basis.z
	if road_manager != null:
		forward_hint = forward_hint.lerp(road_manager.curve_direction_near(target.global_position), 0.28).normalized()
	var steering_hint: float = float(target.get("steering")) if target.get("steering") != null else 0.0
	var look_point := target.global_position + forward_hint * look_ahead + target.global_transform.basis.x * steering_hint * 0.7 + Vector3.UP * look_height
	if stallion_v3 and view_mode == 0:
		var desired_basis := global_transform.looking_at(look_point, Vector3.UP).basis
		var rotation_blend := 1.0 - exp(-V3_ROTATION_RESPONSE * delta)
		global_basis = Basis(global_basis.get_rotation_quaternion().slerp(desired_basis.get_rotation_quaternion(), rotation_blend)).orthonormalized()
	else:
		look_at(look_point, Vector3.UP)
	fov = lerpf(fov, 79.0 if turbo else 70.0, delta * 3.0)

func bump(amount: float = 0.35) -> void:
	shake = maxf(shake, amount)
