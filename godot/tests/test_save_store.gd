## test_save_store.gd
## PORTS: nothing — new file, covers src/meta/save_store.gd
extends GutTest
## Proves the user:// JSON store: absent, round trip, corrupt quarantine, and
## the typed readers that every save consumer goes through.

const PATH: String = "user://test_save_store_probe.json"


func _remove(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "probe file must be writable")
	file.store_string(text)
	file.close()


func before_each() -> void:
	_remove(PATH)
	_remove(SaveStore.corrupt_path_for(PATH))


func after_each() -> void:
	_remove(PATH)
	_remove(SaveStore.corrupt_path_for(PATH))


func test_corrupt_path_swaps_the_extension() -> void:
	assert_eq(SaveStore.corrupt_path_for("user://abc.json"), "user://abc.corrupt.json")
	assert_eq(
		SaveStore.corrupt_path_for("user://tilt_to_live_progression_v3.json"),
		"user://tilt_to_live_progression_v3.corrupt.json"
	)


func test_absent_file_loads_as_empty() -> void:
	assert_false(FileAccess.file_exists(PATH))
	assert_eq(SaveStore.load_dict(PATH), {})
	assert_false(FileAccess.file_exists(PATH), "a load never creates the file")


func test_round_trip_preserves_keys_and_values() -> void:
	var data: Dictionary = {"points": 7331, "name": "classic", "on": true, "list": ["a", "b"]}
	assert_true(SaveStore.save_dict(PATH, data))
	var back: Dictionary = SaveStore.load_dict(PATH)
	assert_eq(SaveStore.read_int(back, "points", 0), 7331, "JSON numbers come back as float")
	assert_eq(SaveStore.read_string(back, "name", ""), "classic")
	assert_true(SaveStore.read_bool(back, "on", false))
	assert_eq(SaveStore.read_string_array(back, "list"), ["a", "b"])


func test_unparseable_file_is_quarantined_and_loads_as_empty() -> void:
	_write_raw(PATH, "{not json")
	assert_eq(SaveStore.load_dict(PATH), {})
	assert_false(FileAccess.file_exists(PATH), "the bad file is moved, not deleted")
	assert_true(FileAccess.file_exists(SaveStore.corrupt_path_for(PATH)), "spec §6.4 backup")
	var kept: FileAccess = FileAccess.open(SaveStore.corrupt_path_for(PATH), FileAccess.READ)
	assert_eq(kept.get_as_text(), "{not json", "the backup is byte-identical")
	kept.close()


func test_non_object_json_is_quarantined() -> void:
	_write_raw(PATH, "[1, 2, 3]")
	assert_eq(SaveStore.load_dict(PATH), {})
	assert_true(FileAccess.file_exists(SaveStore.corrupt_path_for(PATH)))


func test_second_quarantine_replaces_the_first() -> void:
	_write_raw(PATH, "first")
	SaveStore.load_dict(PATH)
	_write_raw(PATH, "second")
	SaveStore.load_dict(PATH)
	var kept: FileAccess = FileAccess.open(SaveStore.corrupt_path_for(PATH), FileAccess.READ)
	assert_eq(kept.get_as_text(), "second")
	kept.close()


func test_typed_readers_fall_back_on_wrong_types() -> void:
	var d: Dictionary = {"i": "x", "f": true, "b": 1.0, "s": 2.0, "arr": "no", "sub": 3.0}
	assert_eq(SaveStore.read_int(d, "i", 9), 9)
	assert_eq(SaveStore.read_int(d, "missing", 9), 9)
	assert_almost_eq(SaveStore.read_float(d, "f", 0.5), 0.5, 0.0001)
	assert_false(SaveStore.read_bool(d, "b", false), "a number is not a bool")
	assert_eq(SaveStore.read_string(d, "s", "dflt"), "dflt")
	assert_eq(SaveStore.read_string_array(d, "arr"), [])
	assert_eq(SaveStore.read_dict(d, "sub"), {})


func test_read_int_accepts_int_and_float() -> void:
	assert_eq(SaveStore.read_int({"a": 3}, "a", 0), 3)
	assert_eq(SaveStore.read_int({"a": 3.0}, "a", 0), 3)
	assert_almost_eq(SaveStore.read_float({"a": 3}, "a", 0.0), 3.0, 0.0001, "int widens")


func test_read_string_array_skips_non_strings() -> void:
	assert_eq(SaveStore.read_string_array({"l": ["a", 1.0, "b", true]}, "l"), ["a", "b"])
