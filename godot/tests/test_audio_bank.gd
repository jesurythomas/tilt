# gdlint:disable=max-public-methods
## test_audio_bank.gd
## PORTS: nothing — covers src/audio/audio_bank.gd (spec §8 M5, §6.4)
extends GutTest
## Proves the baked files exist, each play_* asks for its file, and the bank's
## mute, volume, voice cap and missing-file behaviour.

## One 16th note. PORT: web/src/tilt-to-live/TiltAudio.ts:18
const STEP_SECONDS: float = 60.0 / 134.0 / 4.0
## One cycle of the arrangement. PORT: web/src/tilt-to-live/TiltAudio.ts:110
const CYCLE_STEPS: int = 256

var _host: Node = null


func before_each() -> void:
	_host = Node.new()
	add_child_autofree(_host)


func _attached(
	sfx_dir: String = AudioBank.SFX_DIR, music_path: String = AudioBank.MUSIC_PATH
) -> AudioBank:
	var bank: AudioBank = AudioBank.new()
	bank.attach(_host, sfx_dir, music_path)
	return bank


func test_every_baked_file_exists_and_nothing_else() -> void:
	var on_disk: Array[String] = []
	for name: String in DirAccess.get_files_at(AudioBank.SFX_DIR):
		if name.get_extension() == "wav":
			on_disk.append(name.get_basename())
	on_disk.sort()
	var expected: Array[String] = AudioBank.SFX_STEMS.duplicate()
	expected.sort()
	assert_eq(on_disk, expected, "tools/bake-audio/bake_sfx.mjs writes exactly SFX_STEMS")
	assert_eq(AudioBank.SFX_STEMS.size(), 37, "18 single SFX + 15 dot pops + 4 march steps")


func test_music_loop_is_one_cycle_and_loops_forward() -> void:
	assert_true(ResourceLoader.exists(AudioBank.MUSIC_PATH), "bake_music.mjs writes it (M6 R1)")
	var stream: AudioStreamWAV = load(AudioBank.MUSIC_PATH) as AudioStreamWAV
	assert_not_null(stream, "imported as AudioStreamWAV (M5 R1)")
	if stream == null:
		return
	var rate: float = float(stream.mix_rate)
	# The second cycle's frame span (M6 R2).
	var frames: int = (
		roundi(2 * CYCLE_STEPS * STEP_SECONDS * rate) - roundi(CYCLE_STEPS * STEP_SECONDS * rate)
	)
	assert_eq(roundi(stream.get_length() * rate), frames, "exactly one cycle (M6 R2)")
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "M6 R9")
	assert_eq(stream.loop_begin, 0, "M6 R9")
	assert_eq(stream.loop_end, frames, "the whole file loops; -1 would drop a frame (M6 R9)")


func test_each_play_method_requests_its_file() -> void:
	var spy: SpyAudioBank = SpyAudioBank.new()
	spy.play_orb_pickup()
	spy.play_coin_pickup()
	spy.play_nuke()
	spy.play_missile_launch()
	spy.play_missile_explode()
	spy.play_laser_beam()
	spy.play_lightning()
	spy.play_freeze()
	spy.play_ice_shatter()
	spy.play_siren()
	spy.play_ice_cascade()
	spy.play_gauntlet_klaxon()
	spy.play_vortex()
	spy.play_dot_pop(3)
	spy.play_milestone()
	spy.play_player_death()
	spy.play_close_call()
	spy.play_space_invader_step(2)
	spy.play_warp_in()
	spy.play_invasion_alarm()
	var expected: Array[String] = [
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
		"dot_pop_03",
		"milestone",
		"player_death",
		"close_call",
		"space_invader_step_2",
		"warp_in",
		"invasion_alarm",
	]
	assert_eq(spy.requested, expected)
	for stem: String in spy.requested:
		assert_true(AudioBank.SFX_STEMS.has(stem), "%s is a baked stem" % stem)


func test_dot_pop_wraps_the_pentatonic_scale() -> void:
	var spy: SpyAudioBank = SpyAudioBank.new()
	for combo: int in [0, 14, 15, 16, 31]:
		spy.play_dot_pop(combo)
	var expected: Array[String] = [
		"dot_pop_00", "dot_pop_14", "dot_pop_00", "dot_pop_01", "dot_pop_01"
	]
	assert_eq(spy.requested, expected, "scale[comboIndex % 15] (TiltAudio.ts:754)")


func test_space_invader_step_wraps_the_march() -> void:
	var spy: SpyAudioBank = SpyAudioBank.new()
	for step: int in range(6):
		spy.play_space_invader_step(step)
	var expected: Array[String] = [
		"space_invader_step_0",
		"space_invader_step_1",
		"space_invader_step_2",
		"space_invader_step_3",
		"space_invader_step_0",
		"space_invader_step_1",
	]
	assert_eq(spy.requested, expected, "notes[step % 4] (TiltAudio.ts:830)")


func test_lightning_pitch_spans_the_ts_start_frequencies() -> void:
	seed(5)
	var spy: SpyAudioBank = SpyAudioBank.new()
	for i: int in range(200):
		spy.play_lightning()
	var low: float = 1200.0 / 1400.0
	var high: float = 1600.0 / 1400.0
	var lowest: float = high
	var highest: float = low
	for pitch: float in spy.pitches:
		assert_between(pitch, low, high, "1200 + random() * 400 over the baked 1400 Hz")
		lowest = minf(lowest, pitch)
		highest = maxf(highest, pitch)
	assert_lt(lowest, 0.9, "the spread reaches low")
	assert_gt(highest, 1.1, "the spread reaches high")


func test_other_sounds_play_at_their_baked_pitch() -> void:
	var spy: SpyAudioBank = SpyAudioBank.new()
	spy.play_nuke()
	spy.play_dot_pop(4)
	assert_eq(spy.pitches, [1.0, 1.0] as Array[float], "only lightning is randomised (M5 R6)")


func test_attached_bank_plays_a_voice() -> void:
	var bank: AudioBank = _attached()
	var id: int = bank._play("nuke")
	assert_ne(id, AudioStreamPlaybackPolyphonic.INVALID_ID)
	assert_true(bank._playback.is_stream_playing(id))
	assert_eq(bank._player.get_parent(), _host, "attach() hangs the player on the host")


func test_unattached_bank_is_silent_and_every_method_is_safe() -> void:
	var bank: AudioBank = AudioBank.new()
	assert_eq(bank._play("nuke"), AudioStreamPlaybackPolyphonic.INVALID_ID)
	bank.unlock()
	bank.set_muted(true)
	assert_true(bank.is_muted())
	assert_true(bank.toggle_mute(), "toggle_mute returns !muted (TiltAudio.ts:56)")
	bank.set_sfx_volume(0.5)
	bank.start_music()
	bank.stop_music()
	bank.play_nuke()
	bank.play_dot_pop(7)
	bank.play_lightning()
	pass_test("an unattached bank (every sim spec) plays nothing and never errors")


func test_muting_silences_the_player_and_blocks_new_voices() -> void:
	var bank: AudioBank = _attached()
	bank.set_sfx_volume(0.6)
	bank.set_muted(true)
	assert_eq(bank._player.volume_linear, 0.0, "masterGain 0 while muted (TiltAudio.ts:62)")
	assert_eq(bank._play("nuke"), AudioStreamPlaybackPolyphonic.INVALID_ID, "the :484 guard")
	bank.set_muted(false)
	assert_almost_eq(bank._player.volume_linear, 0.6, 0.0001, "unmuting restores the sfx gain")
	assert_ne(bank._play("nuke"), AudioStreamPlaybackPolyphonic.INVALID_ID)
	bank.toggle_mute()
	assert_eq(bank._player.volume_linear, 0.0, "toggle_mute mutes too (TiltAudio.ts:54)")


func test_sfx_volume_clamps_and_drives_the_player() -> void:
	var bank: AudioBank = _attached()
	bank.set_sfx_volume(0.8)
	assert_almost_eq(bank._player.volume_linear, 0.8, 0.0001)
	bank.set_sfx_volume(1.5)
	assert_almost_eq(bank._player.volume_linear, 1.0, 0.0001, "clamped (TiltAudio.ts:68)")
	bank.set_sfx_volume(-1.0)
	assert_almost_eq(bank._player.volume_linear, 0.0, 0.0001, "clamped (TiltAudio.ts:68)")


func test_music_volume_is_scaled_by_the_music_gain() -> void:
	var bank: AudioBank = AudioBank.new()
	bank.set_music_volume(0.7)
	assert_almost_eq(bank.music_gain, 0.245, 0.0001, "0.7 * 0.35 (TiltAudio.ts:74)")
	bank.set_music_volume(2.0)
	assert_almost_eq(bank.music_gain, 0.35, 0.0001, "clamped before scaling")


func test_voice_cap_drops_the_thirty_third_voice() -> void:
	var bank: AudioBank = _attached()
	for i: int in range(AudioBank.POLYPHONY):
		assert_ne(bank._play("dot_pop_00"), AudioStreamPlaybackPolyphonic.INVALID_ID)
	assert_eq(bank._play("dot_pop_01"), AudioStreamPlaybackPolyphonic.INVALID_ID, "M5 R2: dropped")


func test_missing_files_log_and_play_silence() -> void:
	var bank: AudioBank = _attached("res://tests/fixtures/no_such_sfx/")
	assert_true(bank._streams.is_empty(), "nothing loaded")
	assert_eq(bank._play("nuke"), AudioStreamPlaybackPolyphonic.INVALID_ID)
	bank.play_nuke()
	bank.play_dot_pop(3)
	assert_not_null(bank._player, "the player still exists; only the files are missing")


func test_start_music_plays_the_loop_from_the_top() -> void:
	var bank: AudioBank = _attached()
	assert_false(bank._music_player.playing, "attach() does not start the music")
	assert_eq(bank._music_player.get_parent(), _host)
	bank.start_music()
	assert_true(bank._music_player.playing)
	assert_lt(bank._music_player.get_playback_position(), 0.1, "currentStep = 0 (TiltAudio.ts:88)")


func test_start_music_while_playing_does_not_restart() -> void:
	var bank: AudioBank = _attached()
	bank.start_music()
	bank._music_player.seek(5.0)
	bank.start_music()
	assert_gt(bank._music_player.get_playback_position(), 4.9, "the :86 guard")


func test_stop_then_start_restarts_from_the_top() -> void:
	var bank: AudioBank = _attached()
	bank.start_music()
	bank._music_player.seek(5.0)
	bank.stop_music()
	assert_false(bank._music_player.playing, "TiltAudio.ts:97-103")
	bank.start_music()
	assert_true(bank._music_player.playing)
	assert_lt(bank._music_player.get_playback_position(), 0.1, "resume restarts at step 0 (M6 R5)")


func test_mute_silences_music_but_keeps_it_running() -> void:
	var bank: AudioBank = _attached()
	bank.set_music_volume(0.5)
	bank.start_music()
	bank.set_muted(true)
	assert_eq(bank._music_player.volume_linear, 0.0, "masterGain 0 (TiltAudio.ts:62)")
	assert_true(bank._music_player.playing, "the loop plays on silently (M6 R6)")
	bank.set_music_volume(0.8)
	assert_eq(bank._music_player.volume_linear, 0.0, "a volume change does not unmute")
	bank.set_muted(false)
	assert_almost_eq(bank._music_player.volume_linear, 0.8, 0.0001, "the saved music volume")
	bank.toggle_mute()
	assert_eq(bank._music_player.volume_linear, 0.0, "toggle_mute mutes music too (:54)")


func test_music_volume_applies_live_relative_to_the_baked_gain() -> void:
	var bank: AudioBank = _attached()
	assert_almost_eq(bank._music_player.volume_linear, 1.0, 0.0001, "0.35 is baked in (M6 R4)")
	bank.set_music_volume(0.7)
	assert_almost_eq(bank._music_player.volume_linear, 0.7, 0.0001, "0.245 / 0.35")
	bank.set_music_volume(1.5)
	assert_almost_eq(bank._music_player.volume_linear, 1.0, 0.0001, "clamped (TiltAudio.ts:74)")


func test_missing_music_file_logs_and_stays_silent() -> void:
	var bank: AudioBank = _attached(AudioBank.SFX_DIR, "res://tests/fixtures/no_such_music.wav")
	assert_null(bank._music_stream, "nothing loaded")
	assert_not_null(bank._music_player, "the player still exists; only the file is missing")
	bank.start_music()
	assert_false(bank._music_player.playing, "silence, no error (spec §6.4)")
	bank.stop_music()
	assert_eq(bank._streams.size(), AudioBank.SFX_STEMS.size(), "the SFX are unaffected")
