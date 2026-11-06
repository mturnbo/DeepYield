// Soft additive glow for a comet's coma and tails. The edges fade out, and a tail
// also fades along its length, brightest at the head.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 glow_color : source_color = vec3(0.6, 0.8, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform float edge_softness : hint_range(0.5, 6.0) = 2.0;
// 0 for the round coma. For a tail, its length; the mesh runs along Y with the head at -Y.
uniform float tail_length = 0.0;

varying float along;

void vertex() {
	along = tail_length > 0.0 ? clamp(VERTEX.y / tail_length + 0.5, 0.0, 1.0) : 0.0;
}

void fragment() {
	float edge = pow(abs(dot(NORMAL, VIEW)), edge_softness);
	float fade = pow(1.0 - along, 1.6);
	ALBEDO = glow_color * intensity * edge * fade;
}
