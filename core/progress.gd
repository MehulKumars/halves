class_name Progress
extends RefCounted
## Player progress used by the template screens: best stars per level, best times, coins, purchases
## and the daily reward streak; games keep their own sections through section() and save().
## Stored in the versioned JSON save (SaveStore) and written on every change, so nothing is lost
## if Android kills the app. Tests point `path` at a temporary file.

## Halves ships 100 baked levels (HalvesLevels.COUNT; tests keep the two equal).
const LEVEL_COUNT_DEFAULT: int = 100
## Coins for day 1..7 of the daily reward; day 7 is the big one, then the cycle restarts.
const DAILY_REWARDS: Array[int] = [50, 75, 100, 150, 200, 300, 500]

static var path: String = SaveStore.DEFAULT_PATH
static var _data: Dictionary = {}
static var _loaded_from: String = ""


## Best stars (0-3) for a level, 0 if never won.
static func stars(level: int) -> int:
	return int(_levels().get(str(level), 0))


## Records a finished level, keeping the best star count. Returns true if it was a new best.
static func record_win(level: int, earned: int) -> bool:
	var best := stars(level)
	if earned <= best:
		return false
	_levels()[str(level)] = clampi(earned, 1, 3)
	_save()
	return true


## Level 1 is always open; every other level opens once the one before it is won.
static func is_unlocked(level: int) -> bool:
	return level <= 1 or stars(level - 1) > 0


## The first level not won yet: the one the Play button starts.
static func next_level(level_count: int = LEVEL_COUNT_DEFAULT) -> int:
	for level in range(1, level_count + 1):
		if stars(level) == 0:
			return level
	return level_count


## Levels won at least once.
static func levels_won() -> int:
	var won := 0
	for value: Variant in _levels().values():
		if int(value) > 0:
			won += 1
	return won


static func total_stars() -> int:
	var total := 0
	for value: Variant in _levels().values():
		total += int(value)
	return total


static func coins() -> int:
	return int(_root().get("coins", 0))


static func add_coins(amount: int) -> int:
	_root()["coins"] = maxi(0, coins() + amount)
	_save()
	return coins()


## Spends coins if there are enough. Returns false (and spends nothing) otherwise.
static func spend_coins(amount: int) -> bool:
	if amount > coins():
		return false
	add_coins(-amount)
	return true


static func owns(item: String) -> bool:
	return bool(_owned().get(item, false))


static func set_owned(item: String, owned: bool = true) -> void:
	_owned()[item] = owned
	_save()


## Daily reward state for `today` ("YYYY-MM-DD", local time by default):
## day = 1..7 (the day to claim, or the day already claimed today), can_claim, amount (coins
## for that day), streak (days in a row). Missing a whole day restarts at day 1.
static func daily_status(today: String = "") -> Dictionary:
	today = _today() if today.is_empty() else today
	var daily := _daily()
	var last: String = daily.get("last", "")
	var streak := int(daily.get("streak", 0))
	var claimed_today := last == today
	var continues := claimed_today or _days_between(last, today) == 1
	var current := streak if continues else 0
	var claim_streak := current if claimed_today else current + 1
	var day := (claim_streak - 1) % DAILY_REWARDS.size() + 1
	return {"day": day, "can_claim": not claimed_today, "amount": DAILY_REWARDS[day - 1], "streak": current}


## Claims today's reward. Returns the coins given, or 0 if already claimed today.
static func claim_daily(today: String = "") -> int:
	today = _today() if today.is_empty() else today
	var status := daily_status(today)
	if not status.can_claim:
		return 0
	_daily()["last"] = today
	_daily()["streak"] = int(status.streak) + 1
	add_coins(int(status.amount))
	return int(status.amount)


## Counts an app launch and returns its number (1 = the first launch ever). Call once per launch;
## AdPolicy.start_session() uses it to keep the first session free of interstitials.
static func start_session() -> int:
	_root()["sessions"] = session_index() + 1
	_save()
	return session_index()


## The current launch's number (0 before the first start_session()).
static func session_index() -> int:
	return int(_root().get("sessions", 0))


## The best (lowest) time in ms on a board ("level_12", "daily_2026-10-21"...), 0 if none yet.
static func best_time(board: String) -> int:
	return int(best_record(board).get("ms", 0))


## The record that set the best time: {"ms": int, ...whatever record_time() was given}; {} if none.
static func best_record(board: String) -> Dictionary:
	var record: Variant = _section("best").get(board, {})
	return record if record is Dictionary else {}


## Keeps `ms` (with `extra` fields) as the board's best time if it beats the old one. True if new.
static func record_time(board: String, ms: int, extra: Dictionary = {}) -> bool:
	var old := best_time(board)
	if ms <= 0 or (old > 0 and ms >= old):
		return false
	var record := extra.duplicate(true)
	record["ms"] = ms
	_section("best")[board] = record
	_save()
	return true


## A game's own part of the save (created empty on first use). Call save() after changing it.
static func section(key: String) -> Dictionary:
	return _section(key)


static func save() -> void:
	_save()


## Forgets everything (Settings > Reset progress).
static func reset() -> void:
	_data = {}
	_loaded_from = path
	SaveStore.delete_save(path)


## Re-reads the save file. (Not named reload(): Progress.reload() would call the built-in
## Script.reload(), which recompiles this class and resets its static variables.)
static func load_from_disk() -> void:
	_data = SaveStore.load_data(path)
	_loaded_from = path


static func _root() -> Dictionary:
	if _loaded_from != path:
		load_from_disk()
	return _data


static func _levels() -> Dictionary:
	return _section("levels")


static func _owned() -> Dictionary:
	return _section("owned")


static func _daily() -> Dictionary:
	return _section("daily")


static func _section(key: String) -> Dictionary:
	var data := _root()
	if not data.get(key) is Dictionary:
		data[key] = {}
	return data[key]


static func _save() -> void:
	var err := SaveStore.save_data(_root(), path)
	if err != OK:
		push_warning("Progress: saving failed: %s" % error_string(err))


static func _today() -> String:
	return Time.get_date_string_from_system()


static func _days_between(from: String, to: String) -> int:
	if from.is_empty() or to.is_empty():
		return -1
	var a := Time.get_unix_time_from_datetime_string(from + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(to + "T00:00:00")
	return roundi((b - a) / 86400.0)
