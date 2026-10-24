class_name SaveStore
extends RefCounted
## Versioned JSON save in user://.
##
## JSON cannot carry scripts, unlike Resource-based saves, so it is safe to load.
## When the save layout changes: bump CURRENT_VERSION and add a step to _migrate().
## Writes go to a temp file first, then replace the old save, so a crash mid-write
## never leaves a half-written save.

const CURRENT_VERSION: int = 3
## (v3) Set by the v2 -> v3 step when it reset a journey in progress; Progress reads and clears it.
const JOURNEY_RESET_KEY: String = "journey_reset"
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
	if version < 3:
		# v3: Halves moved from 100 levels in 10 places to 300 in 15, and stars are kept by level
		# number, so the journey starts fresh once: level stars (and with them the unlocks), best
		# level times and Swift medals go, and so do best-run logs kept at the top level by board
		# (user://halves_runs.json); coins, purchases, settings and the daily records stay.
		var had_journey := data.get("levels") is Dictionary and not (data["levels"] as Dictionary).is_empty()
		if data.has("levels"):
			data["levels"] = {}
		for key: String in ["best", "medals"]:
			if data.get(key) is Dictionary:
				_drop_level_boards(data[key] as Dictionary)
		_drop_level_boards(data)
		if had_journey:
			data[JOURNEY_RESET_KEY] = true
		version = 3
	data["version"] = maxi(version, CURRENT_VERSION)
	return data


## Removes the entries of level boards ("level_12") from `section`, in place.
static func _drop_level_boards(section: Dictionary) -> void:
	for key: Variant in section.keys():
		if str(key).begins_with("level_"):
			section.erase(key)
