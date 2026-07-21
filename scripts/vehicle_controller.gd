class_name VehicleController
extends CharacterBody3D

signal crashed(damage: float)
signal offroad_changed(value: bool)
signal repositioned(automatic: bool)
signal jump_landed(impact: float)

var stats: Dictionary
var speed: float = 0.0
var steering: float = 0.0
var controls_enabled: bool = true
var turbo_time: float = 0.0
var offroad: bool = false
var invulnerability: float = 0.0
var visual: Node3D
var road_manager: RoadManager
var current_grip: float = 7.0
var lateral_speed: float = 0.0
var handbrake_blend: float = 0.0
var slip_angle: float = 0.0
var offroad_duration: float = 0.0
var last_safe_transform := Transform3D.IDENTITY
var safe_transform_valid: bool = false
var safe_sample_time: float = 0.0
var road_distance: float = 0.0
var soft_boundary: bool = false
var surface: String = "ASPHALT"
var throttle_smoothed: float = 0.0
var longitudinal_transfer: float = 0.0
var lateral_transfer: float = 0.0
var simulated_rpm: float = 900.0
var simulated_gear: int = 1
var damage_level: float = 0.0
var dust_emitters:Array[GPUParticles3D]=[]
var last_frame_speed:float=0.0
var last_suspicious_collider:String="NESSUNO"
var suspicious_stop_time:float=0.0
var visual_wheels:Array[Node3D]=[]
var wheel_spin:float=0.0
var airborne:bool=false
var last_jump_segment:String=""
var air_time:float=0.0
var last_air_time:float=0.0
var air_start_height:float=0.0
var air_peak_height:float=0.0
var last_air_peak_height:float=0.0
var landing_impact:float=0.0
var landing_visual_impact:=0.0
var landing_response_time:=0.0
var landing_response_duration:=0.0
var landing_response_offset:=0.0
var landing_response_compression:=0.0
var landing_response_rebound:=0.0
var landing_response_count:=0

func setup(vehicle_index: int) -> void:
	stats = VehicleData.get_vehicle(vehicle_index)
	visual = VehicleFactory.create_vehicle(vehicle_index, false)
	add_child(visual)
	_cache_visual_wheels()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.5, 1.25, 4.7)
	shape.shape = box
	shape.position.y = 0.7
	add_child(shape)
	collision_layer = 2
	collision_mask = 1 | 4
	current_grip = float(stats.road_grip)
	floor_snap_length=.85;safe_margin=.06;floor_max_angle=deg_to_rad(48);floor_stop_on_slope=false;floor_constant_speed=true
	_setup_dust()

func _physics_process(delta: float) -> void:
	if stats.is_empty(): return
	invulnerability = maxf(0.0, invulnerability - delta)
	turbo_time = maxf(0.0, turbo_time - delta)
	var throttle := Input.get_axis("brake", "accelerate") if controls_enabled else 0.0
	throttle_smoothed=move_toward(throttle_smoothed,throttle,delta*(2.3 if int(stats.mass)>1350 else 3.2))
	throttle=throttle_smoothed
	var steer_input := Input.get_axis("steer_left", "steer_right") if controls_enabled else 0.0
	surface=road_manager.surface_at(global_position) if road_manager!=null else ("SAND" if offroad else "ASPHALT")
	var surface_data:Dictionary=BalanceData.SURFACES[surface]
	var max_speed: float = float(stats.max_speed) * (1.35 if turbo_time > 0.0 else 1.0)
	var accel: float = float(stats.accel)*float(surface_data.accel)*(1.0-damage_level*.22) * (1.22 if turbo_time > 0.0 else 1.0)
	road_distance = absf(road_manager.road_local_position(global_position).x) if road_manager != null else absf(global_position.x)
	soft_boundary = road_distance > BalanceData.SOFT_WORLD_LIMIT
	if offroad:
		max_speed *= 0.62
		accel *= 0.72
	if soft_boundary:
		var boundary_factor: float = clampf((road_distance - BalanceData.SOFT_WORLD_LIMIT) / (BalanceData.HARD_WORLD_LIMIT - BalanceData.SOFT_WORLD_LIMIT), 0.0, 1.0)
		max_speed *= lerpf(0.72, 0.35, boundary_factor)
		accel *= lerpf(0.85, 0.55, boundary_factor)
	if throttle > 0.0:
		speed = move_toward(speed, max_speed, accel * throttle * delta)
	elif throttle < 0.0:
		if speed > 1.0: speed = move_toward(speed, 0.0, float(stats.brake)*float(surface_data.brake) * delta)
		else: speed = move_toward(speed, -max_speed * 0.28, accel * 0.65 * -throttle * delta)
	else:
		speed = move_toward(speed, 0.0, float(stats.engine_brake)*float(surface_data.drag) * delta)
	longitudinal_transfer=move_toward(longitudinal_transfer,throttle,delta*2.6)
	lateral_transfer=move_toward(lateral_transfer,steering*clampf(absf(speed)/30.0,0,1),delta*3.0)
	var handbrake: bool = controls_enabled and Input.is_action_pressed("handbrake")
	if handbrake:
		speed = move_toward(speed, 0.0, 18.0 * delta)
	var speed_ratio: float = clampf(absf(speed) / max_speed, 0.0, 1.0)
	var steering_authority: float = maxf(speed_ratio, 0.22 if absf(throttle) > 0.05 else 0.12)
	var steer_limit: float = float(stats.steer) * lerpf(1.0, 0.34, speed_ratio)
	if airborne: steer_limit*=.22
	steer_limit*=1.0-damage_level*.12
	if offroad: steer_limit *= 1.12
	var combined_load_loss:float=clampf(absf(throttle)*absf(steer_input)*.16,0,.16)
	steering = move_toward(steering, steer_input * steer_limit, float(stats.steer_response) * delta)
	var direction_sign: float = signf(speed) if absf(speed) > 0.1 else 1.0
	rotation.y -= steering * steering_authority * delta * direction_sign
	if not offroad and road_manager != null and absf(steer_input)<0.05 and absf(speed)>2.0:
		var road_forward:=road_manager.curve_direction_near(global_position)
		var road_yaw:=atan2(-road_forward.x,-road_forward.z)
		rotation.y=lerp_angle(rotation.y,road_yaw,clampf(delta*1.65,0.0,1.0))
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var longitudinal: float = planar.dot(forward)
	lateral_speed = planar.dot(right)
	handbrake_blend = move_toward(handbrake_blend, 1.0 if handbrake else 0.0, delta * (7.0 if handbrake else float(stats.grip_recovery)))
	var target_grip: float = (float(stats.sand_grip) if offroad else float(stats.road_grip))*float(surface_data.lat_grip)*(1.0-combined_load_loss)
	target_grip = lerpf(target_grip, float(stats.handbrake_grip), handbrake_blend)
	var recovery: float = 0.0
	var return_traction := Vector3.ZERO
	if offroad:
		var toward_vector := road_manager.direction_to_center(global_position) if road_manager != null else Vector3(-signf(global_position.x),0,0)
		var toward_road: float = toward_vector.dot(right)
		var steering_toward: bool = steer_input * toward_road > 0.08
		if steering_toward:
			recovery += 2.2
			var edge_depth: float = maxf(road_distance - BalanceData.ROAD_HALF_WIDTH, 0.0)
			return_traction = toward_vector * minf(8.0, 2.4 + edge_depth * 0.5)
			var target_yaw: float = atan2(-toward_vector.x, -toward_vector.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * (0.85 + minf(edge_depth*.04,.35)),0.0,1.0))
		if throttle < 0.35: recovery += 1.3
		if absf(lateral_speed) > 7.0: recovery += 1.8
		if offroad_duration > 2.0: recovery += 1.2
		var nose_toward_road: float = forward.dot(toward_vector)
		if nose_toward_road > 0.25:
			recovery += nose_toward_road * 2.5
			if throttle > 0.0: speed = move_toward(speed, max_speed * 0.48, accel * 0.35 * delta)
			if not steering_toward:
				var edge_depth: float = maxf(road_distance - BalanceData.ROAD_HALF_WIDTH, 0.0)
				return_traction = toward_vector * minf(5.5, 1.4 + edge_depth * 0.32) * nose_toward_road
	current_grip = move_toward(current_grip, target_grip + recovery, float(stats.grip_recovery) * delta)
	var lateral_damping: float = clampf(current_grip * delta, 0.0, 0.92)
	lateral_speed = lerpf(lateral_speed, 0.0, lateral_damping)
	var min_forward: float = maxf(absf(longitudinal), 2.0)
	var max_lateral: float = tan(float(stats.max_slip)) * min_forward
	lateral_speed = clampf(lateral_speed, -max_lateral, max_lateral)
	slip_angle = atan2(absf(lateral_speed), min_forward)
	longitudinal = lerpf(longitudinal, speed, clampf((4.5 if offroad else 7.0) * delta, 0.0, 1.0))
	var desired := forward * longitudinal + right * lateral_speed + return_traction
	velocity.x = desired.x
	velocity.z = desired.z
	var jump_kind:=road_manager.jump_kind_near(global_position) if road_manager!=null else ""
	# The road crest, not an invisible impulse, is responsible for take-off.
	# Floor snap is disabled only on declared crest geometry so the body can
	# naturally lose contact with the descending continuation.
	floor_snap_length=0.0 if not jump_kind.is_empty() else .85
	var was_grounded:=is_on_floor()
	if was_grounded:
		velocity.y=-2.0
	else:
		if not airborne:
			air_time=0.0;air_start_height=global_position.y;air_peak_height=0.0
		velocity.y+=-14.0*delta
		airborne=true
		air_time+=delta;air_peak_height=maxf(air_peak_height,global_position.y-air_start_height)
	var vertical_speed_before_move:=velocity.y
	move_and_slide()
	if airborne and is_on_floor():
		landing_visual_impact=absf(minf(vertical_speed_before_move,0.0));landing_impact=absf(velocity.y);last_air_time=air_time;last_air_peak_height=air_peak_height;air_time=0.0;airborne=false;floor_snap_length=.85;damage_level=clampf(damage_level+maxf(0.0,landing_impact-5.0)*.018,0.0,1.0);_begin_landing_response(landing_visual_impact);jump_landed.emit(landing_impact)
	var actual_planar_speed:=Vector3(velocity.x,0,velocity.z).length()
	var suspicious:bool=absf(speed)>10.0 and actual_planar_speed<absf(speed)*.28 and throttle>=-.05 and invulnerability<=0 and is_on_floor()
	suspicious_stop_time=suspicious_stop_time+delta if suspicious else 0.0
	if suspicious_stop_time>.25:
		last_suspicious_collider="SCONOSCIUTO"
		if get_slide_collision_count()>0:
			var suspect:=get_slide_collision(0).get_collider();last_suspicious_collider=str(suspect.name) if suspect!=null else "NESSUNO"
		push_warning("Arresto anomalo persistente: target=%.2f reale=%.2f collider=%s segment=%s"%[speed,actual_planar_speed,last_suspicious_collider,road_manager.segment_name_near(global_position) if road_manager!=null else "N/A"]);suspicious_stop_time=-2.0
	last_frame_speed=actual_planar_speed
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var collider := hit.get_collider()
		if collider != null and collider.is_in_group("obstacle") and invulnerability <= 0.0:
			invulnerability = 1.1
			speed *= 0.38
			crashed.emit(float(collider.get_meta("damage", 14.0)))
			break
	var now_offroad: bool = not road_manager.is_on_road(global_position) if road_manager != null else absf(global_position.x) > BalanceData.ROAD_HALF_WIDTH
	offroad_duration = offroad_duration + delta if now_offroad else 0.0
	if now_offroad != offroad:
		offroad = now_offroad
		offroad_changed.emit(offroad)
	_update_safe_transform(delta)
	if controls_enabled and Input.is_action_just_pressed("reset_vehicle"):
		reset_to_safe(false)
	elif road_distance >= BalanceData.HARD_WORLD_LIMIT or global_position.y < -8.0:
		reset_to_safe(true)
	_update_wheels(delta)
	_update_visual_feedback(delta)
	_update_rpm()
	if absf(rotation.x) > 1.25 or absf(rotation.z) > 1.25:
		rotation.x = move_toward(rotation.x, 0.0, delta * 2.0)
		rotation.z = move_toward(rotation.z, 0.0, delta * 2.0)
		position.y = maxf(position.y, 0.2)

func _update_wheels(delta: float) -> void:
	if visual == null: return
	if bool(visual.get_meta("blender_stallion_v2", false)) or bool(visual.get_meta("blender_gt_v2", false)):
		wheel_spin=fmod(wheel_spin+speed*delta/.35,TAU)
		for wheel in visual_wheels:
			var steer_angle:=steering*.25 if bool(wheel.get_meta("front_wheel",false)) else 0.0
			wheel.rotation=Vector3(wheel_spin,steer_angle,0.0)
		return
	for child in visual.get_children():
		if child is Node3D and str(child.name).begins_with("Wheel"):
			var pivot := child as Node3D
			if str(pivot.name) == "WheelFront": pivot.rotation.y = steering * 0.25
			if pivot.get_child_count() > 0:
				(pivot.get_child(0) as Node3D).rotation.x += speed * delta * 1.8

func _cache_visual_wheels()->void:
	visual_wheels.clear()
	if visual==null:return
	for name:String in ["Wheel_FL","Wheel_FR","Wheel_RL","Wheel_RR"]:
		var wheel:=visual.find_child(name,true,false) as Node3D
		if wheel!=null:visual_wheels.append(wheel)

func _setup_dust()->void:
	var soft_mesh:=_soft_dust_mesh()
	for z:float in [-1.55,1.55]:
		for x:float in [-1.25,1.25]:
			var particles:=GPUParticles3D.new();particles.amount=16;particles.lifetime=.52;particles.position=Vector3(x,.18,z);particles.emitting=false;particles.local_coords=false
			var process:=ParticleProcessMaterial.new();process.direction=Vector3(0,.12,1);process.spread=28;process.initial_velocity_min=1.4;process.initial_velocity_max=3.8;process.gravity=Vector3(0,-.48,0);process.scale_min=.24;process.scale_max=.62;process.angle_min=-180;process.angle_max=180;process.angular_velocity_min=-52;process.angular_velocity_max=52;process.color=ArtDirection.DUST
			var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0.0,.12,.58,1.0]);gradient.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,.68),Color(1,1,1,.25),Color(1,1,1,0)]);var ramp:=GradientTexture1D.new();ramp.gradient=gradient;process.color_initial_ramp=ramp
			particles.process_material=process;particles.draw_pass_1=soft_mesh;add_child(particles);dust_emitters.append(particles)

func _soft_dust_mesh()->QuadMesh:
	var image:=Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var uv:=(Vector2(x,y)+Vector2(.5,.5))/64.0;var centered:=(uv-Vector2(.5,.5))*2.0;var radius:=centered.length();var edge:=clampf(1.0-radius,0.0,1.0);var breakup:=.82+.18*sin(float(x*11+y*17));var alpha:=pow(edge,2.25)*breakup
			image.set_pixel(x,y,Color(1,1,1,alpha))
	var material:=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.vertex_color_use_as_albedo=true;material.albedo_color=Color(1,1,1,.52);material.albedo_texture=ImageTexture.create_from_image(image);material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var mesh:=QuadMesh.new();mesh.size=Vector2(.62,.38);mesh.material=material;return mesh

func set_effect_quality(level:int)->void:
	var amounts:Array[int]=[6,16,26]
	for emitter in dust_emitters:emitter.amount=amounts[clampi(level,0,2)]

func _update_visual_feedback(delta:float)->void:
	if visual!=null:
		_update_landing_response(delta)
		visual.rotation.x=lerpf(visual.rotation.x,-longitudinal_transfer*.025,.12)
		visual.rotation.z=lerpf(visual.rotation.z,-lateral_transfer*.035,.12)
		var base_y:=-.035 if surface=="DEEP_SAND" else 0.0
		visual.position.y=base_y+landing_response_offset if landing_response_time>0.0 else lerpf(visual.position.y,base_y,.18)
	var dusty:bool=surface!="ASPHALT" and absf(speed)>3.0
	var surface_amount:=.035 if surface=="ASPHALT" else (.48 if surface=="GRAVEL" else (.68 if surface=="SAND" else .82))
	var speed_amount:=clampf((absf(speed)-2.0)/24.0,0.0,1.0)
	for index in dust_emitters.size():
		var emitter:=dust_emitters[index]
		emitter.emitting=dusty or slip_angle>.13
		emitter.amount_ratio=surface_amount*speed_amount*(.35 if index<2 else 1.0)
		var mat:=emitter.process_material as ParticleProcessMaterial
		mat.initial_velocity_max=clampf(absf(speed)*.12+absf(slip_angle)*4.0,2.0,5.8)
		mat.color=Color("91877a",.75) if surface=="GRAVEL" else (Color("b39a76",.68) if surface=="SAND" else (Color("a98261",.72) if surface=="DEEP_SAND" else Color("827d76",.12)))

func _begin_landing_response(impact:float)->void:
	landing_response_compression=.015 if impact<2.5 else clampf(.04+(impact-2.5)*.010,.04,.10)
	landing_response_rebound=landing_response_compression*.32
	landing_response_duration=.34
	landing_response_time=landing_response_duration
	landing_response_offset=0.0
	landing_response_count+=1

func _update_landing_response(delta:float)->void:
	if landing_response_time<=0.0:landing_response_offset=0.0;return
	landing_response_time=maxf(0.0,landing_response_time-delta)
	var elapsed:=landing_response_duration-landing_response_time
	if elapsed<.09:landing_response_offset=lerpf(0.0,-landing_response_compression,elapsed/.09)
	elif elapsed<.19:landing_response_offset=lerpf(-landing_response_compression,landing_response_rebound,(elapsed-.09)/.10)
	else:landing_response_offset=lerpf(landing_response_rebound,0.0,clampf((elapsed-.19)/.15,0.0,1.0))
	if landing_response_time<=0.0:landing_response_offset=0.0

func activate_turbo() -> void:
	turbo_time = 5.0

func speed_kmh() -> int:
	return int(absf(speed) * 3.6)

func _update_rpm() -> void:
	var ratio:float=clampf(absf(speed)/float(stats.max_speed),0,1)
	simulated_gear=clampi(int(ratio*5.0)+1,1,6)
	var gear_band:float=fmod(ratio*6.0,1.0)
	simulated_rpm=lerpf(1200.0,7200.0,gear_band)

func _update_safe_transform(delta: float) -> void:
	if road_manager == null or offroad or invulnerability > 0.0: return
	safe_sample_time += delta
	if safe_sample_time < 0.35: return
	var road_forward := road_manager.curve_direction_near(global_position)
	if (-global_transform.basis.z).dot(road_forward) < 0.68: return
	last_safe_transform = road_manager.safe_transform_near(global_position)
	safe_transform_valid = true
	safe_sample_time = 0.0

func reset_to_safe(automatic: bool) -> void:
	if road_manager == null: return
	var use_saved: bool = not automatic and safe_transform_valid and road_manager.is_point_near_active(last_safe_transform.origin)
	var target := last_safe_transform if use_saved else road_manager.safe_transform_near(global_position)
	global_transform = target
	velocity = Vector3.ZERO
	speed = 0.0
	lateral_speed = 0.0
	steering = 0.0
	handbrake_blend = 0.0
	offroad_duration = 0.0
	offroad = false
	repositioned.emit(automatic)
