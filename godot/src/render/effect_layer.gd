## effect_layer.gd
## PORTS: web/src/tilt-to-live/ParticleEngine.ts:199-236 (particles)
##        web/src/tilt-to-live/ScoreManager.ts:186-205 (floating text)
##        web/src/tilt-to-live/WeaponSystem.ts:616-790 (render active weapons, missiles, arcs)
##        web/src/tilt-to-live/TiltRenderer.ts:513-565 (mode announcement banner)
##        per spec §5.5
class_name EffectLayer
extends Node2D
## Layer rendering particle explosions, shockwaves, shard debris, weapon FX, and floating texts.

## PORT: web/src/tilt-to-live/TiltRenderer.ts:528-529 (classic)
const BANNER_CLASSIC: Color = Color("#5B8CFF")
const BANNER_CLASSIC_BG: Color = Color(20.0 / 255.0, 24.0 / 255.0, 33.0 / 255.0, 0.92)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:534-535 (code red)
const BANNER_CODE_RED: Color = Color("#A78BFA")
const BANNER_CODE_RED_BG: Color = Color(26.0 / 255.0, 18.0 / 255.0, 38.0 / 255.0, 0.92)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:539-540 (gauntlet)
const BANNER_GAUNTLET: Color = Color("#FFB14D")
const BANNER_GAUNTLET_BG: Color = Color(38.0 / 255.0, 28.0 / 255.0, 16.0 / 255.0, 0.92)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:555 (the subline)
const BANNER_SUB: Color = Color("#99A1B3")

var _particles: ParticleEngine = null
var _scores: ScoreManager = null
var _weapons: WeaponSystem = null
## Run clock in seconds, driving the vortex pulse and spin.
var _elapsed: float = 0.0

# DIVERGENCE(M2.5 §6.1): the playfield is inset from the viewport, so every
# draw call in playfield-local coordinates is translated by this.
var _arena_origin: Vector2 = Vector2.ZERO
## The run's mode, for the banner. PORT: web/src/tilt-to-live/TiltRenderer.ts:517
var _game_mode: Types.GameMode = Types.GameMode.CLASSIC
## CSS px → physical px (content_scale_mode is disabled; M10 R2).
var _ui_scale: float = 1.0
## False once the run ends, so a death inside 2.8 s does not freeze the banner.
var _is_banner_shown: bool = false
## PORT: web/src/tilt-to-live/TiltRenderer.ts:551 ('700 … "Archivo"', normal width)
var _banner_title_font: FontVariation = UiTheme.archivo(100.0)
## PORT: web/src/tilt-to-live/TiltRenderer.ts:554 ('500 … "IBM Plex Mono"')
var _banner_sub_font: FontVariation = UiTheme.mono(UiTheme.Weight.MEDIUM)


## Binds particle engine, score manager, and weapon system data sources.
func bind(particles: ParticleEngine, scores: ScoreManager, weapons: WeaponSystem = null) -> void:
	_particles = particles
	_scores = scores
	_weapons = weapons


## Sets the playfield's top-left corner in viewport space. Called by GameRoot.
func set_arena_origin(origin: Vector2) -> void:
	_arena_origin = origin


## Run clock, for the vortex pulse and spin.
func set_elapsed(elapsed: float) -> void:
	_elapsed = elapsed


## Sets the run's mode.
func set_game_mode(mode: Types.GameMode) -> void:
	_game_mode = mode


## Sets the HUD's ui_scale, which sizes the banner.
func set_ui_scale(scale: float) -> void:
	_ui_scale = scale


## Shows the banner at a run's reset; hides it when the run ends.
func set_banner_shown(is_shown: bool) -> void:
	_is_banner_shown = is_shown


## True while the banner is visible this frame.
func is_banner_drawn() -> bool:
	return _is_banner_shown and banner_alpha(_elapsed) > 0.0


## PORT: web/src/tilt-to-live/TiltRenderer.ts:520
static func banner_alpha(elapsed: float) -> float:
	if elapsed > 2.2:
		return maxf(0.0, (2.8 - elapsed) / 0.6)
	return minf(1.0, elapsed / 0.3)


## [title, subline]. PORT: web/src/tilt-to-live/TiltRenderer.ts:526-541
static func banner_copy(mode: Types.GameMode) -> PackedStringArray:
	match mode:
		Types.GameMode.CODE_RED:
			return PackedStringArray(
				["CODE RED PROTOCOL", "1.5X SCORE // INSTANT HYPER-SWARM AMBUSH"]
			)
		Types.GameMode.GAUNTLET:
			return PackedStringArray(["THE GAUNTLET", "1.25X MULTIPLIER // DESCENDING WALL MAZE"])
	return PackedStringArray(["CLASSIC SURVIVAL", "STANDARD 1.0X SCORE // THE NEON ARENA"])


## [accent, box fill]. PORT: web/src/tilt-to-live/TiltRenderer.ts:528-541
static func banner_colors(mode: Types.GameMode) -> PackedColorArray:
	match mode:
		Types.GameMode.CODE_RED:
			return PackedColorArray([BANNER_CODE_RED, BANNER_CODE_RED_BG])
		Types.GameMode.GAUNTLET:
			return PackedColorArray([BANNER_GAUNTLET, BANNER_GAUNTLET_BG])
	return PackedColorArray([BANNER_CLASSIC, BANNER_CLASSIC_BG])


## The banner box in playfield space. PORT: web/src/tilt-to-live/TiltRenderer.ts:543-545
static func banner_rect(arena_width: float, scale: float) -> Rect2:
	var box_w: float = minf(460.0 * scale, arena_width - 32.0 * scale)
	return Rect2(arena_width / 2.0 - box_w / 2.0, 88.0 * scale, box_w, 46.0 * scale)


func _draw() -> void:
	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)
	var pt_draw: int = PerfProbe.now()
	# PORT-NOTE: weapons draw before particles (TiltRenderer.ts:135, :141) but, per
	# spec §5.5, above enemies and the player, where TiltRenderer.ts:138/:144 drew
	# them below — the spec's explicit render order.
	_draw_weapon_fx()
	_draw_particles()
	_draw_floating_texts()
	if is_banner_drawn():
		_draw_mode_banner()
	PerfProbe.add("d_effect", pt_draw)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_weapon_fx() -> void:
	if _weapons == null:
		return

	# 1. Active weapons. PORT: web/src/tilt-to-live/WeaponSystem.ts:616-745
	for w: Types.ActiveWeapon in _weapons.active_weapons:
		var pos: Vector2 = Vector2(w.x, w.y)
		if w.type == Types.WeaponType.NUKE:
			# Moved verbatim from entity_layer.gd:84-113 (M2). PORT: WeaponSystem.ts:617-638
			var progress: float = 1.0 - w.duration / w.max_duration
			var alpha: float = maxf(0.0, 1.0 - progress)

			# PORT-NOTE: canvas draws sub-pixel widths; Godot's draw_line does not, so
			# widths are floored at 1.0 px (WeaponSystem.ts:782).
			# Outer expanding shockwave ring (PORT: WeaponSystem.ts:622-626)
			draw_arc(
				pos,
				w.radius,
				0.0,
				TAU,
				64,
				Color(1.0, 0.0, 85.0 / 255.0, alpha * 0.9),
				maxf(1.0, 6.0 * alpha)
			)

			# Inner secondary shockwave ring (PORT: WeaponSystem.ts:628-632)
			draw_arc(
				pos,
				maxf(1.0, w.radius - 8.0),
				0.0,
				TAU,
				64,
				Color(1.0, 230.0 / 255.0, 120.0 / 255.0, alpha * 0.8),
				maxf(1.0, 3.0 * alpha)
			)

			# Inner translucent core (PORT: WeaponSystem.ts:634-638)
			draw_circle(pos, w.radius, Color(1.0, 30.0 / 255.0, 80.0 / 255.0, alpha * 0.25))
		elif w.type == Types.WeaponType.LASER:
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:640-642
			var beam_length: float = (
				w.radius
				if w.radius != 0.0
				else Tuning.get_tuned_value("laser", "length", 0) * _weapons.scale
			)
			var a: float = w.angle if not is_nan(w.angle) else 0.0
			var dir: Vector2 = Vector2(cos(a), sin(a))
			# PORT-NOTE: the 5 px white core is drawn first and the 14 px aura on top of
			# it (WeaponSystem.ts:645-658), so the aura covers the core — preserved.
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:645-650
			draw_line(pos - dir * beam_length, pos + dir * beam_length, Color.WHITE, 5.0)
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:653-658
			draw_line(
				pos - dir * beam_length,
				pos + dir * beam_length,
				Color(204.0 / 255.0, 34.0 / 255.0, 1.0, 0.65),
				14.0
			)
			# Cross beam. PORT: web/src/tilt-to-live/WeaponSystem.ts:661-678
			var data: Dictionary = w.data if w.data != null else {}
			var cross_beam: bool = data.get("crossBeam", false)
			if cross_beam:
				var dir_b: Vector2 = Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0))
				draw_line(pos - dir_b * beam_length, pos + dir_b * beam_length, Color.WHITE, 5.0)
				draw_line(
					pos - dir_b * beam_length,
					pos + dir_b * beam_length,
					Color(204.0 / 255.0, 34.0 / 255.0, 1.0, 0.65),
					14.0
				)
		elif w.type == Types.WeaponType.VORTEX:
			# PORT: web/src/tilt-to-live/WeaponSystem.ts:681-683
			var pulse: float = 0.85 + 0.15 * sin(_elapsed * 12.0)
			var radius: float = 36.0 * pulse
			var pull_radius: float = (
				w.radius
				if w.radius != 0.0
				else Tuning.get_tuned_value("blackhole", "radius", 0) * _weapons.scale
			)
			# Lensing rings. PORT: web/src/tilt-to-live/WeaponSystem.ts:686-703
			var ring_alpha: float = 0.22 + 0.08 * sin(_elapsed * 6.0)
			draw_arc(
				pos,
				pull_radius * 0.75,
				0.0,
				TAU,
				64,
				Color(160.0 / 255.0, 40.0 / 255.0, 1.0, ring_alpha),
				2.5
			)
			draw_arc(
				pos,
				pull_radius * 0.45,
				0.0,
				TAU,
				64,
				Color(0.0, 240.0 / 255.0, 1.0, ring_alpha * 0.75),
				1.5
			)
			draw_arc(
				pos,
				pull_radius * 0.22,
				0.0,
				TAU,
				64,
				Color(200.0 / 255.0, 80.0 / 255.0, 1.0, ring_alpha * 1.2),
				3.0
			)
			# Accretion arms and core, rotating. PORT: web/src/tilt-to-live/WeaponSystem.ts:706-743
			# PORT-NOTE: shadowColor/shadowBlur (:709-710, :729-730) have no per-draw port;
			# spec §4.5 routes glow to the M11c WorldEnvironment pass.
			draw_set_transform(_arena_origin + pos, _elapsed * 7.5, Vector2.ONE)
			for arm: int in range(6):
				# PORT: web/src/tilt-to-live/WeaponSystem.ts:714
				var base_angle: float = (float(arm) * PI) / 3.0
				# PORT: web/src/tilt-to-live/WeaponSystem.ts:715
				var arm_color: Color = Color("#bb44ff") if arm % 2 == 0 else Color("#00e5ff")
				var points: PackedVector2Array = PackedVector2Array()
				for r: int in range(12, 100, 4):  # PORT: web/src/tilt-to-live/WeaponSystem.ts:718
					var a: float = base_angle + float(r) * 0.09  # PORT: web/src/tilt-to-live/WeaponSystem.ts:719
					points.append(Vector2(cos(a) * float(r), sin(a) * float(r)))
				draw_polyline(points, arm_color, 2.5)  # PORT: web/src/tilt-to-live/WeaponSystem.ts:716
			# Photon ring. PORT: web/src/tilt-to-live/WeaponSystem.ts:731-735
			draw_arc(Vector2.ZERO, radius * 0.85, 0.0, TAU, 32, Color.WHITE, 3.0)
			# Singularity core. PORT: web/src/tilt-to-live/WeaponSystem.ts:738-741
			draw_circle(Vector2.ZERO, radius * 0.75, Color("#020005"))
			draw_set_transform(_arena_origin, 0.0, Vector2.ONE)

	# 2. Homing missiles. PORT: web/src/tilt-to-live/WeaponSystem.ts:748-777
	for m: Types.HomingMissile in _weapons.missiles:
		var angle: float = atan2(m.vy, m.vx)
		draw_set_transform(_arena_origin + Vector2(m.x, m.y), angle, Vector2.ONE)
		# Body. PORT: web/src/tilt-to-live/WeaponSystem.ts:755-756
		draw_rect(Rect2(-6.0, -2.5, 12.0, 5.0), Color.WHITE)
		# Warhead. PORT: web/src/tilt-to-live/WeaponSystem.ts:759-765
		draw_colored_polygon(
			PackedVector2Array([Vector2(6.0, -2.5), Vector2(10.0, 0.0), Vector2(6.0, 2.5)]),
			Color("#ff4400")
		)
		# Thrust flame. PORT: web/src/tilt-to-live/WeaponSystem.ts:768-774
		draw_colored_polygon(
			PackedVector2Array(
				[Vector2(-6.0, -2.0), Vector2(-11.0 - randf() * 4.0, 0.0), Vector2(-6.0, 2.0)]
			),
			Color("#ffcc00")
		)
		draw_set_transform(_arena_origin, 0.0, Vector2.ONE)

	# 3. Lightning arcs. PORT: web/src/tilt-to-live/WeaponSystem.ts:780-790
	for arc: Types.LightningArc in _weapons.lightning_arcs:
		var points: PackedVector2Array = PackedVector2Array()
		points.append(Vector2(arc.x1, arc.y1))
		for b: Vector2 in arc.branches:
			points.append(b)
		points.append(Vector2(arc.x2, arc.y2))
		# PORT: web/src/tilt-to-live/WeaponSystem.ts:781-782
		# PORT-NOTE: canvas draws sub-pixel widths; Godot's draw_line does not, so
		# widths are floored at 1.0 px (WeaponSystem.ts:782).
		draw_polyline(
			points,
			Color(1.0, 240.0 / 255.0, 100.0 / 255.0, arc.intensity),
			maxf(1.0, 2.5 * arc.intensity)
		)


func _draw_particles() -> void:
	if _particles == null:
		return
	for p: ParticleEngine.Particle in _particles.particles:
		var alpha: float = maxf(0.0, p.life / p.max_life)
		var col: Color = p.color
		col.a *= alpha

		match p.shape:
			ParticleEngine.Shape.RING:
				# DIVERGENCE(M2.5 §10): reduced arc segments from 32 to 16 for mobile GPU throughput.
				draw_arc(Vector2(p.x, p.y), p.size, 0.0, TAU, 16, col, maxf(1.0, 2.5 * alpha))
			ParticleEngine.Shape.STREAK:
				# PORT: web/src/tilt-to-live/ParticleEngine.ts:213-218
				var p_to: Vector2 = Vector2(p.x - p.vx * 0.04, p.y - p.vy * 0.04)
				draw_line(Vector2(p.x, p.y), p_to, col, maxf(1.0, p.size))
			ParticleEngine.Shape.SHARD:
				# PORT: web/src/tilt-to-live/ParticleEngine.ts:220-225
				# DIVERGENCE(M2.5 §6.1): draw_set_transform replaces rather than composes, so the
				# playfield origin must be re-applied here or the shard draws off its sim position.
				draw_set_transform(_arena_origin + Vector2(p.x, p.y), p.life * 10.0, Vector2.ONE)
				draw_rect(Rect2(-p.size * 0.5, -p.size * 0.5, p.size, p.size), col)
				draw_set_transform(_arena_origin, 0.0, Vector2.ONE)
			_:
				# ParticleEngine.Shape.CIRCLE and default
				# PORT: web/src/tilt-to-live/ParticleEngine.ts:227-230
				draw_circle(Vector2(p.x, p.y), maxf(0.5, p.size), col)


func _draw_floating_texts() -> void:
	if _scores == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	for t: Types.FloatingText in _scores.floating_texts:
		var alpha: float = clampf(t.alpha, 0.0, 1.0)
		var font_size: int = int(t.size)
		var text_col: Color = t.color
		text_col.a *= alpha
		var shadow_col: Color = Color(0.0, 0.0, 0.0, 0.7 * alpha)

		# Canvas textAlign = 'center', textBaseline = 'middle'
		var str_size: Vector2 = font.get_string_size(
			t.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size
		)
		var ascent: float = font.get_ascent(font_size)
		var baseline_pos: Vector2 = Vector2(t.x - str_size.x * 0.5, t.y - str_size.y * 0.5 + ascent)

		# Shadow at (+2, +2)
		draw_string(
			font,
			baseline_pos + Vector2(2.0, 2.0),
			t.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			shadow_col
		)
		# Foreground text
		draw_string(font, baseline_pos, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)


## PORT: web/src/tilt-to-live/TiltRenderer.ts:513-565
# PORT-NOTE: renderModeAnnouncementBanner has no caller in web/src. M10 R2
# (user ruling) draws it over each run's first 2.8 s from the run clock — the
# window its own fade (:520) describes. The TS sizes are CSS px; every size
# here is multiplied by the HUD's ui_scale.
func _draw_mode_banner() -> void:
	var alpha: float = banner_alpha(_elapsed)
	var arena_width: float = get_viewport_rect().size.x - _arena_origin.x * 2.0
	var box: Rect2 = banner_rect(arena_width, _ui_scale)
	var colors: PackedColorArray = banner_colors(_game_mode)
	var copy: PackedStringArray = banner_copy(_game_mode)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(colors[1], colors[1].a * alpha)
	style.border_color = Color(colors[0], alpha)
	# PORT: web/src/tilt-to-live/TiltRenderer.ts:549
	style.set_border_width_all(maxi(1, roundi(_ui_scale)))
	# PORT: web/src/tilt-to-live/TiltRenderer.ts:550
	style.set_corner_radius_all(roundi(6.0 * _ui_scale))
	draw_style_box(style, box)

	# PORT: web/src/tilt-to-live/TiltRenderer.ts:552
	var is_narrow: bool = arena_width / _ui_scale < 480.0
	# PORT: web/src/tilt-to-live/TiltRenderer.ts:553, :556
	var title_size: int = UiTheme.px(12.0 if is_narrow else 14.0, _ui_scale)
	var sub_size: int = UiTheme.px(9.5 if is_narrow else 11.0, _ui_scale)
	var centre_x: float = box.position.x + box.size.x / 2.0
	# PORT: web/src/tilt-to-live/TiltRenderer.ts:555 (boxY + 16)
	_draw_middle_centred(
		_banner_title_font,
		copy[0],
		Vector2(centre_x, box.position.y + 16.0 * _ui_scale),
		title_size,
		Color(colors[0], alpha)
	)
	# PORT: web/src/tilt-to-live/TiltRenderer.ts:558 (boxY + 32)
	_draw_middle_centred(
		_banner_sub_font,
		copy[1],
		Vector2(centre_x, box.position.y + 32.0 * _ui_scale),
		sub_size,
		Color(BANNER_SUB, alpha)
	)


## textAlign 'center', textBaseline 'middle'. PORT: web/src/tilt-to-live/TiltRenderer.ts:522-523
func _draw_middle_centred(
	font: Font, content: String, centre: Vector2, font_size: int, color: Color
) -> void:
	var width: float = font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = (
		centre.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	)
	draw_string(
		font,
		Vector2(centre.x - width / 2.0, baseline),
		content,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)
