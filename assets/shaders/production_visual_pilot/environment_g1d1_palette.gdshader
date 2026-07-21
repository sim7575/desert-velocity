shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : filter_linear_mipmap_anisotropic;
uniform vec4 palette_high : source_color = vec4(0.58, 0.45, 0.34, 1.0);
uniform vec4 palette_low : source_color = vec4(0.30, 0.27, 0.24, 1.0);
uniform float category_seed = 0.0;
uniform float surface_mode = 0.0;
uniform float normal_strength = 0.45;
uniform float roughness_bias = 0.88;
uniform float metallic_strength = 0.0;
uniform float fracture_strength = 0.28;
uniform float saturation_scale : hint_range(0.0, 1.0) = 0.58;

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float result = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		result += value_noise(p) * amplitude;
		p = p * 2.03 + vec2(7.1, 3.7);
		amplitude *= 0.48;
	}
	return result;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 world_uv = world_position.xz;
	float macro = fbm(world_uv * 0.052 + category_seed);
	float micro = fbm(world_uv * 0.39 + category_seed * 2.7);
	vec3 source = texture(base_map, UV).rgb;
	vec3 orm = texture(orm_map, UV).rgb;
	float source_luma = dot(source, vec3(0.299, 0.587, 0.114));
	float tonal = smoothstep(0.10, 0.82, source_luma);
	vec3 color_value = mix(palette_low.rgb, palette_high.rgb, tonal);
	float top_surface = smoothstep(0.32, 0.82, world_normal.y);
	color_value = mix(color_value, palette_high.rgb * 1.10, top_surface * 0.22);
	color_value *= mix(0.88, 1.08, macro);
	float fracture_axis = abs(sin(world_position.x * 0.47 + world_position.z * 0.31 + micro * 4.0));
	float fracture = smoothstep(0.89, 0.985, fracture_axis) * fracture_strength;
	color_value = mix(color_value, palette_low.rgb * 0.58, fracture);
	float gray = dot(color_value, vec3(0.299, 0.587, 0.114));
	color_value = mix(vec3(gray), color_value, saturation_scale);

	if (surface_mode > 0.5) {
		float compact = smoothstep(0.30, 0.72, macro);
		color_value = mix(palette_high.rgb, palette_low.rgb, compact * 0.48);
		color_value *= mix(0.91, 1.06, micro);
	}

	ALBEDO = clamp(color_value, vec3(0.045), vec3(0.66));
	ROUGHNESS = clamp(mix(roughness_bias - 0.09, roughness_bias + 0.08, orm.g * 0.60 + micro * 0.40), 0.48, 0.98);
	METALLIC = metallic_strength;
	AO = mix(0.68, 1.0, orm.r);
	AO_LIGHT_AFFECT = 0.38;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
