## game_options.gd
## PORTS: web/src/tilt-to-live/GameOptions.ts (137 lines, source commit 7be9614)
class_name GameOptionsManager
extends RefCounted
## Mode selection, audio, controls and visual settings, persisted as
## user://tilt_to_live_settings_v1.json.
##
## PORT-NOTE: the class is GameOptionsManager (GameOptions.ts:34) and the file
## is game_options.gd (spec §4.2) — the TS file and class names differ too.
##
## PORT-NOTE: three string unions (:5, :21, :26) become enums; the three
## *_IDS tables carry the TS strings so the save keeps the web shape
## (spec §4.6). Types.GameMode and Types.ControlScheme already exist as
## cited ports of :5 and :21; ScreenShake is declared here.
##
## PORT-NOTE: controlScheme is persisted for shape fidelity only. The live
## scheme is ControlSettings.scheme (M2.5 spec §4.2, a DIVERGENCE), which
## input_router.gd reads; nothing reads settings.control_scheme yet.

## PORT: web/src/tilt-to-live/GameOptions.ts:26
enum ScreenShake { OFF, LOW, NORMAL, EXTREME, FULL }

## PORT: web/src/tilt-to-live/GameOptions.ts:32
const STORAGE_KEY: String = "tilt_to_live_settings_v1"
## The localStorage key as a user:// file (spec §4.6).
const SAVE_PATH: String = "user://" + STORAGE_KEY + ".json"

## The TS GameMode strings. PORT: web/src/tilt-to-live/GameOptions.ts:5
const MODE_IDS: Dictionary[Types.GameMode, String] = {
	Types.GameMode.CLASSIC: "classic",
	Types.GameMode.CODE_RED: "code-red",
	Types.GameMode.GAUNTLET: "gauntlet",
}
## The TS controlScheme strings. PORT: web/src/tilt-to-live/GameOptions.ts:21
const CONTROL_SCHEME_IDS: Dictionary[Types.ControlScheme, String] = {
	Types.ControlScheme.HYBRID: "hybrid",
	Types.ControlScheme.MOUSE: "mouse",
	Types.ControlScheme.KEYBOARD: "keyboard",
	Types.ControlScheme.GYRO: "gyro",
}
## The TS screenShake strings. PORT: web/src/tilt-to-live/GameOptions.ts:26
const SCREEN_SHAKE_IDS: Dictionary[ScreenShake, String] = {
	ScreenShake.OFF: "off",
	ScreenShake.LOW: "low",
	ScreenShake.NORMAL: "normal",
	ScreenShake.EXTREME: "extreme",
	ScreenShake.FULL: "full",
}

## The live settings. PORT: web/src/tilt-to-live/GameOptions.ts:35
var settings: GameSettings = null
## The three modes, in catalog order. PORT: web/src/tilt-to-live/GameOptions.ts:37-71
var modes: Array[ModeConfig] = []


## PORT: web/src/tilt-to-live/GameOptions.ts:73-75
func _init() -> void:
	modes = _build_modes()
	settings = load_settings()


## PORT: web/src/tilt-to-live/GameOptions.ts:92-105
# PORT-NOTE: the try/catch (:102-104) is SaveStore's quarantine; {} is the
# `!raw` branch (:95). `showGridlines: parsed.showGridlines === true` (:100)
# is what read_bool already does — a non-bool never becomes true.
func load_settings() -> GameSettings:
	var def: GameSettings = _get_default_settings()
	var raw: Dictionary = SaveStore.load_dict(SAVE_PATH)
	if raw.is_empty():
		return def
	def.from_dict(raw)
	return def


## PORT: web/src/tilt-to-live/GameOptions.ts:107-111
func save() -> void:
	SaveStore.save_dict(SAVE_PATH, settings.to_dict())


## PORT: web/src/tilt-to-live/GameOptions.ts:113-115
# PORT-NOTE: the TS defaults `mode` to this.settings.mode; callers pass
# settings.mode explicitly here (TiltGame.ts:1549, :1931 do so already).
func get_mode_config(mode: Types.GameMode) -> ModeConfig:
	for config: ModeConfig in modes:
		if config.id == mode:
			return config
	return modes[0]


## PORT: web/src/tilt-to-live/GameOptions.ts:117-120
func set_mode(mode: Types.GameMode) -> void:
	settings.mode = mode
	save()


## PORT: web/src/tilt-to-live/GameOptions.ts:122-136
func get_shake_multiplier() -> float:
	match settings.screen_shake:
		ScreenShake.OFF:
			return 0.0
		ScreenShake.LOW:
			return 0.5  # PORT: :127
		ScreenShake.NORMAL, ScreenShake.FULL:
			return 1.0
		ScreenShake.EXTREME:
			return 1.8  # PORT: :132
		_:
			return 1.0


## PORT: web/src/tilt-to-live/GameOptions.ts:77-90
func _get_default_settings() -> GameSettings:
	var s: GameSettings = GameSettings.new()
	s.mode = Types.GameMode.CLASSIC
	s.control_scheme = Types.ControlScheme.HYBRID
	s.sfx_enabled = true
	s.sfx_volume = 0.8  # PORT: :82
	s.music_enabled = true
	s.music_volume = 0.7  # PORT: :84
	s.screen_shake = ScreenShake.NORMAL
	s.tether_line = true
	s.high_contrast_halo = true
	s.show_gridlines = false
	return s


# PORT: web/src/tilt-to-live/GameOptions.ts:37-71
func _build_modes() -> Array[ModeConfig]:
	var out: Array[ModeConfig] = []

	# PORT: web/src/tilt-to-live/GameOptions.ts:38-48
	var classic: ModeConfig = ModeConfig.new()
	classic.id = Types.GameMode.CLASSIC
	classic.name = "Standard"
	classic.badge = "1.0×"
	classic.tagline = "The full arsenal, ramping swarms."
	classic.description = "The full arsenal, ramping swarms."
	classic.color = Color("#5B8CFF")
	classic.accent = Color("#8FB0FF")
	classic.glow = Color(91.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0, 0.35)
	classic.score_multiplier = 1.0
	out.append(classic)

	# PORT: web/src/tilt-to-live/GameOptions.ts:49-59
	var gauntlet: ModeConfig = ModeConfig.new()
	gauntlet.id = Types.GameMode.GAUNTLET
	gauntlet.name = "Gauntlet"
	gauntlet.badge = "1.25×"
	gauntlet.tagline = "Walls close in while you dodge."
	gauntlet.description = "Walls close in while you dodge."
	gauntlet.color = Color("#FFB14D")
	gauntlet.accent = Color("#FFD277")
	gauntlet.glow = Color(255.0 / 255.0, 177.0 / 255.0, 77.0 / 255.0, 0.35)
	gauntlet.score_multiplier = 1.25
	out.append(gauntlet)

	# PORT: web/src/tilt-to-live/GameOptions.ts:60-70
	var code_red: ModeConfig = ModeConfig.new()
	code_red.id = Types.GameMode.CODE_RED
	code_red.name = "Code Red"
	code_red.badge = "1.5×"
	code_red.tagline = "Double density from the first second."
	code_red.description = "Double density from the first second."
	code_red.color = Color("#A78BFA")
	code_red.accent = Color("#C4B5FD")
	code_red.glow = Color(167.0 / 255.0, 139.0 / 255.0, 250.0 / 255.0, 0.35)
	code_red.score_multiplier = 1.5
	out.append(code_red)

	return out


## PORT: web/src/tilt-to-live/GameOptions.ts:7-17
class ModeConfig:
	extends RefCounted
	var id: Types.GameMode = Types.GameMode.CLASSIC
	var name: String = ""
	var badge: String = ""
	var tagline: String = ""
	var description: String = ""
	var color: Color = Color.WHITE
	var accent: Color = Color.WHITE
	var glow: Color = Color.WHITE
	var score_multiplier: float = 1.0


## PORT: web/src/tilt-to-live/GameOptions.ts:19-30
class GameSettings:
	extends RefCounted
	var mode: Types.GameMode = Types.GameMode.CLASSIC
	var control_scheme: Types.ControlScheme = Types.ControlScheme.HYBRID
	var sfx_enabled: bool = true
	## 0..1. PORT: web/src/tilt-to-live/GameOptions.ts:23
	var sfx_volume: float = 1.0
	var music_enabled: bool = true
	## 0..1. PORT: web/src/tilt-to-live/GameOptions.ts:25
	var music_volume: float = 1.0
	var screen_shake: ScreenShake = ScreenShake.NORMAL
	var tether_line: bool = true
	var high_contrast_halo: bool = true
	var show_gridlines: bool = false

	## JSON.stringify(this.settings) (GameOptions.ts:109), TS keys and strings.
	func to_dict() -> Dictionary:
		return {
			"mode": MODE_IDS[mode],
			"controlScheme": CONTROL_SCHEME_IDS[control_scheme],
			"sfxEnabled": sfx_enabled,
			"sfxVolume": sfx_volume,
			"musicEnabled": music_enabled,
			"musicVolume": music_volume,
			"screenShake": SCREEN_SHAKE_IDS[screen_shake],
			"tetherLine": tether_line,
			"highContrastHalo": high_contrast_halo,
			"showGridlines": show_gridlines,
		}

	## `{...defaults, ...parsed}` (GameOptions.ts:97-101). An unknown string
	## for an enum field keeps the current value.
	func from_dict(d: Dictionary) -> void:
		var mode_id: String = SaveStore.read_string(d, "mode", MODE_IDS[mode])
		if MODE_IDS.values().has(mode_id):
			mode = MODE_IDS.find_key(mode_id)
		var scheme_id: String = SaveStore.read_string(
			d, "controlScheme", CONTROL_SCHEME_IDS[control_scheme]
		)
		if CONTROL_SCHEME_IDS.values().has(scheme_id):
			control_scheme = CONTROL_SCHEME_IDS.find_key(scheme_id)
		sfx_enabled = SaveStore.read_bool(d, "sfxEnabled", sfx_enabled)
		sfx_volume = SaveStore.read_float(d, "sfxVolume", sfx_volume)
		music_enabled = SaveStore.read_bool(d, "musicEnabled", music_enabled)
		music_volume = SaveStore.read_float(d, "musicVolume", music_volume)
		var shake_id: String = SaveStore.read_string(
			d, "screenShake", SCREEN_SHAKE_IDS[screen_shake]
		)
		if SCREEN_SHAKE_IDS.values().has(shake_id):
			screen_shake = SCREEN_SHAKE_IDS.find_key(shake_id)
		tether_line = SaveStore.read_bool(d, "tetherLine", tether_line)
		high_contrast_halo = SaveStore.read_bool(d, "highContrastHalo", high_contrast_halo)
		show_gridlines = SaveStore.read_bool(d, "showGridlines", show_gridlines)  # PORT: :100
