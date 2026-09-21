## save_store.gd
## NO TS COUNTERPART — authorised by spec §4.6 (persistence) and §6.4 (error
## handling). The web game's localStorage.getItem/setItem calls have no file,
## no parse failure that survives a reload and no backup; this is the one
## place those three things exist in the port.
class_name SaveStore
extends RefCounted
## user:// JSON files with corrupt-file quarantine, and the typed readers every
## save consumer uses on the parsed object.
##
## Never instantiated: every member is static, so nothing here is an autoload
## or a singleton (spec §5.2). Callers keep their own file path constant and
## their own JSON shape — this class knows nothing about what it stores.
##
## PORT-NOTE: the TS wraps every localStorage read in try/catch and falls back
## to defaults (ProgressionManager.ts:480-515, GameOptions.ts:92-105,
## ScoreManager.ts:172-184, GyroscopeController.ts:37-46). Spec §6.4 turns that
## into: parse failure → move the file aside as <name>.corrupt.json, warn,
## return {} so the caller applies its defaults. A file that parses but is not
## a JSON object is treated the same way — the TS would spread a non-object
## into defaults and silently lose it; here the evidence is kept.

## The extension a quarantined file gets, replacing ".json".
const CORRUPT_SUFFIX: String = ".corrupt.json"


## Where a corrupt copy of `path` is moved. "user://x.json" -> "user://x.corrupt.json".
static func corrupt_path_for(path: String) -> String:
	return path.trim_suffix(".json") + CORRUPT_SUFFIX


## Reads `path` as a JSON object. {} when absent, unreadable, or quarantined.
static func load_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.warn("SaveStore: %s exists but could not be opened; using defaults" % path)
		return {}
	var raw: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: Error = json.parse(raw)
	# PORT-NOTE: JSON.new().parse is used over JSON.parse_string because the
	# static form logs an engine error on bad input, which GUT counts as a
	# failure. The `is Dictionary` check narrows json.data before any read.
	if err == OK and json.data is Dictionary:
		return json.data
	_quarantine(path)
	return {}


## Writes `data` to `path` as JSON. False (and a warning) when the file cannot be opened.
static func save_dict(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Log.warn("SaveStore: %s could not be written" % path)
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


## `d[key]` as an int; `fallback` when absent or not a number. JSON numbers arrive as float.
static func read_int(d: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = d.get(key)
	if value is int:
		return value
	if value is float:
		# PORT-NOTE: narrowed by the is-check above
		@warning_ignore("unsafe_cast")
		return int(value as float)
	return fallback


## `d[key]` as a float; `fallback` when absent or not a number.
static func read_float(d: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = d.get(key)
	if value is float:
		return value
	if value is int:
		# PORT-NOTE: narrowed by the is-check above
		@warning_ignore("unsafe_cast")
		return float(value as int)
	return fallback


## `d[key]` as a bool; `fallback` when absent or not a bool. A number is not a bool.
static func read_bool(d: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = d.get(key)
	if value is bool:
		return value
	return fallback


## `d[key]` as a String; `fallback` when absent or not a string.
static func read_string(d: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = d.get(key)
	if value is String:
		return value
	return fallback


## `d[key]` as a typed String array; non-string elements are skipped. [] when absent.
static func read_string_array(d: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	var value: Variant = d.get(key)
	if not (value is Array):
		return out
	var items: Array = value
	for item: Variant in items:
		if item is String:
			out.append(item)
	return out


## `d[key]` as a Dictionary; {} when absent or not an object.
static func read_dict(d: Dictionary, key: String) -> Dictionary:
	var value: Variant = d.get(key)
	if value is Dictionary:
		return value
	return {}


static func _quarantine(path: String) -> void:
	var from: String = ProjectSettings.globalize_path(path)
	var to: String = ProjectSettings.globalize_path(corrupt_path_for(path))
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	var err: Error = DirAccess.rename_absolute(from, to)
	if err != OK:
		var fail_msg: String = (
			"SaveStore: %s could not be parsed as a JSON object and could not be moved aside (%d)"
			% [path, err]
		)
		Log.warn(fail_msg)
		return
	var moved_msg: String = (
		"SaveStore: %s could not be parsed as a JSON object; moved to %s and using defaults"
		% [path, to]
	)
	Log.warn(moved_msg)
