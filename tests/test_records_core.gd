extends GutTest
## Core record keeping added for v2: Progress best times and game sections, the SaveStore migrations
## (v2 kept stars by level number; (v3) the move to 300 levels resets the journey once), and
## lower-is-better time boards in the mock leaderboard.
## Uses its own save files so the real save is never touched.

const PROGRESS_PATH := "user://test_records_progress.json"
const SAVE_PATH := "user://test_records_save.json"


func before_each() -> void:
	Progress.path = PROGRESS_PATH
	Progress.reset()


func after_each() -> void:
	SaveStore.delete_save(SAVE_PATH)


func after_all() -> void:
	Progress.reset()
	Progress.path = SaveStore.DEFAULT_PATH
	Progress.load_from_disk()


func test_best_time_keeps_the_lowest_and_its_record() -> void:
	assert_eq(Progress.best_time("level_3"), 0, "no time yet")
	assert_eq(Progress.best_record("level_3"), {})
	assert_true(Progress.record_time("level_3", 81_000, {"slips": 1}))
	assert_false(Progress.record_time("level_3", 90_000), "slower is not a best")
	assert_false(Progress.record_time("level_3", 81_000), "equal is not a new best")
	assert_true(Progress.record_time("level_3", 64_500, {"slips": 0}))
	assert_eq(Progress.best_time("level_3"), 64_500)
	assert_eq(int(Progress.best_record("level_3").get("slips", -1)), 0)
	assert_false(Progress.record_time("level_3", 0), "zero is not a time")
	assert_eq(Progress.best_time("level_4"), 0, "boards are separate")


func test_best_times_survive_a_reload() -> void:
	Progress.record_time("daily_2026-10-21", 42_000)
	Progress.load_from_disk()
	assert_eq(Progress.best_time("daily_2026-10-21"), 42_000)


func test_sections_are_saved_by_save() -> void:
	var tips := Progress.section("tips")
	assert_eq(tips, {}, "a new section starts empty")
	tips["mist"] = true
	Progress.save()
	Progress.load_from_disk()
	assert_eq(Progress.section("tips").get("mist"), true)


## (v3) An old save now migrates on to version 3, which starts the journey fresh once
## (docs/HALVES.md 4b, Progress): v1 kept stars by level number, v3 drops them with the move to 300 levels.
func test_a_v1_save_migrates_to_v3_and_resets_the_journey() -> void:
	var v1 := {"version": 1, "coins": 300, "levels": {"1": 3, "2": 2, "30": 1}, "daily": {"last": "2026-10-19", "streak": 2}}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(v1))
	file.close()
	var loaded := SaveStore.load_data(SAVE_PATH)
	assert_eq(int(loaded["version"]), 3)
	assert_eq(SaveStore.CURRENT_VERSION, 3)
	assert_eq(loaded["levels"], {}, "v3: stars and unlocks start fresh")
	assert_eq(int(loaded["coins"]), 300, "coins stay")
	assert_eq(int(loaded["daily"]["streak"]), 2, "the daily reward streak stays")
	assert_true(loaded.get("best") is Dictionary, "v2 adds the best-times section")
	assert_eq(loaded.get(SaveStore.JOURNEY_RESET_KEY), true, "the UI is told about the reset")


## (v3) A v2 save loses its level stars, level times and level Swift medals, and keeps the rest.
func test_a_v2_save_migrates_to_v3() -> void:
	var v2 := {"version": 2, "coins": 120, "levels": {"1": 3, "7": 2},
		"best": {"level_1": {"ms": 12_000}, "daily_2026-10-21": {"ms": 42_000}},
		"medals": {"level_1": true, "daily_2026-10-21": true}, "tips": {"pair": true}}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(v2))
	file.close()
	var loaded := SaveStore.load_data(SAVE_PATH)
	assert_eq(loaded["levels"], {})
	assert_false((loaded["best"] as Dictionary).has("level_1"), "level times go")
	assert_eq(int(loaded["best"]["daily_2026-10-21"]["ms"]), 42_000, "daily times stay")
	assert_false((loaded["medals"] as Dictionary).has("level_1"), "level medals go")
	assert_true((loaded["medals"] as Dictionary).has("daily_2026-10-21"))
	assert_eq(int(loaded["coins"]), 120)
	assert_eq(loaded["tips"], {"pair": true}, "other sections stay")
	assert_eq(loaded.get(SaveStore.JOURNEY_RESET_KEY), true)


## (v3) Progress exposes the reset to the UI once, until the UI clears it; a fresh save has none.
func test_progress_reports_a_journey_reset_until_cleared() -> void:
	assert_false(Progress.journey_reset_pending(), "a fresh save has nothing to report")
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 2, "coins": 50, "levels": {"3": 1}}))
	file.close()
	Progress.load_from_disk()
	assert_true(Progress.journey_reset_pending())
	assert_eq(Progress.coins(), 50)
	assert_eq(Progress.stars(3), 0)
	Progress.clear_journey_reset()
	assert_false(Progress.journey_reset_pending())
	Progress.load_from_disk()
	assert_false(Progress.journey_reset_pending(), "cleared for good once saved")


func test_a_v2_save_keeps_its_best_times() -> void:
	SaveStore.save_data({"best": {"level_1": {"ms": 12_000}}}, SAVE_PATH)
	var loaded := SaveStore.load_data(SAVE_PATH)
	assert_eq(int(loaded["best"]["level_1"]["ms"]), 12_000)


func test_mock_leaderboard_keeps_the_lowest_time() -> void:
	var board := MockLeaderboardService.new()
	add_child_autofree(board)
	assert_eq(board.get_local_best_time("daily_x"), 0)
	board.submit_time("daily_x", 50_000)
	board.submit_time("daily_x", 70_000)
	assert_eq(board.get_local_best_time("daily_x"), 50_000)
	board.submit_time("daily_x", 40_000)
	assert_eq(board.get_local_best_time("daily_x"), 40_000)
	board.submit_score("rush", 120)
	board.submit_score("rush", 80)
	assert_eq(board.get_local_best("rush"), 120, "scores stay higher-is-better")
