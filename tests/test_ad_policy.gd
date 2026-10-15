extends GutTest
## AdPolicy encodes the plan's interstitial rules. Each test checks one rule.

var policy: AdPolicy


func before_each() -> void:
	policy = AdPolicy.new()
	policy.start_session(2)  # past the ad-free first session unless a test says otherwise


func _win_levels(count: int) -> void:
	for i in count:
		policy.record_level_result(true)


func test_allows_after_two_wins_past_min_level() -> void:
	_win_levels(2)
	assert_true(policy.can_show_interstitial(8, true, 1000.0))


func test_first_session_is_ad_free() -> void:
	policy.start_session(1)
	_win_levels(5)
	assert_false(policy.can_show_interstitial(20, true, 1000.0))


func test_never_after_a_fail() -> void:
	_win_levels(2)
	assert_false(policy.can_show_interstitial(9, false, 1000.0))


func test_never_before_min_level() -> void:
	_win_levels(2)
	assert_false(policy.can_show_interstitial(7, true, 1000.0))


func test_needs_two_wins_since_last_interstitial() -> void:
	_win_levels(2)
	policy.record_interstitial_shown(1000.0)
	policy.record_level_result(true)
	assert_false(policy.can_show_interstitial(10, true, 2000.0))
	policy.record_level_result(true)
	assert_true(policy.can_show_interstitial(11, true, 2000.0))


func test_respects_minimum_gap() -> void:
	_win_levels(2)
	policy.record_interstitial_shown(1000.0)
	_win_levels(2)
	assert_false(policy.can_show_interstitial(12, true, 1100.0))
	assert_true(policy.can_show_interstitial(12, true, 1120.0))


func test_respects_session_cap() -> void:
	policy.max_per_session = 1
	_win_levels(2)
	policy.record_interstitial_shown(0.0)
	_win_levels(2)
	assert_false(policy.can_show_interstitial(12, true, 10000.0))
	policy.start_session(3)
	assert_true(policy.can_show_interstitial(12, true, 10000.0))


func test_cooldown_after_rewarded_ad() -> void:
	_win_levels(2)
	policy.record_rewarded_shown(1000.0)
	assert_false(policy.can_show_interstitial(9, true, 1030.0))
	assert_true(policy.can_show_interstitial(9, true, 1061.0))


func test_daily_and_zen_modes_never_show() -> void:
	_win_levels(2)
	assert_false(policy.can_show_interstitial(9, true, 1000.0, true))
