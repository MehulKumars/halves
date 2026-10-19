extends GutTest
## Core record keeping added for v2: Progress best times and game sections, the SaveStore v1 -> v2
## migration (stars kept by level number), and lower-is-better time boards in the mock leaderboard.
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


func test_a_v1_save_migrates_to_v2_and_keeps_stars() -> void:
	var v1 := {"version": 1, "coins": 300, "levels": {"1": 3, "2": 2, "30": 1}, "daily": {"last": "2026-10-19", "streak": 2}}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(v1))
	file.close()
	var loaded := SaveStore.load_data(SAVE_PATH)
	assert_eq(int(loaded["version"]), 2)
	assert_eq(SaveStore.CURRENT_VERSION, 2)
	assert_eq(int(loaded["levels"]["30"]), 1, "stars are kept by level number")
	assert_eq(int(loaded["coins"]), 300)
	assert_true(loaded.get("best") is Dictionary, "v2 adds the best-times section")


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
