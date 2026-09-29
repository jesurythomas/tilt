// arena_background.gdshader
// DIVERGENCE(M11c review, emulator play 2026-09-27): the arena's radial background
// (TiltRenderer.ts:82-92) computed per pixel instead of a 256 px GradientTexture2D
// stretched to ~3400 px, which showed stepped rings (8-bit banding across the dark
// stops). Same stops and radius (see grid_layer.gd's PORT-NOTE on 0.69375), colours
// interpolated as raw sRGB values like the canvas gradient, plus a +/-0.5 of one
// 8-bit level dither that breaks the rings up.
//
// DIVERGENCE(THEME R2, user 2026-09-29: "arena themes kinda look similar"): each arena
// theme also draws a dim procedural effect over the gradient, picked by `pattern` (the
// order of ProgressionManager.ArenaPattern). Effects move with TIME, so they cost no CPU,
// and stay faint so the dots stay readable. `unit` is height / 1080, so the small Armory
// preview is a scaled picture of the arena. `accent` is the theme's dust colour and
// `accent2` its boundary colour.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 inner_color;
uniform vec4 mid_color;
uniform vec4 outer_color;
uniform vec2 centre;
uniform float radius = 1.0;
uniform int pattern = 0;
uniform vec4 accent = vec4(1.0);
uniform vec4 accent2 = vec4(1.0);
uniform float unit = 1.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// A sparse field of soft dots (or thin rings, `hollow` = 1) drifting by `vel` px/s: at
// most one per `cell` px square, kept 20% off the cell edge so nothing is clipped.
// `stretch` lengthens a dot into a streak; `twinkle` (0..1) makes it flicker.
float dots(vec2 p, float cell, vec2 vel, float rad, float density, float seed,
		vec2 stretch, float twinkle, float hollow) {
	vec2 q = (p - vel * TIME) / cell;
	vec2 id = floor(q);
	vec2 f = fract(q);
	float h = hash(id + seed);
	if (h > density) {
		return 0.0;
	}
	vec2 pos = vec2(hash(id + seed + 7.1), hash(id + seed + 13.7)) * 0.6 + 0.2;
	float d = length((f - pos) * cell / stretch);
	float body = 1.0 - smoothstep(rad * 0.25, rad, d);
	float rim = 1.0 - smoothstep(0.0, 1.5, abs(d - rad));
	float flick = 1.0 - twinkle * (0.5 + 0.5 * sin(TIME * 2.5 + h * 40.0));
	return mix(body, rim, hollow) * flick;
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

	vec2 size = centre * 2.0;
	vec2 uv = local_pos / size;
	vec2 p = local_pos / unit;
	vec2 mid = centre / unit;
	vec2 aspect = vec2(size.x / size.y, 1.0);
	vec3 add = vec3(0.0);
	float mul = 1.0;

	if (pattern == 1) {
		// STARS (Cosmic Nebula): twinkling stars over a slow cloud.
		float s = dots(p, 70.0, vec2(0.0), 2.8, 0.4, 1.0, vec2(1.0), 0.6, 0.0);
		s += 0.9 * dots(p, 130.0, vec2(0.0), 4.2, 0.3, 5.0, vec2(1.0), 0.5, 0.0);
		float cloud = vnoise(p / 260.0 + vec2(TIME * 0.01, 0.0));
		add = accent.rgb * (s * 0.9 + cloud * 0.11);
	} else if (pattern == 2) {
		// SUN (Synthwave Sunset): a striped sun on a horizon line.
		vec2 sc = vec2(0.5, 0.66);
		vec2 d = (uv - sc) * aspect;
		float r = 0.24;
		float disc = 1.0 - smoothstep(r - 0.006, r, length(d));
		float below = step(sc.y, uv.y);
		float thick = mix(0.15, 0.85, clamp((uv.y - sc.y) / r, 0.0, 1.0));
		float cut = below * (1.0 - step(thick, fract((uv.y - sc.y) * 30.0)));
		disc *= 1.0 - cut;
		vec3 sun = mix(vec3(1.0, 0.85, 0.35), accent.rgb,
				clamp((uv.y - (sc.y - r)) / (2.0 * r), 0.0, 1.0));
		float glow = exp(-length(d) * 5.0);
		float horizon = 1.0 - smoothstep(0.0, 0.004, abs(uv.y - 0.86));
		add = sun * disc * 0.35 + accent.rgb * (glow * 0.10 + horizon * 0.15);
	} else if (pattern == 3) {
		// CODE (Matrix Terminal): falling columns of glyph blocks.
		float col = floor(p.x / 30.0);
		float h = hash(vec2(col, 3.0));
		float y = p.y - TIME * (90.0 + h * 200.0) + h * 1000.0;
		float len = 500.0 + h * 500.0;
		float v = fract(y / len);
		float glyph = step(0.35, hash(vec2(col, floor(y / 30.0))));
		float used = step(0.5, hash(vec2(col, 9.0)));
		float inside = step(abs(fract(p.x / 30.0) - 0.5), 0.3);
		add = accent.rgb * pow(v, 5.0) * glyph * used * inside * 0.30;
	} else if (pattern == 4) {
		// SPARKS (Ember Ruins): embers rising off a warm floor.
		float s = dots(p, 90.0, vec2(20.0, -70.0), 3.6, 0.45, 2.0, vec2(1.0), 0.5, 0.0);
		s += 0.9 * dots(p, 150.0, vec2(-12.0, -45.0), 5.0, 0.35, 8.0, vec2(1.0), 0.4, 0.0);
		add = accent.rgb * (s * 1.0 + smoothstep(0.45, 1.0, uv.y) * 0.16);
	} else if (pattern == 5) {
		// HEAT (Supernova Furnace): rising heat bands and a glowing core.
		float wob = sin(uv.x * 7.0 + TIME * 0.35) * 0.9;
		float band = smoothstep(0.55, 1.0, sin(uv.y * 16.0 - TIME * 0.7 + wob));
		float core = exp(-length((uv - vec2(0.5)) * aspect) * 2.2);
		add = accent.rgb * (band * 0.06 + core * 0.09);
	} else if (pattern == 6) {
		// DRAFT (Architectural Blueprint): minor and major drafting lines and circles.
		vec2 g1 = abs(fract(p / 27.0 - 0.5) - 0.5) * 27.0;
		vec2 g5 = abs(fract(p / 135.0 - 0.5) - 0.5) * 135.0;
		float minor = 1.0 - smoothstep(0.0, 1.2, min(g1.x, g1.y));
		float major = 1.0 - smoothstep(0.0, 1.6, min(g5.x, g5.y));
		float rr = length(p - mid);
		float circle = 1.0 - smoothstep(0.0, 1.6, min(abs(rr - 270.0), abs(rr - 540.0)));
		add = accent.rgb * (minor * 0.05 + major * 0.10 + circle * 0.13);
	} else if (pattern == 7) {
		// SNOW (Arctic Lattice): three layers of flakes falling and swaying.
		float s = 0.0;
		for (int i = 0; i < 3; i++) {
			float k = float(i);
			vec2 pp = p + vec2(sin(TIME * 0.6 + k * 2.0) * 18.0, 0.0);
			s += dots(pp, 80.0 + 50.0 * k, vec2(6.0 * (k - 1.0), 40.0 + 25.0 * k),
					3.0 + 2.2 * k, 0.45, 3.0 + k * 11.0, vec2(1.0), 0.0, 0.0) * (1.0 - 0.15 * k);
		}
		add = accent.rgb * s * 0.85;
	} else if (pattern == 8) {
		// RAIN (Neon Tokyo Night): slanted streaks over a glowing skyline.
		vec2 r = vec2(p.x + p.y * 0.3, p.y);
		float col = floor(r.x / 38.0);
		float h = hash(vec2(col, 5.0));
		float y = r.y - TIME * (900.0 + h * 500.0) + h * 2000.0;
		float len = 420.0 + h * 300.0;
		float head = smoothstep(1.0 - 90.0 / len, 1.0, fract(y / len));
		float xin = 1.0 - smoothstep(1.0, 2.4, abs(fract(r.x / 38.0) - 0.5) * 38.0);
		float used = step(0.35, hash(vec2(col, 11.0)));
		add = accent.rgb * head * xin * used * 0.6
				+ accent2.rgb * smoothstep(0.6, 1.0, uv.y) * 0.14;
	} else if (pattern == 9) {
		// BUBBLES (Deep Ocean): rising bubbles over drifting caustic light.
		vec2 pp = p + vec2(sin(TIME * 0.7 + p.y * 0.01) * 10.0, 0.0);
		float b = dots(pp, 110.0, vec2(0.0, -45.0), 9.0, 0.35, 4.0, vec2(1.0), 0.0, 1.0);
		b += dots(pp, 170.0, vec2(0.0, -30.0), 14.0, 0.3, 10.0, vec2(1.0), 0.0, 1.0);
		float cs = sin(p.x * 0.018 + TIME * 0.5) * sin(p.y * 0.021 - TIME * 0.4)
				+ sin((p.x + p.y) * 0.011 + TIME * 0.3);
		add = accent.rgb * (b * 0.45 + smoothstep(1.1, 1.9, cs) * 0.05);
	} else if (pattern == 10) {
		// SAND (Desert Signal): blown streaks over soft dune bands.
		float s = dots(p, 90.0, vec2(320.0, 14.0), 1.6, 0.4, 4.0, vec2(9.0, 1.0), 0.0, 0.0);
		s += dots(p, 130.0, vec2(200.0, 8.0), 2.0, 0.3, 9.0, vec2(7.0, 1.0), 0.0, 0.0);
		float dune = 0.5 + 0.5 * sin(uv.y * 9.0 + sin(uv.x * 2.5 + TIME * 0.05) * 1.2);
		add = accent.rgb * (s * 0.5 + dune * 0.035);
	} else if (pattern == 11) {
		// RAYS (Perlas Archipelago): slowly turning wedges of the two colours.
		vec2 d = (uv - vec2(0.5)) * aspect;
		float ang = atan(d.y, d.x);
		float wedge = smoothstep(0.35, 0.95, sin(ang * 8.0 + TIME * 0.12));
		vec3 col = mix(accent.rgb, accent2.rgb, step(0.0, sin(ang * 4.0 + TIME * 0.12)));
		add = col * wedge * exp(-length(d) * 1.6) * 0.11;
	} else if (pattern == 12) {
		// RIPPLES (Rising Sun): rings spreading from the centre.
		float rr = length(p - mid);
		float ph = rr / 150.0 - TIME * 0.1;
		float ring = 1.0 - smoothstep(0.0, 0.06, abs(fract(ph) - 0.5));
		vec3 col = mix(accent.rgb, accent2.rgb, step(0.5, hash(vec2(floor(ph), 1.0))));
		add = col * ring * exp(-rr / 850.0) * 0.20;
	} else if (pattern == 13) {
		// BANDS_DIAG (Carnaval): diagonal bands drifting across.
		float x = (p.x + p.y) / 260.0 - TIME * 0.02;
		float v = fract(x);
		float band = smoothstep(0.0, 0.03, v) * (1.0 - smoothstep(0.30, 0.33, v));
		vec3 col = mix(accent.rgb, accent2.rgb, step(0.5, fract(floor(x) * 0.5)));
		add = col * band * 0.07;
	} else if (pattern == 14) {
		// STARS_BARS (Liberty Grid): faint alternating bars and twinkling stars.
		float row = floor(uv.y * 13.0);
		float bar = step(0.5, fract(uv.y * 13.0));
		vec3 col = mix(accent2.rgb, accent.rgb, step(0.5, fract(row * 0.5)));
		float s = dots(p, 60.0, vec2(0.0), 3.0, 0.35, 6.0, vec2(1.0), 0.7, 0.0);
		add = col * bar * 0.05 + accent.rgb * s * 0.9;
	} else if (pattern == 15) {
		// BANDS (Black Forest): a dark top band, a red middle and a gold bottom.
		float band = floor(clamp(uv.y, 0.0, 0.999) * 3.0);
		float shimmer = 0.85 + 0.15 * sin(uv.x * 20.0 + TIME * 0.4 + band);
		if (band < 0.5) {
			mul = 0.6;
		} else if (band < 1.5) {
			add = accent2.rgb * 0.07 * shimmer;
		} else {
			add = accent.rgb * 0.06 * shimmer;
		}
	}

	float n = (hash(FRAGCOORD.xy) - 0.5) / 255.0;
	COLOR = vec4(c.rgb * mul + add + vec3(n), 1.0);
}
