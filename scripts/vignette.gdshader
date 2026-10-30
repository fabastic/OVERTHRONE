// The hurt flash: red only at the edges of the screen (a vignette), never a full red wash.
// The ColorRect's own alpha drives it; the edge is ragged with a pixel noise so it reads as pain.
shader_type canvas_item;

uniform float pixel = 6.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.25, 1.0);
	vec2 cell = floor(FRAGCOORD.xy / pixel);
	float r = length(d) + (hash(cell) - 0.5) * 0.06;
	float v = smoothstep(0.32, 0.78, r);
	COLOR = vec4(COLOR.rgb * (0.7 + 0.3 * v), COLOR.a * v * 1.4);
}
