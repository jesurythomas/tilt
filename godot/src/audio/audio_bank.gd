# gdlint:ignore=max-public-methods
## audio_bank.gd
## PORTS: web/src/tilt-to-live/TiltAudio.ts (887 lines, source commit 7be9614)
# PORT-NOTE: TiltAudio.ts has 28 public audio methods. Law 3 requires faithfully
# porting all public methods, which exceeds gdlint's default max-public-methods (20).
class_name AudioBank
extends RefCounted
## Audio playback engine. In Module 2, operates as a silent null-object stub
## per spec §8 M2; real baked audio and playback land in Module 5.
##
## PORT-NOTE: silent null-object stub for M2. ScoreManager and WeaponSystem take
## an audio instance parameter in the TypeScript, so the full public method
## surface of TiltAudio.ts exists here from M2 onward. Every method logs at DEBUG
## level and returns cleanly.

var _muted: bool = false


## Unlocks the audio context. PORT: web/src/tilt-to-live/TiltAudio.ts:29-49
func unlock() -> void:
	Log.debug("AudioBank.unlock()")


## Toggles mute state. PORT: web/src/tilt-to-live/TiltAudio.ts:51-57
func toggle_mute() -> bool:
	_muted = not _muted
	Log.debug("AudioBank.toggle_mute() -> %s" % _muted)
	return not _muted


## Sets the muted state. PORT: web/src/tilt-to-live/TiltAudio.ts:59-64
func set_muted(muted: bool) -> void:
	_muted = muted
	Log.debug("AudioBank.set_muted(%s)" % muted)


## Sets sound effects volume. PORT: web/src/tilt-to-live/TiltAudio.ts:66-70
func set_sfx_volume(vol: float) -> void:
	Log.debug("AudioBank.set_sfx_volume(%f)" % vol)


## Sets background music volume. PORT: web/src/tilt-to-live/TiltAudio.ts:72-76
func set_music_volume(vol: float) -> void:
	Log.debug("AudioBank.set_music_volume(%f)" % vol)


## Reports whether audio is muted. PORT: web/src/tilt-to-live/TiltAudio.ts:78-80
func is_muted() -> bool:
	return _muted


## Starts the background music sequencer. PORT: web/src/tilt-to-live/TiltAudio.ts:84-95
func start_music() -> void:
	Log.debug("AudioBank.start_music()")


## Stops the background music sequencer. PORT: web/src/tilt-to-live/TiltAudio.ts:97-104
func stop_music() -> void:
	Log.debug("AudioBank.stop_music()")


## Plays the orb pickup sound. PORT: web/src/tilt-to-live/TiltAudio.ts:483-503
func play_orb_pickup() -> void:
	Log.debug("AudioBank.play_orb_pickup()")


## Plays the coin pickup sound. PORT: web/src/tilt-to-live/TiltAudio.ts:505-531
func play_coin_pickup() -> void:
	Log.debug("AudioBank.play_coin_pickup()")


## Plays the nuke detonation sound. PORT: web/src/tilt-to-live/TiltAudio.ts:533-551
func play_nuke() -> void:
	Log.debug("AudioBank.play_nuke()")


## Plays the missile launch sound. PORT: web/src/tilt-to-live/TiltAudio.ts:553-570
func play_missile_launch() -> void:
	Log.debug("AudioBank.play_missile_launch()")


## Plays the missile explosion sound. PORT: web/src/tilt-to-live/TiltAudio.ts:572-589
func play_missile_explode() -> void:
	Log.debug("AudioBank.play_missile_explode()")


## Plays the laser beam sound. PORT: web/src/tilt-to-live/TiltAudio.ts:591-608
func play_laser_beam() -> void:
	Log.debug("AudioBank.play_laser_beam()")


## Plays the lightning arc sound. PORT: web/src/tilt-to-live/TiltAudio.ts:610-627
func play_lightning() -> void:
	Log.debug("AudioBank.play_lightning()")


## Plays the freeze burst sound. PORT: web/src/tilt-to-live/TiltAudio.ts:629-646
func play_freeze() -> void:
	Log.debug("AudioBank.play_freeze()")


## Plays the ice shatter sound. PORT: web/src/tilt-to-live/TiltAudio.ts:648-665
func play_ice_shatter() -> void:
	Log.debug("AudioBank.play_ice_shatter()")


## Plays the shield warning siren sound. PORT: web/src/tilt-to-live/TiltAudio.ts:667-685
func play_siren() -> void:
	Log.debug("AudioBank.play_siren()")


## Plays the ice cascade sound. PORT: web/src/tilt-to-live/TiltAudio.ts:687-707
func play_ice_cascade() -> void:
	Log.debug("AudioBank.play_ice_cascade()")


## Plays the gauntlet warning klaxon. PORT: web/src/tilt-to-live/TiltAudio.ts:709-727
func play_gauntlet_klaxon() -> void:
	Log.debug("AudioBank.play_gauntlet_klaxon()")


## Plays the vortex singularity sound. PORT: web/src/tilt-to-live/TiltAudio.ts:729-746
func play_vortex() -> void:
	Log.debug("AudioBank.play_vortex()")


## Plays the pentatonic combo dot pop sound. PORT: web/src/tilt-to-live/TiltAudio.ts:748-765
func play_dot_pop(combo_index: int = 0) -> void:
	Log.debug("AudioBank.play_dot_pop(%d)" % combo_index)


## Plays the combo milestone chime. PORT: web/src/tilt-to-live/TiltAudio.ts:767-785
func play_milestone() -> void:
	Log.debug("AudioBank.play_milestone()")


## Plays the player death crash sound. PORT: web/src/tilt-to-live/TiltAudio.ts:787-804
func play_player_death() -> void:
	Log.debug("AudioBank.play_player_death()")


## Plays the close call near-miss sound. PORT: web/src/tilt-to-live/TiltAudio.ts:806-824
func play_close_call() -> void:
	Log.debug("AudioBank.play_close_call()")


## Plays a space invader formation march step. PORT: web/src/tilt-to-live/TiltAudio.ts:826-845
func play_space_invader_step(step: int) -> void:
	Log.debug("AudioBank.play_space_invader_step(%d)" % step)


## Plays the enemy warp in sound. PORT: web/src/tilt-to-live/TiltAudio.ts:847-865
func play_warp_in() -> void:
	Log.debug("AudioBank.play_warp_in()")


## Plays the invasion alarm klaxon. PORT: web/src/tilt-to-live/TiltAudio.ts:867-885
func play_invasion_alarm() -> void:
	Log.debug("AudioBank.play_invasion_alarm()")
