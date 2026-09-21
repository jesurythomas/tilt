## score_manager.gd
## PORTS: web/src/tilt-to-live/ScoreManager.ts (207 lines, source commit 7be9614)
class_name ScoreManager
extends RefCounted
## Manages in-run scoring, multipliers, combos, close calls and floating texts.
##
## PORT-NOTE: ScoreManager.renderFloatingTexts() relocates to render/effect_layer.gd
## (spec §4.2/D4) because CanvasItem 2D drawing belongs to Node2D render layers.

const BEST_SCORE_PATH: String = "user://tilt_to_live_best.json"

## Run statistics. PORT: web/src/tilt-to-live/ScoreManager.ts:9-18
var stats: Types.GameStats = Types.GameStats.new()

## Active floating text callouts. PORT: web/src/tilt-to-live/ScoreManager.ts:20
var floating_texts: Array[Types.FloatingText] = []

## Mode-dependent score multiplier. PORT: web/src/tilt-to-live/ScoreManager.ts:21
var mode_multiplier: float = 1.0

## Progression perk score multiplier. PORT: web/src/tilt-to-live/ScoreManager.ts:27
var progression_multiplier: float = 1.0

## Active combo kill streak count. PORT: web/src/tilt-to-live/ScoreManager.ts:29
var combo_count: int = 0

## Remaining time in seconds before combo decays. PORT: web/src/tilt-to-live/ScoreManager.ts:30
var combo_timer: float = 0.0

## True if this run beat the previous best score. PORT: web/src/tilt-to-live/ScoreManager.ts:31
var is_new_best: bool = false

## Difference between current score and previous best. PORT: web/src/tilt-to-live/ScoreManager.ts:32
var best_score_diff: int = 0

var _next_text_id: int = 1


func _init() -> void:
	load_best_score()


## Sets the game mode score multiplier. PORT: web/src/tilt-to-live/ScoreManager.ts:39-41
func set_mode_multiplier(multiplier: float) -> void:
	mode_multiplier = multiplier


## Sets the progression score multiplier. PORT: web/src/tilt-to-live/ScoreManager.ts:43-45
func set_progression_multiplier(multiplier: float) -> void:
	progression_multiplier = multiplier


## Resets all in-run scoring state. PORT: web/src/tilt-to-live/ScoreManager.ts:47-61
func reset() -> void:
	stats.score = 0
	stats.multiplier = 1.0
	stats.max_multiplier = 1.0
	stats.kills = 0
	stats.survival_time = 0.0
	stats.best_combo = 0
	stats.close_calls = 0

	combo_count = 0
	combo_timer = 0.0
	is_new_best = false
	best_score_diff = 0
	floating_texts = []


## Advances survival time and decays combos and text popups.
## PORT: web/src/tilt-to-live/ScoreManager.ts:63-90
func update(dt: float, game_mode: Types.GameMode = Types.GameMode.CLASSIC) -> void:
	stats.survival_time += dt

	if game_mode == Types.GameMode.GAUNTLET:
		# PORT: web/src/tilt-to-live/ScoreManager.ts:68
		stats.score += roundi(250.0 * dt * mode_multiplier * progression_multiplier)

	# Combo window decays. PORT: web/src/tilt-to-live/ScoreManager.ts:72-77
	if combo_timer > 0.0:
		combo_timer -= dt
		if combo_timer <= 0.0:
			combo_count = 0

	# Update floating texts. PORT: web/src/tilt-to-live/ScoreManager.ts:80-89
	for i: int in range(floating_texts.size() - 1, -1, -1):
		var t: Types.FloatingText = floating_texts[i]
		t.y += t.vy * dt
		t.lifetime -= dt
		t.alpha = maxf(0.0, t.lifetime / 1.0)  # PORT: web/src/tilt-to-live/ScoreManager.ts:84

		if t.lifetime <= 0.0:
			floating_texts.remove_at(i)


## Records an enemy kill and awards points and multipliers.
## PORT: web/src/tilt-to-live/ScoreManager.ts:92-132
# DIVERGENCE(HUD-FEEDBACK §3): x/y are unused now that no kill-site floating
# text spawns here; kept in the signature so callers (and the TS shape) don't change.
func register_kill(_x: float, _y: float, _weapon_type: Types.WeaponType, audio: AudioBank) -> void:
	stats.kills += 1
	combo_count += 1
	combo_timer = 1.6  # PORT: web/src/tilt-to-live/ScoreManager.ts:95

	if combo_count > stats.best_combo:
		stats.best_combo = combo_count

	# Multiplier builds up: +1x every 8 kills in combo, up to 50x
	# PORT: web/src/tilt-to-live/ScoreManager.ts:102-108
	if combo_count % 8 == 0 and stats.multiplier < 50.0:
		stats.multiplier += 1.0
		if stats.multiplier > stats.max_multiplier:
			stats.max_multiplier = stats.multiplier
		# PORT: web/src/tilt-to-live/ScoreManager.ts:105-107 (add_floating_text "Nx MULTIPLIER!")
		# DIVERGENCE(HUD-FEEDBACK §3): callout moved to the HUD

	# Base score per kill = 10 * multiplier * modeMultiplier * progressionMultiplier
	# PORT: web/src/tilt-to-live/ScoreManager.ts:111
	var points: int = roundi(10.0 * stats.multiplier * mode_multiplier * progression_multiplier)
	stats.score += points

	# Play musical combo note. PORT: web/src/tilt-to-live/ScoreManager.ts:115
	audio.play_dot_pop(combo_count)

	# Combo callout milestones. PORT: web/src/tilt-to-live/ScoreManager.ts:118-131
	if combo_count == 3:
		# PORT: web/src/tilt-to-live/ScoreManager.ts:119 (add_floating_text "TRIPLE!")
		# DIVERGENCE(HUD-FEEDBACK §3): callout moved to the HUD
		pass
	elif combo_count == 6:
		# PORT: web/src/tilt-to-live/ScoreManager.ts:121 (add_floating_text "MULTI KILL!")
		# DIVERGENCE(HUD-FEEDBACK §3): callout moved to the HUD
		pass
	elif combo_count == 10:
		audio.play_milestone()
		# PORT: web/src/tilt-to-live/ScoreManager.ts:124 (add_floating_text "MEGA KILL!")
		# DIVERGENCE(HUD-FEEDBACK §3): callout moved to the HUD
	elif combo_count == 16:
		audio.play_milestone()
		# PORT: web/src/tilt-to-live/ScoreManager.ts:127 (add_floating_text "UNBELIEVABLE!")
		# DIVERGENCE(HUD-FEEDBACK §3): callout moved to the HUD
	elif combo_count == 25 or (combo_count > 25 and combo_count % 15 == 0):
		audio.play_milestone()
		# PORT: web/src/tilt-to-live/ScoreManager.ts:130 (add_floating_text "HOLY CRAP!")
		# DIVERGENCE(HUD-FEEDBACK §3): callout moved to the HUD


## Awards near-miss close call bonus. PORT: web/src/tilt-to-live/ScoreManager.ts:134-140
func register_close_call(x: float, y: float, audio: AudioBank) -> void:
	stats.close_calls += 1
	audio.play_close_call()
	# PORT: web/src/tilt-to-live/ScoreManager.ts:137
	var bonus: int = roundi(250.0 * stats.multiplier * mode_multiplier * progression_multiplier)
	stats.score += bonus
	# PORT: web/src/tilt-to-live/ScoreManager.ts:139
	add_floating_text("CLOSE CALL! +%d" % bonus, x, y - 15.0, Color("#3ddc97"), 17.0)


## Spawns floating popup text. PORT: web/src/tilt-to-live/ScoreManager.ts:142-154
func add_floating_text(text: String, x: float, y: float, color: Color, size: float = 18.0) -> void:
	var t: Types.FloatingText = Types.FloatingText.new()
	t.id = _next_text_id
	_next_text_id += 1
	t.text = text
	t.x = x
	t.y = y
	t.vy = -48.0  # PORT: web/src/tilt-to-live/ScoreManager.ts:148
	t.color = color
	t.size = size
	t.alpha = 1.0
	t.lifetime = 1.1  # PORT: web/src/tilt-to-live/ScoreManager.ts:152
	floating_texts.append(t)


## Finalizes end-of-run score and checks for new high score.
## PORT: web/src/tilt-to-live/ScoreManager.ts:156-170
func finalize_game() -> void:
	if stats.score > stats.best_score:
		best_score_diff = (stats.score - stats.best_score if stats.best_score > 0 else stats.score)
		is_new_best = true
		stats.best_score = stats.score
		_save_best_score()
	else:
		is_new_best = false
		best_score_diff = 0


## Loads best score from persistent storage. PORT: web/src/tilt-to-live/ScoreManager.ts:172-184
func load_best_score() -> void:
	_load_best_score()


func _save_best_score() -> void:
	# PORT-NOTE: ScoreManager.ts:161 stores the bare integer string under
	# 'tilt_to_live_best'; M2 chose the {"bestScore": n} object so every
	# user:// file is a JSON object. Shape unchanged here; the I/O moves to
	# SaveStore per spec §4.6.
	SaveStore.save_dict(BEST_SCORE_PATH, {"bestScore": stats.best_score})


func _load_best_score() -> void:
	var data: Dictionary = SaveStore.load_dict(BEST_SCORE_PATH)
	var parsed: int = SaveStore.read_int(data, "bestScore", 0)
	# PORT: web/src/tilt-to-live/ScoreManager.ts:177 (Number.isFinite && >= 0)
	stats.best_score = parsed if parsed >= 0 else 0
