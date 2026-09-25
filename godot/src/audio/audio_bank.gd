# gdlint:ignore=max-public-methods
## audio_bank.gd
## PORTS: web/src/tilt-to-live/TiltAudio.ts (887 lines, source commit 7be9614)
# PORT-NOTE: TiltAudio.ts has 28 public audio methods. Law 3 requires faithfully
# porting all public methods, which exceeds gdlint's default max-public-methods (20).
class_name AudioBank
extends RefCounted
## Sound effects played from the files tools/bake-audio/bake_sfx.mjs renders out
## of TiltAudio.ts (spec D5, §8 M5), and the music loop tools/bake-audio/
## bake_music.mjs renders from its scheduler (spec §8 M6, M6 R1).
##
## Instantiated by GameRoot, which attaches it to the scene tree; the sim systems
## receive it as a parameter, as the TS passes its TiltAudio. An unattached bank
## (every sim spec) plays nothing. Never an autoload (spec §5.2).
##
## PORT-NOTE: each file is its play* method rendered through the TS gain graph,
## so it already carries sfxGain 1.0 and masterGain 0.28 (TiltAudio.ts:35, :39).
## Playback applies only what the TS changes at run time: the sfx gain and the
## master mute (M5 R4). The music loop carries musicGain 0.35 and masterGain 0.28
## the same way (M6 R4).

## Where the bake writes (spec §4.2; WAV per M5 R1).
const SFX_DIR: String = "res://assets/audio/sfx/"
## Where the music bake writes (M6 R1).
const MUSIC_PATH: String = "res://assets/audio/music/music_loop.wav"
## One dot_pop file per pentatonic note. PORT: web/src/tilt-to-live/TiltAudio.ts:23-27
const DOT_POP_NOTES: int = 15
## One file per march note. PORT: web/src/tilt-to-live/TiltAudio.ts:829
const INVADER_STEPS: int = 4
## playLightning's start frequency is 1200 + random() * 400.
const LIGHTNING_BASE_HZ: float = 1200.0  # PORT: web/src/tilt-to-live/TiltAudio.ts:617
const LIGHTNING_SPREAD_HZ: float = 400.0  # PORT: web/src/tilt-to-live/TiltAudio.ts:617
## The bake pins random() to 0.5, so lightning.wav starts at 1400 Hz (M5 R6).
const LIGHTNING_BAKED_HZ: float = LIGHTNING_BASE_HZ + 0.5 * LIGHTNING_SPREAD_HZ  # M5 R6
## The music bus gain at full volume. PORT: web/src/tilt-to-live/TiltAudio.ts:43, :74
const MUSIC_GAIN: float = 0.35
## Simultaneous SFX voices; a voice past the cap is dropped.
const POLYPHONY: int = 32  # DIVERGENCE(M5 R2): Web Audio overlaps without limit
## Every baked file, in bake order (tools/bake-audio/bake_sfx.mjs).
const SFX_STEMS: Array[String] = [
	"orb_pickup",
	"coin_pickup",
	"nuke",
	"missile_launch",
	"missile_explode",
	"laser_beam",
	"lightning",
	"freeze",
	"ice_shatter",
	"siren",
	"ice_cascade",
	"gauntlet_klaxon",
	"vortex",
	"dot_pop_00",
	"dot_pop_01",
	"dot_pop_02",
	"dot_pop_03",
	"dot_pop_04",
	"dot_pop_05",
	"dot_pop_06",
	"dot_pop_07",
	"dot_pop_08",
	"dot_pop_09",
	"dot_pop_10",
	"dot_pop_11",
	"dot_pop_12",
	"dot_pop_13",
	"dot_pop_14",
	"milestone",
	"player_death",
	"close_call",
	"space_invader_step_0",
	"space_invader_step_1",
	"space_invader_step_2",
	"space_invader_step_3",
	"warp_in",
	"invasion_alarm",
]

## The music gain; the player plays at music_gain / MUSIC_GAIN (M6 R4).
## PORT: web/src/tilt-to-live/TiltAudio.ts:43
var music_gain: float = MUSIC_GAIN

var _muted: bool = false
var _is_music_playing: bool = false  # PORT: web/src/tilt-to-live/TiltAudio.ts:13
var _sfx_volume: float = 1.0  # PORT: web/src/tilt-to-live/TiltAudio.ts:39
var _streams: Dictionary[String, AudioStream] = {}
var _player: AudioStreamPlayer = null
var _playback: AudioStreamPlaybackPolyphonic = null
var _music_stream: AudioStream = null
var _music_player: AudioStreamPlayer = null


## Hangs the SFX and music players on `host` and loads every baked file. A missing file
## logs a warning and plays silence (spec §6.4). `host` must be in the tree.
## PORT-NOTE: stands in for unlock()'s context and gain creation
## (TiltAudio.ts:30-45); Godot needs a node in the tree, not a user gesture (M5 R10).
func attach(host: Node, sfx_dir: String = SFX_DIR, music_path: String = MUSIC_PATH) -> void:
	for stem: String in SFX_STEMS:
		var path: String = sfx_dir + stem + ".wav"
		if ResourceLoader.exists(path):
			_streams[stem] = load(path) as AudioStream
		else:
			Log.warn("AudioBank: missing baked sfx %s; it plays silence" % path)
	var polyphonic: AudioStreamPolyphonic = AudioStreamPolyphonic.new()
	polyphonic.polyphony = POLYPHONY
	_player = AudioStreamPlayer.new()
	_player.stream = polyphonic
	host.add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if ResourceLoader.exists(music_path):
		_music_stream = load(music_path) as AudioStream
	else:
		Log.warn("AudioBank: missing baked music %s; it plays silence" % music_path)
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = _music_stream
	host.add_child(_music_player)
	_apply_volume()


## Unlocks the audio context. PORT: web/src/tilt-to-live/TiltAudio.ts:29-49
# PORT-NOTE: attach() builds what unlock() creates; Godot has no suspended
# context to resume (:46-48), so the call site is kept and the body is empty.
func unlock() -> void:
	pass


## Toggles mute state. PORT: web/src/tilt-to-live/TiltAudio.ts:51-57
func toggle_mute() -> bool:
	_muted = not _muted
	_apply_volume()
	return not _muted


## Sets the muted state. PORT: web/src/tilt-to-live/TiltAudio.ts:59-64
func set_muted(muted: bool) -> void:
	_muted = muted
	_apply_volume()


## Sets sound effects volume. PORT: web/src/tilt-to-live/TiltAudio.ts:66-70
func set_sfx_volume(vol: float) -> void:
	_sfx_volume = clampf(vol, 0.0, 1.0)
	_apply_volume()


## Sets background music volume. PORT: web/src/tilt-to-live/TiltAudio.ts:72-76
func set_music_volume(vol: float) -> void:
	music_gain = clampf(vol, 0.0, 1.0) * MUSIC_GAIN
	_apply_volume()


## Reports whether audio is muted. PORT: web/src/tilt-to-live/TiltAudio.ts:78-80
func is_muted() -> bool:
	return _muted


## Starts the background music. PORT: web/src/tilt-to-live/TiltAudio.ts:84-95
# PORT-NOTE: the TS calls unlock() first (:85); attach() did its work (M5 R10) and
# unlock() is a no-op, so it is not called here (M6 R5). currentStep = 0 (:88) is
# the loop's first frame.
# DIVERGENCE(M6 R8): the TS waits 50 ms before step 0 (:89) and its first cycle has
# no bar-15 tails at its head; the loop starts at once, tails included.
func start_music() -> void:
	if _is_music_playing:
		return
	_is_music_playing = true
	if _music_player != null and _music_stream != null:
		_music_player.play(0.0)


## Stops the background music. PORT: web/src/tilt-to-live/TiltAudio.ts:97-103
# DIVERGENCE(M6 R8): notes the TS already scheduled (up to scheduleAheadSec, :20)
# still sound after clearInterval; stop() cuts the loop at once.
func stop_music() -> void:
	_is_music_playing = false
	if _music_player != null:
		_music_player.stop()


# PORT-NOTE: scheduler, getNoiseBuffer, scheduleStep, scheduleDrums, triggerKick,
# triggerSnare, triggerHiHat, triggerCrash, scheduleBassLine, scheduleArpeggio,
# scheduleLeadMelody and schedulePadChord (TiltAudio.ts:105-479), with the fields
# currentStep..scheduleAheadSec (:14-20), run inside tools/bake-audio/bake_music.mjs;
# their output is music_loop.wav, so they have no GDScript counterpart (M6 R1).


## Plays the orb pickup sound. PORT: web/src/tilt-to-live/TiltAudio.ts:483-500
func play_orb_pickup() -> void:
	_play("orb_pickup")


## Plays the coin pickup sound. PORT: web/src/tilt-to-live/TiltAudio.ts:505-531
func play_coin_pickup() -> void:
	_play("coin_pickup")


## Plays the nuke detonation sound. PORT: web/src/tilt-to-live/TiltAudio.ts:533-551
func play_nuke() -> void:
	_play("nuke")


## Plays the missile launch sound. PORT: web/src/tilt-to-live/TiltAudio.ts:553-570
func play_missile_launch() -> void:
	_play("missile_launch")


## Plays the missile explosion sound. PORT: web/src/tilt-to-live/TiltAudio.ts:572-589
func play_missile_explode() -> void:
	_play("missile_explode")


## Plays the laser beam sound. PORT: web/src/tilt-to-live/TiltAudio.ts:591-608
func play_laser_beam() -> void:
	_play("laser_beam")


## Plays the lightning arc sound. PORT: web/src/tilt-to-live/TiltAudio.ts:610-627
# PORT-NOTE: the TS draws a fresh start frequency per call (:617). The bake
# pins it at 1400 Hz and pitch_scale restores the spread, which also scales the
# 200 Hz end and the sweep's length: close, not identical (spec §9, M5 R6).
func play_lightning() -> void:
	var start_hz: float = LIGHTNING_BASE_HZ + randf() * LIGHTNING_SPREAD_HZ
	_play("lightning", start_hz / LIGHTNING_BAKED_HZ)


## Plays the freeze burst sound. PORT: web/src/tilt-to-live/TiltAudio.ts:629-646
func play_freeze() -> void:
	_play("freeze")


## Plays the ice shatter sound. PORT: web/src/tilt-to-live/TiltAudio.ts:648-665
func play_ice_shatter() -> void:
	_play("ice_shatter")


## Plays the life-lost siren. PORT: web/src/tilt-to-live/TiltAudio.ts:667-685
func play_siren() -> void:
	_play("siren")


## Plays the ice cascade sound. PORT: web/src/tilt-to-live/TiltAudio.ts:687-707
# PORT-NOTE: no caller in web/src outside the menu's no-op audio stub
# (TiltGame.ts:1803); baked and playable, not called (M5 R8).
func play_ice_cascade() -> void:
	_play("ice_cascade")


## Plays the gauntlet warning klaxon. PORT: web/src/tilt-to-live/TiltAudio.ts:709-727
# PORT-NOTE: uncalled in web/src (M10 R11, M5 R8).
func play_gauntlet_klaxon() -> void:
	_play("gauntlet_klaxon")


## Plays the vortex singularity sound. PORT: web/src/tilt-to-live/TiltAudio.ts:729-746
func play_vortex() -> void:
	_play("vortex")


## Plays the pentatonic combo note. PORT: web/src/tilt-to-live/TiltAudio.ts:748-765
func play_dot_pop(combo_index: int = 0) -> void:
	_play("dot_pop_%02d" % (combo_index % DOT_POP_NOTES))  # PORT: :754


## Plays the combo milestone chime. PORT: web/src/tilt-to-live/TiltAudio.ts:767-785
func play_milestone() -> void:
	_play("milestone")


## Plays the player death crash sound. PORT: web/src/tilt-to-live/TiltAudio.ts:787-804
func play_player_death() -> void:
	_play("player_death")


## Plays the close call near-miss sound. PORT: web/src/tilt-to-live/TiltAudio.ts:806-823
func play_close_call() -> void:
	_play("close_call")


## Plays one march step. PORT: web/src/tilt-to-live/TiltAudio.ts:826-845
# PORT-NOTE: referenced only by the menu's no-op audio stub (TiltGame.ts:1801);
# baked and playable, not called (M5 R8).
func play_space_invader_step(step: int) -> void:
	_play("space_invader_step_%d" % (step % INVADER_STEPS))  # PORT: :830


## Plays the warp-in sound. PORT: web/src/tilt-to-live/TiltAudio.ts:847-865
# PORT-NOTE: its caller is the entrance cinematic (TiltEntranceCinematic.ts:74),
# which is M11b (M5 R8).
func play_warp_in() -> void:
	_play("warp_in")


## Plays the invasion alarm. PORT: web/src/tilt-to-live/TiltAudio.ts:867-885
# PORT-NOTE: no reference in web/src (M5 R8).
func play_invasion_alarm() -> void:
	_play("invasion_alarm")


## Plays one baked file. Returns its voice id, or INVALID_ID when the bank is
## unattached or muted, the file is missing, or every voice is busy (M5 R2).
## PORT: web/src/tilt-to-live/TiltAudio.ts:484 (the guard every play* opens with)
func _play(stem: String, pitch_scale: float = 1.0) -> int:
	if _playback == null or _muted:
		return AudioStreamPlaybackPolyphonic.INVALID_ID
	if not _streams.has(stem):
		return AudioStreamPlaybackPolyphonic.INVALID_ID
	var stream: AudioStream = _streams[stem]
	return _playback.play_stream(stream, 0.0, 0.0, pitch_scale)


## masterGain is 0 while muted (TiltAudio.ts:54, :62); otherwise the sfx gain, and
## for music its gain relative to the baked MUSIC_GAIN (M6 R4).
func _apply_volume() -> void:
	if _player != null:
		_player.volume_linear = 0.0 if _muted else _sfx_volume
	if _music_player != null:
		# DIVERGENCE(M6 R6): the TS scheduler skips steps while muted (:106) and bursts
		# the backlog on unmute; the loop plays on at volume 0 instead.
		_music_player.volume_linear = 0.0 if _muted else music_gain / MUSIC_GAIN
