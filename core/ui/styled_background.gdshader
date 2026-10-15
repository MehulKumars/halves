shader_type canvas_item;
// Background gradient with an optional pattern, drawn behind every screen by StyledBackground.
// A few operations per pixel and fully opaque, so it is cheap on low-end phones.
// pattern: 0 none, 1 dots, 2 diagonal stripes, 3 synthwave grid, 4 paper grain, 5 checker.

uniform vec4 top_color : source_color = vec4(0.08, 0.09, 0.14, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.04, 0.05, 0.07, 1.0);
uniform vec4 pattern_color : source_color = vec4(1.0, 1.0, 1.0, 0.05);
uniform int pattern = 0;
uniform float pattern_scale = 48.0;
// Pattern drift in canvas pixels. StyledBackground advances it; Reduce Motion stops it.
uniform float offset = 0.0;
uniform vec2 rect_size = vec2(720.0, 1280.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grid_floor(vec2 uv, float s) {
	float horizon = 0.62;
	float y = uv.y - horizon;
	float glow = exp(-abs(y) * 40.0) * 0.9;
	if (y <= 0.0) {
		return glow * 0.6;
	}
	float depth = 1.0 / y;
	vec2 g = vec2((uv.x - 0.5) * depth * (rect_size.x / s), depth * 1.5 + offset / s);
	vec2 dist = abs(fract(g) - 0.5);
	vec2 width = fwidth(g) * 1.2;
	float lines = max(smoothstep(0.5 - width.x - 0.02, 0.5, dist.x), smoothstep(0.5 - width.y - 0.02, 0.5, dist.y));
	return max(lines * smoothstep(0.0, 0.18, y), glow);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec3 color = mix(top_color.rgb, bottom_color.rgb, UV.y);
	float s = max(pattern_scale, 2.0);
	float m = 0.0;
	if (pattern == 1) {
		vec2 cell = mod(px + vec2(offset, offset * 0.5), s) - 0.5 * s;
		float r = s * 0.08;
		m = 1.0 - smoothstep(r - 1.0, r + 1.0, length(cell));
	} else if (pattern == 2) {
		float d = mod(px.x + px.y + offset, s);
		m = smoothstep(0.5 * s - 1.0, 0.5 * s + 1.0, d) * (1.0 - smoothstep(s - 2.0, s, d));
	} else if (pattern == 3) {
		m = grid_floor(UV, s);
	} else if (pattern == 4) {
		m = hash(floor(px / s));
	} else if (pattern == 5) {
		vec2 c = floor((px + vec2(offset)) / s);
		m = mod(c.x + c.y, 2.0);
	}
	COLOR = vec4(mix(color, pattern_color.rgb, clamp(m, 0.0, 1.0) * pattern_color.a), 1.0);
}
