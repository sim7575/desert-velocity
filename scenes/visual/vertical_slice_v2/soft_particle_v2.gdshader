shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius = length(vec2(centered.x, centered.y * 0.82));
	float soft_alpha = 1.0 - smoothstep(0.20, 1.0, radius);
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = soft_alpha * tint.a * COLOR.a;
}
