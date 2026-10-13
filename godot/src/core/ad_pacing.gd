## ad_pacing.gd
## PORTS: nothing — new file (ruling ADS R2, docs/superpowers/plans/2026-10-13-in-game-ads.md)
class_name AdPacing
extends RefCounted
## Whether the ad break may show an interstitial (MVP R1: "not after very short runs; at most
## one per 2–3 deaths"). Numbers in, yes or no out; `Ads` owns one and the clock.

# DIVERGENCE(ADS R2): new pacing, my calls under MVP R1; retune from AdMob's session data.
## A run shorter than this (seconds) never earns an ad.
const MIN_RUN_SECONDS: float = 20.0
## Runs that must end between two ads, and from launch to the first.
const RUNS_PER_AD: int = 3
## Seconds that must pass between two ads, and from launch to the first.
const MIN_SECONDS_BETWEEN_ADS: float = 180.0

## Runs ended since the last ad opened, or since launch.
var runs_since_ad: int = 0
## When the last ad opened, or the session began, on the `Ads` clock (seconds).
var last_ad_at: float = 0.0

var _last_run_seconds: float = 0.0
## True until a run ends: no break before any run, and none after the player's first ever.
var _was_last_run_first: bool = true


func _init(now: float) -> void:
	last_ad_at = now


## A run ended after `seconds`; `was_first_run` marks the player's very first run.
func note_run_end(seconds: float, was_first_run: bool) -> void:
	runs_since_ad += 1
	_last_run_seconds = seconds
	_was_last_run_first = was_first_run


## True when the run that just ended may be followed by an ad at `now`.
func is_due(now: float) -> bool:
	return (
		not _was_last_run_first
		and _last_run_seconds >= MIN_RUN_SECONDS
		and runs_since_ad >= RUNS_PER_AD
		and now - last_ad_at >= MIN_SECONDS_BETWEEN_ADS
	)


## An ad opened at `now`: both counts start over.
func note_ad_shown(now: float) -> void:
	runs_since_ad = 0
	last_ad_at = now
