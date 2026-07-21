shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform float surface_kind : hint_range(0.0, 2.0) = 0.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.65;
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
	float macro = fbm(world_uv * 0.045 + surface_kind * 7.1);
	float micro = fbm(world_uv * 0.31 + surface_kind * 13.7);
	float grit = smoothstep(0.63, 0.90, fbm(world_uv * 0.78 + 22.0));
	vec3 color_value;
	float roughness_value;

	if (surface_kind < 0.5) {
		vec3 warm_sand = vec3(0.50, 0.405, 0.285);
		vec3 compact = vec3(0.365, 0.315, 0.255);
		vec3 gravel = vec3(0.285, 0.275, 0.255);
		float compact_mask = smoothstep(0.36, 0.72, macro);
		color_value = mix(warm_sand, compact, compact_mask * 0.56);
		color_value = mix(color_value, gravel, grit * 0.28);
		color_value *= mix(0.92, 1.08, micro * detail_strength);
		roughness_value = mix(0.86, 0.98, micro * 0.62 + grit * 0.22);
	} else if (surface_kind < 1.5) {
		vec3 compact_road = vec3(0.205, 0.195, 0.175);
		vec3 worn_road = vec3(0.31, 0.285, 0.235);
		vec3 edge_dust = vec3(0.43, 0.355, 0.255);
		float edge = smoothstep(0.54, 0.96, abs(UV.x - 0.5) * 2.0);
		float wear = smoothstep(0.32, 0.76, macro);
		float wheel_tracks = smoothstep(0.82, 0.98, sin(UV.x * 15.0 + micro * 1.8) * 0.5 + 0.5);
		color_value = mix(compact_road, worn_road, wear * 0.48);
		color_value = mix(color_value, edge_dust, edge * 0.62);
		color_value *= 1.0 - wheel_tracks * 0.10;
		roughness_value = mix(0.74, 0.94, edge * 0.50 + micro * 0.34);
	} else {
		vec3 shoulder_sand = vec3(0.44, 0.35, 0.245);
		vec3 crushed_gravel = vec3(0.31, 0.285, 0.245);
		color_value = mix(shoulder_sand, crushed_gravel, smoothstep(0.38, 0.78, macro));
		color_value *= mix(0.90, 1.07, micro);
		roughness_value = mix(0.88, 0.98, grit);
	}

	float height_a = fbm(world_uv * 0.43 + 0.07);
	float height_b = fbm((world_uv + vec2(0.10, 0.0)) * 0.43 + 0.07);
	float height_c = fbm((world_uv + vec2(0.0, 0.10)) * 0.43 + 0.07);
	ALBEDO = clamp(color_value, vec3(0.07), vec3(0.72));
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	NORMAL_MAP = normalize(vec3(0.5 + (height_a - height_b) * 0.34, 0.5 + (height_a - height_c) * 0.34, 1.0));
	NORMAL_MAP_DEPTH = 0.30;
}
