class_name PremiumSliceGeometry
extends RefCounted

const ROAD_HALF_WIDTH := 6.4
const TERRAIN_HALF_WIDTH := 26.0
const SAMPLE_STEP := 3.0

static func control_points() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(0, 0, 40),
		Vector3(0, 0, -20),
		Vector3(12, 1, -75),
		Vector3(45, 1, -130),
		Vector3(78, -3, -190),
		Vector3(88, -10, -250),
		Vector3(72, -14, -310),
		Vector3(52, -12.6, -350),
		Vector3(30, -14, -390),
		Vector3(0, -13, -455),
	])

static func build_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	var points := control_points()
	for i in points.size():
		var previous := points[maxi(0, i - 1)]
		var following := points[mini(points.size() - 1, i + 1)]
		var tangent := (following - previous) * 0.18
		if i == 0: tangent = (following - points[i]) * 0.28
		if i == points.size() - 1: tangent = (points[i] - previous) * 0.28
		curve.add_point(points[i], -tangent, tangent)
	return curve

static func neutral_material(color: Color, roughness: float = 0.82) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

static func build_road(curve: Curve3D, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := curve.get_baked_length()
	var distance := 0.0
	while distance < length:
		var next_distance := minf(distance + SAMPLE_STEP, length)
		var tangent_a := _tangent(curve, distance)
		var tangent_b := _tangent(curve, next_distance)
		var side_a := Vector3.UP.cross(tangent_a).normalized()
		var side_b := Vector3.UP.cross(tangent_b).normalized()
		var edge_a := sin(distance * 0.117) * 0.22 + sin(distance * 0.041) * 0.16
		var edge_b := sin(next_distance * 0.117) * 0.22 + sin(next_distance * 0.041) * 0.16
		var center_a := curve.sample_baked(distance, true) + Vector3.UP * 0.015
		var center_b := curve.sample_baked(next_distance, true) + Vector3.UP * 0.015
		var left_a := center_a - side_a * (ROAD_HALF_WIDTH + edge_a)
		var right_a := center_a + side_a * (ROAD_HALF_WIDTH - edge_a * 0.55)
		var left_b := center_b - side_b * (ROAD_HALF_WIDTH + edge_b)
		var right_b := center_b + side_b * (ROAD_HALF_WIDTH - edge_b * 0.55)
		_add_triangle(surface, left_a, right_a, right_b, Vector2(0, distance), Vector2(1, distance), Vector2(1, next_distance))
		_add_triangle(surface, left_a, right_b, left_b, Vector2(0, distance), Vector2(1, next_distance), Vector2(0, next_distance))
		distance = next_distance
	surface.generate_normals()
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	return mesh_instance

static func build_terrain(curve: Curve3D, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := curve.get_baked_length()
	var longitudinal_step := 6.0
	var lateral_sections := 12
	var distance := 0.0
	while distance < length:
		var next_distance := minf(distance + longitudinal_step, length)
		for lateral_index in lateral_sections:
			var u0 := float(lateral_index) / float(lateral_sections)
			var u1 := float(lateral_index + 1) / float(lateral_sections)
			var a0 := _terrain_point(curve, distance, u0)
			var a1 := _terrain_point(curve, distance, u1)
			var b0 := _terrain_point(curve, next_distance, u0)
			var b1 := _terrain_point(curve, next_distance, u1)
			_add_triangle(surface, a0, a1, b1, Vector2(u0, distance), Vector2(u1, distance), Vector2(u1, next_distance))
			_add_triangle(surface, a0, b1, b0, Vector2(u0, distance), Vector2(u1, next_distance), Vector2(u0, next_distance))
		distance = next_distance
	surface.generate_normals()
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	return mesh_instance

static func build_track_mark(curve: Curve3D, lateral_offset: float, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := curve.get_baked_length()
	var distance := 0.0
	while distance < length:
		var next_distance := minf(distance + 4.0, length)
		var center_a := curve.sample_baked(distance, true)
		var center_b := curve.sample_baked(next_distance, true)
		var side_a := Vector3.UP.cross(_tangent(curve, distance)).normalized()
		var side_b := Vector3.UP.cross(_tangent(curve, next_distance)).normalized()
		var width := 0.13 + sin(distance * 0.21) * 0.025
		center_a += side_a * lateral_offset + Vector3.UP * 0.032
		center_b += side_b * lateral_offset + Vector3.UP * 0.032
		_add_triangle(surface, center_a - side_a * width, center_a + side_a * width, center_b + side_b * width, Vector2(0, distance), Vector2(1, distance), Vector2(1, next_distance))
		_add_triangle(surface, center_a - side_a * width, center_b + side_b * width, center_b - side_b * width, Vector2(0, distance), Vector2(1, next_distance), Vector2(0, next_distance))
		distance = next_distance
	surface.generate_normals()
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	return mesh_instance

static func build_ribbon(curve: Curve3D, half_width: float, vertical_offset: float, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := curve.get_baked_length()
	var distance := 0.0
	while distance < length:
		var next_distance := minf(distance + SAMPLE_STEP, length)
		var center_a := curve.sample_baked(distance, true) + Vector3.UP * vertical_offset
		var center_b := curve.sample_baked(next_distance, true) + Vector3.UP * vertical_offset
		var tangent_a := _tangent(curve, distance)
		var tangent_b := _tangent(curve, next_distance)
		var side_a := Vector3.UP.cross(tangent_a).normalized()
		var side_b := Vector3.UP.cross(tangent_b).normalized()
		var left_a := center_a - side_a * half_width
		var right_a := center_a + side_a * half_width
		var left_b := center_b - side_b * half_width
		var right_b := center_b + side_b * half_width
		_add_triangle(surface, left_a, right_a, right_b, Vector2(0, distance), Vector2(1, distance), Vector2(1, next_distance))
		_add_triangle(surface, left_a, right_b, left_b, Vector2(0, distance), Vector2(1, next_distance), Vector2(0, next_distance))
		distance = next_distance
	surface.generate_normals()
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	return mesh_instance

static func build_canyon(curve: Curve3D, side_sign: float, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := minf(curve.get_baked_length(), 305.0)
	var samples: Array[PackedVector3Array] = []
	var distance := 0.0
	while distance <= length:
		var sample_distance := minf(distance, length)
		var center := curve.sample_baked(sample_distance, true)
		var tangent := _tangent(curve, sample_distance)
		var side := Vector3.UP.cross(tangent).normalized() * side_sign
		# Large offsets fold over themselves on the inside of the presentation bend.
		var primary_wave := sin(distance * 0.037 + side_sign) * 1.7 + sin(distance * 0.011) * 1.1
		var toe_offset := 18.5 + primary_wave
		var lower_offset := toe_offset + 3.8 + sin(distance * 0.071) * 0.7
		var upper_offset := lower_offset + 4.2 + cos(distance * 0.047) * 0.8
		var crest_offset := upper_offset + 3.6 + sin(distance * 0.093) * 0.9
		var lower_height := 3.4 + sin(distance * 0.059 + side_sign) * 1.1
		var upper_height := 10.5 + sin(distance * 0.028 + side_sign * 2.0) * 2.4
		var crest_height := 17.0 + sin(distance * 0.021 + side_sign) * 4.0 + sin(distance * 0.083) * 1.8
		samples.append(PackedVector3Array([
			center + side * toe_offset + Vector3.DOWN * 0.7,
			center + side * lower_offset + Vector3.UP * lower_height,
			center + side * upper_offset + Vector3.UP * upper_height,
			center + side * crest_offset + Vector3.UP * crest_height,
		]))
		distance += 8.0
	for sample_index in samples.size() - 1:
		for layer_index in 3:
			var a := samples[sample_index][layer_index]
			var b := samples[sample_index + 1][layer_index]
			var c := samples[sample_index + 1][layer_index + 1]
			var d := samples[sample_index][layer_index + 1]
			_add_triangle(surface, a, b, c, Vector2(layer_index, sample_index), Vector2(layer_index, sample_index + 1), Vector2(layer_index + 1, sample_index + 1))
			_add_triangle(surface, a, c, d, Vector2(layer_index, sample_index), Vector2(layer_index + 1, sample_index + 1), Vector2(layer_index + 1, sample_index))
	surface.generate_normals()
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	return mesh_instance

static func build_distant_mesa(curve: Curve3D, side_sign: float, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := curve.get_baked_length()
	# Independent mesa masses avoid a long background ribbon intersecting itself.
	var distance := 34.0
	while distance < length:
		var center := curve.sample_baked(distance, true)
		var tangent := _tangent(curve, distance)
		var side := Vector3.UP.cross(tangent).normalized() * side_sign
		var half_length := 11.0 + sin(distance * 0.041) * 2.5
		var half_width := 6.0 + cos(distance * 0.033) * 1.4
		var height := 13.0 + sin(distance * 0.027 + side_sign) * 3.0
		var base := center + side * (54.0 + sin(distance * 0.019) * 5.0) + Vector3.DOWN * 2.5
		var front_a := base - tangent * half_length - side * half_width
		var front_b := base + tangent * half_length - side * half_width
		var back_a := base - tangent * half_length + side * half_width
		var back_b := base + tangent * half_length + side * half_width
		var inset := 0.55
		var top_front_a := front_a.lerp(base, inset) + Vector3.UP * height
		var top_front_b := front_b.lerp(base, inset) + Vector3.UP * (height + 1.2)
		var top_back_a := back_a.lerp(base, inset) + Vector3.UP * (height - 0.8)
		var top_back_b := back_b.lerp(base, inset) + Vector3.UP * height
		_add_quad(surface, front_a, front_b, top_front_b, top_front_a)
		_add_quad(surface, back_b, back_a, top_back_a, top_back_b)
		_add_quad(surface, back_a, front_a, top_front_a, top_back_a)
		_add_quad(surface, front_b, back_b, top_back_b, top_front_b)
		_add_quad(surface, top_front_a, top_front_b, top_back_b, top_back_a)
		distance += 58.0
	surface.generate_normals()
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	return mesh_instance

static func build_rock_mesh(seed_value: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 18
	var heights := PackedFloat32Array([0.0, 0.14, 0.40, 0.78, 1.15, 1.52, 1.82])
	var radii := PackedFloat32Array([0.38, 0.78, 1.0, 0.94, 0.73, 0.43, 0.08])
	var rings: Array[PackedVector3Array] = []
	for ring_index in heights.size():
		var ring := PackedVector3Array()
		for segment_index in segments:
			var angle := TAU * float(segment_index) / float(segments)
			var jitter := 1.0 + sin(float(seed_value * 7 + ring_index * 13 + segment_index * 17)) * 0.11 + cos(float(seed_value + segment_index * 5)) * 0.045
			var radius := radii[ring_index] * jitter
			ring.append(Vector3(cos(angle) * radius, heights[ring_index], sin(angle) * radius))
		rings.append(ring)
	for ring_index in rings.size() - 1:
		for segment_index in segments:
			var next_index := (segment_index + 1) % segments
			_add_triangle(surface, rings[ring_index][segment_index], rings[ring_index][next_index], rings[ring_index + 1][next_index], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			_add_triangle(surface, rings[ring_index][segment_index], rings[ring_index + 1][next_index], rings[ring_index + 1][segment_index], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	surface.generate_normals()
	return surface.commit()

static func path_metrics(curve: Curve3D) -> Dictionary:
	var length := curve.get_baked_length()
	var min_y := INF
	var max_y := -INF
	var min_heading := INF
	var max_heading := -INF
	var max_gap := 0.0
	var previous := curve.sample_baked(0.0, true)
	var distance := 0.0
	while distance <= length:
		var point := curve.sample_baked(minf(distance, length), true)
		var tangent := _tangent(curve, minf(distance, length))
		var heading := atan2(tangent.x, -tangent.z)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
		min_heading = minf(min_heading, heading)
		max_heading = maxf(max_heading, heading)
		max_gap = maxf(max_gap, previous.distance_to(point))
		previous = point
		distance += 1.0
	var points := control_points()
	var bump_prominence := points[7].y - (points[6].y + points[8].y) * 0.5
	return {
		"path_length": length,
		"elevation_drop": max_y - min_y,
		"wide_curve_degrees": rad_to_deg(max_heading - min_heading),
		"bump_prominence": bump_prominence,
		"continuity_max_gap": max_gap,
	}

static func sample_frame(curve: Curve3D, distance: float) -> Transform3D:
	var clamped := clampf(distance, 0.0, curve.get_baked_length())
	var position := curve.sample_baked(clamped, true)
	var forward := _tangent(curve, clamped)
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	return Transform3D(Basis(right, up, -forward).orthonormalized(), position)

static func _tangent(curve: Curve3D, distance: float) -> Vector3:
	var length := curve.get_baked_length()
	var before := curve.sample_baked(maxf(0.0, distance - 1.0), true)
	var after := curve.sample_baked(minf(length, distance + 1.0), true)
	return before.direction_to(after)

static func _terrain_point(curve: Curve3D, distance: float, lateral_ratio: float) -> Vector3:
	var center := curve.sample_baked(distance, true)
	var side := Vector3.UP.cross(_tangent(curve, distance)).normalized()
	var lateral := lerpf(-TERRAIN_HALF_WIDTH, TERRAIN_HALF_WIDTH, lateral_ratio)
	var road_blend := smoothstep(ROAD_HALF_WIDTH + 0.8, ROAD_HALF_WIDTH + 8.0, absf(lateral))
	var dune := sin(distance * 0.031 + lateral * 0.12) * 0.72 + sin(distance * 0.009 - lateral * 0.21) * 0.44
	var erosion := sin(lateral * 0.39 + distance * 0.067) * 0.18
	var height := -0.24 + (dune + erosion) * road_blend
	return center + side * lateral + Vector3.UP * height

static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	surface.set_uv(uv_a); surface.add_vertex(a)
	surface.set_uv(uv_b); surface.add_vertex(b)
	surface.set_uv(uv_c); surface.add_vertex(c)

static func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_triangle(surface, a, b, c, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	_add_triangle(surface, a, c, d, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
