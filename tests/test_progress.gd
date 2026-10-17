extends GutTest
## Progress: best stars, unlocks, coins, purchases and the daily reward streak.
## Uses its own save file so the real one is never touched.

const TEST_PATH := "user://test_progress.json"


func before_each() -> void:
	Progress.path = TEST_PATH
	Progress.reset()


func after_all() -> void:
	Progress.reset()
	Progress.path = SaveStore.DEFAULT_PATH
	Progress.load_from_disk()


func test_new_player_has_only_level_one_open() -> void:
	assert_true(Progress.is_unlocked(1))
	assert_false(Progress.is_unlocked(2))
	assert_eq(Progress.next_level(), 1)
	assert_eq(Progress.coins(), 0)


func test_win_unlocks_the_next_level_and_keeps_the_best_stars() -> void:
	assert_true(Progress.record_win(1, 2))
	assert_true(Progress.is_unlocked(2))
	assert_eq(Progress.next_level(), 2)
	assert_false(Progress.record_win(1, 1), "a worse result is not a new best")
	assert_eq(Progress.stars(1), 2)
	assert_true(Progress.record_win(1, 3))
	assert_eq(Progress.total_stars(), 3)


func test_progress_survives_a_reload() -> void:
	Progress.record_win(1, 3)
	Progress.add_coins(120)
	Progress.set_owned("remove_ads")
	Progress.load_from_disk()
	assert_eq(Progress.stars(1), 3)
	assert_eq(Progress.coins(), 120)
	assert_true(Progress.owns("remove_ads"))


func test_sessions_count_launches_and_survive_a_reload() -> void:
	assert_eq(Progress.session_index(), 0, "no launch counted yet")
	assert_eq(Progress.start_session(), 1, "the first launch is session 1 (ad-free)")
	assert_eq(Progress.start_session(), 2)
	Progress.load_from_disk()
	assert_eq(Progress.session_index(), 2)
	Progress.reset()
	assert_eq(Progress.session_index(), 0, "reset forgets the launches too")


func test_spending_more_than_you_have_spends_nothing() -> void:
	Progress.add_coins(50)
	assert_false(Progress.spend_coins(80))
	assert_eq(Progress.coins(), 50)
	assert_true(Progress.spend_coins(30))
	assert_eq(Progress.coins(), 20)


func test_next_level_stops_at_the_last_level() -> void:
	for level in range(1, 4):
		Progress.record_win(level, 1)
	assert_eq(Progress.next_level(3), 3)


func test_daily_reward_once_per_day() -> void:
	var first := Progress.daily_status("2026-10-01")
	assert_eq(first.day, 1)
	assert_true(first.can_claim)
	assert_eq(Progress.claim_daily("2026-10-01"), Progress.DAILY_REWARDS[0])
	assert_false(Progress.daily_status("2026-10-01").can_claim)
	assert_eq(Progress.claim_daily("2026-10-01"), 0, "second claim the same day gives nothing")


func test_daily_streak_grows_on_consecutive_days() -> void:
	Progress.claim_daily("2026-10-01")
	var next := Progress.daily_status("2026-10-02")
	assert_eq(next.day, 2)
	assert_eq(Progress.claim_daily("2026-10-02"), Progress.DAILY_REWARDS[1])
	assert_eq(Progress.coins(), Progress.DAILY_REWARDS[0] + Progress.DAILY_REWARDS[1])


func test_missing_a_day_restarts_the_streak() -> void:
	Progress.claim_daily("2026-10-01")
	Progress.claim_daily("2026-10-02")
	var after_gap := Progress.daily_status("2026-10-04")
	assert_eq(after_gap.day, 1)
	assert_eq(after_gap.streak, 0)


func test_streak_cycles_after_day_seven() -> void:
	for d in range(1, 9):
		Progress.claim_daily("2026-10-%02d" % d)
	assert_eq(Progress.daily_status("2026-10-08").day, 1, "day 8 is day 1 of the next cycle")
	assert_eq(Progress.daily_status("2026-10-09").day, 2)


func test_streak_crosses_month_ends() -> void:
	Progress.claim_daily("2026-10-31")
	assert_eq(Progress.daily_status("2026-11-01").day, 2)
