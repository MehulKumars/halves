class_name HalvesLevels
extends RefCounted
## Loads the 300 baked Halves levels (v3) from data/levels/halves_v3.json (made offline by
## tools/levelgen/generate_halves.gd) and caches them. Used by the game screen and level select.
## JSON hands numbers back as floats; everything is cast to int here so seeds and ids stay exact.

const PATH: String = "res://data/levels/halves_v3.json"
const COUNT: int = 300

static var _levels: Array[HalvesLevelData] = []
static var _gen_version: int = 0
static var _loaded: bool = false


## Level `n` (1-based), or null if it is not in the file.
static func get_level(n: int) -> HalvesLevelData:
	_ensure_loaded()
	if n < 1 or n > _levels.size():
		return null
	return _levels[n - 1]


static func count() -> int:
	_ensure_loaded()
	return _levels.size()


static func gen_version() -> int:
	_ensure_loaded()
	return _gen_version


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		push_error("Halves: missing %s; run tools/levelgen/generate_halves.gd" % PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("Halves: %s is not valid JSON" % PATH)
		return
	var data: Dictionary = parsed
	_gen_version = int(data.get("gen_version", 0))
	var levels: Array = data.get("levels", [])
	for entry: Variant in levels:
		_levels.append(HalvesLevelData.from_dict(entry as Dictionary))
