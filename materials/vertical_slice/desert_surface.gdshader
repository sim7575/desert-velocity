shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.35, 0.24, 0.16, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.55, 0.34, 0.19, 1.0);
uniform vec4 detail_color : source_color = vec4(0.72, 0.48, 0.25, 1.0);
uniform float base_roughness : hint_range(0.2, 1.0) = 0.82;
uniform float edge_sand : hint_range(0.0, 1.0) = 0.0;
uniform float track_strength : hint_range(0.0, 1.0) = 0.0;
uniform float micro_strength : hint_range(0.0, 1.0) = 0.25;

varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float macro = value_noise(world_position.xz * 0.027);
	float medium = value_noise(world_position.xz * 0.11 + vec2(8.3, 2.1));
	float micro = value_noise(world_position.xz * 0.72 + vec2(3.7, 9.4));
	vec3 color = mix(base_color.rgb, secondary_color.rgb, smoothstep(0.26, 0.78, macro));
	color = mix(color, detail_color.rgb, medium * micro_strength * 0.34);
	float edge = smoothstep(0.58, 0.98, abs(UV.x - 0.5) * 2.0);
	float sand_breakup = smoothstep(0.35, 0.78, medium + edge * 0.42);
	color = mix(color, detail_color.rgb, edge * edge_sand * sand_breakup);
	float left_track = 1.0 - smoothstep(0.025, 0.085, abs(UV.x - 0.35));
	float right_track = 1.0 - smoothstep(0.025, 0.085, abs(UV.x - 0.65));
	float tracks = max(left_track, right_track) * track_strength;
	float worn_center = (1.0 - smoothstep(0.0, 0.34, abs(UV.x - 0.5))) * track_strength * 0.24;
	color *= 1.0 - tracks * (0.09 + medium * 0.06) - worn_center;
	float fine_grain = (micro - 0.5) * 0.08 * micro_strength;
	ALBEDO = color + vec3(fine_grain);
	ROUGHNESS = clamp(base_roughness + (medium - 0.5) * 0.18 + edge * edge_sand * 0.08 - tracks * 0.06, 0.28, 1.0);
}
