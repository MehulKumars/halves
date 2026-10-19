extends GutTest
## HalvesPools (v2): daily numbering from DAILY_EPOCH, daily_board, wrapping get_board, seeded
## run_order, and the baked pool files (ids, seed parts, features, solutions, replay). Written from
## docs/HALVES.md alone; needs the pool files. Boards are sampled (every 7th) to keep the run short.

const H := preload("res://tests/halves_helpers.gd")
const K := HalvesPools.Kind
const KINDS: Array[HalvesPools.Kind] = [K.DAILY, K.ZEN, K.RUSH]
const BASE := {K.DAILY: 10000, K.ZEN: 20000, K.RUSH: 30000}
const SAMPLE_STEP := 7


func test_daily_epoch() -> void:
	assert_eq(HalvesPools.DAILY_EPOCH, "2026-10-01")


func test_daily_number() -> void:
	assert_eq(HalvesPools.daily_number("2026-10-01"), 1, "the epoch is daily #1")
	assert_eq(HalvesPools.daily_number("2026-10-02"), 2)
	assert_eq(HalvesPools.daily_number("2026-10-31"), 31)
	assert_eq(HalvesPools.daily_number("2026-11-01"), 32, "October has 31 days")
	assert_eq(HalvesPools.daily_number("2027-10-01"), 366, "365 days later")
	assert_eq(HalvesPools.daily_number("2028-10-01"), 732, "2028 has a 29 February")


func test_daily_number_before_the_epoch_is_one() -> void:
	assert_eq(HalvesPools.daily_number("2026-09-30"), 1)
	assert_eq(HalvesPools.daily_number("2025-01-01"), 1)


func test_every_pool_has_boards() -> void:
	for kind: HalvesPools.Kind in KINDS:
		assert_gt(HalvesPools.count(kind), 0, "pool %d has boards" % kind)
		assert_gt(HalvesPools.gen_version(kind), 0, "pool %d has a gen version" % kind)


func test_daily_board_is_the_board_of_its_number() -> void:
	if HalvesPools.count(K.DAILY) == 0:
		fail_test("no daily boards")
		return
	for date: String in ["2026-10-01", "2026-10-02", "2026-11-01", "2027-03-15", "2020-01-01"]:
		var got := HalvesPools.daily_board(date)
		var want := HalvesPools.get_board(K.DAILY, HalvesPools.daily_number(date) - 1)
		assert_not_null(got, date)
		if got == null or want == null:
			continue
		assert_eq(got.level, want.level, date)
		assert_eq(got.faces, want.faces, date)
	var first := HalvesPools.daily_board("2026-10-01")
	if first != null:
		assert_eq(first.level, BASE[K.DAILY], "daily #1 is board 0")


func test_get_board_wraps() -> void:
	for kind: HalvesPools.Kind in KINDS:
		var n := HalvesPools.count(kind)
		if n == 0:
			fail_test("pool %d is empty" % kind)
			continue
		assert_eq(HalvesPools.get_board(kind, -1).level, HalvesPools.get_board(kind, n - 1).level, "index -1 is the last board")
		assert_eq(HalvesPools.get_board(kind, n).level, HalvesPools.get_board(kind, 0).level, "index count is the first board")
		assert_eq(HalvesPools.get_board(kind, 2 * n + 1).level, HalvesPools.get_board(kind, 1 % n).level)
		assert_eq(HalvesPools.get_board(kind, -n).level, HalvesPools.get_board(kind, 0).level)


func test_run_order_is_a_seeded_permutation() -> void:
	for kind: HalvesPools.Kind in KINDS:
		var n := HalvesPools.count(kind)
		var order := HalvesPools.run_order(kind, ["test_halves_pools", 1])
		var want: Array[int] = []
		for i: int in n:
			want.append(i)
		assert_eq(H.sorted_ints(order), want, "pool %d: a permutation of 0..count-1" % kind)
		assert_eq(HalvesPools.run_order(kind, ["test_halves_pools", 1]), order, "pool %d: same seed parts, same order" % kind)
		if n > 2:
			var differs := false
			for s: int in range(2, 6):
				differs = differs or HalvesPools.run_order(kind, ["test_halves_pools", s]) != order
			assert_true(differs, "pool %d: other seed parts give other orders" % kind)


func test_board_ids_and_seed_parts() -> void:
	for kind: HalvesPools.Kind in KINDS:
		for i: int in HalvesPools.count(kind):
			var board := HalvesPools.get_board(kind, i)
			if board == null:
				fail_test("pool %d board %d is null" % [kind, i])
				continue
			assert_eq(board.level, BASE[kind] + i, "pool %d board %d id" % [kind, i])
			if i % SAMPLE_STEP != 0:
				continue
			assert_eq(board.seed_parts.size(), 4, "pool %d board %d: [\"halves\", kind, i, k]" % [kind, i])
			if board.seed_parts.size() == 4:
				assert_eq(board.seed_parts[0], "halves")
				assert_eq(board.seed_parts[2], i, "pool %d board %d: the index in its seed parts" % [kind, i])
				assert_eq(typeof(board.seed_parts[3]), TYPE_INT, "JSON numbers come back as ints")


func test_sampled_boards_are_valid() -> void:
	for kind: HalvesPools.Kind in KINDS:
		for i: int in range(0, HalvesPools.count(kind), SAMPLE_STEP):
			var board := HalvesPools.get_board(kind, i)
			if board == null:
				continue
			var label := "pool %d board %d" % [kind, i]
			var plain := HalvesGeometry.from_positions(board.positions)
			assert_eq(H.js(board.features), H.js(HalvesFeatures.normalize(board.features)), label + ": normalised features")
			var errors := HalvesFeatures.validate(plain, board.features, board.solution)
			assert_true(errors.is_empty(), label + ": " + ", ".join(errors))
			assert_eq(board.geometry().features, board.features, label + ": geometry() has the features")
			assert_eq(board.solution.size(), int(board.positions.size() / 2.0), label)
			assert_eq(H.replay_error(board.new_state(), board.solution), "", label + ": the solution replays")


func test_replay_on_a_pool_board_uses_the_pool_gen_version() -> void:
	for kind: HalvesPools.Kind in KINDS:
		var board := HalvesPools.get_board(kind, 0)
		if board == null:
			fail_test("pool %d is empty" % kind)
			continue
		var run := HalvesRun.new()
		run.board = ["daily_2026-10-01", "zen", "rush"][kind]
		run.level = board.level
		run.gen_version = HalvesPools.gen_version(kind)
		for p: Vector2i in board.solution:
			run.advance(30)
			run.record(HalvesRun.Event.PAIR, p.x, p.y)
		run.finish()
		var r := HalvesRun.replay(board, run.to_dict())
		assert_eq(r.get("ok"), true, "pool %d: %s" % [kind, r.get("error", "")])
		assert_eq(r.get("cleared"), true)
		assert_eq(r.get("stars"), 3)
		run.gen_version = HalvesPools.gen_version(kind) + 1
		var wrong := HalvesRun.replay(board, run.to_dict())
		assert_eq(wrong.get("ok"), false, "pool %d: another gen version" % kind)
		assert_ne(String(wrong.get("error", "")), "")
