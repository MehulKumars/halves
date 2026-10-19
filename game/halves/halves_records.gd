class_name HalvesRecords
extends RefCounted
## Halves' records on top of Progress: best times and Swift medals per board, the best runs' move
## logs (a separate file, written only on a new best, ready for a leaderboard server to replay),
## the daily puzzle streak, zen boards, the rush best score and which tip cards were seen.

const RUNS_PATH: String = "user://halves_runs.json"

## Tests point this at a temporary file.
static var runs_path: String = RUNS_PATH


static func level_board(level: int) -> String:
	return "level_%d" % level


static func daily_board(date: String) -> String:
	return "daily_%s" % date


## After a clear: keeps the best time (and its run log) and the Swift medal.
## Returns {"ms", "best_ms", "new_best", "first_clear", "swift", "swift_new"}.
static func record_clear(board: String, run: HalvesRun, stars: int, slips: int, par_ms: int,
		assisted: bool) -> Dictionary:
	var ms := run.active_ms
	var first_clear := Progress.best_time(board) == 0
	var new_best := Progress.record_time(board, ms, {"stars": stars, "slips": slips, "assisted": assisted,
			"date": today()})
	if new_best:
		_save_run(board, run.to_dict())
	var swift := par_ms > 0 and ms <= par_ms
	var medals := Progress.section("medals")
	var swift_new := swift and not bool(medals.get(board, false))
	if swift_new:
		medals[board] = true
		Progress.save()
	return {"ms": ms, "best_ms": Progress.best_time(board), "new_best": new_best and not first_clear,
			"first_clear": first_clear, "swift": swift, "swift_new": swift_new}


static func has_swift(board: String) -> bool:
	return bool(Progress.section("medals").get(board, false))


static func swift_count() -> int:
	var count := 0
	for value: Variant in Progress.section("medals").values():
		count += 1 if bool(value) else 0
	return count


## The move log of the board's best run ({} if none).
static func best_run(board: String) -> Dictionary:
	var runs := SaveStore.load_data(runs_path)
	var run: Variant = runs.get(board, {})
	return run if run is Dictionary else {}


static func _save_run(board: String, run: Dictionary) -> void:
	var runs := SaveStore.load_data(runs_path)
	runs[board] = run
	SaveStore.save_data(runs, runs_path)


## Daily puzzle for `date`: {"date", "number", "done", "best_ms", "stars", "streak", "week"}; `week`
## is the last 7 days (oldest first) as bools: was that day's puzzle cleared?
static func daily_state(date: String = "") -> Dictionary:
	date = today() if date.is_empty() else date
	var section := Progress.section("daily_puzzle")
	var done: Dictionary = section.get("done", {})
	var entry: Variant = done.get(date, null)
	var week: Array = []
	for back in range(6, -1, -1):
		week.append(done.has(shift_date(date, -back)))
	var last: String = section.get("last", "")
	var streak := int(section.get("streak", 0))
	if last != date and last != shift_date(date, -1):
		streak = 0
	return {"date": date, "number": HalvesPools.daily_number(date), "done": entry is Dictionary,
			"best_ms": int((entry as Dictionary).get("ms", 0)) if entry is Dictionary else 0,
			"stars": int((entry as Dictionary).get("stars", 0)) if entry is Dictionary else 0,
			"streak": streak, "week": week}


## A cleared daily: the first clear of a day extends the streak and pays that day's reward.
## Returns {"first_today", "streak", "reward"}.
static func record_daily(date: String, ms: int, stars: int) -> Dictionary:
	var section := Progress.section("daily_puzzle")
	if not section.get("done") is Dictionary:
		section["done"] = {}
	var done: Dictionary = section.done
	var first := not done.has(date)
	var old: Dictionary = done.get(date, {}) if done.get(date) is Dictionary else {}
	if first or ms < int(old.get("ms", 1 << 30)):
		done[date] = {"ms": ms, "stars": maxi(stars, int(old.get("stars", 0)))}
	var reward := 0
	var streak := int(section.get("streak", 0))
	if first:
		var last: String = section.get("last", "")
		streak = streak + 1 if last == shift_date(date, -1) else 1
		section["last"] = date
		section["streak"] = streak
		reward = Progress.DAILY_REWARDS[(streak - 1) % Progress.DAILY_REWARDS.size()]
		Progress.add_coins(reward)
	Progress.save()
	return {"first_today": first, "streak": streak, "reward": reward}


## "Halves Daily #20 ⏱ 1:42 ★★★" for the clipboard.
static func share_line(date: String) -> String:
	var state := daily_state(date)
	var stars := "★".repeat(int(state.stars)) + "☆".repeat(3 - int(state.stars))
	return "Halves Daily #%d  %s  %s" % [int(state.number), format_time(int(state.best_ms)), stars]


static func zen_boards() -> int:
	return int(Progress.section("modes").get("zen_boards", 0))


static func add_zen_board() -> int:
	var modes := Progress.section("modes")
	modes["zen_boards"] = zen_boards() + 1
	Progress.save()
	return zen_boards()


static func rush_best() -> int:
	return int(Progress.section("modes").get("rush_best", 0))


## Keeps the best rush score; true if `score` beat it.
static func record_rush(score: int) -> bool:
	if score <= rush_best():
		return false
	Progress.section("modes")["rush_best"] = score
	Progress.save()
	return true


static func tip_seen(id: String) -> bool:
	return bool(Progress.section("tips").get(id, false))


static func mark_tip(id: String) -> void:
	if tip_seen(id):
		return
	Progress.section("tips")[id] = true
	Progress.save()


## "1:05" (or "0:42.3" when `tenths`).
static func format_time(ms: int, tenths: bool = false) -> String:
	var total := maxi(0, ms)
	var seconds := total / 1000
	if tenths:
		return "%d:%02d.%d" % [seconds / 60, seconds % 60, (total % 1000) / 100]
	return "%d:%02d" % [seconds / 60, seconds % 60]


static func today() -> String:
	return Time.get_date_string_from_system()


## `date` ("YYYY-MM-DD") moved by `days`.
static func shift_date(date: String, days: int) -> String:
	var unix := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	return Time.get_date_string_from_unix_time(int(unix) + days * 86400)


## One line per played level for the dev console's `stats` command (tuning par and targets).
static func stats_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for level in range(1, HalvesLevels.count() + 1):
		var record := Progress.best_record(level_board(level))
		if record.is_empty():
			continue
		var data := HalvesLevels.get_level(level)
		lines.append("L%d %s best %s par %s stars %d slips %d%s" % [level, data.role,
				format_time(int(record.ms), true), format_time(data.par_ms()), int(record.get("stars", 0)),
				int(record.get("slips", 0)), " assisted" if bool(record.get("assisted", false)) else ""])
	return lines
