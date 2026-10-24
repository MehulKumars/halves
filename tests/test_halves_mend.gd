extends GutTest
## Contract v3 M3 mechanics, part 2: the gold pair earns a mend; HalvesState.try_mend and mend_mate
## (result order, which mate is taken, history, not a slip, pairs_done, undo, lucky clocks, mist); a
## mend keeps a solvable board solvable (twin boards exhaustively, baked v2 and crest boards); the
## bots' mends; HalvesRun Event.MEND replay. Written from docs/HALVES.md (contract v3) alone.

const H := preload("res://tests/halves_helpers.gd")
const R := HalvesState.Result
const E := HalvesRun.Event
const P := HalvesBot.Policy
const STEP_MS := 40


func _rng(parts: Array) -> RandomNumberGenerator:
	return SeedService.make_rng(["test_halves_mend"] + parts, 3)


func _gold_a() -> int:
	return HalvesCrests.pair_of(HalvesCrests.motif_index(&"kin"), 0) << 1


func _gold_b() -> int:
	return _gold_a() | 1


## Text faces like H.faces, plus "gold:a" / "gold:b" for the gold pair.
func _faces(texts: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for t: String in texts:
		if t == "gold:a":
			out.append(_gold_a())
		elif t == "gold:b":
			out.append(_gold_b())
		else:
			out.append(-1 if t == "" else HalvesFace.from_text(t))
	return out


func _state(points: Array, texts: Array, features: Dictionary = {}) -> HalvesState:
	var g := H.geometry(points)
	if not features.is_empty():
		g = g.with_features(features)
	return HalvesState.new(g, _faces(texts))


func _clocks(s: HalvesState) -> String:
	var out := {}
	for t: int in s.lucky_start:
		out[t] = int(s.lucky_start[t])
	return H.js(out)


func _level(n: int) -> HalvesLevelData:
	var data := HalvesLevels.get_level(n)
	if data == null:
		fail_test("level %d missing from %s" % [n, HalvesLevels.PATH])
	return data


## Free tiles of `s` whose face has a mate among the other remaining tiles.
func _mendable(s: HalvesState) -> Array[int]:
	var out: Array[int] = []
	for a: int in s.geometry.free_tiles(s.remaining):
		if _lowest_mate(s, a) >= 0:
			out.append(a)
	return out


## The lowest-id remaining tile whose face is the mate of a's face, or -1.
func _lowest_mate(s: HalvesState, a: int) -> int:
	var all := _mates(s.faces, s.remaining, a)
	return all[0] if not all.is_empty() else -1


## Every tile of `left` (ascending) whose face is the mate of a's face.
func _mates(faces: PackedInt32Array, left: PackedInt64Array, a: int) -> Array[int]:
	var out: Array[int] = []
	var mate := HalvesFace.mate(faces[a])
	for t: int in HalvesBits.ids(left):
		if t != a and faces[t] == mate:
			out.append(t)
	return out


## Section 1, "Which mate a mend takes", with the solver as the contract says: one mate -> that one;
## else the lowest-id mate whose removal with `a` the solver proves solvable within MEND_BUDGET;
## else the lowest-id mate not proven unsolvable; else the lowest-id mate. -1 without a mate.
## Also returns which rule decided ("one", "proven", "not_unsolvable", "lowest").
func _ref_mend_mate(g: HalvesGeometry, faces: PackedInt32Array, left: PackedInt64Array, a: int) -> Dictionary:
	var all := _mates(faces, left, a)
	if all.is_empty():
		return {"b": -1, "rule": "none"}
	if all.size() == 1:
		return {"b": all[0], "rule": "one"}
	var not_unsolvable := -1
	for m: int in all:
		var after := HalvesBits.minus(left, H.mask_of([a, m]))
		var status: int = HalvesSolver.solve(g, faces, after, HalvesConfig.MEND_BUDGET).get("status")
		if status == HalvesSolver.Status.SOLVED:
			return {"b": m, "rule": "proven"}
		if status != HalvesSolver.Status.UNSOLVABLE and not_unsolvable < 0:
			not_unsolvable = m
	if not_unsolvable >= 0:
		return {"b": not_unsolvable, "rule": "not_unsolvable"}
	return {"b": all[0], "rule": "lowest"}


## The same rule with the brute-force check instead of the solver, for boards small enough that
## the solver is exact within MEND_BUDGET (so "not proven unsolvable" never applies).
func _brute_mend_mate(g: HalvesGeometry, faces: PackedInt32Array, left: PackedInt64Array, a: int) -> int:
	var all := _mates(faces, left, a)
	if all.size() <= 1:
		return all[0] if not all.is_empty() else -1
	for m: int in all:
		if H.solvable(g, faces, HalvesBits.minus(left, H.mask_of([a, m]))):
			return m
	return all[0]


## The state of `data` (or `faces` on its geometry) after the first `k` pairs of its solution.
func _state_after(data: HalvesLevelData, faces: PackedInt32Array, k: int) -> HalvesState:
	var s := HalvesState.new(data.geometry(), faces)
	for i: int in k:
		var r := s.try_pair(data.solution[i].x, data.solution[i].y)
		if r != R.MATCH:
			fail_test("level %d step %d: %d, not MATCH" % [data.level, i, r])
	return s


# --- the gold pair earns a mend ---


## 0 (0,0,0) circle b under 3 (0,0,1) circle a: a half on its only mate. 1 (4,0,0) and 2 (8,0,0)
## are the gold pair.
func _gold_dead_end() -> HalvesState:
	return _state([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0), Vector3i(0, 0, 1)],
			["circle:v:-:b", "gold:a", "gold:b", "circle:v:-:a"])


func test_a_gold_match_earns_one_mend() -> void:
	var s := _gold_dead_end()
	assert_eq(s.mends, 0)
	assert_eq(s.try_pair(2, 1), R.MATCH)
	assert_eq(s.mends, 1, "clearing the gold pair gives one mend")
	assert_eq(s.pairs_done, 1)
	assert_eq(s.slips(), 0)
	assert_true(s.undo())
	assert_eq(s.mends, 0, "undo takes back the mend the gold pair earned")
	assert_eq(s.pairs_done, 0)


func test_only_a_gold_match_earns_a_mend() -> void:
	var s := _state(H.column(6), ["circle:v:-:a", "circle:v:-:b", "gold:a", "gold:a", "tri:v:-:a", "tri:v:-:b"],
			{"gold": [0, 1, 4, 5]})
	assert_eq(s.try_pair(0, 1), R.MATCH)
	assert_eq(s.mends, 0, "a v2 gold (coin) tile is not the gold pair")
	assert_eq(s.gold_earned, 2)
	assert_eq(s.try_pair(2, 3), R.MISMATCH, "two gold halves of the same side are twins")
	assert_eq(s.mends, 0, "a mistake earns nothing")
	assert_eq(s.try_pair(4, 5), R.MATCH)
	assert_eq(s.mends, 0)


func test_try_mend_full_flow_on_a_dead_end() -> void:
	var s := _gold_dead_end()
	assert_eq(s.try_mend(3), R.INVALID, "no mend yet")
	assert_eq(s.try_pair(1, 2), R.MATCH)
	assert_true(s.is_stuck(), "a half on its only mate")
	assert_eq(s.try_mend(3), R.MATCH)
	assert_true(s.is_cleared(), "the covered mate is taken")
	assert_eq(s.mends, 0)
	assert_eq(s.pairs_done, 2)
	assert_eq(s.slips(), 0, "a mend is not a slip")
	assert_eq(s.mistakes, 0)
	assert_eq(s.stars(0), 3)
	assert_eq(s.history, [{"kind": "pair", "a": 1, "b": 2}, {"kind": "mend", "a": 3, "b": 0}])
	assert_eq(s.last_action(), {"kind": "mend", "a": 3, "b": 0})
	assert_true(s.undo())
	assert_eq(s.remaining, H.mask_of([0, 3]), "both tiles return")
	assert_eq(s.mends, 1, "the spent mend is returned")
	assert_eq(s.pairs_done, 1)
	assert_eq(s.history, [{"kind": "pair", "a": 1, "b": 2}])
	assert_true(s.undo())
	assert_eq(s.mends, 0, "and the gold pair's mend is taken back")
	assert_eq(s.remaining, s.geometry.full_mask())
	assert_eq(s.try_mend(3), R.INVALID, "no mend after undoing the gold pair")


# --- try_mend: result order and which mate is taken ---


## Ids in (z, y, x) order; layer 0 stands four half-units apart:
##   0 (0,0,0) circle b [under 6]   1 (4,0,0) tri a [under 7; no tri b anywhere]   2 (8,0,0) circle a
##   3 (12,0,0) circle b   4 (16,0,0) square a [no square b]   5 (20,0,0) circle a (twin of 2)
##   6 (0,0,1) diamond a   7 (4,0,1) diamond b
func _mend_board() -> HalvesState:
	return _state([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0), Vector3i(12, 0, 0), Vector3i(16, 0, 0),
			Vector3i(20, 0, 0), Vector3i(0, 0, 1), Vector3i(4, 0, 1)],
			["circle:v:-:b", "tri:v:-:a", "circle:v:-:a", "circle:v:-:b", "square:v:-:a", "circle:v:-:a",
			"diamond:v:-:a", "diamond:v:-:b"])


func _assert_unchanged(s: HalvesState, mends: int, label: String) -> void:
	assert_eq(s.remaining, s.geometry.full_mask(), label + ": remaining unchanged")
	assert_eq(s.mends, mends, label + ": mends unchanged")
	assert_true(s.history.is_empty(), label + ": no history")
	assert_eq(s.pairs_done, 0, label + ": pairs_done unchanged")
	assert_eq(s.mistakes, 0, label + ": no mistake")


func test_try_mend_without_a_mend_is_invalid() -> void:
	var s := _mend_board()
	assert_eq(s.try_mend(2), R.INVALID, "free with a mate, but mends == 0")
	assert_eq(s.try_mend(0), R.INVALID, "mends == 0 comes before BLOCKED")
	_assert_unchanged(s, 0, "mends 0")


func test_try_mend_invalid_and_blocked() -> void:
	var s := _mend_board()
	s.mends = 1
	assert_eq(s.try_mend(-1), R.INVALID, "id out of range")
	assert_eq(s.try_mend(8), R.INVALID, "id == size")
	assert_eq(s.try_mend(1000), R.INVALID, "id far out")
	assert_eq(s.try_mend(4), R.INVALID, "free, but no tile has its mate face")
	assert_eq(s.try_mend(1), R.INVALID, "covered and no mate: INVALID comes before BLOCKED")
	_assert_unchanged(s, 1, "invalid")
	assert_eq(s.try_mend(0), R.BLOCKED, "covered, with mates 2 and 5 remaining")
	_assert_unchanged(s, 1, "blocked")


func test_try_mend_on_a_board_no_mate_can_save_takes_the_lowest_id_mate() -> void:
	# The board can never clear (tri a and square a have no mates), so the solver proves both mates
	# of 2 (0 and 3) unsolvable and mend_mate falls back to the lowest-id mate: 0, though covered.
	var s := _mend_board()
	assert_eq(HalvesState.mend_mate(s.geometry, s.faces, s.remaining, 2), 0)
	assert_eq(HalvesState.mend_mate(s.geometry, s.faces, s.remaining, 2), int(_ref_mend_mate(s.geometry, s.faces,
			s.remaining, 2)["b"]), "the contract's rule, with the solver")
	s.mends = 1
	assert_eq(s.try_mend(2), R.MATCH)
	assert_eq(s.remaining, H.mask_of([1, 3, 4, 5, 6, 7]), "2 and 0 (the lowest-id circle b, covered) leave; 3 stays")
	assert_eq(s.mends, 0)
	assert_eq(s.pairs_done, 1)
	assert_eq(s.history, [{"kind": "mend", "a": 2, "b": 0}])
	assert_eq(s.slips(), 0)
	assert_eq(s.mistakes, 0)
	s.mends = 1
	assert_eq(s.try_mend(2), R.INVALID, "2 is not remaining")
	assert_eq(s.try_mend(3), R.MATCH, "3's mates are 5 only now (2 is gone)")
	assert_eq(s.remaining, H.mask_of([1, 4, 6, 7]), "the twin 5 was taken")
	assert_eq(s.last_action(), {"kind": "mend", "a": 3, "b": 5})


func test_try_mend_never_takes_a_twin() -> void:
	var s := _state(H.column(4), ["circle:v:-:a", "circle:v:-:a", "circle:v:-:a", "circle:v:-:b"])
	s.mends = 1
	assert_eq(s.try_mend(1), R.MATCH)
	assert_eq(s.remaining, H.mask_of([0, 2]), "the mate face (3), not the lower-id twins")


## Section 1's example: 0 (0,0,0) circle a, 1 (4,0,0) circle b, 2 (6,0,0) circle a, and 3 (5,0,1)
## circle b bridging 1 and 2. Solvable: (0, 3), then (1, 2).
func _bridge_board() -> HalvesState:
	return _state([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0), Vector3i(5, 0, 1)],
			["circle:v:-:a", "circle:v:-:b", "circle:v:-:a", "circle:v:-:b"])


func test_mend_on_the_bridge_board_takes_the_top_circle() -> void:
	# Regression: the lowest-id circle b (1, under the bridge) would leave 3 lying on its only mate 2.
	var s := _bridge_board()
	assert_true(H.solvable(s.geometry, s.faces, s.remaining), "test setup: solvable before the mend")
	assert_eq(HalvesState.mend_mate(s.geometry, s.faces, s.remaining, 0), 3)
	s.mends = 1
	assert_eq(s.try_mend(0), R.MATCH)
	assert_eq(s.remaining, H.mask_of([1, 2]), "0 and the top circle b (3) leave, not 1")
	assert_eq(s.last_action(), {"kind": "mend", "a": 0, "b": 3})
	assert_eq(s.try_pair(1, 2), R.MATCH, "the board stays solvable")
	assert_true(s.is_cleared())


## 0 (0,0,0) circle a   1 (4,0,0) circle b   2 (6,0,0) circle a   3 (10,0,0) circle a [under 5]
## 4 (5,0,1) circle b, a bridge on 1 and 2   5 (10,0,1) circle b, on 3.
## Mates of 0: 1 (strands: 4 and 5 are then twins on circle a's), 4 (safe) and 5 (safe).
func _three_mates_board() -> HalvesState:
	return _state([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0), Vector3i(10, 0, 0), Vector3i(5, 0, 1),
			Vector3i(10, 0, 1)], ["circle:v:-:a", "circle:v:-:b", "circle:v:-:a", "circle:v:-:a", "circle:v:-:b",
			"circle:v:-:b"])


func test_mend_mate_takes_the_lowest_id_safe_mate() -> void:
	var s := _three_mates_board()
	var g := s.geometry
	assert_true(H.solvable(g, s.faces, s.remaining), "test setup: solvable")
	assert_false(H.solvable(g, s.faces, H.mask_of([2, 3, 4, 5])), "test setup: mate 1 strands")
	assert_true(H.solvable(g, s.faces, H.mask_of([1, 2, 3, 5])), "test setup: mate 4 is safe")
	assert_true(H.solvable(g, s.faces, H.mask_of([1, 2, 3, 4])), "test setup: mate 5 is safe")
	assert_eq(HalvesState.mend_mate(g, s.faces, s.remaining, 0), 4, "the lowest-id mate that keeps it solvable")
	s.mends = 1
	assert_eq(s.try_mend(0), R.MATCH)
	assert_eq(s.remaining, H.mask_of([1, 2, 3, 5]))


func test_mend_mate_with_one_mate_takes_it_whatever_blocks_it() -> void:
	# The only circle b (1) is under 3, and the board can never clear (tri a and square a have no mates).
	var s := _state([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0), Vector3i(4, 0, 1)],
			["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "square:v:-:a"])
	assert_eq(HalvesState.mend_mate(s.geometry, s.faces, s.remaining, 0), 1)
	var dead := _gold_dead_end()
	assert_eq(HalvesState.mend_mate(dead.geometry, dead.faces, dead.remaining, 3), 0, "the mate under it")


func test_mend_mate_is_minus_one_without_a_mate() -> void:
	var s := _mend_board()
	assert_eq(HalvesState.mend_mate(s.geometry, s.faces, s.remaining, 4), -1, "no square b on the board")
	assert_eq(HalvesState.mend_mate(s.geometry, s.faces, H.mask_of([1, 2, 4, 5, 6, 7]), 2), -1,
			"both circle b tiles are gone from `left`")
	assert_eq(HalvesState.mend_mate(s.geometry, s.faces, s.remaining, 3), 2, "a twin pair of mates on a board no mate saves")


func test_mend_mate_reads_left_and_does_not_change_it() -> void:
	var s := _three_mates_board()
	var left := s.remaining.duplicate()
	var keep := left.duplicate()
	HalvesState.mend_mate(s.geometry, s.faces, left, 0)
	assert_eq(left, keep, "left is not changed")
	# `left` without 2 and 4: mate 1 leaves 5 on its only mate 3; mate 5 leaves 1 and 3 free.
	assert_eq(HalvesState.mend_mate(s.geometry, s.faces, H.mask_of([0, 1, 3, 5]), 0), 5, "the set passed as left counts")
	assert_eq(_brute_mend_mate(s.geometry, s.faces, H.mask_of([0, 1, 3, 5]), 0), 5, "test setup")


func test_try_mend_is_invalid_once_the_mate_is_gone() -> void:
	var s := _state(H.column(3), ["circle:v:-:a", "circle:v:-:b", "circle:v:-:a"])
	assert_eq(s.try_pair(0, 1), R.MATCH)
	s.mends = 1
	assert_eq(s.try_mend(2), R.INVALID, "no remaining tile has the mate face")
	assert_eq(s.mends, 1)
	assert_eq(s.remaining, H.bit(2))


func test_try_mend_takes_a_side_blocked_mate() -> void:
	# A row of three: 1 (the only circle b) is between 0 and 2; 3 stands apart.
	var s := _state([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0)],
			["tri:v:-:a", "circle:v:-:b", "tri:v:-:b", "circle:v:-:a"])
	assert_false(s.geometry.is_free(1, s.remaining), "test setup")
	s.mends = 1
	assert_eq(s.try_mend(3), R.MATCH)
	assert_eq(s.remaining, H.mask_of([0, 2]))


func test_try_mend_takes_a_locked_or_frosted_mate() -> void:
	var locked := _state(H.column(4), ["tri:v:-:a", "circle:v:-:a", "tri:v:-:b", "circle:v:-:b"],
			{"locks": [{"keys": [0], "locked": [3]}]})
	locked.mends = 1
	assert_eq(locked.try_mend(1), R.MATCH, "the only mate is locked")
	assert_eq(locked.remaining, H.mask_of([0, 2]))
	var frosted := _state(H.column(4), ["circle:v:-:a", "tri:v:-:a", "tri:v:-:b", "circle:v:-:b"], {"frost": [3]})
	assert_false(frosted.geometry.is_free(3, frosted.remaining), "test setup")
	frosted.mends = 1
	assert_eq(frosted.try_mend(0), R.MATCH, "the only mate is frosted")
	assert_eq(frosted.remaining, H.mask_of([1, 2]))


func test_try_mend_needs_a_free_tile_under_the_feature_rules() -> void:
	var s := _state(H.column(4), ["tri:v:-:a", "circle:v:-:a", "circle:v:-:b", "tri:v:-:b"],
			{"locks": [{"keys": [0], "locked": [1]}], "frost": [2]})
	s.mends = 1
	assert_eq(s.try_mend(1), R.BLOCKED, "a locked tile")
	assert_eq(s.try_mend(2), R.BLOCKED, "a frosted tile")
	assert_eq(s.mends, 1)
	assert_eq(s.try_mend(3), R.MATCH, "a key is free")
	assert_eq(s.remaining, H.mask_of([1, 2]))


func test_a_stuck_board_with_a_mend_is_still_stuck_and_hints_nothing() -> void:
	var s := _gold_dead_end()
	assert_eq(s.try_pair(1, 2), R.MATCH)
	assert_eq(s.mends, 1)
	assert_true(s.is_stuck(), "a mend is not a free pair")
	assert_true(s.free_pairs().is_empty())
	assert_eq(HalvesSolver.hint(s), Vector2i(-1, -1), "the hint never suggests a mend")


func test_a_mend_reveals_mist() -> void:
	# Section 1: a mist face is hidden until the tile is free for the first time.
	# 0 (0,0,0) square a [mist, under 3]   1 (4,0,0) circle b [mist, free]   2 (8,0,0) square b   3 (0,0,1) circle a
	var s := _state([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0), Vector3i(0, 0, 1)],
			["square:v:-:a", "circle:v:-:b", "square:v:-:b", "circle:v:-:a"], {"mist": [0, 1]})
	assert_eq(s.veiled, H.bit(0), "test setup")
	s.mends = 1
	assert_eq(s.try_mend(3), R.MATCH)
	assert_eq(s.veiled, HalvesBits.empty(), "tile 0 is free after the mend, so it is shown")
	assert_true(s.undo())
	assert_eq(s.veiled, HalvesBits.empty(), "never hidden again")


# --- mends and lucky clocks ---


## Same board as test_halves_mechanics: 0 circle a [lucky, under 9], 1 circle b, 2 tri a [lucky],
## 3 tri b, 4/5 diamond, 6/7 square:h, 8 circle dot a, 9 (0,0,1) circle dot b on tile 0.
func _lucky_state() -> HalvesState:
	return _state([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0), Vector3i(12, 0, 0),
			Vector3i(16, 0, 0), Vector3i(20, 0, 0), Vector3i(24, 0, 0), Vector3i(28, 0, 0), Vector3i(32, 0, 0),
			Vector3i(0, 0, 1)], ["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b", "diamond:v:-:a",
			"diamond:v:-:b", "square:h:-:a", "square:h:-:b", "circle:v:dot:a", "circle:v:dot:b"], {"lucky": [0, 2]})


func test_a_mend_of_a_lucky_tile_in_time_wins_it() -> void:
	var s := _lucky_state()
	s.mends = 1
	assert_eq(s.try_mend(2), R.MATCH, "tile 2 is lucky with clock 0")
	assert_eq(s.lucky_won, 1)
	assert_eq(s.pairs_done, 1)
	assert_true(s.undo())
	assert_eq(s.lucky_won, 0, "undo takes the win back")
	assert_eq(s.mends, 1)
	assert_eq(s.pairs_done, 0)


func test_a_mend_that_takes_a_covered_lucky_tile_wins_nothing() -> void:
	var s := _lucky_state()
	s.mends = 1
	assert_eq(s.try_mend(1), R.MATCH, "takes tile 0, lucky but never free (no clock)")
	assert_eq(s.remaining, HalvesBits.minus(s.geometry.full_mask(), H.mask_of([0, 1])))
	assert_eq(s.lucky_won, 0)


func test_a_mend_starts_clocks_and_undo_removes_them() -> void:
	var s := _lucky_state()
	s.mends = 1
	assert_eq(s.try_mend(9), R.MATCH, "takes 8 and frees tile 0")
	assert_eq(_clocks(s), H.js({2: 0, 0: 1}), "tile 0's clock starts at pairs_done after the mend")
	assert_true(s.undo())
	assert_eq(_clocks(s), H.js({2: 0}), "the clock the mend started is removed")


func test_mends_count_as_snaps_on_the_lucky_clock() -> void:
	var s := _lucky_state()
	s.mends = 3
	assert_eq(s.try_mend(4), R.MATCH)
	assert_eq(s.try_mend(6), R.MATCH)
	assert_eq(s.try_mend(8), R.MATCH)
	assert_eq(s.pairs_done, 3, "pairs_done counts mends")
	assert_eq(s.mends, 0)
	assert_eq(s.try_pair(2, 3), R.MATCH, "pairs_done 3 before, clock 0: not won")
	assert_eq(s.lucky_won, 0)


# --- a mend never makes a solvable board unsolvable (within the budget) ---


## Mends tile `a` on a copy of the board (`rem` on `g` with `faces`, one mend in hand) and checks
## the mend itself: mend_mate gives `want_b`, try_mend gives MATCH, and exactly `a` and `want_b`
## leave. Returns {"error": String, "after": PackedInt64Array}.
func _mend_copy(g: HalvesGeometry, faces: PackedInt32Array, rem: PackedInt64Array, a: int, want_b: int) -> Dictionary:
	var error := ""
	var picked := HalvesState.mend_mate(g, faces, rem, a)
	if picked != want_b:
		error = "mend_mate(%d) = %d, the rule says %d" % [a, picked, want_b]
	var s := HalvesState.new(g, faces)
	s.apply_deal(rem, faces)
	s.mends = 1
	var r := s.try_mend(a)
	if error != "":
		pass
	elif r != R.MATCH:
		error = "mend %d gave %d, not MATCH" % [a, r]
	elif s.remaining != HalvesBits.minus(rem, H.mask_of([a, want_b])):
		error = "mend %d took %s, the rule says %d" % [a, H.ids(HalvesBits.minus(HalvesBits.minus(rem, s.remaining),
				H.bit(a))), want_b]
	elif s.last_action() != {"kind": "mend", "a": a, "b": want_b}:
		error = "mend %d: history entry %s" % [a, s.last_action()]
	return {"error": error, "after": s.remaining}


## "" if `after` is solvable: by the brute-force check up to 30 tiles, else the solver must not
## find it unsolvable (and its moves must replay when SOLVED).
func _solvable_verdict(g: HalvesGeometry, faces: PackedInt32Array, after: PackedInt64Array) -> String:
	if HalvesBits.is_empty(after):
		return ""
	if HalvesBits.count(after) <= 30:
		return "" if H.solvable(g, faces, after) else "no solution left (brute-force check)"
	var result := HalvesSolver.solve(g, faces, after, 60000)
	if result.get("status") == HalvesSolver.Status.UNSOLVABLE:
		return "the solver finds it UNSOLVABLE"
	if result.get("status") == HalvesSolver.Status.SOLVED:
		var t := HalvesState.new(g, faces)
		t.apply_deal(after, faces)
		var err := H.replay_error(t, result.get("moves", []))
		if err != "":
			return "the solver's moves fail: " + err
	return ""


func _all_states(g: HalvesGeometry, faces: PackedInt32Array, rem: PackedInt64Array, seen: Dictionary) -> void:
	if seen.has(rem):
		return
	seen[rem] = true
	var free := g.free_tiles(rem)
	for i: int in free.size():
		for j: int in range(i + 1, free.size()):
			if HalvesFace.matches(faces[free[i]], faces[free[j]]):
				_all_states(g, faces, HalvesBits.removed(HalvesBits.removed(rem, free[i]), free[j]), seen)


## Asserts no failures, naming how many of the checked mends failed and the first few.
func _assert_no_failures(failures: Array[String], checked: int, label: String) -> void:
	var shown: Array[String] = []
	for f: String in failures.slice(0, 5):
		shown.append(f)
	assert_eq(failures.size(), 0, "%s: %d of %d mends failed, e.g. %s" % [label, failures.size(), checked,
			" | ".join(shown)])


func test_mend_on_twin_boards_exhaustive() -> void:
	# Small boards with twins (several copies of each pair). In every reachable state (solvable or
	# not), every free tile with a mate: the mend takes the mate of section 1's rule (checked with the
	# brute-force check, exact on boards this small), and on a solvable state the rest stays solvable.
	var pyramid: Array = [Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0),
			Vector3i(10, 0, 0), Vector3i(1, 0, 1), Vector3i(5, 0, 1), Vector3i(3, 0, 2)]
	var rows: Array = [Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0),
			Vector3i(0, 2, 0), Vector3i(2, 2, 0), Vector3i(4, 2, 0), Vector3i(1, 1, 1), Vector3i(3, 1, 1),
			Vector3i(2, 1, 2)]
	var circle := HalvesFace.pair_from_text("circle:v:-")
	var tri := HalvesFace.pair_from_text("tri:v:-")
	var boards: Array = [
		[H.geometry(pyramid), PackedInt32Array([circle, circle, tri, tri])],
		[H.geometry(rows), PackedInt32Array([circle, circle, circle, tri, tri])],
		[H.geometry(rows).with_features({"locks": [{"keys": [3], "locked": [0, 4]}], "frost": [6]}),
				PackedInt32Array([circle, circle, circle, tri, tri])],
		[H.geometry(rows), PackedInt32Array([circle, circle, circle, circle, circle])],
	]
	var checked := 0
	var on_solvable := 0
	var lowest_unsafe := 0
	var failures: Array[String] = []
	for bi: int in boards.size():
		var g: HalvesGeometry = boards[bi][0]
		var keys: PackedInt32Array = boards[bi][1]
		for seed_n: int in 3:
			var dealt := HalvesFill.deal(g, keys, _rng(["twins", bi, seed_n]))
			if dealt.is_empty():
				fail_test("board %d seed %d: no deal" % [bi, seed_n])
				continue
			var faces: PackedInt32Array = dealt["faces"]
			var seen := {}
			_all_states(g, faces, g.full_mask(), seen)
			for rem: PackedInt64Array in seen:
				var solvable := H.solvable(g, faces, rem)
				var s := HalvesState.new(g, faces)
				s.apply_deal(rem, faces)
				for a: int in _mendable(s):
					checked += 1
					var label := "board %d seed %d, %s, mend %d" % [bi, seed_n, H.ids(rem), a]
					var want := _brute_mend_mate(g, faces, rem, a)
					var by_solver: int = _ref_mend_mate(g, faces, rem, a)["b"]
					if by_solver != want:
						failures.append("%s: test setup: the solver rule gives %d, the brute-force rule %d" % [label, by_solver, want])
						continue
					var lowest := _lowest_mate(s, a)
					if solvable and not H.solvable(g, faces, HalvesBits.minus(rem, H.mask_of([a, lowest]))):
						lowest_unsafe += 1
					var m := _mend_copy(g, faces, rem, a, want)
					if m["error"] != "":
						failures.append("%s: %s" % [label, m["error"]])
						continue
					if solvable:
						on_solvable += 1
						var verdict := _solvable_verdict(g, faces, m["after"])
						if verdict != "":
							failures.append("%s takes %d: %s" % [label, want, verdict])
	_assert_no_failures(failures, checked, "twin boards")
	assert_true(on_solvable > 50, "%d mends checked on solvable states" % on_solvable)
	assert_true(lowest_unsafe > 0, "some states where the lowest-id mate would strand a half (%d)" % lowest_unsafe)


## Section 1's claim on a real board: the mend takes the rule's mate (with the solver at
## MEND_BUDGET), and when one mate exists or a mate was proven within the budget, the rest stays
## solvable. A solvable board never falls back to "the lowest-id mate" (every mate proven unsolvable).
func _check_mend_on_board(g: HalvesGeometry, faces: PackedInt32Array, rem: PackedInt64Array, a: int, label: String,
		failures: Array[String], tally: Dictionary) -> void:
	var ref := _ref_mend_mate(g, faces, rem, a)
	var rule: String = ref["rule"]
	tally[rule] = int(tally.get(rule, 0)) + 1
	var m := _mend_copy(g, faces, rem, a, ref["b"])
	if m["error"] != "":
		failures.append("%s: %s" % [label, m["error"]])
		return
	if rule == "lowest":
		failures.append("%s: every mate proven unsolvable on a solvable board" % label)
		return
	if rule == "one" or rule == "proven":
		var verdict := _solvable_verdict(g, faces, m["after"])
		if verdict != "":
			failures.append("%s takes %d (%s): %s" % [label, ref["b"], rule, verdict])


func test_mend_on_baked_boards_keeps_them_solvable() -> void:
	# Baked v2 levels (v2 faces, with their locks, frost, mist and coin gold): at several points of
	# the solution (so the board is solvable), mend every free tile with a mate.
	var checked := 0
	var tally := {}
	var failures: Array[String] = []
	for level: int in [4, 12, 20, 45, 65, 85]:
		var data := _level(level)
		if data == null:
			continue
		var n := data.solution.size()
		for k: int in [0, floori(n / 3.0), floori(2 * n / 3.0), n - 2]:
			var s := _state_after(data, data.faces, k)
			for a: int in _mendable(s):
				checked += 1
				_check_mend_on_board(data.geometry(), data.faces, s.remaining, a,
						"level %d after %d pairs, mend %d" % [level, k, a], failures, tally)
	_assert_no_failures(failures, checked, "baked boards")
	assert_true(checked > 30, "%d mends checked" % checked)
	assert_true(int(tally.get("proven", 0)) > 10, "mends with twins decided by the solver: %s" % [tally])
	gut.p("baked boards: mends by rule %s" % [tally])


## Every valid crest pair outside the gold family, ascending.
func _crest_pairs() -> Array[int]:
	var out: Array[int] = []
	for m: int in HalvesCrests.motif_count():
		for cut: int in 2:
			var p := HalvesCrests.pair_of(m, cut)
			if HalvesCrests.is_valid_pair(p) and HalvesCrests.family_of(p) != &"gold":
				out.append(p)
	return out


## The level's faces with each v2 pair renamed to a crest pair (same structure, crest faces).
func _crest_faces(data: HalvesLevelData) -> PackedInt32Array:
	var crests := _crest_pairs()
	var keys: Array[int] = []
	for f: int in data.faces:
		if not keys.has(HalvesFace.pair_key(f)):
			keys.append(HalvesFace.pair_key(f))
	keys.sort()
	var out := PackedInt32Array()
	for f: int in data.faces:
		out.append((crests[keys.find(HalvesFace.pair_key(f))] << 1) | HalvesFace.side(f))
	return out


func _gold_step(order: Array[Vector2i], faces: PackedInt32Array) -> int:
	for k: int in order.size():
		if HalvesState.is_gold(faces[order[k].x]) and HalvesState.is_gold(faces[order[k].y]):
			return k
	return -1


func test_mend_on_crest_boards_keeps_them_solvable() -> void:
	# Crest boards with a gold pair: the mend is earned by clearing the gold pair along the solution.
	var checked := 0
	var tally := {}
	var failures: Array[String] = []
	for level: int in [5, 12, 85]:
		var data := _level(level)
		if data == null:
			continue
		var crest := _crest_faces(data)
		assert_true(HalvesFace.is_crest(crest[0]), "test setup: crest faces")
		var faces := HalvesFill.with_gold_pair(HalvesGeometry.from_positions(data.positions), data.solution, crest,
				_rng(["crest gold", level]))
		var k := _gold_step(data.solution, faces)
		assert_true(k >= 0, "level %d: a gold step" % level)
		if k < 0:
			continue
		var n := data.solution.size()
		for point: int in [k + 1, floori((k + 1 + n) / 2.0), n - 1]:
			if point >= n:
				continue
			var s := _state_after(data, faces, point)
			assert_eq(s.mends, 1, "level %d: the gold pair earned a mend" % level)
			for a: int in _mendable(s):
				checked += 1
				_check_mend_on_board(data.geometry(), faces, s.remaining, a,
						"crest level %d after %d pairs, mend %d" % [level, point, a], failures, tally)
	_assert_no_failures(failures, checked, "crest boards")
	assert_true(checked > 15, "%d mends checked" % checked)
	gut.p("crest boards: mends by rule %s" % [tally])


# --- the bots mend when stuck ---


## After the gold pair (2, 3) the board is stuck with free 4 (circle a) and 5 (tri a):
##   0 (3,0,0) tri b, under 4 and 5 (two covers)   1 (5,0,0) circle b, under 5 (one cover)
##   2 (0,4,0) gold a   3 (4,4,0) gold b   4 (2,0,1) circle a   5 (4,0,1) tri a
## Mending 5 (its mate has the most covers) clears the board; mending 4 (the lower id) leaves 5 on 0.
func _most_covered_board(gold: bool) -> Array:
	var g := H.geometry([Vector3i(3, 0, 0), Vector3i(5, 0, 0), Vector3i(0, 4, 0), Vector3i(4, 4, 0),
			Vector3i(2, 0, 1), Vector3i(4, 0, 1)])
	var pair := ["gold:a", "gold:b"] if gold else ["diamond:v:-:a", "diamond:v:-:b"]
	return [g, _faces(["tri:v:-:b", "circle:v:-:b", pair[0], pair[1], "circle:v:-:a", "tri:v:-:a"])]


## After the gold pair (3, 4): free 5 (circle a), 6 (tri a), 7 (square a); every mate has one cover:
##   0 (0,0,0) circle b under 5   1 (2,0,0) tri b under 5   2 (6,0,0) square b under 6
##   3 (0,4,0) gold a   4 (4,4,0) gold b   5 (1,0,1) circle a   6 (6,0,1) tri a   7 (10,0,1) square a
## A tie: the lowest id, 5, is the only mend that clears the board.
func _tie_board() -> Array:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(6, 0, 0), Vector3i(0, 4, 0), Vector3i(4, 4, 0),
			Vector3i(1, 0, 1), Vector3i(6, 0, 1), Vector3i(10, 0, 1)])
	return [g, _faces(["circle:v:-:b", "tri:v:-:b", "square:v:-:b", "gold:a", "gold:b", "circle:v:-:a", "tri:v:-:a",
			"square:v:-:a"])]


## Two halves each on its only mate and one gold pair: one mend is not enough.
func _two_dead_ends_board() -> Array:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 4, 0), Vector3i(4, 4, 0),
			Vector3i(0, 0, 1), Vector3i(4, 0, 1)])
	return [g, _faces(["circle:v:-:b", "tri:v:-:b", "gold:a", "gold:b", "circle:v:-:a", "tri:v:-:a"])]


## After the gold pair (3, 4): free 5 (circle a) and 7 (tri a); 5 has two mates (twins):
##   0 (0,0,0) tri b under 5   1 (4,0,0) circle b and 2 (6,0,0) circle a, under 6 and 7
##   3 (0,4,0) gold a   4 (4,4,0) gold b   5 (0,0,1) circle a   6 (5,0,1) circle b, a bridge on 1 and 2
##   7 (5,0,2) tri a, on top of the bridge.
## The bot mends 5 (its lowest-id mate 1 has two covers; 7's mate 0 has one). mend_mate takes 6,
## which clears; the lowest-id mate 1 would leave the bridge 6 on its only mate 2.
func _twin_mates_board() -> Array:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0), Vector3i(0, 4, 0), Vector3i(4, 4, 0),
			Vector3i(0, 0, 1), Vector3i(5, 0, 1), Vector3i(5, 0, 2)])
	return [g, _faces(["tri:v:-:b", "circle:v:-:b", "circle:v:-:a", "gold:a", "gold:b", "circle:v:-:a", "circle:v:-:b",
			"tri:v:-:a"])]


func test_twin_mates_board_setup() -> void:
	var board := _twin_mates_board()
	var s := HalvesState.new(board[0], board[1])
	assert_eq(s.free_pairs(), H.pairs([Vector2i(3, 4)]), "only the gold pair is free at the start")
	assert_eq(s.try_pair(3, 4), R.MATCH)
	assert_true(s.is_stuck())
	assert_false(H.solvable(s.geometry, s.faces, H.mask_of([0, 2, 6, 7])), "the lowest-id mate 1 strands the bridge")
	assert_eq(HalvesState.mend_mate(s.geometry, s.faces, s.remaining, 5), 6)
	assert_eq(s.try_mend(5), R.MATCH)
	assert_eq(s.remaining, H.mask_of([0, 1, 2, 7]), "5 and 6 leave")
	assert_true(H.solvable(s.geometry, s.faces, s.remaining))


func test_a_stuck_bot_removes_the_mate_mend_mate_picks() -> void:
	_play_all(_twin_mates_board(), true, "twin mates")


func test_board_setups_need_the_right_mend() -> void:
	# The boards above, checked with HalvesState alone, so the bot tests below mean what they say.
	for entry: Array in [[_most_covered_board(true), 5, 4], [_tie_board(), 5, 6], [_tie_board(), 5, 7]]:
		var board: Array = entry[0]
		var good: int = entry[1]
		var wrong: int = entry[2]
		for pick: int in [good, wrong]:
			var s := HalvesState.new(board[0], board[1])
			assert_eq(s.free_pairs().size(), 1, "only the gold pair is free at the start")
			var gp: Vector2i = s.free_pairs()[0]
			assert_eq(s.try_pair(gp.x, gp.y), R.MATCH)
			assert_true(s.is_stuck())
			assert_eq(s.try_mend(pick), R.MATCH)
			assert_eq(H.solvable(s.geometry, s.faces, s.remaining), pick == good, "mend %d" % pick)


func _play_all(board: Array, cleared: bool, label: String) -> void:
	var g: HalvesGeometry = board[0]
	var faces: PackedInt32Array = board[1]
	for policy: int in [P.RANDOM, P.CAREFUL, P.WARY]:
		for seed_n: int in 4:
			var result := HalvesBot.play(g, faces, _rng(["bot", label, policy, seed_n]), policy)
			assert_eq(result.get("cleared"), cleared, "%s: policy %d seed %d" % [label, policy, seed_n])
			if cleared:
				assert_eq(result.get("steps"), g.size() / 2, "%s: steps count the mend as a removed pair" % label)


func test_a_stuck_bot_mends_the_tile_whose_mate_is_most_covered() -> void:
	_play_all(_most_covered_board(true), true, "most covered")


func test_a_stuck_bot_breaks_a_tie_by_the_lowest_id() -> void:
	_play_all(_tie_board(), true, "tie")


func test_a_bot_without_a_mend_stays_stuck() -> void:
	_play_all(_most_covered_board(false), false, "no gold pair")


func test_a_bot_mends_only_as_often_as_it_has_mends() -> void:
	_play_all(_two_dead_ends_board(), false, "two dead ends")


# --- HalvesRun: Event.MEND ---


func _new_run(data: HalvesLevelData) -> HalvesRun:
	var run := HalvesRun.new()
	run.board = "level_%d" % data.level
	run.level = data.level
	run.gen_version = HalvesLevels.gen_version()
	run.free_mistakes = 0
	run.strict = false
	return run


func _record_pairs(run: HalvesRun, moves: Array) -> void:
	for p: Vector2i in moves:
		run.advance(STEP_MS)
		run.record(E.PAIR, p.x, p.y)


## A copy of baked level `n` with a gold pair: {"data", "k" (gold step), "a" (a tile to mend
## after step k, preferably one whose mate is not free), "rest" (a solution after that mend)}.
func _gold_level(n: int) -> Dictionary:
	var base := _level(n)
	if base == null:
		return {}
	var data := HalvesLevelData.from_dict(base.to_dict())
	data.faces = HalvesFill.with_gold_pair(HalvesGeometry.from_positions(data.positions), data.solution, data.faces,
			_rng(["run gold", n]))
	var k := _gold_step(data.solution, data.faces)
	if k < 0:
		fail_test("no gold step")
		return {}
	var s := _state_after(data, data.faces, k + 1)
	var picks := _mendable(s)
	if picks.is_empty():
		fail_test("nothing to mend")
		return {}
	# Mends whose mate is not free first (a real mend); the first one that leaves a solved board.
	var free := s.geometry.free_mask(s.remaining)
	var ordered: Array[int] = []
	for t: int in picks:
		if not HalvesBits.has(free, _lowest_mate(s, t)):
			ordered.append(t)
	for t: int in picks:
		if not ordered.has(t):
			ordered.append(t)
	for a: int in ordered:
		var t2 := _state_after(data, data.faces, k + 1)
		assert_eq(t2.try_mend(a), R.MATCH, "test setup: the mend of %d" % a)
		var solved := HalvesSolver.solve(t2.geometry, t2.faces, t2.remaining)
		if solved.get("status") == HalvesSolver.Status.SOLVED:
			return {"data": data, "k": k, "a": a, "rest": solved.get("moves", [])}
	fail_test("test setup: no mend after the gold step left a board the solver clears")
	return {}


func _assert_ok(r: Dictionary, cleared: bool, stars: int, slips: int, label: String) -> void:
	assert_eq(r.get("ok"), true, "%s: ok (error: %s)" % [label, r.get("error", "")])
	assert_eq(r.get("error"), "", label + ": no error")
	assert_eq(r.get("cleared"), cleared, label + ": cleared")
	assert_eq(r.get("stars"), stars, label + ": stars")
	assert_eq(r.get("slips"), slips, label + ": slips")


func _assert_fails(r: Dictionary, label: String) -> void:
	assert_eq(r.get("ok"), false, label + ": ok is false")
	assert_ne(String(r.get("error", "")).strip_edges(), "", label + ": with a readable error")


func test_mend_event_value_and_record() -> void:
	# Saved logs store the kind as an int, so the enum order is part of the format.
	assert_eq([E.PAIR, E.MISMATCH, E.UNDO, E.SHUFFLE, E.HINT, E.MEND], [0, 1, 2, 3, 4, 5])
	var run := HalvesRun.new()
	run.record(E.PAIR, 1, 2)
	run.advance(60)
	run.record(E.MEND, 7)
	assert_eq(run.events, [[0, E.PAIR, 1, 2], [60, E.MEND, 7, -1]], "[ms, MEND, a] with b left at -1")
	var parsed: Variant = JSON.parse_string(JSON.stringify(run.to_dict()))
	var back := HalvesRun.from_dict(parsed as Dictionary)
	assert_eq(back.events, run.events, "a MEND event survives JSON as ints")
	for e: Array in back.events:
		for v: Variant in e:
			assert_eq(typeof(v), TYPE_INT, "event %s" % [e])


func test_replay_a_run_with_a_mend() -> void:
	var g := _gold_level(5)
	if g.is_empty():
		return
	var data: HalvesLevelData = g["data"]
	var k: int = g["k"]
	var run := _new_run(data)
	_record_pairs(run, data.solution.slice(0, k + 1))
	run.advance(STEP_MS)
	run.record(E.MEND, g["a"])
	_record_pairs(run, g["rest"])
	run.finish()
	_assert_ok(HalvesRun.replay(data, run.to_dict()), true, 3, 0, "pairs, a mend, then the rest")
	var parsed: Variant = JSON.parse_string(JSON.stringify(run.to_dict()))
	_assert_ok(HalvesRun.replay(data, parsed as Dictionary), true, 3, 0, "the same run through JSON")


func test_replay_a_partial_run_ending_in_a_mend() -> void:
	var g := _gold_level(5)
	if g.is_empty():
		return
	var data: HalvesLevelData = g["data"]
	var run := _new_run(data)
	_record_pairs(run, data.solution.slice(0, int(g["k"]) + 1))
	run.record(E.MEND, g["a"])
	_assert_ok(HalvesRun.replay(data, run.to_dict()), false, 3, 0, "not cleared yet")


func test_replay_undo_of_a_mend() -> void:
	var g := _gold_level(5)
	if g.is_empty():
		return
	var data: HalvesLevelData = g["data"]
	var run := _new_run(data)
	_record_pairs(run, data.solution.slice(0, int(g["k"]) + 1))
	run.record(E.MEND, g["a"])
	run.advance(STEP_MS)
	run.record(E.UNDO)
	run.advance(STEP_MS)
	run.record(E.MEND, g["a"])
	_record_pairs(run, g["rest"])
	_assert_ok(HalvesRun.replay(data, run.to_dict()), true, 3, 0, "undo gives the mend back")


func test_replay_rejects_a_mend_before_the_gold_pair_is_cleared() -> void:
	var g := _gold_level(5)
	if g.is_empty():
		return
	var data: HalvesLevelData = g["data"]
	var k: int = g["k"]
	var s := _state_after(data, data.faces, k)
	var picks := _mendable(s)
	assert_false(picks.is_empty(), "test setup")
	if picks.is_empty():
		return
	var run := _new_run(data)
	_record_pairs(run, data.solution.slice(0, k))
	run.record(E.MEND, picks[0])
	_assert_fails(HalvesRun.replay(data, run.to_dict()), "a mend with no mend earned")
	var first := _new_run(data)
	first.record(E.MEND, _mendable(data.new_state())[0])
	_assert_fails(HalvesRun.replay(data, first.to_dict()), "a mend as the first event")


func test_replay_rejects_a_second_mend_and_a_blocked_mend() -> void:
	var g := _gold_level(5)
	if g.is_empty():
		return
	var data: HalvesLevelData = g["data"]
	var k: int = g["k"]
	var twice := _new_run(data)
	_record_pairs(twice, data.solution.slice(0, k + 1))
	twice.record(E.MEND, g["a"])
	var s := _state_after(data, data.faces, k + 1)
	s.try_mend(g["a"])
	var picks := _mendable(s)
	if not picks.is_empty():
		twice.record(E.MEND, picks[0])
		_assert_fails(HalvesRun.replay(data, twice.to_dict()), "one gold pair, two mends")
	# A covered tile whose mate remains: BLOCKED, not a MATCH.
	var t := _state_after(data, data.faces, k + 1)
	var blocked := -1
	var free := t.geometry.free_mask(t.remaining)
	for i: int in HalvesBits.ids(t.remaining):
		if not HalvesBits.has(free, i) and _lowest_mate(t, i) >= 0:
			blocked = i
			break
	if blocked < 0:
		pending("no blocked tile with a mate after the gold step")
		return
	var run := _new_run(data)
	_record_pairs(run, data.solution.slice(0, k + 1))
	run.record(E.MEND, blocked)
	_assert_fails(HalvesRun.replay(data, run.to_dict()), "a mend on a blocked tile")
