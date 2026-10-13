## ad_pacing.gd
## PORTS: nothing — new file (rulings ADS R2, R5, docs/superpowers/plans/2026-10-13-in-game-ads.md)
class_name AdPacing
extends RefCounted
## Whether the ad break may show an interstitial: after a random 5-10 games or 5 minutes of
## play, whichever comes first, and never right after a very short run (MVP R1). Numbers in,
## yes or no out; `Ads` owns one and saves it, so the count carries across launches.

# DIVERGENCE(ADS R5): user 2026-10-14, "after every 5-10 games at random or total ingame time
# e.g. actually playing a mode". Replaces ADS R2's 3 runs and 3 wall-clock minutes.
## A run shorter than this (seconds) never earns an ad; the ad waits for a longer one.
const MIN_RUN_SECONDS: float = 20.0
## The fewest games between two ads; each gap is drawn at random up to MAX_GAMES_PER_AD.
const MIN_GAMES_PER_AD: int = 5
## The most games between two ads.
const MAX_GAMES_PER_AD: int = 10
## Seconds of play (run time, not menus) that make an ad due before the game count does.
const PLAY_SECONDS_PER_AD: float = 300.0

## Games ended since the last ad opened (or ever, before the first).
var games_since_ad: int = 0
## Seconds played in those games.
var play_seconds_since_ad: float = 0.0
## Games this gap needs, drawn from MIN_GAMES_PER_AD..MAX_GAMES_PER_AD.
var games_per_ad: int = MIN_GAMES_PER_AD

var _rng: RandomNumberGenerator = null
var _last_run_seconds: float = 0.0
## True until a run ends: no break before any run, and none after the player's first ever.
var _was_last_run_first: bool = true


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng
	_draw_gap()


## A run ended after `seconds`; `was_first_run` marks the player's very first run.
func note_run_end(seconds: float, was_first_run: bool) -> void:
	games_since_ad += 1
	play_seconds_since_ad += seconds
	_last_run_seconds = seconds
	_was_last_run_first = was_first_run


## True when the run that just ended may be followed by an ad.
func is_due() -> bool:
	if _was_last_run_first or _last_run_seconds < MIN_RUN_SECONDS:
		return false
	return games_since_ad >= games_per_ad or play_seconds_since_ad >= PLAY_SECONDS_PER_AD


## An ad opened: both counts start over and the next gap is drawn.
func note_ad_shown() -> void:
	games_since_ad = 0
	play_seconds_since_ad = 0.0
	_draw_gap()


## The counts to save.
func to_dict() -> Dictionary:
	return {
		"games_since_ad": games_since_ad,
		"play_seconds_since_ad": play_seconds_since_ad,
		"games_per_ad": games_per_ad,
	}


## Takes the saved counts; anything missing or out of range keeps its fresh value.
func load_dict(d: Dictionary) -> void:
	games_since_ad = maxi(SaveStore.read_int(d, "games_since_ad", 0), 0)
	play_seconds_since_ad = maxf(SaveStore.read_float(d, "play_seconds_since_ad", 0.0), 0.0)
	var gap: int = SaveStore.read_int(d, "games_per_ad", games_per_ad)
	if gap >= MIN_GAMES_PER_AD and gap <= MAX_GAMES_PER_AD:
		games_per_ad = gap


func _draw_gap() -> void:
	games_per_ad = _rng.randi_range(MIN_GAMES_PER_AD, MAX_GAMES_PER_AD)
