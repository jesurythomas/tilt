## tuning.gd
## PORTS: web/src/tilt-to-live/WeaponTuning.ts (87 lines, source commit 7be9614)
class_name Tuning
extends RefCounted
## Single source of truth for weapon range/radius/duration constants, plus the
## global simulation speed. WeaponSystem must read get_tuned_value() rather
## than re-declaring its own literals, exactly as WeaponTuning.ts:5-9 requires.

## PORT: web/src/tilt-to-live/WeaponTuning.ts:17
enum TuningUnit { RANGE, SECONDS, PERCENT, COUNT }

# PORT-NOTE: GAME_SPEED is declared in TiltGame.ts:35, not WeaponTuning.ts.
# Spec §4.3 places it here explicitly, so this file carries two sources.
## Global simulation time scale applied only to the fixed-step gameplay delta.
const GAME_SPEED: float = 0.75  # PORT: web/src/tilt-to-live/TiltGame.ts:35

## Blackhole "Supernova Collapse" keystone shockwave radius.
const SUPERNOVA_SHOCKWAVE: float = 320.0  # PORT: web/src/tilt-to-live/WeaponTuning.ts:68

## Keystone perk prices, as ArmoryUI's weaponsCatalog displays them.
## PORT: web/src/tilt-to-live/WeaponTuning.ts:73-87
const KEYSTONE_COSTS: Dictionary[String, int] = {
	"crossBeam": 3500,
	"refractorLance": 4500,
	"falloutZone": 3000,
	"batteringRam": 3000,
	"overchargePulse": 4500,
	"plasmaArc": 3500,
	"superconductor": 4500,
	"shatterCascade": 2500,
	"cryoNova": 4000,
	"clusterSplit": 2500,
	"hyperThrusters": 4000,
	"supernovaCollapse": 5000,
	"chainReaction": 5000,
}

# PORT-NOTE: WeaponTuning.ts:26 types the table `Record<string, Record<string,
# TuningEntry>>`. GDScript does not accept a nested type argument, so the inner
# Dictionary is untyped in the declaration; every value is a TuningEntry.
# It is a `static var` rather than a `const` because TuningEntry.new() is not a
# constant expression.
# PORT-NOTE: named `weapon_tuning`, not `WEAPON_TUNING` as the TS export and the
# task plan spell it — CONVENTIONS §3 has no CONSTANT_CASE row for a static
# variable, only for `const`, and gdlint's class-variable-name check rejects
# CONSTANT_CASE here (verified live). snake_case is the compliant spelling.
## weapon → track → TuningEntry. PORT: web/src/tilt-to-live/WeaponTuning.ts:28-58
static var weapon_tuning: Dictionary[String, Dictionary] = {}


static func _static_init() -> void:
	weapon_tuning = {
		"blackhole":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:30
			"radius": TuningEntry.new(340.0, 18.0, 430.0, TuningUnit.RANGE),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:31
			"duration": TuningEntry.new(4.8, 0.5, 7.3, TuningUnit.SECONDS),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:32
			"gravity": TuningEntry.new(0.0, 20.0, 100.0, TuningUnit.PERCENT),
		},
		"nuke":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:35
			"radius": TuningEntry.new(360.0, 22.0, 470.0, TuningUnit.RANGE),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:36
			"speed": TuningEntry.new(0.0, 25.0, 75.0, TuningUnit.PERCENT),
		},
		"shield":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:39
			"duration": TuningEntry.new(6.0, 1.0, 11.0, TuningUnit.SECONDS),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:40
			"radius": TuningEntry.new(20.0, 2.0, 26.0, TuningUnit.RANGE),
		},
		"missiles":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:43
			"count": TuningEntry.new(8.0, 1.0, 13.0, TuningUnit.COUNT),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:44
			"blastRadius": TuningEntry.new(40.0, 6.0, 58.0, TuningUnit.RANGE),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:45
			"flightSpeed": TuningEntry.new(0.0, 20.0, 60.0, TuningUnit.PERCENT),
		},
		"laser":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:48
			"length": TuningEntry.new(260.0, 20.0, 360.0, TuningUnit.RANGE),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:49
			"duration": TuningEntry.new(1.8, 0.4, 3.0, TuningUnit.SECONDS),
		},
		"lightning":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:52
			"maxTargets": TuningEntry.new(14.0, 3.0, 29.0, TuningUnit.COUNT),
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:53
			"chainRange": TuningEntry.new(220.0, 22.0, 286.0, TuningUnit.RANGE),
		},
		"freeze":
		{
			# PORT: web/src/tilt-to-live/WeaponTuning.ts:56
			"duration": TuningEntry.new(4.5, 0.7, 8.2, TuningUnit.SECONDS),
		},
	}


## base + per_rank * rank for the given weapon/track pair. Returns 0 if unknown.
## PORT: web/src/tilt-to-live/WeaponTuning.ts:61-65
static func get_tuned_value(weapon: String, track: String, rank: int) -> float:
	if not weapon_tuning.has(weapon):
		return 0.0
	var tracks: Dictionary = weapon_tuning[weapon]
	if not tracks.has(track):
		return 0.0
	var entry: TuningEntry = tracks[track]
	return entry.base + entry.per_rank * rank


## PORT: web/src/tilt-to-live/WeaponTuning.ts:19-24
class TuningEntry:
	extends RefCounted
	var base: float = 0.0
	var per_rank: float = 0.0
	var max: float = 0.0
	var unit: TuningUnit = TuningUnit.RANGE

	func _init(p_base: float, p_per_rank: float, p_max: float, p_unit: TuningUnit) -> void:
		base = p_base
		per_rank = p_per_rank
		max = p_max
		unit = p_unit
