// Vael's water: a translucent surface whose colour comes from how deep the water really is
// (the distance from the surface to the seabed behind it, read from the depth buffer).
// Turquoise over the shallows, ink-blue in the deeps, a ring of pixel foam along every shore,
// blocky waves and glints snapped to a world-space pixel grid so it matches the voxel world.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec3 shallow_col : source_color = vec3(0.30, 0.74, 0.74);
uniform vec3 mid_col : source_color = vec3(0.10, 0.42, 0.58);
uniform vec3 deep_col : source_color = vec3(0.03, 0.11, 0.28);
uniform vec3 foam_col : source_color = vec3(0.92, 0.97, 1.0);
uniform float max_depth = 3.2;
uniform float pixel = 6.0;        // wave pixels per metre
uniform float tint = 1.0;         // dusk dims it

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 bed = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	bed.xyz /= bed.w;
	float thick = clamp(VERTEX.z - bed.z, 0.0, 60.0);
	float t = clamp(thick / max_depth, 0.0, 1.0);
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 cell = floor(wpos.xz * pixel) / pixel;
	float wave = sin(cell.x * 1.7 + TIME * 1.3) * sin(cell.y * 1.3 - TIME * 1.1);
	wave += 0.5 * sin((cell.x + cell.y) * 0.9 + TIME * 0.7);
	vec3 col = mix(shallow_col, mid_col, smoothstep(0.0, 0.45, t));
	col = mix(col, deep_col, smoothstep(0.4, 1.0, t));
	// Refraction: the seabed seen through the shallows, wobbling a little
	vec2 wob = vec2(sin(cell.y * 3.0 + TIME * 2.0), cos(cell.x * 3.0 + TIME * 1.7)) * 0.004 * (1.0 - t);
	vec3 below = texture(screen_tex, SCREEN_UV + wob).rgb;
	col = mix(below * shallow_col * 1.6, col, smoothstep(0.0, 0.55, t) * 0.85 + 0.15);
	// Wave crests and sun glints
	col += vec3(0.08, 0.1, 0.1) * step(1.05, wave);
	float glint = step(0.985, hash(cell + floor(TIME * 2.0)));
	col += vec3(0.6) * glint * (0.3 + 0.7 * t);
	// Foam: a flickering pixel ring where the water meets the shore
	float edge = 1.0 - smoothstep(0.05, 0.4, thick);
	float flick = step(0.45, hash(cell + floor(TIME * 3.0) * 0.37));
	float foam = clamp(edge * (0.55 + 0.45 * flick), 0.0, 1.0);
	col = mix(col, foam_col, foam * 0.85);
	ALBEDO = col * tint;
	ALPHA = clamp(0.55 + t * 0.4 + foam * 0.4, 0.0, 0.96);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
