shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 lower_color : source_color = vec4(0.24, 0.10, 0.065, 1.0);
uniform vec4 upper_color : source_color = vec4(0.48, 0.22, 0.12, 1.0);
uniform vec4 strata_color : source_color = vec4(0.67, 0.34, 0.17, 1.0);
uniform float strata_scale : hint_range(0.2, 8.0) = 2.4;
uniform float variation_scale : hint_range(0.005, 0.2) = 0.035;
uniform float atmospheric_mix : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 31.4);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float macro = noise2(world_position.xz * variation_scale);
	float bands = sin((world_position.y + noise2(world_position.xz * 0.08) * 1.8) * strata_scale);
	float thin_band = smoothstep(0.58, 0.88, bands) * (0.45 + macro * 0.55);
	float broad_band = smoothstep(-0.75, 0.25, sin(world_position.y * strata_scale * 0.34 + macro * 2.0));
	vec3 color = mix(lower_color.rgb, upper_color.rgb, macro * 0.62 + broad_band * 0.28);
	color = mix(color, strata_color.rgb, thin_band * 0.18);
	color = mix(color, vec3(0.47, 0.39, 0.37), atmospheric_mix);
	ALBEDO = color;
	ROUGHNESS = clamp(0.82 + macro * 0.14 - thin_band * 0.05, 0.58, 1.0);
}
