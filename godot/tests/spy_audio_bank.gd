## spy_audio_bank.gd
## PORTS: nothing — test helper; records what the sim asks AudioBank to play
class_name SpyAudioBank
extends AudioBank
## An unattached, therefore silent, AudioBank that records every play request
## and music lifecycle call, so specs can assert which sound fires when.

## Stems requested through _play, in call order.
var requested: Array[String] = []
## The pitch scale of each request, parallel to `requested`.
var pitches: Array[float] = []
## "unlock", "start_music" and "stop_music" calls, in call order.
var lifecycle: Array[String] = []


## Records the TS unlock() call site.
func unlock() -> void:
	lifecycle.append("unlock")
	super()


## Records the TS startMusic() call site.
func start_music() -> void:
	lifecycle.append("start_music")
	super()


## Records the TS stopMusic() call site.
func stop_music() -> void:
	lifecycle.append("stop_music")
	super()


func _play(stem: String, pitch_scale: float = 1.0) -> int:
	requested.append(stem)
	pitches.append(pitch_scale)
	return super(stem, pitch_scale)
