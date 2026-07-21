shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : filter_linear_mipmap_anisotropic;
uniform vec4 primary_tint : source_color = vec4(1.0);
uniform vec4 secondary_tint : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform float category_seed = 0.0;
uniform float surface_mode = 0.0;
uniform float normal_strength = 0.4;
uniform float roughness_bias = 0.8;
uniform float metallic_strength = 0.0;
uniform float fracture_strength = 0.25;

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
}

void fragment() {
	vec2 world_uv = world_position.xz;
	float macro = fbm(world_uv * 0.055 + category_seed);
	float micro = fbm(world_uv * 0.42 + category_seed * 2.7);
	vec3 color_value;
	float roughness_value;
	float ao_value = 1.0;
	vec3 mapped_normal = vec3(0.5, 0.5, 1.0);

	if (surface_mode > 1.5) {
		float tracks = smoothstep(0.74, 0.96, sin(world_position.x * 1.15 + micro * 2.0) * 0.5 + 0.5);
		float dust = smoothstep(0.56, 0.78, fbm(world_uv * 0.12 + 11.0));
		float wear = smoothstep(0.38, 0.72, macro);
		vec3 compact = vec3(0.245, 0.245, 0.225);
		vec3 worn = vec3(0.355, 0.335, 0.285);
		vec3 dusty = vec3(0.49, 0.43, 0.33);
		color_value = mix(compact, worn, wear);
		color_value = mix(color_value, dusty, dust * 0.34);
		color_value *= 1.0 - tracks * 0.13;
		roughness_value = mix(0.73, 0.94, dust * 0.6 + micro * 0.25);
	} else if (surface_mode > 0.5) {
		float compact_mask = smoothstep(0.34, 0.68, macro);
		float gravel_mask = smoothstep(0.66, 0.88, micro);
		vec3 fine_sand = vec3(0.46, 0.40, 0.31);
		vec3 compact_ground = vec3(0.30, 0.285, 0.265);
		vec3 gravel = vec3(0.25, 0.265, 0.28);
		color_value = mix(fine_sand, compact_ground, compact_mask * 0.64);
		color_value = mix(color_value, gravel, gravel_mask * 0.30);
		color_value *= mix(0.91, 1.07, fbm(world_uv * 0.2 + 19.0));
		roughness_value = mix(0.83, 0.98, 1.0 - micro * 0.45);
	} else {
		vec3 base_value = texture(base_map, UV).rgb * primary_tint.rgb;
		vec3 orm = texture(orm_map, UV).rgb;
		float broad_break = fbm(world_position.xz * 0.075 + world_position.y * 0.035 + category_seed);
		float fracture_axis = abs(sin(world_position.x * 0.47 + world_position.z * 0.31 + micro * 4.0));
		float fracture = smoothstep(0.91, 0.985, fracture_axis) * fracture_strength;
		float band_interrupt = smoothstep(0.28, 0.76, broad_break);
		color_value = mix(base_value, base_value * secondary_tint.rgb, band_interrupt * 0.12);
		color_value *= mix(0.94, 1.05, macro);
		color_value = mix(color_value, color_value * vec3(0.64, 0.72, 0.80), fracture);
		roughness_value = clamp(mix(roughness_bias - 0.10, roughness_bias + 0.09, orm.g * 0.62 + micro * 0.38), 0.42, 0.98);
		ao_value = mix(0.72, 1.0, orm.r);
		mapped_normal = texture(normal_map, UV).rgb;
	}

	float height_a = fbm(world_uv * 0.46 + 0.07);
	float height_b = fbm((world_uv + vec2(0.11, 0.0)) * 0.46 + 0.07);
	float height_c = fbm((world_uv + vec2(0.0, 0.11)) * 0.46 + 0.07);
	if (surface_mode > 0.5) {
		mapped_normal = normalize(vec3(0.5 + (height_a - height_b) * 0.38, 0.5 + (height_a - height_c) * 0.38, 1.0));
	}

	ALBEDO = clamp(color_value, vec3(0.055), vec3(0.72));
	ROUGHNESS = roughness_value;
	METALLIC = metallic_strength;
	AO = ao_value;
	AO_LIGHT_AFFECT = 0.32;
	NORMAL_MAP = mapped_normal;
	NORMAL_MAP_DEPTH = normal_strength;
}
