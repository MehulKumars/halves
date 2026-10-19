class_name SaveStore
extends RefCounted
## Versioned JSON save in user://.
##
## JSON cannot carry scripts, unlike Resource-based saves, so it is safe to load.
## When the save layout changes: bump CURRENT_VERSION and add a step to _migrate().
## Writes go to a temp file first, then replace the old save, so a crash mid-write
## never leaves a half-written save.

const CURRENT_VERSION: int = 2
const DEFAULT_PATH: String = "user://save.json"


static func save_data(data: Dictionary, path: String = DEFAULT_PATH) -> Error:
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = CURRENT_VERSION
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(path)
	)


static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"version": CURRENT_VERSION}
	var json := JSON.new()
	var err := json.parse(FileAccess.get_file_as_string(path))
	if err != OK or not json.data is Dictionary:
		push_warning("SaveStore: unreadable save at %s, starting fresh" % path)
		return {"version": CURRENT_VERSION}
	return _migrate(json.data as Dictionary)


static func delete_save(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	# One step per layout change.
	if version < 2:
		# v2: best times per board ("best"); level stars are kept by number so unlocks survive
		# the move from 30 to 100 Halves levels.
		if not data.get("best") is Dictionary:
			data["best"] = {}
		version = 2
	data["version"] = maxi(version, CURRENT_VERSION)
	return data
