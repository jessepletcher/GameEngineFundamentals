shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform float reflection_strength : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 reflect_uv = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y);
	vec3 reflected = texture(screen_texture, reflect_uv).rgb;
	ALBEDO = reflected;
	ALPHA = reflection_strength;
}
