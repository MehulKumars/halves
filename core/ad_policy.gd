class_name AdPolicy
extends RefCounted
## Decides when an interstitial may show. Pure logic, so it is unit-tested (tests/test_ad_policy.gd).
##
## Call can_show_interstitial() only when a results screen opens, after the win animation.
## Never attach an interstitial to Next / Retry / Play again, to level start, or to a fail
## screen that offers a continue: Google Play counts those as policy violations.
## Defaults follow the plan; tune per game through FeatureFlags-style overrides.

## No interstitials at all in the player's first session (protects day-1 retention).
var first_session_ad_free: bool = true
## Lowest level number (1-based) that may be followed by an interstitial.
var min_level: int = 8
## Won levels required since the last interstitial.
var won_levels_between: int = 2
## Minimum seconds between two interstitials.
var min_seconds_between: float = 120.0
## Interstitial cap per session.
var max_per_session: int = 3
## No interstitial this soon after the player watched a rewarded ad.
var rewarded_cooldown_sec: float = 60.0

## 1 = the player's first session ever. Persist and increment it in the game's save.
var session_index: int = 1

var _won_since_last: int = 0
var _shown_this_session: int = 0
var _last_interstitial_time: float = -INF
var _last_rewarded_time: float = -INF


func start_session(index: int) -> void:
	session_index = index
	_shown_this_session = 0


func record_level_result(won: bool) -> void:
	if won:
		_won_since_last += 1


func record_rewarded_shown(now_sec: float) -> void:
	_last_rewarded_time = now_sec


func record_interstitial_shown(now_sec: float) -> void:
	_last_interstitial_time = now_sec
	_won_since_last = 0
	_shown_this_session += 1


## `ritual_mode` is true for daily puzzles and zen modes, which never show interstitials.
func can_show_interstitial(level: int, won: bool, now_sec: float, ritual_mode: bool = false) -> bool:
	if ritual_mode:
		return false
	if first_session_ad_free and session_index <= 1:
		return false
	if not won:
		return false
	if level < min_level:
		return false
	if _won_since_last < won_levels_between:
		return false
	if _shown_this_session >= max_per_session:
		return false
	if now_sec - _last_interstitial_time < min_seconds_between:
		return false
	if now_sec - _last_rewarded_time < rewarded_cooldown_sec:
		return false
	return true
