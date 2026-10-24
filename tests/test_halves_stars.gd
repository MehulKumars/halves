extends GutTest
## Stars v3, the slip allowance: HalvesConfig's constants and star_allowance, HalvesState.stars(allowance)
## (thresholds, unlimited, slips = mistakes + stuck shuffles, undo, at least one star), and
## HalvesRun.replay(..., allowance) on real baked levels.
## Written from docs/HALVES.md (contract v3) alone, in a separate session from the implementation.

const H := preload("res://tests/halves_helpers.gd")
const R := HalvesState.Result
const E := HalvesRun.Event
const LEVELS: int = Screens.Mode.LEVELS
const DAILY: int = Screens.Mode.DAILY


## Section 1, Stars (v3): 3 if A < 0 or slips <= A; 2 if slips <= A + 3; else 1.
func _want(slips: int, allowance: int) -> int:
	if allowance < 0 or slips <= allowance:
		return 3
	if slips <= allowance + 3:
		return 2
	return 1


func _column(texts: Array) -> HalvesState:
	return H.state(H.column(texts.size()), texts)


# --- HalvesConfig ---


func test_constants() -> void:
	assert_eq(HalvesConfig.STAR_FREE_LEVELS, 10)
	assert_eq(HalvesConfig.STAR_ALLOWANCE_PAIRS, 15)
	assert_eq(HalvesConfig.STAR2_EXTRA_SLIPS, 3)


func test_levels_1_to_10_have_no_limit() -> void:
	for level: int in range(1, 11):
		for pairs: int in [0, 1, 8, 15, 30, 64]:
			assert_eq(HalvesConfig.star_allowance(LEVELS, level, pairs), -1, "level %d, %d pairs" % [level, pairs])


func test_allowance_after_level_10_grows_with_the_pairs() -> void:
	# max(1, pairs / 15) with integer division.
	var table := {0: 1, 1: 1, 7: 1, 14: 1, 15: 1, 16: 1, 29: 1, 30: 2, 31: 2, 44: 2, 45: 3, 59: 3, 60: 4, 64: 4}
	for level: int in [11, 12, 20, 55, 100]:
		for pairs: int in table:
			assert_eq(HalvesConfig.star_allowance(LEVELS, level, pairs), table[pairs], "level %d, %d pairs" % [level, pairs])


func test_daily_boards_use_the_pairs_on_any_level_number() -> void:
	# Only the LEVELS mode has free levels; a daily board always has an allowance.
	for level: int in [1, 5, 10, 11, 10000, 10042]:
		assert_eq(HalvesConfig.star_allowance(DAILY, level, 20), 1, "daily, level %d, 20 pairs" % level)
		assert_eq(HalvesConfig.star_allowance(DAILY, level, 47), 3, "daily, level %d, 47 pairs" % level)


func test_baked_levels_have_the_documented_allowance() -> void:
	for n: int in [1, 10, 11, 25, 50, 100]:
		var data := HalvesLevels.get_level(n)
		if data == null:
			fail_test("level %d missing" % n)
			continue
		var pairs := int(data.positions.size() / 2.0)
		var want := -1 if n <= 10 else maxi(1, int(pairs / 15.0))
		assert_eq(HalvesConfig.star_allowance(LEVELS, n, pairs), want, "level %d (%d pairs)" % [n, pairs])


# --- HalvesState.stars(allowance) ---


func test_stars_by_slips_and_allowance() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b"])
	for allowance: int in [0, 1, 2, 3, 4]:
		for slips: int in range(0, allowance + 8):
			s.mistakes = slips
			s.stuck_shuffles = 0
			assert_eq(s.stars(allowance), _want(slips, allowance), "%d mistakes, allowance %d" % [slips, allowance])
			s.mistakes = 0
			s.stuck_shuffles = slips
			assert_eq(s.stars(allowance), _want(slips, allowance), "%d stuck shuffles, allowance %d" % [slips, allowance])


func test_the_edges_of_each_band() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b"])
	s.mistakes = 2
	assert_eq(s.stars(2), 3, "slips == allowance keeps 3 stars")
	s.mistakes = 3
	assert_eq(s.stars(2), 2, "one over")
	s.mistakes = 5
	assert_eq(s.stars(2), 2, "allowance + 3")
	s.mistakes = 6
	assert_eq(s.stars(2), 1, "allowance + 4")


func test_an_unlimited_allowance_always_gives_three() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b"])
	for slips: int in [0, 1, 3, 4, 10, 100]:
		s.mistakes = slips
		assert_eq(s.stars(-1), 3, "%d slips, unlimited" % slips)
		assert_eq(s.stars(-7), 3, "%d slips, any negative allowance" % slips)


func test_slips_add_mistakes_and_stuck_shuffles() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b"])
	s.mistakes = 1
	s.stuck_shuffles = 1
	assert_eq(s.stars(1), 2, "2 slips over an allowance of 1")
	assert_eq(s.stars(2), 3)
	s.mistakes = 3
	s.stuck_shuffles = 2
	assert_eq(s.stars(1), 1, "5 slips: over 1 + 3")


func test_the_default_allowance_is_zero() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b"])
	for slips: int in range(0, 7):
		s.mistakes = slips
		assert_eq(s.stars(), s.stars(0), "%d slips" % slips)
	s.mistakes = 3
	assert_eq(s.stars(0), 2, "v3: 2 stars up to 3 slips (v2 gave 1 here)")
	s.mistakes = 4
	assert_eq(s.stars(0), 1)


func test_a_cleared_board_gets_at_least_one_star() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:a", "circle:v:-:b", "circle:v:-:b"])
	for i: int in 30:
		assert_eq(s.try_pair(0, 1), R.MISMATCH)
	assert_eq(s.try_pair(0, 2), R.MATCH)
	assert_eq(s.try_pair(1, 3), R.MATCH)
	assert_true(s.is_cleared())
	assert_eq(s.slips(), 30)
	for allowance: int in [-1, 0, 1, 4, 26]:
		assert_gte(s.stars(allowance), 1, "allowance %d" % allowance)
	assert_eq(s.stars(1), 1)


func test_undo_takes_a_mistake_back_under_an_allowance() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:a", "tri:v:-:a", "tri:v:-:b"])
	assert_eq(s.try_pair(0, 1), R.MISMATCH)
	assert_eq(s.stars(1), 3, "one slip is free with an allowance of 1")
	assert_eq(s.try_pair(1, 0), R.MISMATCH)
	assert_eq(s.stars(1), 2, "the second costs a star")
	assert_true(s.undo())
	assert_eq(s.slips(), 1)
	assert_eq(s.stars(1), 3, "undo takes the mistake back")


func test_free_mistakes_and_plain_shuffles_cost_nothing() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:a", "tri:v:-:a", "tri:v:-:b"])
	s.free_mistakes = 1
	assert_eq(s.try_pair(0, 1), R.MISMATCH)
	assert_eq(s.slips(), 0, "the tutorial's free mistake")
	s.apply_deal(s.remaining, s.faces)
	assert_eq(s.slips(), 0, "a shuffle that is not stuck is not a slip (boosters cost no stars)")
	assert_eq(s.stars(0), 3)


# --- HalvesRun.replay(..., allowance) ---


func _new_run(data: HalvesLevelData) -> HalvesRun:
	var run := HalvesRun.new()
	run.board = "level_%d" % data.level
	run.level = data.level
	run.gen_version = HalvesLevels.gen_version()
	run.free_mistakes = 0
	run.strict = false
	return run


## The first (level, step, free decoy pair) along a level's solution, or [].
func _find_decoy(from_level: int) -> Array:
	for n: int in range(from_level, HalvesLevels.count() + 1):
		var data := HalvesLevels.get_level(n)
		if data == null:
			continue
		var s := data.new_state()
		for k: int in data.solution.size():
			var d := H.free_decoy(s)
			if d.x >= 0:
				return [data, k, d]
			s.try_pair(data.solution[k].x, data.solution[k].y)
	return []


## A run that follows the solution and makes `mismatches` mistakes on the decoy at step k.
func _run_with_mistakes(data: HalvesLevelData, k: int, decoy: Vector2i, mismatches: int) -> Dictionary:
	var run := _new_run(data)
	for p: Vector2i in data.solution.slice(0, k):
		run.advance(40)
		run.record(E.PAIR, p.x, p.y)
	for i: int in mismatches:
		run.advance(40)
		run.record(E.MISMATCH, decoy.x, decoy.y)
	for p: Vector2i in data.solution.slice(k):
		run.advance(40)
		run.record(E.PAIR, p.x, p.y)
	run.finish()
	return run.to_dict()


func _check(r: Dictionary, stars: int, slips: int, label: String) -> void:
	assert_eq(r.get("ok"), true, "%s: ok (%s)" % [label, r.get("error", "")])
	assert_eq(r.get("cleared"), true, label + ": cleared")
	assert_eq(r.get("slips"), slips, label + ": slips")
	assert_eq(r.get("stars"), stars, label + ": stars")


func test_replay_counts_stars_with_the_allowance() -> void:
	var found := _find_decoy(1)
	if found.is_empty():
		pending("no level offers a free decoy along its solution")
		return
	var data: HalvesLevelData = found[0]
	var k: int = found[1]
	var decoy: Vector2i = found[2]
	var one := _run_with_mistakes(data, k, decoy, 1)
	_check(HalvesRun.replay(data, one), 2, 1, "1 slip, default allowance 0")
	_check(HalvesRun.replay(data, one, -1, 0), 2, 1, "1 slip, allowance 0")
	_check(HalvesRun.replay(data, one, -1, 1), 3, 1, "1 slip, allowance 1")
	_check(HalvesRun.replay(data, one, -1, -1), 3, 1, "1 slip, unlimited")
	var two := _run_with_mistakes(data, k, decoy, 2)
	_check(HalvesRun.replay(data, two, -1, 1), 2, 2, "2 slips, allowance 1")
	_check(HalvesRun.replay(data, two, -1, 2), 3, 2, "2 slips, allowance 2")
	var five := _run_with_mistakes(data, k, decoy, 5)
	_check(HalvesRun.replay(data, five, -1, 1), 1, 5, "5 slips, allowance 1")
	_check(HalvesRun.replay(data, five, -1, 2), 2, 5, "5 slips, allowance 2")
	_check(HalvesRun.replay(data, five, -1, -1), 3, 5, "5 slips, unlimited")


func test_replay_with_the_games_allowance() -> void:
	var found := _find_decoy(HalvesConfig.STAR_FREE_LEVELS + 1)
	if found.is_empty():
		pending("no level after 10 offers a free decoy along its solution")
		return
	var data: HalvesLevelData = found[0]
	var k: int = found[1]
	var decoy: Vector2i = found[2]
	var allowance := HalvesConfig.star_allowance(LEVELS, data.level, int(data.positions.size() / 2.0))
	assert_gte(allowance, 1, "test setup: level %d is past the free levels" % data.level)
	_check(HalvesRun.replay(data, _run_with_mistakes(data, k, decoy, allowance), -1, allowance), 3, allowance,
			"level %d: as many slips as the allowance" % data.level)
	_check(HalvesRun.replay(data, _run_with_mistakes(data, k, decoy, allowance + 1), -1, allowance), 2, allowance + 1,
			"level %d: one more" % data.level)
