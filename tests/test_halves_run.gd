extends GutTest
## HalvesRun (v2): the clock (start, advance clamped to MAX_STEP_MS, record, finish), to_dict and
## from_dict through JSON, and replay on real baked levels: clean runs, mistakes, undo, shuffles and
## every documented failure. Written from docs/HALVES.md alone; needs data/levels/halves_v2.json.

const H := preload("res://tests/halves_helpers.gd")
const E := HalvesRun.Event
const STEP_MS := 40


func _level(n: int) -> HalvesLevelData:
	var data := HalvesLevels.get_level(n)
	if data == null:
		fail_test("level %d missing from %s" % [n, HalvesLevels.PATH])
	return data


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


func _solution_from(data: HalvesLevelData, k: int) -> Array:
	return data.solution.slice(k)


func _assert_result(r: Dictionary, ok: bool, cleared: bool, stars: int, slips: int, label: String) -> void:
	for key: String in ["ok", "error", "cleared", "stars", "slips"]:
		assert_true(r.has(key), "%s: result has '%s'" % [label, key])
	assert_eq(r.get("ok"), ok, "%s: ok (error: %s)" % [label, r.get("error", "")])
	if ok:
		assert_eq(r.get("error"), "", label + ": no error")
	assert_eq(r.get("cleared"), cleared, label + ": cleared")
	assert_eq(r.get("stars"), stars, label + ": stars")
	assert_eq(r.get("slips"), slips, label + ": slips")


func _assert_fails(r: Dictionary, label: String) -> void:
	assert_eq(r.get("ok"), false, label + ": ok is false")
	assert_ne(String(r.get("error", "")).strip_edges(), "", label + ": with a readable error")


## The first (level, step, free decoy pair) found by following each level's solution, or [].
func _find_decoy() -> Array:
	for n: int in range(1, HalvesLevels.count() + 1):
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


## The state after `moves` and one shuffle with the documented rng, applied with `stuck`.
func _after_shuffle(data: HalvesLevelData, moves: Array, count: int, stuck: bool) -> HalvesState:
	var s := data.new_state()
	for p: Vector2i in moves:
		s.try_pair(p.x, p.y)
	var result := HalvesFill.shuffle(s, data.solution, HalvesFill.shuffle_rng(data.level, count))
	s.apply_deal(result["remaining"], result["faces"], stuck)
	return s


func _solve_rest(s: HalvesState) -> Array:
	var result := HalvesSolver.solve(s.geometry, s.faces, s.remaining)
	if result.get("status") != HalvesSolver.Status.SOLVED:
		fail_test("the shuffled board did not solve: %s" % result.get("status"))
		return []
	return result.get("moves", [])


# --- the clock ---


func test_constants_and_event_values() -> void:
	assert_eq(HalvesRun.FORMAT, 1)
	assert_eq(HalvesRun.MAX_STEP_MS, 250)
	# Saved logs store the kind as an int, so the enum order is part of the format.
	assert_eq([E.PAIR, E.MISMATCH, E.UNDO, E.SHUFFLE, E.HINT], [0, 1, 2, 3, 4])


func test_a_new_run() -> void:
	var run := HalvesRun.new()
	assert_false(run.started)
	assert_false(run.finished)
	assert_eq(run.active_ms, 0)
	assert_true(run.events.is_empty())


func test_advance_does_nothing_before_start() -> void:
	var run := HalvesRun.new()
	run.advance(100)
	assert_eq(run.active_ms, 0)
	assert_false(run.started)


func test_advance_clamps_each_step() -> void:
	var run := HalvesRun.new()
	run.start()
	assert_true(run.started)
	run.advance(100)
	assert_eq(run.active_ms, 100)
	run.advance(HalvesRun.MAX_STEP_MS + 5000)
	assert_eq(run.active_ms, 100 + HalvesRun.MAX_STEP_MS, "a long frame (or a pause) counts at most MAX_STEP_MS")
	run.advance(-40)
	assert_eq(run.active_ms, 100 + HalvesRun.MAX_STEP_MS, "negative steps count 0")
	run.advance(0)
	run.advance(HalvesRun.MAX_STEP_MS)
	assert_eq(run.active_ms, 100 + 2 * HalvesRun.MAX_STEP_MS)


func test_start_twice_keeps_the_clock() -> void:
	var run := HalvesRun.new()
	run.start()
	run.advance(120)
	run.start()
	assert_eq(run.active_ms, 120, "start is a no-op once started")
	assert_true(run.started)


func test_record_starts_the_clock_and_stamps_active_ms() -> void:
	var run := HalvesRun.new()
	run.record(E.PAIR, 3, 5)
	assert_true(run.started, "the first tap starts the clock")
	assert_eq(run.events, [[0, E.PAIR, 3, 5]])
	run.advance(120)
	run.record(E.UNDO)
	run.advance(30)
	run.record(E.SHUFFLE, 2, 1)
	assert_eq(run.events.size(), 3)
	assert_eq(run.events[1], [120, E.UNDO, -1, -1], "missing arguments are -1")
	assert_eq(run.events[2], [150, E.SHUFFLE, 2, 1])


func test_finish_stops_advance_and_record() -> void:
	var run := HalvesRun.new()
	run.start()
	run.advance(200)
	run.record(E.HINT, 1, 2)
	run.finish()
	assert_true(run.finished)
	run.advance(200)
	assert_eq(run.active_ms, 200, "the clock stops at the clear")
	run.record(E.PAIR, 1, 2)
	assert_eq(run.events.size(), 1, "records are ignored once finished")


# --- to_dict / from_dict ---


func _sample_run() -> HalvesRun:
	var run := HalvesRun.new()
	run.board = "daily_2026-10-21"
	run.level = 10020
	run.gen_version = 2
	run.free_mistakes = 1
	run.strict = true
	run.record(E.PAIR, 4, 9)
	run.advance(90)
	run.record(E.MISMATCH, 1, 2)
	run.advance(250)
	run.record(E.SHUFFLE, 0, 1)
	run.advance(10)
	return run


func test_to_dict_keys_and_values() -> void:
	var d := _sample_run().to_dict()
	assert_eq(d.get("format"), 1)
	assert_eq(d.get("board"), "daily_2026-10-21")
	assert_eq(d.get("level"), 10020)
	assert_eq(d.get("gen"), 2)
	assert_eq(d.get("free_mistakes"), 1)
	assert_eq(d.get("strict"), true)
	assert_eq(d.get("active_ms"), 350)
	assert_eq(d.get("events"), [[0, E.PAIR, 4, 9], [90, E.MISMATCH, 1, 2], [340, E.SHUFFLE, 0, 1]])
	var keys: Array = d.keys()
	keys.sort()
	assert_eq(keys, ["active_ms", "board", "events", "format", "free_mistakes", "gen", "level", "strict"])


func test_from_dict_round_trip() -> void:
	var run := _sample_run()
	var d := run.to_dict()
	var back := HalvesRun.from_dict(d)
	assert_eq(back.board, run.board)
	assert_eq(back.level, run.level)
	assert_eq(back.gen_version, run.gen_version)
	assert_eq(back.free_mistakes, run.free_mistakes)
	assert_eq(back.strict, run.strict)
	assert_eq(back.active_ms, run.active_ms)
	assert_eq(back.events, run.events)
	assert_eq(H.js(back.to_dict()), H.js(d))


func test_from_dict_through_json_casts_ints_back() -> void:
	var d := _sample_run().to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	assert_true(parsed is Dictionary)
	var back := HalvesRun.from_dict(parsed as Dictionary)
	assert_eq(typeof(back.level), TYPE_INT)
	assert_eq(typeof(back.active_ms), TYPE_INT)
	assert_eq(H.js(back.to_dict()), H.js(d), "ints, not floats, after JSON")
	assert_eq(back.events, d.get("events"))
	for e: Array in back.events:
		for v: Variant in e:
			assert_eq(typeof(v), TYPE_INT, "event %s" % [e])


# --- replay ---


func test_replay_the_baked_solution() -> void:
	for n: int in [2, 3]:
		var data := _level(n)
		if data == null:
			continue
		var run := _new_run(data)
		run.record(E.HINT, data.solution[0].x, data.solution[0].y)
		run.record(E.PAIR, data.solution[0].y, data.solution[0].x)
		_record_pairs(run, _solution_from(data, 1))
		run.finish()
		_assert_result(HalvesRun.replay(data, run.to_dict()), true, true, 3, 0, "level %d" % n)


func test_replay_a_run_saved_as_json() -> void:
	var data := _level(2)
	if data == null:
		return
	var run := _new_run(data)
	_record_pairs(run, data.solution)
	run.finish()
	var parsed: Variant = JSON.parse_string(JSON.stringify(run.to_dict()))
	_assert_result(HalvesRun.replay(data, parsed as Dictionary), true, true, 3, 0, "after JSON")


func test_replay_a_partial_run() -> void:
	var data := _level(3)
	if data == null:
		return
	var run := _new_run(data)
	_record_pairs(run, data.solution.slice(0, 2))
	_assert_result(HalvesRun.replay(data, run.to_dict()), true, false, 3, 0, "two pairs")


func test_replay_a_mismatch_costs_a_star() -> void:
	var found := _find_decoy()
	if found.is_empty():
		pending("no level offers a free decoy along its solution")
		return
	var data: HalvesLevelData = found[0]
	var k: int = found[1]
	var decoy: Vector2i = found[2]
	var run := _new_run(data)
	_record_pairs(run, data.solution.slice(0, k))
	run.advance(STEP_MS)
	run.record(E.MISMATCH, decoy.x, decoy.y)
	_record_pairs(run, _solution_from(data, k))
	_assert_result(HalvesRun.replay(data, run.to_dict()), true, true, 2, 1, "level %d" % data.level)
	# (v3) The default allowance is 0; with an allowance of 1 (or unlimited) one slip is free.
	_assert_result(HalvesRun.replay(data, run.to_dict(), -1, 1), true, true, 3, 1, "level %d, allowance 1" % data.level)
	_assert_result(HalvesRun.replay(data, run.to_dict(), -1, -1), true, true, 3, 1, "level %d, unlimited" % data.level)
	# The same run with the tutorial's free mistake: the mismatch still replays, at no cost.
	run.free_mistakes = 1
	_assert_result(HalvesRun.replay(data, run.to_dict()), true, true, 3, 0, "level %d, free mistake" % data.level)
	# And undoing the mistake gives the star back.
	var undone := _new_run(data)
	_record_pairs(undone, data.solution.slice(0, k))
	undone.record(E.MISMATCH, decoy.y, decoy.x)
	undone.record(E.UNDO)
	_record_pairs(undone, _solution_from(data, k))
	_assert_result(HalvesRun.replay(data, undone.to_dict()), true, true, 3, 0, "level %d, undone" % data.level)


func test_replay_undo_of_a_pair() -> void:
	var data := _level(3)
	if data == null:
		return
	var run := _new_run(data)
	_record_pairs(run, data.solution.slice(0, 1))
	run.advance(STEP_MS)
	run.record(E.UNDO)
	_record_pairs(run, data.solution)
	_assert_result(HalvesRun.replay(data, run.to_dict()), true, true, 3, 0, "pair, undo, then the solution")


func test_replay_a_shuffle_while_not_stuck() -> void:
	var data := _level(3)
	if data == null:
		return
	var moves: Array = data.solution.slice(0, 2)
	var s := _after_shuffle(data, moves, 0, false)
	var rest := _solve_rest(s)
	var run := _new_run(data)
	_record_pairs(run, moves)
	run.advance(STEP_MS)
	run.record(E.SHUFFLE, 0, 0)
	_record_pairs(run, rest)
	_assert_result(HalvesRun.replay(data, run.to_dict()), true, true, 3, 0, "a shuffle is not a slip unless stuck")
	var wrong := _new_run(data)
	_record_pairs(wrong, moves)
	wrong.record(E.SHUFFLE, 0, 1)
	_record_pairs(wrong, rest)
	_assert_fails(HalvesRun.replay(data, wrong.to_dict()), "stuck flag 1 on a board that is not stuck")


func test_replay_a_stuck_shuffle_is_a_slip() -> void:
	var data: HalvesLevelData = null
	var line: Array[Vector2i] = []
	for n: int in range(2, HalvesLevels.count() + 1):
		var candidate := HalvesLevels.get_level(n)
		if candidate == null:
			continue
		line = H.stuck_line(candidate, 10)
		if not line.is_empty():
			data = candidate
			break
	if data == null:
		pending("no random line of play got stuck")
		return
	var s := _after_shuffle(data, line, 0, true)
	assert_eq(s.stuck_shuffles, 1, "test setup")
	var rest := _solve_rest(s)
	var run := _new_run(data)
	_record_pairs(run, line)
	run.advance(STEP_MS)
	run.record(E.SHUFFLE, 0, 1)
	_record_pairs(run, rest)
	_assert_result(HalvesRun.replay(data, run.to_dict()), true, true, 2, 1, "level %d" % data.level)
	var wrong := _new_run(data)
	_record_pairs(wrong, line)
	wrong.record(E.SHUFFLE, 0, 0)
	_record_pairs(wrong, rest)
	_assert_fails(HalvesRun.replay(data, wrong.to_dict()), "stuck flag 0 on a stuck board")


func test_replay_rejects_a_pair_that_is_not_a_match() -> void:
	var data := _level(3)
	if data == null:
		return
	var same := _new_run(data)
	same.record(E.PAIR, data.solution[0].x, data.solution[0].x)
	_assert_fails(HalvesRun.replay(data, same.to_dict()), "a tile paired with itself")
	var found := _find_decoy()
	if found.is_empty():
		return
	var decoy_data: HalvesLevelData = found[0]
	var k: int = found[1]
	var decoy: Vector2i = found[2]
	var run := _new_run(decoy_data)
	_record_pairs(run, decoy_data.solution.slice(0, k))
	run.record(E.PAIR, decoy.x, decoy.y)
	_assert_fails(HalvesRun.replay(decoy_data, run.to_dict()), "a decoy recorded as a pair")


func test_replay_rejects_a_mismatch_that_matches() -> void:
	var data := _level(3)
	if data == null:
		return
	var run := _new_run(data)
	run.record(E.MISMATCH, data.solution[0].x, data.solution[0].y)
	_assert_fails(HalvesRun.replay(data, run.to_dict()), "MISMATCH on a free matching pair")


func test_replay_rejects_an_undo_with_nothing_to_undo() -> void:
	var data := _level(3)
	if data == null:
		return
	var run := _new_run(data)
	run.record(E.UNDO)
	_record_pairs(run, data.solution)
	_assert_fails(HalvesRun.replay(data, run.to_dict()), "UNDO on a fresh board")


func test_replay_rejects_bad_times() -> void:
	var data := _level(3)
	if data == null:
		return
	var run := _new_run(data)
	_record_pairs(run, data.solution)
	run.finish()
	var good := run.to_dict()
	_assert_result(HalvesRun.replay(data, good), true, true, 3, 0, "test setup")
	var decreasing: Dictionary = good.duplicate(true)
	var events_d: Array = decreasing["events"]
	var first: Array = events_d[0]
	var second: Array = events_d[1]
	second[0] = int(first[0]) - 1
	_assert_fails(HalvesRun.replay(data, decreasing), "a time going backwards")
	var late: Dictionary = good.duplicate(true)
	var events: Array = late["events"]
	late["active_ms"] = int((events[events.size() - 1] as Array)[0]) - 1
	_assert_fails(HalvesRun.replay(data, late), "an event after the clock stopped")


func test_replay_rejects_another_gen_version() -> void:
	var data := _level(3)
	if data == null:
		return
	var run := _new_run(data)
	_record_pairs(run, data.solution)
	run.gen_version = HalvesLevels.gen_version() + 1
	_assert_fails(HalvesRun.replay(data, run.to_dict()), "gen differs from the level file's")
