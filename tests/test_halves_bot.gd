extends GutTest
## HalvesBot: play on forced and trap boards (hand-computed step counts, free pairs and decoy means),
## rate keys, ranges and determinism, and the difficulty formula at its ends and in the middle.
## Written from docs/HALVES.md alone. "Per step" means every board the bot looks at with tiles left,
## the final stuck board included (the doc's max(1, free pairs) only matters there); a clear board is not a step.

const H := preload("res://tests/halves_helpers.gd")
const RATE_KEYS: Array[String] = ["runs", "random_win", "careful_win", "avg_free_pairs", "decoy_exposure", "difficulty"]
const PLAY_KEYS: Array[String] = ["cleared", "steps", "free_pairs", "decoy"]


func _rng(n: int) -> RandomNumberGenerator:
	return SeedService.make_rng(["test_halves_bot", n], 1)


## Forced board with decoys, ids in (z, y, x) order:
##   0 (0,0,0) circle:h:-:b  under tile 3
##   1 (0,4,0) circle:v:-:b
##   2 (0,8,0) circle:h:-:a
##   3 (0,0,1) circle:v:-:a
## Step 1: free 1, 2, 3. One match (1,3); (1,2) and (2,3) are decoys (other cut): 2 / 1 = 2.0.
## Step 2: free 0, 2. One match (0,2), no decoy: 0.0. Then the board is clear (not a step).
## Means: free_pairs 1.0, decoy 1.0.
func _forced_board() -> HalvesState:
	return H.state([Vector3i(0, 0, 0), Vector3i(0, 4, 0), Vector3i(0, 8, 0), Vector3i(0, 0, 1)],
			["circle:h:-:b", "circle:v:-:b", "circle:h:-:a", "circle:v:-:a"])


## The trap board of test_halves_solver.gd (see the comment there). CAREFUL always takes (3,4),
## which leaves 3 free tiles against 2 for (3,5), and then gets stuck after (0,1): 2 removals.
## Boards seen: the start has 2 free pairs and 1 decoy (4,5 are twins): 1/2; after (3,4) 1 pair, no
## decoy; the stuck board (only tile 5 free) 0 pairs, no decoy.
## So free_pairs = (2 + 1 + 0) / 3 = 1.0 and decoy = (0.5 + 0 + 0) / 3 = 1/6.
func _trap_board() -> HalvesState:
	return H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(0, 4, 0), Vector3i(0, 8, 0),
			Vector3i(1, 0, 1), Vector3i(0, 4, 1)],
			["tri:v:-:a", "tri:v:-:b", "circle:v:-:b", "circle:v:-:b", "circle:v:-:a", "circle:v:-:a"])


func _play(s: HalvesState, n: int, policy: HalvesBot.Policy) -> Dictionary:
	return HalvesBot.play(s.geometry, s.faces, _rng(n), policy)


func _assert_keys(d: Dictionary, keys: Array[String], label: String) -> void:
	for k: String in keys:
		assert_true(d.has(k), "%s has '%s'" % [label, k])


func test_forced_board_clears_with_both_policies() -> void:
	var s := _forced_board()
	for policy: HalvesBot.Policy in [HalvesBot.Policy.RANDOM, HalvesBot.Policy.CAREFUL]:
		for n: int in 3:
			var r := _play(s, n, policy)
			_assert_keys(r, PLAY_KEYS, "play")
			assert_eq(r.get("cleared"), true, "policy %d" % policy)
			assert_eq(r.get("steps"), 2)
			assert_almost_eq(float(r.get("free_pairs", -1.0)), 1.0, 1e-6)
			assert_almost_eq(float(r.get("decoy", -1.0)), 1.0, 1e-6)


func test_row_without_decoys() -> void:
	# Row of four: the ends match, then the middle pair: one free pair per step, never a decoy.
	var s := H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0)],
			["circle:v:-:a", "tri:v:-:a", "tri:v:-:b", "circle:v:-:b"])
	var r := _play(s, 0, HalvesBot.Policy.RANDOM)
	assert_eq(r.get("cleared"), true)
	assert_eq(r.get("steps"), 2)
	assert_almost_eq(float(r.get("free_pairs", -1.0)), 1.0, 1e-6)
	assert_almost_eq(float(r.get("decoy", -1.0)), 0.0, 1e-6)


func test_careful_walks_into_the_trap() -> void:
	var s := _trap_board()
	for n: int in 3:
		var r := _play(s, n, HalvesBot.Policy.CAREFUL)
		assert_eq(r.get("cleared"), false, "the most-free-tiles pick is the trap")
		assert_eq(r.get("steps"), 2)
		assert_almost_eq(float(r.get("free_pairs", -1.0)), 1.0, 1e-6)
		assert_almost_eq(float(r.get("decoy", -1.0)), 1.0 / 6.0, 1e-6)


func test_random_sometimes_avoids_the_trap() -> void:
	var s := _trap_board()
	var outcomes := {}
	for n: int in 24:
		var r := _play(s, n, HalvesBot.Policy.RANDOM)
		var cleared: bool = r.get("cleared", false)
		assert_eq(r.get("steps"), 3 if cleared else 2)
		outcomes[cleared] = true
	assert_eq(outcomes.size(), 2, "a uniform first pick clears about half the games")


func test_stuck_from_the_start() -> void:
	# One board seen: both tiles free, twins: 0 free pairs, 1 decoy / max(1, 0) = 1.
	var s := H.state(H.column(2), ["circle:v:-:a", "circle:v:-:a"])
	var r := _play(s, 0, HalvesBot.Policy.RANDOM)
	_assert_keys(r, PLAY_KEYS, "play")
	assert_eq(r.get("cleared"), false)
	assert_eq(r.get("steps"), 0)
	assert_almost_eq(float(r.get("free_pairs", -1.0)), 0.0, 1e-6)
	assert_almost_eq(float(r.get("decoy", -1.0)), 1.0, 1e-6)


func test_dealt_board_games() -> void:
	var g := H.plan_geometry(4)
	var dealt := HalvesFill.deal(g, H.plan_keys(4, g.size()), _rng(100))
	assert_false(dealt.is_empty())
	if dealt.is_empty():
		return
	var faces: PackedInt32Array = dealt["faces"]
	var half := int(g.size() / 2.0)
	for policy: HalvesBot.Policy in [HalvesBot.Policy.RANDOM, HalvesBot.Policy.CAREFUL]:
		for n: int in 5:
			var r := HalvesBot.play(g, faces, _rng(n), policy)
			_assert_keys(r, PLAY_KEYS, "play")
			var steps: int = r.get("steps", -1)
			if r.get("cleared", false):
				assert_eq(steps, half, "a cleared game removes every pair")
			else:
				assert_between(steps, 0, half - 1)
			# Every removal had at least one free pair; a stuck board adds one more board with none.
			var low := 1.0 if r.get("cleared", false) else steps / (steps + 1.0)
			assert_true(float(r.get("free_pairs", -1.0)) >= low - 1e-9, "free_pairs %s >= %s" % [r.get("free_pairs"), low])
			assert_true(float(r.get("decoy", -1.0)) >= 0.0)


func test_rate_keys_ranges_and_determinism() -> void:
	var g := H.plan_geometry(2)
	var dealt := HalvesFill.deal(g, H.plan_keys(2, g.size()), _rng(200))
	assert_false(dealt.is_empty())
	if dealt.is_empty():
		return
	var faces: PackedInt32Array = dealt["faces"]
	var a := HalvesBot.rate(g, faces, ["test_halves_bot", 2], 5)
	_assert_keys(a, RATE_KEYS, "rate")
	assert_eq(a.get("runs"), 5)
	assert_between(float(a.get("random_win", -1.0)), 0.0, 1.0)
	assert_between(float(a.get("careful_win", -1.0)), 0.0, 1.0)
	assert_between(float(a.get("difficulty", -1.0)), 0.0, 100.0)
	assert_true(float(a.get("avg_free_pairs", -1.0)) >= 0.0)
	assert_true(float(a.get("decoy_exposure", -1.0)) >= 0.0)
	assert_eq(HalvesBot.rate(g, faces, ["test_halves_bot", 2], 5), a, "same seed parts, same rating")


func test_rate_of_the_forced_board() -> void:
	var s := _forced_board()
	var r := HalvesBot.rate(s.geometry, s.faces, ["test_halves_bot", "forced"], 4)
	assert_almost_eq(float(r.get("random_win", -1.0)), 1.0, 1e-6)
	assert_almost_eq(float(r.get("careful_win", -1.0)), 1.0, 1e-6)
	assert_almost_eq(float(r.get("avg_free_pairs", -1.0)), 1.0, 1e-6)
	assert_almost_eq(float(r.get("decoy_exposure", -1.0)), 1.0, 1e-6)
	# 100 * (0.6 * 0 + 0.25 * (1 / 1.5) + 0.15 * (1 - 1 / 6)) = 100 * (1/6 + 1/8) = 29.1666...
	assert_almost_eq(float(r.get("difficulty", -1.0)), 700.0 / 24.0, 1e-4)


func test_rate_of_the_trap_board() -> void:
	var s := _trap_board()
	var r := HalvesBot.rate(s.geometry, s.faces, ["test_halves_bot", "trap"], 24)
	assert_almost_eq(float(r.get("careful_win", -1.0)), 0.0, 1e-6, "CAREFUL always takes the trap")
	var random_win := float(r.get("random_win", -1.0))
	assert_true(random_win > 0.0 and random_win < 1.0, "RANDOM wins some and loses some: %f" % random_win)


func test_difficulty_formula() -> void:
	assert_almost_eq(HalvesBot.difficulty(1.0, 0.0, 6.0), 0.0, 1e-6, "trivial")
	assert_almost_eq(HalvesBot.difficulty(0.0, 1.5, 0.0), 100.0, 1e-6, "hardest")
	# 100 * (0.6 * 0.5 + 0.25 * 0.5 + 0.15 * 0.5) = 50
	assert_almost_eq(HalvesBot.difficulty(0.5, 0.75, 3.0), 50.0, 1e-6)
	# Clamps: decoy 3.0 counts as 1.5, 10 free pairs as 6. 100 * (0.6 * 0.2 + 0.25) = 37
	assert_almost_eq(HalvesBot.difficulty(0.8, 3.0, 10.0), 37.0, 1e-6)
