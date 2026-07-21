shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform float surface_variant : hint_range(0.0, 1.0) = 0.0;
uniform float zone_seed : hint_range(0.0, 8.0) = 0.0;
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
	float macro = fbm(world_uv * 0.042 + zone_seed * 2.7);
	float micro = fbm(world_uv * 0.29 + zone_seed * 5.3);
	float grit = smoothstep(0.61, 0.88, fbm(world_uv * 0.74 + 22.0));
	float edge_distance = abs(UV.x - 0.5) * 2.0;
	float irregular_edge = smoothstep(0.68 + (macro - 0.5) * 0.20, 0.98, edge_distance);
	float center_wear = 1.0 - smoothstep(0.0, 0.38, abs(UV.x - 0.5));
	float track_left = 1.0 - smoothstep(0.035, 0.095, abs(UV.x - 0.31));
	float track_right = 1.0 - smoothstep(0.035, 0.095, abs(UV.x - 0.69));
	float tracks = max(track_left, track_right) * mix(0.62, 1.0, micro);
	vec3 asphalt = mix(vec3(0.165, 0.160, 0.152), vec3(0.275, 0.252, 0.220), center_wear * 0.38 + macro * 0.14);
	vec3 gravel = mix(vec3(0.300, 0.276, 0.240), vec3(0.405, 0.335, 0.260), macro * 0.48 + grit * 0.22);
	vec3 color_value = mix(asphalt, gravel, surface_variant);
	color_value *= 1.0 - tracks * mix(0.20, 0.10, surface_variant);
	color_value = mix(color_value, vec3(0.405, 0.325, 0.235), irregular_edge * 0.62);
	float height_a = fbm(world_uv * 0.43 + 0.07);
	float height_b = fbm((world_uv + vec2(0.10, 0.0)) * 0.43 + 0.07);
	float height_c = fbm((world_uv + vec2(0.0, 0.10)) * 0.43 + 0.07);
	ALBEDO = clamp(color_value, vec3(0.055), vec3(0.66));
	ROUGHNESS = mix(0.72, 0.94, surface_variant) + micro * 0.04;
	METALLIC = 0.0;
	NORMAL_MAP = normalize(vec3(0.5 + (height_a - height_b) * 0.42, 0.5 + (height_a - height_c) * 0.42, 1.0));
	NORMAL_MAP_DEPTH = mix(0.30, 0.40, surface_variant);
}
