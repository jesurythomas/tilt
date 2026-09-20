## log.gd
## PORTS: nothing — new file per spec §7; CONVENTIONS §6 bans bare print()
# PORT-NOTE: no `class_name`, against CONVENTIONS §2. An autoload script cannot
# carry one: `class_name Log` shadows the `Log` singleton and every call site
# resolves against a Nil base. Measured, not assumed — see HANDOFF.md.
extends Node
## Leveled logging. Autoloaded as `Log`; the only sanctioned output path in
## this project. Not a simulation system, so autoloading it is permitted
## (spec §5.2 constrains sim systems only).

## Severity floor. Messages below `min_level` are dropped.
enum Level { DEBUG, INFO, WARN, ERROR }

## Messages below this level are not emitted.
var min_level: Level = Level.DEBUG


## True when a message at `level` would be emitted.
func is_enabled(level: Level) -> bool:
	return level >= min_level


## Verbose developer detail.
func debug(msg: String) -> void:
	if is_enabled(Level.DEBUG):
		_emit("DEBUG", msg)


## Ordinary lifecycle information.
func info(msg: String) -> void:
	if is_enabled(Level.INFO):
		_emit("INFO", msg)


## A recoverable problem worth seeing in logcat.
func warn(msg: String) -> void:
	if is_enabled(Level.WARN):
		_emit("WARN", msg)
		push_warning(msg)


## A failure. Never silently swallowed.
func error(msg: String) -> void:
	if is_enabled(Level.ERROR):
		_emit("ERROR", msg)
		push_error(msg)


# PORT-NOTE: this is the single sanctioned print() in the project. CONVENTIONS
# §6 bans bare print() everywhere else; the ban needs one sink.
func _emit(tag: String, msg: String) -> void:
	print("[%s] %s" % [tag, msg])
