shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 tint : source_color = vec4(1.0, 0.48, 0.12, 1.0);

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float core = 1.0 - smoothstep(0.08, 0.94, length(vec2(centered.x * 1.6, centered.y)));
	float hot = 1.0 - smoothstep(0.0, 0.55, abs(centered.x));
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.72, 0.24), hot * 0.22);
	ALPHA = core * tint.a * COLOR.a;
}
