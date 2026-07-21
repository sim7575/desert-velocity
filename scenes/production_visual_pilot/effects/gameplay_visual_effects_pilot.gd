class_name GameplayVisualEffectsPilot
extends Node3D

const DUST_COLOR := Color("9b9185")
const DUST_OFFROAD_COLOR := Color("b19d82")
const BOOST_COLOR := Color("f6a23c")
const BOOST_CORE_COLOR := Color("ffd47a")
const CHECKPOINT_COLOR := Color("d88b2b")

var vehicle: VehicleController
var dust_emitters: Array[GPUParticles3D] = []
var boost_emitters: Array[GPUParticles3D] = []
var landing_emitter: GPUParticles3D
var landing_fragment_emitter: GPUParticles3D
var spark_emitter: GPUParticles3D
var boost_accent: Node3D
var boost_light: OmniLight3D
var checkpoint_portal: Node3D
var checkpoint_manager: Node
var last_checkpoint := 0
var checkpoint_poll_time := 0.0
var boost_was_active := false
var boost_start_count := 0
var boost_stop_count := 0
var landing_burst_count := 0
var spark_burst_count := 0
var dust_intensity := 0.0
var surface_factor := 0.0

func _ready() -> void:
	_build_dust()
	_build_boost()
	_build_impacts()
	call_deferred("_bind_vehicle")

func _bind_vehicle() -> void:
	vehicle = get_parent().get_parent() as VehicleController
	if vehicle == null:
		return
	if not vehicle.jump_landed.is_connected(_on_jump_landed):
		vehicle.jump_landed.connect(_on_jump_landed)
	if not vehicle.crashed.is_connected(_on_crashed):
		vehicle.crashed.connect(_on_crashed)
	checkpoint_manager = vehicle.get_parent().get_parent() if vehicle.get_parent() != null else null
	if checkpoint_manager != null:
		last_checkpoint = _read_stage_checkpoint()
	set_meta("reads_real_gameplay_state", true)
	set_meta("collision_free", true)

func _process(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	_update_dust()
	_update_boost()
	checkpoint_poll_time -= delta
	if checkpoint_poll_time <= 0.0:
		checkpoint_poll_time = 0.15
		_find_or_refresh_checkpoint_portal()
	_update_checkpoint_feedback(delta)

func _update_dust() -> void:
	# The approved controller remains untouched. Its legacy emitters are muted only
	# while this V3-local replacement exists, preventing duplicate overdraw.
	for legacy in vehicle.dust_emitters:
		legacy.emitting = false
	var speed_factor: float = clampf(vehicle.speed / 34.0, 0.0, 1.0)
	var surface := str(vehicle.surface).to_upper()
	match surface:
		"ASPHALT": surface_factor = 0.015
		"GRAVEL": surface_factor = 0.38
		"SAND": surface_factor = 0.56
		"DEEP_SAND": surface_factor = 0.74
		_: surface_factor = 0.62 if vehicle.offroad else 0.28
	if vehicle.offroad:
		surface_factor = maxf(surface_factor, 0.72)
	var steering_factor: float = clampf(absf(vehicle.steering), 0.0, 1.0) * 0.18
	var slip_factor: float = clampf(absf(vehicle.slip_angle) / 0.42, 0.0, 1.0) * 0.26
	var throttle_factor: float = clampf(vehicle.throttle_smoothed, 0.0, 1.0) * 0.12
	var boost_factor: float = 0.14 if vehicle.turbo_time > 0.0 else 0.0
	dust_intensity = clampf(surface_factor * (speed_factor + steering_factor * speed_factor + slip_factor + throttle_factor * speed_factor + boost_factor), 0.0, 1.0)
	if vehicle.airborne or vehicle.speed < 0.75:
		dust_intensity = 0.0
	for emitter in dust_emitters:
		emitter.emitting = dust_intensity > 0.025
		emitter.amount_ratio = dust_intensity
		var process := emitter.process_material as ParticleProcessMaterial
		process.spread = lerpf(20.0, 48.0, clampf(absf(vehicle.steering) + absf(vehicle.slip_angle), 0.0, 1.0))
		process.color = Color("817c76",.10) if surface=="ASPHALT" else (Color("938a7e",.78) if surface=="GRAVEL" else (Color("b19a78",.68) if surface=="SAND" else Color("a98762",.72)))
	set_meta("dust_intensity", dust_intensity)
	set_meta("dust_surface_factor", surface_factor)

func _update_boost() -> void:
	var active := vehicle.turbo_time > 0.0 and not get_tree().paused
	for emitter in boost_emitters:
		emitter.emitting = active
	boost_accent.visible = active
	# Emissive exhaust cores provide the rear light accent without a dynamic
	# per-frame light on the MX150/GL Compatibility path.
	boost_light.visible = false
	if active != boost_was_active:
		if active:
			boost_start_count += 1
		else:
			boost_stop_count += 1
		boost_was_active = active
	set_meta("boost_active", active)
	set_meta("boost_start_count", boost_start_count)
	set_meta("boost_stop_count", boost_stop_count)

func _on_jump_landed(impact: float) -> void:
	if impact < 0.12:
		return
	landing_emitter.amount_ratio = clamp(0.35 + impact * 0.08, 0.35, 1.0)
	landing_emitter.emitting = true
	landing_emitter.restart()
	landing_fragment_emitter.amount_ratio = clamp(0.25 + impact * 0.06, 0.25, 0.8)
	landing_fragment_emitter.emitting = true
	landing_fragment_emitter.restart()
	landing_burst_count += 1
	set_meta("landing_burst_count", landing_burst_count)

func _on_crashed(damage: float) -> void:
	if damage < 8.0:
		return
	spark_emitter.amount_ratio = clamp(damage / 30.0, 0.3, 1.0)
	spark_emitter.emitting = true
	spark_emitter.restart()
	spark_burst_count += 1
	set_meta("spark_burst_count", spark_burst_count)

func _build_dust() -> void:
	var particle_mesh := _directional_particle_mesh(DUST_COLOR, 0.42, Vector2(1.45, 0.44), false)
	for x in [-0.88, 0.88]:
		var dust := GPUParticles3D.new()
		dust.name = "RearDustLeft" if x < 0.0 else "RearDustRight"
		dust.position = Vector3(x, 0.14, 2.35)
		dust.amount = 38
		dust.amount_ratio = 0.0
		dust.lifetime = 0.50
		dust.local_coords = false
		dust.visibility_aabb = AABB(Vector3(-7, -3, -7), Vector3(14, 9, 20))
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(0.15, 0.025, 0.32)
		process.direction = Vector3(0, 0.08, 1.0)
		process.spread = 18.0
		process.initial_velocity_min = 2.4
		process.initial_velocity_max = 5.4
		process.gravity = Vector3(0, -0.52, 0)
		process.scale_min = 0.15
		process.scale_max = 0.48
		process.angle_min=-22.0
		process.angle_max=22.0
		process.angular_velocity_min=-34.0
		process.angular_velocity_max=34.0
		process.color = DUST_COLOR
		var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0.0,.10,.55,1.0]);gradient.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,.72),Color(1,1,1,.24),Color(1,1,1,0)]);var ramp:=GradientTexture1D.new();ramp.gradient=gradient;process.color_initial_ramp=ramp
		dust.process_material = process
		dust.draw_pass_1 = particle_mesh
		add_child(dust)
		dust_emitters.append(dust)

func _build_boost() -> void:
	var flame_mesh := _directional_particle_mesh(BOOST_COLOR, 0.92, Vector2(0.22, 0.72), true)
	for x in [-0.45, 0.45]:
		var flame := GPUParticles3D.new()
		flame.name = "BoostFlameLeft" if x < 0.0 else "BoostFlameRight"
		flame.position = Vector3(x, 0.46, 2.18)
		flame.amount = 8
		flame.lifetime = 0.085
		flame.local_coords = true
		flame.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 8))
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0, 0.02, 1.0)
		process.spread = 7.0
		process.initial_velocity_min = 2.2
		process.initial_velocity_max = 4.0
		process.gravity = Vector3.ZERO
		process.scale_min = 0.045
		process.scale_max = 0.09
		process.color = BOOST_COLOR
		flame.process_material = process
		flame.draw_pass_1 = flame_mesh
		flame.emitting = false
		add_child(flame)
		boost_emitters.append(flame)
	boost_accent = Marker3D.new()
	boost_accent.name = "BoostWarmCore"
	boost_accent.position = Vector3(0, 0.50, 2.22)
	boost_accent.visible = false
	add_child(boost_accent)
	boost_light = OmniLight3D.new()
	boost_light.name = "BoostRearAccent"
	boost_light.position = Vector3(0, 0.55, 2.3)
	boost_light.light_color = BOOST_COLOR
	boost_light.light_energy = 0.0
	boost_light.omni_range = 2.6
	boost_light.shadow_enabled = false
	boost_light.visible = false
	add_child(boost_light)
	set_meta("boost_emissive_accent", true)
	set_meta("boost_dynamic_light", false)

func _build_impacts() -> void:
	landing_emitter = _one_shot_particles("LandingDustBurst", DUST_OFFROAD_COLOR, 34, 0.34, Vector3(0, 0.08, 1.0), 5.2, 78.0, 0.35, 0.82)
	landing_emitter.position = Vector3(0, 0.10, 2.05)
	add_child(landing_emitter)
	landing_fragment_emitter = _fragment_particles()
	landing_fragment_emitter.position = Vector3(0, 0.12, 2.0)
	add_child(landing_fragment_emitter)
	spark_emitter = _one_shot_particles("ImpactSparks", Color("ffe08a"), 10, 0.24, Vector3(0.55, 0.30, 1.0), 8.5, 24.0, 0.8, 1.2)
	spark_emitter.position = Vector3(1.35, 0.55, 2.20)
	add_child(spark_emitter)

func _one_shot_particles(node_name: String, color: Color, amount: int, lifetime: float, direction: Vector3, velocity: float, spread: float, scale_min: float, scale_max: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.emitting = false
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 12, 16))
	var process := ParticleProcessMaterial.new()
	process.direction = direction
	process.spread = spread
	process.initial_velocity_min = velocity * 0.55
	process.initial_velocity_max = velocity
	process.gravity = Vector3(0, -5.0, 0)
	process.scale_min = scale_min
	process.scale_max = scale_max
	process.color = color
	particles.process_material = process
	particles.draw_pass_1 = _directional_particle_mesh(color, 0.58 if node_name == "LandingDustBurst" else 1.0, Vector2(1.8, 0.45) if node_name == "LandingDustBurst" else Vector2(0.05, 0.55), node_name == "ImpactSparks")
	return particles

func _fragment_particles() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "LandingFragments"
	particles.amount = 10
	particles.lifetime = 0.32
	particles.one_shot = true
	particles.explosiveness = 0.96
	particles.emitting = false
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-7, -2, -7), Vector3(14, 7, 14))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0.32, 1.0)
	process.spread = 76.0
	process.initial_velocity_min = 2.2
	process.initial_velocity_max = 4.8
	process.gravity = Vector3(0, -8.5, 0)
	process.scale_min = 0.40
	process.scale_max = 0.75
	process.color = Color("6f5a45")
	particles.process_material = process
	var fragment := BoxMesh.new()
	fragment.size = Vector3(0.045, 0.022, 0.075)
	fragment.material = _surface_material(Color("6f5a45"), 0.0, 0.92)
	particles.draw_pass_1 = fragment
	return particles

func _directional_particle_mesh(color: Color, alpha: float, size: Vector2, additive: bool) -> QuadMesh:
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 64:
			var uv := Vector2(float(x) / 63.0, float(y) / 31.0)
			var vertical: float = clampf(1.0 - absf(uv.y - 0.5) * 2.0, 0.0, 1.0)
			var tail: float = sin(clampf(uv.x, 0.0, 1.0) * PI)
			var breakup := 0.78 + 0.22 * sin(float(x * 13 + y * 7))
			var fade: float = pow(vertical, 1.8) * pow(maxf(tail, 0.0), 0.72) * breakup
			image.set_pixel(x, y, Color(1, 1, 1, fade))
	var texture := ImageTexture.create_from_image(image)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh

func _find_or_refresh_checkpoint_portal() -> void:
	if checkpoint_portal != null and is_instance_valid(checkpoint_portal):
		return
	if vehicle.road_manager == null:
		return
	for segment in vehicle.road_manager.segments:
		if int(segment.get_meta("route_index", -1)) != 9:
			continue
		for child in segment.get_children():
			if not child.is_in_group("route_detail"):
				continue
			var meshes: Array[MeshInstance3D] = []
			for detail in child.get_children():
				if detail is MeshInstance3D:
					meshes.append(detail)
			if meshes.size() < 3:
				continue
			for mesh in meshes:
				mesh.visible = false
			checkpoint_portal = _build_checkpoint_portal()
			child.add_child(checkpoint_portal)
			return

func _build_checkpoint_portal() -> Node3D:
	var portal := Node3D.new()
	portal.name = "G1ECheckpointPortal"
	portal.set_meta("g1e_checkpoint_portal", true)
	portal.set_meta("collision_free", true)
	var dark := _surface_material(Color("40372b"), 0.32, 0.76)
	var amber := _emissive_material(CHECKPOINT_COLOR, 0.55)
	for x in [-8.8, 8.8]:
		_add_box(portal, Vector3(0.72, 5.1, 0.72), Vector3(x, 2.55, 0), dark)
		_add_box(portal, Vector3(0.84, 0.28, 0.84), Vector3(x, 0.48, 0), amber)
		_add_box(portal, Vector3(0.84, 0.28, 0.84), Vector3(x, 3.95, 0), amber)
	_add_box(portal, Vector3(18.3, 0.68, 0.72), Vector3(0, 5.0, 0), dark)
	_add_box(portal, Vector3(7.8, 0.78, 0.20), Vector3(0, 4.96, -0.46), _surface_material(Color("211c17"), 0.08, 0.88))
	_add_box(portal, Vector3(7.2, 0.18, 0.24), Vector3(0, 5.30, -0.58), amber)
	for x in [-4.65, 4.65]:
		_add_box(portal, Vector3(1.35, 0.22, 0.24), Vector3(x, 4.96, -0.58), amber)
	var label := Label3D.new()
	label.name = "CheckpointNumber"
	label.text = "CP 01"
	label.position = Vector3(0, 4.91, -0.61)
	label.font_size = 72
	label.pixel_size = 0.020
	label.outline_size = 16
	label.modulate = Color("fff0ce")
	label.outline_modulate = Color("211b14")
	label.no_depth_test = true
	portal.add_child(label)
	return portal

func _update_checkpoint_feedback(delta: float) -> void:
	if checkpoint_manager == null or not is_instance_valid(checkpoint_manager):
		return
	var current: int = _read_stage_checkpoint()
	if current > last_checkpoint and checkpoint_portal != null and is_instance_valid(checkpoint_portal):
		checkpoint_portal.set_meta("feedback_time", 0.48)
		checkpoint_portal.set_meta("feedback_count", int(checkpoint_portal.get_meta("feedback_count", 0)) + 1)
	last_checkpoint = current
	if checkpoint_portal == null or not is_instance_valid(checkpoint_portal):
		return
	var feedback_time := float(checkpoint_portal.get_meta("feedback_time", 0.0))
	if feedback_time > 0.0:
		feedback_time = max(0.0, feedback_time - delta)
		checkpoint_portal.set_meta("feedback_time", feedback_time)
		var normalized := feedback_time / 0.48
		var pulse := 1.0 + sin((1.0 - normalized) * PI) * 0.045
		checkpoint_portal.scale = Vector3.ONE * pulse
		var label := checkpoint_portal.get_node_or_null("CheckpointNumber") as Label3D
		if label != null:
			label.modulate.a = clampf(normalized * 2.4, 0.35, 1.0)
	else:
		checkpoint_portal.scale = Vector3.ONE
		var label := checkpoint_portal.get_node_or_null("CheckpointNumber") as Label3D
		if label != null:
			label.modulate.a = 1.0

func _read_stage_checkpoint() -> int:
	if checkpoint_manager == null:
		return 0
	var value: Variant = checkpoint_manager.get("stage_checkpoint")
	if value is int:
		return value
	return 0

func _add_box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

func _surface_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _surface_material(color.darkened(0.18), 0.12, 0.52)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
