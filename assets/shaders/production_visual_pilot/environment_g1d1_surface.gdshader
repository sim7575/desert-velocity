shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform float surface_kind : hint_range(0.0, 2.0) = 0.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.78;
varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		value += noise2d(p) * amplitude;
		p = p * 2.03 + vec2(5.7, 8.9);
		amplitude *= 0.48;
	}
	return value;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 world_uv = world_position.xz;
	float macro = fbm(world_uv * 0.042 + surface_kind * 7.1);
	float micro = fbm(world_uv * 0.29 + surface_kind * 13.7);
	float grit = smoothstep(0.61, 0.88, fbm(world_uv * 0.74 + 22.0));
	vec3 color_value;
	float roughness_value;

	if (surface_kind < 0.5) {
		vec3 warm_sand = vec3(0.43, 0.345, 0.255);
		vec3 burnt_ground = vec3(0.31, 0.285, 0.255);
		vec3 warm_gravel = vec3(0.245, 0.25, 0.245);
		float compact_mask = smoothstep(0.30, 0.73, macro);
		color_value = mix(warm_sand, burnt_ground, compact_mask * 0.62);
		color_value = mix(color_value, warm_gravel, grit * 0.34);
		color_value *= mix(0.88, 1.10, micro * detail_strength);
		roughness_value = mix(0.86, 0.98, micro * 0.58 + grit * 0.26);
	} else if (surface_kind < 1.5) {
		vec3 compact_road = vec3(0.185, 0.178, 0.165);
		vec3 worn_road = vec3(0.295, 0.27, 0.23);
		vec3 invading_sand = vec3(0.405, 0.325, 0.235);
		float edge_distance = abs(UV.x - 0.5) * 2.0;
		float irregular_edge = smoothstep(0.68 + (macro - 0.5) * 0.20, 0.98, edge_distance);
		float center_wear = 1.0 - smoothstep(0.0, 0.38, abs(UV.x - 0.5));
		float track_left = 1.0 - smoothstep(0.035, 0.095, abs(UV.x - 0.31));
		float track_right = 1.0 - smoothstep(0.035, 0.095, abs(UV.x - 0.69));
		float tracks = max(track_left, track_right) * mix(0.62, 1.0, micro);
		float dust_patch = smoothstep(0.61, 0.86, fbm(world_uv * 0.13 + 31.0));
		color_value = mix(compact_road, worn_road, center_wear * 0.40 + macro * 0.16);
		color_value *= 1.0 - tracks * 0.22;
		color_value = mix(color_value, invading_sand, irregular_edge * (0.70 + dust_patch * 0.20));
		roughness_value = mix(0.68, 0.96, irregular_edge * 0.58 + dust_patch * 0.20 + micro * 0.16);
	} else {
		vec3 shoulder_sand = vec3(0.43, 0.345, 0.255);
		vec3 crushed_gravel = vec3(0.335, 0.305, 0.265);
		float sand_ribbon = smoothstep(0.38, 0.78, macro + sin(world_position.z * 0.11) * 0.08);
		color_value = mix(shoulder_sand, crushed_gravel, sand_ribbon);
		color_value *= mix(0.88, 1.08, micro);
		roughness_value = mix(0.88, 0.98, grit);
	}

	float height_a = fbm(world_uv * 0.43 + 0.07);
	float height_b = fbm((world_uv + vec2(0.10, 0.0)) * 0.43 + 0.07);
	float height_c = fbm((world_uv + vec2(0.0, 0.10)) * 0.43 + 0.07);
	ALBEDO = clamp(color_value, vec3(0.055), vec3(0.66));
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	NORMAL_MAP = normalize(vec3(0.5 + (height_a - height_b) * 0.42, 0.5 + (height_a - height_c) * 0.42, 1.0));
	NORMAL_MAP_DEPTH = 0.36;
}
