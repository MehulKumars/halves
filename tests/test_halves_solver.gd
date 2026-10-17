extends GutTest
## HalvesSolver: solve (SOLVED moves replay, UNSOLVABLE only when exhausted, tiny budgets) and hint
## (keeps the board solvable, avoids a hand-built trap that a greedy pick would fall into).
## Written from docs/HALVES.md alone. The trap board is drawn out in _trap_state().

const H := preload("res://tests/halves_helpers.gd")
const S := HalvesSolver.Status


## Six tiles, ids in (z, y, x) order:
##   0 (0,0,0) tri a   \ both under tile 4 (a bridge at (1,0,1))
##   1 (2,0,0) tri b   /
##   2 (0,4,0) circle b  under tile 5
##   3 (0,8,0) circle b  alone
##   4 (1,0,1) circle a  bridge
##   5 (0,4,1) circle a  on tile 2
## Free at the start: 3, 4, 5, so the free matches are (3,4) and (3,5).
## (3,4) is the trap: it frees 0 and 1 (three free tiles after it, the most), but then 5 sits on its
## only mate 2 and the board ends stuck. (3,5) frees 2, then (2,4), then (0,1) clears the board.
func _trap_state() -> HalvesState:
	return H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(0, 4, 0), Vector3i(0, 8, 0),
			Vector3i(1, 0, 1), Vector3i(0, 4, 1)],
			["tri:v:-:a", "tri:v:-:b", "circle:v:-:b", "circle:v:-:b", "circle:v:-:a", "circle:v:-:a"])


func _solve(s: HalvesState, budget: int = 20000) -> Dictionary:
	return HalvesSolver.solve(s.geometry, s.faces, s.remaining, budget)


func _moves(result: Dictionary) -> Array:
	var moves: Array = result.get("moves", [])
	return moves


func test_trap_board_is_what_the_comment_says() -> void:
	var s := _trap_state()
	assert_eq(s.free_pairs(), H.pairs([Vector2i(3, 4), Vector2i(3, 5)]))
	assert_true(H.solvable(s.geometry, s.faces, s.remaining))
	assert_false(H.solvable(s.geometry, s.faces, H.mask_of([0, 1, 2, 5])), "after the trap")


func test_solve_a_dealt_board() -> void:
	for level: int in [3, 6]:
		var g := H.plan_geometry(level)
		var dealt := HalvesFill.deal(g, H.plan_keys(level, g.size()), SeedService.make_rng(["test_solver", level], 1))
		assert_false(dealt.is_empty(), "level %d dealt" % level)
		if dealt.is_empty():
			continue
		var s := HalvesState.new(g, dealt["faces"])
		var result := _solve(s)
		assert_eq(result.get("status"), S.SOLVED, "level %d" % level)
		assert_eq(_moves(result).size(), int(g.size() / 2.0))
		assert_eq(H.replay_error(s, _moves(result)), "", "level %d moves replay" % level)


func test_solve_the_trap_board_avoids_the_trap() -> void:
	var s := _trap_state()
	var result := _solve(s)
	assert_eq(result.get("status"), S.SOLVED)
	var moves := _moves(result)
	assert_eq(moves.size(), 3)
	if moves.size() == 3:
		assert_eq(H.norm(moves[0]), Vector2i(3, 5), "(3,4) is a dead end")
	assert_eq(H.replay_error(s, moves), "")


func test_solve_from_a_partly_cleared_board() -> void:
	var s := _trap_state()
	assert_eq(s.try_pair(3, 5), HalvesState.Result.MATCH)
	var result := _solve(s)
	assert_eq(result.get("status"), S.SOLVED)
	assert_eq(_moves(result).size(), 2)
	assert_eq(H.replay_error(s, _moves(result)), "")


func test_empty_board_is_solved_with_no_moves() -> void:
	var g := H.geometry(H.column(2))
	var result := HalvesSolver.solve(g, H.faces(["circle:v:-:a", "circle:v:-:b"]), 0)
	assert_eq(result.get("status"), S.SOLVED)
	assert_eq(_moves(result).size(), 0)


func test_twins_only_is_unsolvable() -> void:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0)])
	var result := HalvesSolver.solve(g, H.faces(["circle:v:-:a", "circle:v:-:a"]), 0b11)
	assert_eq(result.get("status"), S.UNSOLVABLE)


func test_mates_stacked_on_each_other_are_unsolvable() -> void:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(0, 0, 1)])
	var result := HalvesSolver.solve(g, H.faces(["circle:v:-:a", "circle:v:-:b"]), 0b11)
	assert_eq(result.get("status"), S.UNSOLVABLE)


func test_after_the_trap_is_unsolvable() -> void:
	# A free pair (0,1) still exists, but every line ends stuck.
	var s := _trap_state()
	assert_eq(s.try_pair(3, 4), HalvesState.Result.MATCH)
	assert_eq(s.free_pairs(), H.pairs([Vector2i(0, 1)]))
	assert_eq(_solve(s).get("status"), S.UNSOLVABLE)


func test_tiny_budget_never_claims_unsolvable() -> void:
	var g := H.plan_geometry(30)
	var dealt := HalvesFill.deal(g, H.plan_keys(30, g.size()), SeedService.make_rng(["test_solver", "big"], 1))
	assert_false(dealt.is_empty())
	if dealt.is_empty():
		return
	var s := HalvesState.new(g, dealt["faces"])
	var result := _solve(s, 1)
	assert_has([S.SOLVED, S.UNKNOWN], result.get("status"), "a dealt board is never UNSOLVABLE")
	if result.get("status") == S.SOLVED:
		assert_eq(H.replay_error(s, _moves(result)), "")


func test_hint_avoids_the_trap() -> void:
	var s := _trap_state()
	assert_eq(H.norm(HalvesSolver.hint(s)), Vector2i(3, 5), "a greedy pick would take the trap (3,4)")
	assert_eq(s.remaining, 0b111111, "hint does not change the board")


func test_hint_is_minus_one_when_unsolvable_even_with_a_free_pair() -> void:
	var s := _trap_state()
	s.try_pair(3, 4)
	assert_eq(HalvesSolver.hint(s), Vector2i(-1, -1))


func test_hint_is_minus_one_without_a_free_pair() -> void:
	var stuck := H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0)], ["circle:v:-:a", "circle:v:-:a"])
	assert_eq(HalvesSolver.hint(stuck), Vector2i(-1, -1))
	var clear := H.state(H.column(2), ["circle:v:-:a", "circle:v:-:b"])
	clear.try_pair(0, 1)
	assert_eq(HalvesSolver.hint(clear), Vector2i(-1, -1), "nothing left to hint")


func test_following_hints_clears_a_dealt_board() -> void:
	var g := H.plan_geometry(5)
	var dealt := HalvesFill.deal(g, H.plan_keys(5, g.size()), SeedService.make_rng(["test_solver", "hints"], 1))
	assert_false(dealt.is_empty())
	if dealt.is_empty():
		return
	var s := HalvesState.new(g, dealt["faces"])
	var steps := 0
	while not s.is_cleared() and steps < g.size():
		var h := HalvesSolver.hint(s)
		assert_has(s.free_pairs(), H.norm(h), "hint %d is a free match" % steps)
		assert_eq(s.try_pair(h.x, h.y), HalvesState.Result.MATCH)
		steps += 1
	assert_true(s.is_cleared(), "every hint kept the board solvable")


func test_hint_with_a_tiny_budget_still_gives_a_free_pair() -> void:
	var g := H.plan_geometry(30)
	var dealt := HalvesFill.deal(g, H.plan_keys(30, g.size()), SeedService.make_rng(["test_solver", "big"], 1))
	if dealt.is_empty():
		fail_test("no deal")
		return
	var s := HalvesState.new(g, dealt["faces"])
	var h := HalvesSolver.hint(s, 1)
	assert_has(s.free_pairs(), H.norm(h), "SOLVED or UNKNOWN both give a free pair")
