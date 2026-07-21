shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform float opacity : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float ellipse = length(vec2(centered.x, centered.y * 0.72));
	ALBEDO = vec3(0.012, 0.015, 0.018);
	ALPHA = (1.0 - smoothstep(0.12, 1.0, ellipse)) * opacity;
}
