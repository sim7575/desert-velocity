shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.72, 0.45, 0.24, 0.45);
uniform float emission_strength : hint_range(0.0, 8.0) = 0.0;
uniform float soft_edge : hint_range(0.05, 0.48) = 0.32;
uniform float billboard_mode : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	if (billboard_mode > 0.5) {
		vec3 model_scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		mat4 scale_matrix = mat4(vec4(model_scale.x, 0.0, 0.0, 0.0), vec4(0.0, model_scale.y, 0.0, 0.0), vec4(0.0, 0.0, model_scale.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]) * scale_matrix;
	}
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float distance_from_center = length(centered);
	float radial = 1.0 - smoothstep(soft_edge, 0.5, distance_from_center);
	float core = 1.0 - smoothstep(0.0, 0.46, distance_from_center);
	vec3 color = tint.rgb * COLOR.rgb;
	ALBEDO = color;
	EMISSION = color * emission_strength * core;
	ALPHA = radial * radial * tint.a * COLOR.a;
}
