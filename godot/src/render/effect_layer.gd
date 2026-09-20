## effect_layer.gd
## PORTS: web/src/tilt-to-live/ParticleEngine.ts:199-236 (particles)
##        web/src/tilt-to-live/ScoreManager.ts:186-205 (floating text)
##        per spec §5.5
class_name EffectLayer
extends Node2D
## Layer rendering particle explosions, shockwaves, shard debris, and floating texts.

var _particles: ParticleEngine = null
var _scores: ScoreManager = null

# DIVERGENCE(M2.5 §6.1): the playfield is inset from the viewport, so every
# draw call in playfield-local coordinates is translated by this.
var _arena_origin: Vector2 = Vector2.ZERO


## Binds particle engine and score manager data sources.
func bind(particles: ParticleEngine, scores: ScoreManager) -> void:
	_particles = particles
	_scores = scores


## Sets the playfield's top-left corner in viewport space. Called by GameRoot.
func set_arena_origin(origin: Vector2) -> void:
	_arena_origin = origin


func _draw() -> void:
	draw_set_transform(_arena_origin, 0.0, Vector2.ONE)
	_draw_particles()
	_draw_floating_texts()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_particles() -> void:
	if _particles == null:
		return
	for p: ParticleEngine.Particle in _particles.particles:
		var alpha: float = maxf(0.0, p.life / p.max_life)
		var col: Color = p.color
		col.a *= alpha

		match p.shape:
			ParticleEngine.Shape.RING:
				# PORT: web/src/tilt-to-live/ParticleEngine.ts:207-211
				draw_arc(Vector2(p.x, p.y), p.size, 0.0, TAU, 32, col, maxf(1.0, 2.5 * alpha))
			ParticleEngine.Shape.STREAK:
				# PORT: web/src/tilt-to-live/ParticleEngine.ts:213-218
				var p_to: Vector2 = Vector2(p.x - p.vx * 0.04, p.y - p.vy * 0.04)
				draw_line(Vector2(p.x, p.y), p_to, col, maxf(1.0, p.size))
			ParticleEngine.Shape.SHARD:
				# PORT: web/src/tilt-to-live/ParticleEngine.ts:220-225
				draw_set_transform(Vector2(p.x, p.y), p.life * 10.0, Vector2.ONE)
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
