extends GutTest
## HalvesState: try_pair results in the documented order of checks, mistakes, free mistakes,
## strict mode, undo, stars, free pairs, stuck/cleared and apply_deal. Hand-built boards only.
## Written from docs/HALVES.md alone. "Column" boards have every tile free (no tile touches another).

const H := preload("res://tests/halves_helpers.gd")
const R := HalvesState.Result


func _column(texts: Array) -> HalvesState:
	return H.state(H.column(texts.size()), texts)


func _assert_unchanged(s: HalvesState, remaining: int, mistakes: int, history_size: int) -> void:
	assert_eq(s.remaining, remaining, "remaining unchanged")
	assert_eq(s.mistakes, mistakes, "mistakes unchanged")
	assert_eq(s.history.size(), history_size, "history unchanged")


func test_new_state_has_every_tile() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b"])
	assert_eq(s.remaining, 0b1111)
	assert_eq(s.tiles_left(), 4)
	assert_eq(s.mistakes, 0)
	assert_eq(s.free_mistakes, 0)
	assert_false(s.strict)
	assert_true(s.history.is_empty())
	assert_false(s.is_cleared())
	assert_eq(s.faces, H.faces(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b"]))


func test_match_removes_both_and_records_the_pair() -> void:
	var s := _column(["circle:v:-:a", "tri:v:-:a", "circle:v:-:b", "tri:v:-:b"])
	assert_eq(s.try_pair(0, 2), R.MATCH)
	assert_eq(s.remaining, 0b1010)
	assert_eq(s.tiles_left(), 2)
	assert_eq(s.mistakes, 0)
	assert_eq(s.history, [{"kind": "pair", "a": 0, "b": 2}])
	assert_eq(s.try_pair(3, 1), R.MATCH)
	assert_eq(s.remaining, 0)
	assert_eq(s.history.size(), 2)
	var last: Dictionary = s.history[1]
	assert_eq(last.get("kind"), "pair")
	assert_eq(H.norm(Vector2i(int(last.get("a", -1)), int(last.get("b", -1)))), Vector2i(1, 3))
	assert_true(s.is_cleared())
	assert_false(s.is_stuck(), "a clear board is not stuck")
	assert_eq(s.tiles_left(), 0)
	assert_eq(s.stars(), 3)


func test_invalid_ids_change_nothing() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b"])
	assert_eq(s.try_pair(0, 0), R.INVALID, "same tile")
	assert_eq(s.try_pair(-1, 1), R.INVALID, "negative id")
	assert_eq(s.try_pair(0, 4), R.INVALID, "id == size")
	assert_eq(s.try_pair(99, 1), R.INVALID, "id far out of range")
	_assert_unchanged(s, 0b1111, 0, 0)
	assert_eq(s.try_pair(0, 1), R.MATCH)
	assert_eq(s.try_pair(0, 1), R.INVALID, "both already removed")
	assert_eq(s.try_pair(0, 2), R.INVALID, "first already removed")
	assert_eq(s.try_pair(3, 1), R.INVALID, "second already removed")
	_assert_unchanged(s, 0b1100, 0, 1)


func test_invalid_is_checked_before_blocked() -> void:
	# Row of three: tile 1 is blocked on both sides.
	var s := H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0)],
			["circle:v:-:a", "circle:v:-:a", "circle:v:-:b"])
	assert_eq(s.try_pair(1, 1), R.INVALID, "same blocked tile")
	assert_eq(s.try_pair(1, 3), R.INVALID, "blocked tile with an out-of-range id")
	_assert_unchanged(s, 0b111, 0, 0)


func test_blocked_by_neighbours_changes_nothing() -> void:
	# Tiles 0-2 in a row (tile 1 blocked); tile 3 alone below. Tile 1 and tile 3 would match.
	var s := H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 4, 0)],
			["tri:v:-:a", "circle:v:-:a", "tri:v:-:b", "circle:v:-:b"])
	assert_eq(s.try_pair(1, 3), R.BLOCKED)
	assert_eq(s.try_pair(3, 1), R.BLOCKED)
	_assert_unchanged(s, 0b1111, 0, 0)
	assert_eq(s.try_pair(0, 2), R.MATCH)
	assert_eq(s.try_pair(1, 3), R.MATCH, "free once its neighbours are gone")


func test_blocked_is_checked_before_mismatch() -> void:
	# Tile 1 (blocked) is a twin of tile 3: still BLOCKED, and no mistake.
	var s := H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 4, 0)],
			["tri:v:-:a", "circle:v:-:a", "tri:v:-:b", "circle:v:-:a"])
	assert_eq(s.try_pair(1, 3), R.BLOCKED)
	_assert_unchanged(s, 0b1111, 0, 0)


func test_blocked_by_a_covering_tile() -> void:
	# Tile 0 lies under tile 3; tile 0 and tile 1 would match.
	var s := H.state([Vector3i(0, 0, 0), Vector3i(0, 4, 0), Vector3i(0, 8, 0), Vector3i(0, 0, 1)],
			["circle:v:-:a", "circle:v:-:b", "tri:v:-:b", "tri:v:-:a"])
	assert_eq(s.try_pair(0, 1), R.BLOCKED)
	_assert_unchanged(s, 0b1111, 0, 0)
	assert_eq(s.try_pair(3, 2), R.MATCH)
	assert_eq(s.try_pair(0, 1), R.MATCH)
	assert_true(s.is_cleared())


func test_twins_are_a_mistake() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:a"])
	assert_eq(s.try_pair(0, 1), R.MISMATCH)
	assert_eq(s.remaining, 0b11, "nothing is removed")
	assert_eq(s.mistakes, 1)
	assert_eq(s.history, [{"kind": "mistake"}])
	assert_eq(s.try_pair(1, 0), R.MISMATCH)
	assert_eq(s.mistakes, 2)
	assert_eq(s.history.size(), 2)


func test_near_twins_are_mistakes() -> void:
	var s := _column(["circle:v:-:a", "circle:h:-:b", "circle:v:dot:b", "circle:v:dot:a"])
	assert_eq(s.try_pair(0, 1), R.MISMATCH, "other cut")
	assert_eq(s.try_pair(0, 2), R.MISMATCH, "other mark")
	assert_eq(s.try_pair(0, 3), R.MISMATCH, "other mark, same side")
	assert_eq(s.remaining, 0b1111)
	assert_eq(s.mistakes, 3)
	assert_eq(s.history.size(), 3)


func test_different_shapes_switch_without_penalty() -> void:
	var s := _column(["circle:v:-:a", "tri:v:-:b", "square:v:-:a", "diamond:v:-:b"])
	assert_eq(s.try_pair(0, 1), R.SWITCH)
	assert_eq(s.try_pair(2, 3), R.SWITCH, "square and diamond are different shapes")
	assert_eq(s.try_pair(1, 2), R.SWITCH)
	_assert_unchanged(s, 0b1111, 0, 0)


func test_strict_makes_every_non_match_a_mistake() -> void:
	var s := _column(["circle:v:-:a", "tri:v:-:b", "circle:v:-:b", "circle:v:-:a"])
	s.strict = true
	assert_eq(s.try_pair(0, 1), R.MISMATCH, "different shapes")
	assert_eq(s.mistakes, 1)
	assert_eq(s.try_pair(0, 3), R.MISMATCH, "twins")
	assert_eq(s.mistakes, 2)
	assert_eq(s.history.size(), 2)
	assert_eq(s.try_pair(0, 2), R.MATCH, "matches still match")
	assert_eq(s.remaining, 0b1010)


func test_free_mistake_absorbs_the_first_mismatch() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:a", "tri:v:-:a"])
	s.free_mistakes = 1
	assert_eq(s.try_pair(0, 2), R.SWITCH)
	assert_eq(s.free_mistakes, 1, "a switch does not use the free mistake")
	assert_eq(s.try_pair(0, 1), R.MISMATCH)
	assert_eq(s.free_mistakes, 0)
	assert_eq(s.mistakes, 0, "the first mismatch is free")
	assert_true(s.history.is_empty(), "a free mistake leaves no history")
	assert_false(s.undo(), "nothing to undo")
	assert_eq(s.try_pair(0, 1), R.MISMATCH)
	assert_eq(s.mistakes, 1, "the second one counts")
	assert_eq(s.history, [{"kind": "mistake"}])


func test_undo_a_pair() -> void:
	var s := _column(["circle:v:-:a", "tri:v:-:a", "circle:v:-:b", "tri:v:-:b"])
	assert_eq(s.try_pair(0, 2), R.MATCH)
	assert_true(s.undo())
	assert_eq(s.remaining, 0b1111, "both tiles return")
	assert_eq(s.tiles_left(), 4)
	assert_true(s.history.is_empty())
	assert_eq(s.mistakes, 0)
	assert_false(s.undo(), "nothing left to undo")


func test_undo_a_mistake() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:a"])
	s.try_pair(0, 1)
	s.try_pair(0, 1)
	assert_eq(s.mistakes, 2)
	assert_true(s.undo())
	assert_eq(s.mistakes, 1)
	assert_eq(s.remaining, 0b11)
	assert_true(s.undo())
	assert_eq(s.mistakes, 0)
	assert_eq(s.stars(), 3, "the star comes back")
	assert_false(s.undo())


func test_undo_takes_back_the_last_action_first() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:a"])
	assert_eq(s.try_pair(0, 1), R.MATCH)
	assert_eq(s.try_pair(2, 3), R.MISMATCH)
	assert_true(s.undo())
	assert_eq(s.mistakes, 0, "the mistake went first")
	assert_eq(s.remaining, 0b1100, "the pair is still gone")
	assert_true(s.undo())
	assert_eq(s.remaining, 0b1111)
	assert_false(s.undo())


func test_undo_on_a_fresh_board() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b"])
	assert_false(s.undo())
	assert_eq(s.remaining, 0b11)


func test_stars_thresholds() -> void:
	assert_eq(HalvesConfig.STAR2_MAX_MISTAKES, 2)
	var s := _column(["circle:v:-:a", "circle:v:-:b"])
	var want := {0: 3, 1: 2, 2: 2, 3: 1, 4: 1, 10: 1}
	for m: int in want:
		s.mistakes = m
		assert_eq(s.stars(), want[m], "%d mistakes" % m)


func test_free_pairs_lists_every_free_match_sorted() -> void:
	var s := _column(["circle:v:-:a", "tri:v:-:b", "circle:v:-:b", "tri:v:-:a", "circle:v:-:b", "square:v:-:a"])
	# 2 and 4 are twins (not a pair); 5 has no mate.
	assert_eq(s.free_pairs(), H.pairs([Vector2i(0, 2), Vector2i(0, 4), Vector2i(1, 3)]))


func test_free_pairs_skip_blocked_tiles() -> void:
	# Row of four: tiles 0 and 3 are free; tile 1 would match tile 0 but is blocked.
	var s := H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0)],
			["circle:v:-:a", "circle:v:-:b", "circle:v:-:a", "circle:v:-:b"])
	assert_eq(s.free_pairs(), H.pairs([Vector2i(0, 3)]))
	assert_eq(s.try_pair(0, 3), R.MATCH)
	assert_eq(s.free_pairs(), H.pairs([Vector2i(1, 2)]))


func test_stuck_when_tiles_are_left_but_no_free_pair() -> void:
	# Row of four: the free ends 0 and 3 are twins, the matching tiles sit in the middle.
	var s := H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0)],
			["circle:v:-:a", "circle:v:-:b", "circle:v:-:b", "circle:v:-:a"])
	assert_true(s.free_pairs().is_empty())
	assert_true(s.is_stuck())
	assert_false(s.is_cleared())
	assert_eq(s.tiles_left(), 4)


func test_not_stuck_with_a_free_pair() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b"])
	assert_false(s.is_stuck())
	assert_eq(s.free_pairs(), H.pairs([Vector2i(0, 1)]))


func test_64_tiles_use_bit_63() -> void:
	# 8 x 8 grid, tile i at row i / 8, column i % 8: only row ends are free. The last row's ends
	# (56 and 63) are the only match; every other tile is the same twin.
	var points: Array = []
	var texts: Array = []
	for i: int in 64:
		points.append(Vector3i(2 * (i % 8), 2 * int(i / 8.0), 0))
		texts.append("tri:v:-:a")
	texts[56] = "circle:v:-:a"
	texts[63] = "circle:v:-:b"
	var s := H.state(points, texts)
	assert_eq(s.remaining, -1, "all 64 bits")
	assert_eq(s.tiles_left(), 64)
	assert_eq(s.free_pairs(), H.pairs([Vector2i(56, 63)]))
	assert_eq(s.try_pair(62, 63), R.BLOCKED)
	assert_eq(s.try_pair(63, 64), R.INVALID)
	assert_eq(s.try_pair(0, 7), R.MISMATCH, "free twins")
	assert_eq(s.try_pair(63, 56), R.MATCH)
	assert_eq(s.remaining, -1 & ~((1 << 56) | (1 << 63)))
	assert_eq(s.tiles_left(), 62)
	assert_true(s.undo())
	assert_true(s.undo())
	assert_eq(s.remaining, -1)
	assert_eq(s.mistakes, 0)


func test_apply_deal_replaces_the_board_and_clears_history() -> void:
	var s := _column(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:a"])
	s.try_pair(0, 1)
	s.try_pair(2, 3)
	assert_eq(s.history.size(), 2)
	var new_faces := H.faces(["", "", "tri:v:-:b", "tri:v:-:a"])
	s.apply_deal(0b1100, new_faces)
	assert_eq(s.remaining, 0b1100)
	assert_eq(s.faces, new_faces)
	assert_true(s.history.is_empty())
	assert_false(s.undo(), "a shuffle clears the undo history")
	assert_eq(s.mistakes, 1, "a shuffle does not give back stars")
	assert_eq(s.try_pair(2, 3), R.MATCH, "the new faces are used")
	assert_true(s.is_cleared())
