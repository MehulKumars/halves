class_name HalvesPools
extends RefCounted
## The baked board pools of the Daily, Zen and Rush modes (data/levels/halves_<kind>_v2.json),
## loaded the first time each is asked for. Daily picks a board by date; Zen and Rush walk a
## seeded order of their pool. Board ids are 10000 + i (daily), 20000 + i (zen), 30000 + i (rush).

enum Kind { DAILY, ZEN, RUSH }

const DAILY_EPOCH: String = "2026-10-01"
const PATHS: Array[String] = [
	"res://data/levels/halves_daily_v2.json",
	"res://data/levels/halves_zen_v2.json",
	"res://data/levels/halves_rush_v2.json",
]
const NAMES: Array[String] = ["daily", "zen", "rush"]

static var _boards: Array = [null, null, null]
static var _gen: PackedInt32Array = PackedInt32Array([0, 0, 0])


static func count(kind: Kind) -> int:
	return _load(kind).size()


static func gen_version(kind: Kind) -> int:
	_load(kind)
	return _gen[kind]


## Board `index` of the pool, wrapping around; null if the pool is empty.
static func get_board(kind: Kind, index: int) -> HalvesLevelData:
	var boards := _load(kind)
	if boards.is_empty():
		return null
	var entry: Variant = boards[posmod(index, boards.size())]
	if entry is Dictionary:
		entry = HalvesLevelData.from_dict(entry)
		boards[posmod(index, boards.size())] = entry
	return entry


## 1 + days from DAILY_EPOCH to `date` ("YYYY-MM-DD"); 1 for dates before the epoch.
static func daily_number(date: String) -> int:
	var epoch := Time.get_unix_time_from_datetime_string(DAILY_EPOCH + "T00:00:00")
	var day := Time.get_unix_time_from_datetime_string(date + "T00:00:00")
	return maxi(1, int(floor((day - epoch) / 86400.0)) + 1)


static func daily_board(date: String) -> HalvesLevelData:
	return get_board(Kind.DAILY, daily_number(date) - 1)


## A permutation of the pool's indices, shuffled with the given seed parts.
static func run_order(kind: Kind, seed_parts: Array) -> PackedInt32Array:
	var order := PackedInt32Array()
	for i in count(kind):
		order.append(i)
	HalvesFill.shuffle_ints(order, SeedService.make_rng(seed_parts, gen_version(kind)))
	return order


static func _load(kind: Kind) -> Array:
	if _boards[kind] != null:
		return _boards[kind]
	var boards: Array = []
	_boards[kind] = boards
	var path := PATHS[kind]
	if not FileAccess.file_exists(path):
		push_warning("Halves: pool %s is missing (%s)" % [NAMES[kind], path])
		return boards
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Halves: %s is not valid JSON" % path)
		return boards
	var data: Dictionary = parsed
	_gen[kind] = int(data.get("gen_version", 0))
	boards.append_array(data.get("boards", []))
	return boards
