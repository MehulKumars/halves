extends GutTest
## HalvesState v2: slips (mistakes + stuck shuffles) and stars by slips, apply_deal's stuck flag, mist
## (veiled, revealed when first free, never hidden again), gold, locks and frost in try_pair, and solve,
## hint and shuffle on boards with features. Written from docs/HALVES.md alone; mostly hand-built boards.

const H := preload("res://tests/halves_helpers.gd")
const R := HalvesState.Result


func _column(texts: Array, features: Dictionary = {}) -> HalvesState:
	var g := H.geometry(H.column(texts.size()))
	if not features.is_empty():
		g = g.with_features(features)
	return HalvesState.new(g, H.faces(texts))


## Six tiles, ids in (z, y, x) order; 5 is a bridge on 0 and 1, the rest stand apart:
##   0 (0,0,0) circle a   1 (2,0,0) circle b   2 (8,0,0) tri a   3 (12,0,0) square a   4 (16,0,0) square b
##   5 (1,0,1) tri b
## Free at the start: 2, 3, 4, 5. Mist on 0, 1 and 3 (3 is free, so only 0 and 1 start veiled).
## Gold on 0 and 5.
func _mist_state() -> HalvesState:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(8, 0, 0), Vector3i(12, 0, 0),
			Vector3i(16, 0, 0), Vector3i(1, 0, 1)])
	return HalvesState.new(g.with_features({"mist": [0, 1, 3], "gold": [0, 5]}),
			H.faces(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "square:v:-:a", "square:v:-:b", "tri:v:-:b"]))


# --- slips and stars ---


func test_a_fresh_state_has_no_slips() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b"])
	assert_eq(s.stuck_shuffles, 0)
	assert_eq(s.slips(), 0)
	assert_eq(s.veiled, HalvesBits.empty(), "no features, no mist")
	assert_eq(s.gold, HalvesBits.empty(), "no features, no gold")
	assert_eq(s.gold_earned, 0)


func test_slips_are_mistakes_plus_stuck_shuffles() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:a", "tri:v:-:a", "tri:v:-:b"])
	assert_eq(s.try_pair(0, 1), R.MISMATCH)
	assert_eq(s.slips(), 1)
	s.apply_deal(s.remaining, s.faces, true)
	assert_eq(s.stuck_shuffles, 1)
	assert_eq(s.mistakes, 1, "apply_deal keeps mistakes")
	assert_eq(s.slips(), 2)
	s.mistakes = 3
	s.stuck_shuffles = 2
	assert_eq(s.slips(), 5)


func test_apply_deal_counts_only_stuck_shuffles() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b"])
	s.apply_deal(s.remaining, s.faces)
	assert_eq(s.stuck_shuffles, 0, "the default is not stuck")
	s.apply_deal(s.remaining, s.faces, false)
	assert_eq(s.stuck_shuffles, 0)
	s.apply_deal(s.remaining, s.faces, true)
	assert_eq(s.stuck_shuffles, 1)
	s.apply_deal(s.remaining, s.faces, true)
	assert_eq(s.stuck_shuffles, 2)
	assert_eq(s.mistakes, 0)


func test_stars_by_slips() -> void:
	assert_eq(HalvesConfig.STAR2_MAX_MISTAKES, 2)
	var s := _column(["circle:v:-:a", "circle:v:-:b"])
	var want := {0: 3, 1: 2, 2: 2, 3: 1, 4: 1}
	for n: int in want:
		s.mistakes = 0
		s.stuck_shuffles = n
		assert_eq(s.stars(), want[n], "%d stuck shuffles" % n)
		s.mistakes = n
		s.stuck_shuffles = 0
		assert_eq(s.stars(), want[n], "%d mistakes" % n)
	s.mistakes = 1
	s.stuck_shuffles = 1
	assert_eq(s.stars(), 2, "1 mistake + 1 stuck shuffle = 2 slips")
	s.mistakes = 2
	s.stuck_shuffles = 1
	assert_eq(s.stars(), 1, "3 slips")


func test_undo_does_not_take_back_a_stuck_shuffle() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:a", "tri:v:-:a", "tri:v:-:b"])
	s.apply_deal(s.remaining, s.faces, true)
	assert_eq(s.try_pair(0, 1), R.MISMATCH)
	assert_eq(s.slips(), 2)
	assert_true(s.undo(), "the mistake is undone")
	assert_eq(s.mistakes, 0)
	assert_eq(s.stuck_shuffles, 1, "the stuck shuffle stays")
	assert_eq(s.slips(), 1)
	assert_eq(s.stars(), 2)
	assert_false(s.undo(), "the shuffle cleared the history")
	assert_eq(s.stuck_shuffles, 1)


# --- mist ---


func test_mist_starts_veiled_only_where_not_free() -> void:
	var s := _mist_state()
	assert_eq(s.veiled, H.mask_of([0, 1]), "3 is free at the start, so it is shown at once")


func test_mist_is_revealed_when_a_tile_becomes_free_and_never_hidden_again() -> void:
	var s := _mist_state()
	assert_eq(s.try_pair(2, 5), R.MATCH, "the bridge goes")
	assert_eq(s.veiled, HalvesBits.empty(), "0 and 1 are free now")
	assert_true(s.undo())
	assert_eq(s.remaining, s.geometry.full_mask(), "the bridge is back on 0 and 1")
	assert_eq(s.veiled, HalvesBits.empty(), "revealing never hides a tile again")


func test_a_mismatch_reveals_nothing_new() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:a"], {"mist": [0, 1]})
	assert_eq(s.veiled, HalvesBits.empty(), "both free at the start")
	# Tile 0 lies under tile 1; tile 2 stands apart. All three are the same face.
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(4, 0, 0)]).with_features({"mist": [0]})
	var stacked := HalvesState.new(g, H.faces(["circle:v:-:a", "circle:v:-:a", "circle:v:-:a"]))
	assert_eq(stacked.veiled, H.bit(0))
	assert_eq(stacked.try_pair(1, 2), R.MISMATCH)
	assert_eq(stacked.veiled, H.bit(0), "still covered")


func test_mist_is_revealed_after_apply_deal() -> void:
	var s := _mist_state()
	var faces := H.faces(["circle:v:-:a", "circle:v:-:b", "", "square:v:-:a", "square:v:-:b", ""])
	s.apply_deal(s.geometry.full_mask(), s.faces)
	assert_eq(s.veiled, H.mask_of([0, 1]), "same board: still covered")
	s.apply_deal(H.mask_of([0, 1, 3, 4]), faces)
	assert_eq(s.veiled, HalvesBits.empty(), "the new board leaves 0 and 1 free")


func test_mist_is_revealed_after_undo() -> void:
	# In normal play undo cannot free a tile that was never free, so mark tiles veiled by hand to
	# see the reveal step run after undo (docs: reveal happens after _init, MATCH, undo and apply_deal).
	var s := _mist_state()
	assert_eq(s.try_pair(3, 4), R.MATCH)
	s.veiled = H.mask_of([1, 3])
	assert_true(s.undo())
	assert_eq(s.veiled, H.bit(1), "3 is back and free, so it is shown; 1 is still under the bridge")


func test_mist_has_no_effect_on_the_rules() -> void:
	var s := _mist_state()
	assert_eq(s.free_pairs(), H.pairs([Vector2i(2, 5), Vector2i(3, 4)]))
	assert_eq(s.try_pair(3, 4), R.MATCH, "a mist tile that is shown plays as usual")


# --- gold ---


func test_gold_mask_comes_from_the_features() -> void:
	assert_eq(_mist_state().gold, H.mask_of([0, 5]))
	assert_eq(_column(["circle:v:-:a", "circle:v:-:b"], {"gold": [1]}).gold, H.bit(1))


func test_gold_earned_goes_up_on_match_and_down_on_undo() -> void:
	var s := _mist_state()
	assert_eq(s.try_pair(2, 5), R.MATCH)
	assert_eq(s.gold_earned, 1, "tile 5 is gold")
	assert_eq(s.try_pair(1, 0), R.MATCH)
	assert_eq(s.gold_earned, 2, "tile 0 is gold")
	assert_eq(s.try_pair(3, 4), R.MATCH)
	assert_eq(s.gold_earned, 2, "no gold in this pair")
	assert_true(s.is_cleared())
	assert_true(s.undo())
	assert_eq(s.gold_earned, 2)
	assert_true(s.undo())
	assert_eq(s.gold_earned, 1, "tile 0 is back")
	assert_true(s.undo())
	assert_eq(s.gold_earned, 0)
	assert_eq(s.gold, H.mask_of([0, 5]), "the gold tiles stay gold")


func test_a_pair_of_two_gold_tiles_earns_two() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:a"], {"gold": [0, 1, 2]})
	assert_eq(s.try_pair(2, 3), R.MISMATCH)
	assert_eq(s.gold_earned, 0, "a mistake earns nothing")
	assert_true(s.undo())
	assert_eq(s.try_pair(0, 1), R.MATCH)
	assert_eq(s.gold_earned, 2)
	assert_true(s.undo())
	assert_eq(s.gold_earned, 0)


# --- locks and frost through try_pair ---


func test_a_locked_pair_is_blocked_until_the_keys_are_cleared() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b", "square:v:-:a", "square:v:-:b"],
			{"locks": [{"keys": [0, 1], "locked": [4, 5]}]})
	assert_eq(s.free_pairs(), H.pairs([Vector2i(0, 1), Vector2i(2, 3)]))
	assert_eq(s.try_pair(4, 5), R.BLOCKED)
	assert_eq(s.remaining, H.from_int(0b111111), "nothing changes")
	assert_eq(s.try_pair(0, 1), R.MATCH)
	assert_eq(s.free_pairs(), H.pairs([Vector2i(2, 3), Vector2i(4, 5)]))
	assert_eq(s.try_pair(4, 5), R.MATCH)
	assert_true(s.undo())
	assert_true(s.undo())
	assert_eq(s.try_pair(5, 4), R.BLOCKED, "the keys are back, so the lock is too")


func test_a_frosted_pair_is_blocked_until_a_touching_tile_goes() -> void:
	# Column: tile 1 touches 0 and 2.
	var s := _column(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b"], {"frost": [1]})
	assert_eq(s.try_pair(0, 1), R.BLOCKED)
	assert_eq(s.free_pairs(), H.pairs([Vector2i(2, 3)]))
	assert_eq(s.try_pair(2, 3), R.MATCH, "tile 2 touched tile 1")
	assert_eq(s.try_pair(0, 1), R.MATCH, "thawed")
	assert_true(s.is_cleared())


## A dealt plan board with every feature kind, as a state on the geometry with those features.
func _featured_state(level: int, seed_name: String) -> Dictionary:
	var g := H.plan_geometry(level)
	var spec := {"key_pairs": 1, "locked": 3, "frost": 3, "mist": 3, "gold": 2}
	var dealt := HalvesFill.deal_v2(g, H.plan_keys(level, g.size()),
			SeedService.make_rng(["test_halves_rules_v2", seed_name, level], 2), 0.4, spec)
	if dealt.is_empty():
		return {}
	var s := HalvesState.new(g.with_features(dealt["features"]), dealt["faces"])
	return {"state": s, "solution": H.pairs(dealt["solution"])}


func test_solve_and_hints_follow_the_feature_rules() -> void:
	for level: int in [9, 13]:
		var board := _featured_state(level, "solve")
		if board.is_empty():
			fail_test("level %d: no deal" % level)
			continue
		var s: HalvesState = board["state"]
		var result := HalvesSolver.solve(s.geometry, s.faces, s.remaining)
		assert_eq(result.get("status"), HalvesSolver.Status.SOLVED, "level %d" % level)
		assert_eq(H.replay_error(s, result.get("moves", [])), "", "level %d: solver moves replay under the features" % level)
		var t: HalvesState = _featured_state(level, "solve")["state"]
		var steps := 0
		while not t.is_cleared() and steps < t.geometry.size():
			var h := HalvesSolver.hint(t)
			assert_has(t.free_pairs(), H.norm(h), "level %d hint %d is a free match" % [level, steps])
			assert_eq(t.try_pair(h.x, h.y), R.MATCH)
			steps += 1
		assert_true(t.is_cleared(), "level %d: following hints clears a board with features" % level)


func test_shuffle_keeps_a_board_with_features_solvable() -> void:
	var board := _featured_state(9, "shuffle")
	if board.is_empty():
		fail_test("no deal")
		return
	var s: HalvesState = board["state"]
	var solution: Array[Vector2i] = board["solution"]
	for k: int in 3:
		assert_eq(s.try_pair(solution[k].x, solution[k].y), R.MATCH)
	var result := HalvesFill.shuffle(s, solution, SeedService.make_rng(["test_halves_rules_v2", "shuffle rng"], 2))
	assert_false(result.is_empty())
	if result.is_empty():
		return
	var rem: PackedInt64Array = result["remaining"]
	var faces: PackedInt32Array = result["faces"]
	assert_eq(H.faces_on(rem, faces), H.faces_on(s.remaining, s.faces), "same faces, new places")
	assert_true(H.solvable(s.geometry, faces, rem), "solvable under the features (locks and frost stay put)")


func test_stuck_counts_the_feature_rules() -> void:
	# Key 2's only mate is locked by it: no free pair at all.
	var s := _column(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b"],
			{"locks": [{"keys": [2], "locked": [0, 1, 3]}]})
	assert_true(s.free_pairs().is_empty())
	assert_true(s.is_stuck())
