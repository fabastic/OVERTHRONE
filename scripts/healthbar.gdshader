// A tiny health bar over a foe's head: a billboard quad, drawn as a pixel bar with a dark frame.
// Each foe sets its own fill (instance uniform), so one material serves them all.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float fill = 1.0;
instance uniform float flash = 0.0;
uniform vec3 full_col : source_color = vec3(0.35, 0.85, 0.3);
uniform vec3 low_col : source_color = vec3(0.9, 0.2, 0.15);
uniform float cells = 20.0;

void vertex() {
	// Face the camera, keep the size the object gives it
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 uv = UV;
	float border = step(uv.x, 0.03) + step(0.97, uv.x) + step(uv.y, 0.18) + step(0.82, uv.y);
	float x = floor(uv.x * cells) / cells;
	vec3 col = mix(low_col, full_col, clamp(fill * 1.4 - 0.2, 0.0, 1.0));
	vec3 bg = vec3(0.08, 0.04, 0.06);
	vec3 c = x < fill ? col : bg;
	c = mix(c, vec3(1.0), flash);
	c = border > 0.0 ? vec3(0.02, 0.01, 0.02) : c;
	ALBEDO = c;
	ALPHA = 0.95;
}
