## test_audio_bank.gd
## PORTS: nothing — new file, covers src/audio/audio_bank.gd
extends GutTest
## Proves AudioBank stub methods execute without error.


func test_audio_bank_methods_callable() -> void:
	var audio: AudioBank = AudioBank.new()
	audio.unlock()
	audio.set_muted(true)
	assert_true(audio.is_muted(), "is_muted should report true after set_muted(true)")
	var toggled: bool = audio.toggle_mute()
	assert_true(toggled, "toggle_mute should return !muted (true when unmuting)")
	audio.set_sfx_volume(0.8)
	audio.set_music_volume(0.5)
	audio.start_music()
	audio.stop_music()
	audio.play_orb_pickup()
	audio.play_coin_pickup()
	audio.play_nuke()
	audio.play_missile_launch()
	audio.play_missile_explode()
	audio.play_laser_beam()
	audio.play_lightning()
	audio.play_freeze()
	audio.play_ice_shatter()
	audio.play_siren()
	audio.play_ice_cascade()
	audio.play_gauntlet_klaxon()
	audio.play_vortex()
	audio.play_dot_pop(1)
	audio.play_milestone()
	audio.play_player_death()
	audio.play_close_call()
	audio.play_space_invader_step(0)
	audio.play_warp_in()
	audio.play_invasion_alarm()
	pass_test("All 28 AudioBank methods called cleanly")
