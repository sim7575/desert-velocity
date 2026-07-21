class_name PremiumSliceV2Geometry
extends RefCounted

const ROAD_HALF_WIDTH := 5.15
const TERRAIN_HALF_WIDTH := 92.0
const SAMPLE_STEP := 2.8

static func control_points() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(0, 0, 42), Vector3(0, 0, -18), Vector3(18, 1, -82),
		Vector3(58, 0, -148), Vector3(92, -5, -216), Vector3(100, -12, -286),
		Vector3(78, -17, -346), Vector3(55, -13.5, -392), Vector3(34, -18, -448),
		Vector3(8, -17, -512), Vector3(0, -16, -558),
	])

static func build_curve() -> Curve3D:
	var result := Curve3D.new()
	result.bake_interval = 0.8
	var points := control_points()
	for index in points.size():
		var previous := points[maxi(0, index - 1)]
		var following := points[mini(points.size() - 1, index + 1)]
		var tangent := (following - previous) * 0.18
		if index == 0: tangent = (following - points[index]) * 0.30
		if index == points.size() - 1: tangent = (points[index] - previous) * 0.30
		result.add_point(points[index], -tangent, tangent)
	return result

static func build_road(curve: Curve3D, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := curve.get_baked_length()
	var distance := 0.0
	while distance < length:
		var next_distance := minf(distance + SAMPLE_STEP, length)
		var frame_a := sample_frame(curve, distance)
		var frame_b := sample_frame(curve, next_distance)
		var width_a := ROAD_HALF_WIDTH + sin(distance * 0.13) * 0.16 + sin(distance * 0.041) * 0.11
		var width_b := ROAD_HALF_WIDTH + sin(next_distance * 0.13) * 0.16 + sin(next_distance * 0.041) * 0.11
		var a := frame_a.origin + Vector3.UP * 0.055
		var b := frame_b.origin + Vector3.UP * 0.055
		_add_triangle(surface, a - frame_a.basis.x * width_a, a + frame_a.basis.x * width_a, b + frame_b.basis.x * width_b, Vector2(0, distance), Vector2(1, distance), Vector2(1, next_distance))
		_add_triangle(surface, a - frame_a.basis.x * width_a, b + frame_b.basis.x * width_b, b - frame_b.basis.x * width_b, Vector2(0, distance), Vector2(1, next_distance), Vector2(0, next_distance))
		distance = next_distance
	surface.generate_normals()
	surface.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	return instance

static func build_terrain(curve: Curve3D, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := curve.get_baked_length()
	var distance := 0.0
	var longitudinal_step := 5.5
	var lateral_sections := 16
	while distance < length:
		var next_distance := minf(distance + longitudinal_step, length)
		for lateral_index in lateral_sections:
			var u0 := float(lateral_index) / lateral_sections
			var u1 := float(lateral_index + 1) / lateral_sections
			var a0 := _terrain_point(curve, distance, u0)
			var a1 := _terrain_point(curve, distance, u1)
			var b0 := _terrain_point(curve, next_distance, u0)
			var b1 := _terrain_point(curve, next_distance, u1)
			_add_triangle(surface, a0, a1, b1, Vector2(u0, distance), Vector2(u1, distance), Vector2(u1, next_distance))
			_add_triangle(surface, a0, b1, b0, Vector2(u0, distance), Vector2(u1, next_distance), Vector2(u0, next_distance))
		distance = next_distance
	surface.generate_normals()
	surface.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	return instance

static func build_track_mark(curve: Curve3D, offset: float, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := curve.get_baked_length()
	var distance := 0.0
	while distance < length:
		var next_distance := minf(distance + 3.8, length)
		var a := sample_frame(curve, distance)
		var b := sample_frame(curve, next_distance)
		var center_a := a.origin + a.basis.x * offset + Vector3.UP * 0.085
		var center_b := b.origin + b.basis.x * offset + Vector3.UP * 0.085
		var width := 0.12 + sin(distance * 0.21) * 0.025
		_add_triangle(surface, center_a - a.basis.x * width, center_a + a.basis.x * width, center_b + b.basis.x * width, Vector2.ZERO, Vector2.ONE, Vector2.ONE)
		_add_triangle(surface, center_a - a.basis.x * width, center_b + b.basis.x * width, center_b - b.basis.x * width, Vector2.ZERO, Vector2.ONE, Vector2.ZERO)
		distance = next_distance
	surface.generate_normals()
	surface.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	return instance

static func build_shoulder(curve: Curve3D, side: float, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := curve.get_baked_length()
	var distance := 0.0
	while distance < length:
		var next_distance := minf(distance + 3.6, length)
		var frame_a := sample_frame(curve, distance)
		var frame_b := sample_frame(curve, next_distance)
		var inner_a := ROAD_HALF_WIDTH + sin(distance * 0.13) * 0.16
		var inner_b := ROAD_HALF_WIDTH + sin(next_distance * 0.13) * 0.16
		var outer_a := inner_a + 2.1 + sin(distance * 0.071 + side) * 0.34
		var outer_b := inner_b + 2.1 + sin(next_distance * 0.071 + side) * 0.34
		var a0 := frame_a.origin + frame_a.basis.x * side * inner_a + Vector3.UP * 0.035
		var a1 := frame_a.origin + frame_a.basis.x * side * outer_a + Vector3.UP * (-0.05 + sin(distance * 0.09) * 0.06)
		var b0 := frame_b.origin + frame_b.basis.x * side * inner_b + Vector3.UP * 0.035
		var b1 := frame_b.origin + frame_b.basis.x * side * outer_b + Vector3.UP * (-0.05 + sin(next_distance * 0.09) * 0.06)
		if side > 0.0:
			_add_triangle(surface, a0, a1, b1, Vector2(0, distance), Vector2(1, distance), Vector2(1, next_distance))
			_add_triangle(surface, a0, b1, b0, Vector2(0, distance), Vector2(1, next_distance), Vector2(0, next_distance))
		else:
			_add_triangle(surface, a1, a0, b0, Vector2(1, distance), Vector2(0, distance), Vector2(0, next_distance))
			_add_triangle(surface, a1, b0, b1, Vector2(1, distance), Vector2(0, next_distance), Vector2(1, next_distance))
		distance = next_distance
	surface.generate_normals()
	surface.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	return instance

static func sample_frame(curve: Curve3D, distance: float) -> Transform3D:
	var clamped := clampf(distance, 0.0, curve.get_baked_length())
	var origin := curve.sample_baked(clamped, true)
	var before := curve.sample_baked(maxf(0.0, clamped - 1.0), true)
	var after := curve.sample_baked(minf(curve.get_baked_length(), clamped + 1.0), true)
	var forward := before.direction_to(after)
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	return Transform3D(Basis(right, up, -forward).orthonormalized(), origin)

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
		var frame := sample_frame(curve, minf(distance, length))
		var heading := atan2((-frame.basis.z).x, -(-frame.basis.z).z)
		min_y = minf(min_y, point.y); max_y = maxf(max_y, point.y)
		min_heading = minf(min_heading, heading); max_heading = maxf(max_heading, heading)
		max_gap = maxf(max_gap, previous.distance_to(point)); previous = point
		distance += 1.0
	var points := control_points()
	return {"path_length": length, "elevation_drop": max_y - min_y, "wide_curve_degrees": rad_to_deg(max_heading - min_heading), "bump_prominence": points[7].y - (points[6].y + points[8].y) * 0.5, "continuity_max_gap": max_gap}

static func _terrain_point(curve: Curve3D, distance: float, lateral_ratio: float) -> Vector3:
	var frame := sample_frame(curve, distance)
	var lateral := lerpf(-TERRAIN_HALF_WIDTH, TERRAIN_HALF_WIDTH, lateral_ratio)
	var road_blend := smoothstep(ROAD_HALF_WIDTH + 0.55, ROAD_HALF_WIDTH + 8.5, absf(lateral))
	var dune := sin(distance * 0.027 + lateral * 0.13) * 1.10 + sin(distance * 0.009 - lateral * 0.24) * 0.64
	var erosion := sin(lateral * 0.42 + distance * 0.061) * 0.24 + sin(lateral * 0.91 - distance * 0.034) * 0.10
	return frame.origin + frame.basis.x * lateral + Vector3.UP * (-0.20 + (dune + erosion) * road_blend)

static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	surface.set_uv(uv_a); surface.add_vertex(a)
	surface.set_uv(uv_b); surface.add_vertex(b)
	surface.set_uv(uv_c); surface.add_vertex(c)
