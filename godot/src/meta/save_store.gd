## save_store.gd
## NO TS COUNTERPART — authorised by spec §4.6 (persistence) and §6.4 (error
## handling). The web game's localStorage.getItem/setItem calls have no file,
## no parse failure that survives a reload and no backup; this is the one
## place those three things exist in the port.
class_name SaveStore
extends RefCounted
## user:// JSON files (objects, and one bare string array) with corrupt-file
## quarantine, and the typed readers every save consumer uses on the parsed object.
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

## DIVERGENCE(M11c P16): when true, a save serialises on the caller's thread and one
## WorkerThreadPool task writes the file, so saving costs the game thread no file I/O
## (the death tick saves 3-5 files). Off by default, since tests read files back at once;
## GameRoot turns it on and calls flush() on pause and quit. Loads flush first.
static var write_behind: bool = false
## Path -> text waiting for the writer (the latest save of a path wins).
static var _pending: Dictionary[String, String] = {}
static var _mutex: Mutex = Mutex.new()
## True while a writer task is draining _pending (guarded by _mutex).
static var _draining: bool = false
static var _task: int = -1


## Where a corrupt copy of `path` is moved. "user://x.json" -> "user://x.corrupt.json".
static func corrupt_path_for(path: String) -> String:
	return path.trim_suffix(".json") + CORRUPT_SUFFIX


## Reads `path` as a JSON object. {} when absent, unreadable, or quarantined.
static func load_dict(path: String) -> Dictionary:
	flush()
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
## With write_behind, true means queued (a failed write warns from the writer).
static func save_dict(path: String, data: Dictionary) -> bool:
	return _write(path, JSON.stringify(data))


## Reads `path` as a JSON array of strings; non-string elements are skipped.
## [] when absent, unreadable, or quarantined.
# PORT-NOTE: the one save whose TS shape is a bare array — GoalManager.ts:676-686,
# 'tilt_to_live_completed_goals_v1'. Spec §4.6 keeps the shape, and load_dict
# quarantines anything that is not an object, so this is its array twin.
static func load_string_list(path: String) -> Array[String]:
	var out: Array[String] = []
	flush()
	if not FileAccess.file_exists(path):
		return out
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.warn("SaveStore: %s exists but could not be opened; using defaults" % path)
		return out
	var raw: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: Error = json.parse(raw)
	if err != OK or not (json.data is Array):
		_quarantine(path)
		return out
	var items: Array = json.data
	for item: Variant in items:
		if item is String:
			out.append(item)
	return out


## Writes `items` to `path` as a JSON array. False (and a warning) when the file cannot be opened.
static func save_string_list(path: String, items: Array[String]) -> bool:
	return _write(path, JSON.stringify(items))


## Writes every queued save now and waits for the writer. A no-op without write_behind.
static func flush() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_mutex.lock()
	var left: Dictionary[String, String] = _pending.duplicate()
	_pending.clear()
	_mutex.unlock()
	for path: String in left:
		_write_now(path, left[path])


## Saves `text` to `path`: at once, or queued for the writer (DIVERGENCE(M11c P16)).
static func _write(path: String, text: String) -> bool:
	if not write_behind:
		return _write_now(path, text)
	_mutex.lock()
	_pending[path] = text
	var start: bool = not _draining
	_draining = true
	_mutex.unlock()
	if start:
		if _task != -1:
			# The previous writer found nothing left and is returning.
			WorkerThreadPool.wait_for_task_completion(_task)
		_task = WorkerThreadPool.add_task(_drain)
	return true


## The writer task: writes queued saves until none are left.
static func _drain() -> void:
	while true:
		_mutex.lock()
		if _pending.is_empty():
			_draining = false
			_mutex.unlock()
			return
		var path: String = _pending.keys()[0]
		var text: String = _pending[path]
		_pending.erase(path)
		_mutex.unlock()
		_write_now(path, text)


static func _write_now(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Log.warn("SaveStore: %s could not be written" % path)
		return false
	file.store_string(text)
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
