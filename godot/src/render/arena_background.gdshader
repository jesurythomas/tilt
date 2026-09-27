// arena_background.gdshader
// DIVERGENCE(M11c review, emulator play 2026-09-27): the arena's radial background
// (TiltRenderer.ts:82-92) computed per pixel instead of a 256 px GradientTexture2D
// stretched to ~3400 px, which showed stepped rings (8-bit banding across the dark
// stops). Same stops and radius (see grid_layer.gd's PORT-NOTE on 0.69375), colours
// interpolated as raw sRGB values like the canvas gradient, plus a +/-0.5 of one
// 8-bit level dither that breaks the rings up.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 inner_color;
uniform vec4 mid_color;
uniform vec4 outer_color;
uniform vec2 centre;
uniform float radius = 1.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float t = clamp(length(local_pos - centre) / radius, 0.0, 1.0);
	vec4 c;
	if (t <= 0.125) {
		c = inner_color;
	} else if (t <= 0.69375) {
		c = mix(inner_color, mid_color, (t - 0.125) / (0.69375 - 0.125));
	} else {
		c = mix(mid_color, outer_color, (t - 0.69375) / (1.0 - 0.69375));
	}
	float n = (hash(FRAGCOORD.xy) - 0.5) / 255.0;
	COLOR = vec4(c.rgb + vec3(n), 1.0);
}
