extends GutTest
## Contract tests for the baked v3 levels (data/levels/halves_v3.json), the v3 pools and the PERCEPTIVE bot.
## Written from docs/HALVES.md section 4b (and 2, 3) alone, not from the generator or the bot code.
## Stats-based checks read the baked "stats"; bot checks use tiny forced boards and few runs to stay fast.

const H := preload("res://tests/halves_helpers.gd")
const PLACE_ROLES: Array[String] = ["rest", "ramp", "ramp", "ramp", "hard", "breather", "ramp", "ramp", "ramp",
		"hard", "rest", "ramp", "ramp", "ramp", "hard", "breather", "ramp", "ramp", "hard", "finale"]
## Section 4b table: the new idea's tip on the first level of its place.
const TIPS: Dictionary = {1: "pair", 2: "layers", 3: "sides", 4: "decoy", 6: "trap", 8: "cut_h", 10: "diamond",
		21: "lookalike", 61: "mist", 101: "lock", 121: "lucky", 141: "frost", 161: "gold_pair", 162: "mend",
		181: "turned"}
const WARY_FLOOR: Dictionary = {"intro": 1.0, "rest": 0.97, "breather": 0.97, "ramp": 0.9, "hard": 0.75, "finale": 0.6}
const TRAP_RANGE: Dictionary = {"rest": [0.0, 0.1], "breather": [0.0, 0.1], "ramp": [0.15, 0.3],
		"hard": [0.3, 0.5], "finale": [0.4, 0.6]}

var _levels: Array[HalvesLevelData] = []


func before_all() -> void:
	for n: int in range(1, 301):
		var data := HalvesLevels.get_level(n)
		if data != null:
			_levels.append(data)


func _has_gold_pair(data: HalvesLevelData) -> bool:
	for face: int in data.faces:
		if HalvesState.is_gold(face):
			return true
	return false


func _count(data: HalvesLevelData, key: String) -> int:
	return (data.features.get(key, []) as Array).size()


func _has_locks(data: HalvesLevelData) -> bool:
	return not (data.features.get("locks", []) as Array).is_empty()


func _replays(data: HalvesLevelData) -> bool:
	var s := data.new_state()
	for step: Vector2i in data.solution:
		if s.try_pair(step.x, step.y) != HalvesState.Result.MATCH:
			return false
	return s.is_cleared()


# ---- the baked file ----

func test_file_numbering_places_and_version() -> void:
	var file := H.load_json(HalvesLevels.PATH)
	assert_eq(int(file.get("gen_version", 0)), 3)
	assert_eq(int(file.get("count", 0)), 300)
	assert_eq((file.get("levels", []) as Array).size(), 300)
	assert_eq(_levels.size(), 300)
	for i in _levels.size():
		assert_eq(_levels[i].level, i + 1, "numbered in order")
		assert_eq(_levels[i].place, i / 20 + 1, "level %d place" % (i + 1))
	for p: int in range(1, 16):
		var n := 0
		for data: HalvesLevelData in _levels:
			n += 1 if data.place == p else 0
		assert_eq(n, 20, "place %d has 20 levels" % p)


func test_roles_follow_the_sawtooth() -> void:
	for data: HalvesLevelData in _levels:
		var pos := (data.level - 1) % 20
		var want := "intro" if data.level == 1 else PLACE_ROLES[pos]
		assert_eq(data.role, want, "level %d role" % data.level)


func test_tile_counts_are_even_and_within_the_contract() -> void:
	for data: HalvesLevelData in _levels:
		var t := data.positions.size()
		assert_eq(t % 2, 0, "level %d even tile count" % data.level)
		assert_true(t >= 2 and t <= 120, "level %d: %d tiles within 120" % [data.level, t])
		if data.place == 1:
			assert_true(t >= 12 and t <= 32, "level %d (place 1) has %d tiles, contract [12, 32]" % [data.level, t])
		if data.place >= 11:
			assert_true(t >= 56 and t <= 112, "level %d (place %d) has %d tiles, contract [56, 112]" % [data.level, data.place, t])


func test_boards_grow_over_places_and_rest_is_smaller_than_hard() -> void:
	var mean: Array[float] = []
	for p: int in range(1, 16):
		var sum := 0.0
		var small := 0.0
		var big := 0.0
		var ns := 0
		var nb := 0
		for data: HalvesLevelData in _levels:
			if data.place != p:
				continue
			sum += data.positions.size()
			if data.role == "rest" or data.role == "breather":
				small += data.positions.size()
				ns += 1
			elif data.role == "hard" or data.role == "finale":
				big += data.positions.size()
				nb += 1
		mean.append(sum / 20.0)
		assert_lt(small / ns, big / nb, "place %d: rest/breather boards are smaller than hard/finale" % p)
	for p in range(1, 11):
		assert_gte(mean[p], mean[p - 1] - 1.0, "mean board size does not shrink from place %d to %d" % [p, p + 1])


func test_faces_are_valid_and_pairs_complete() -> void:
	for data: HalvesLevelData in _levels:
		var counts: Dictionary = {}
		for f: int in data.faces:
			assert_true(HalvesFace.is_valid(f), "level %d: valid face" % data.level)
			counts[HalvesFace.pair_key(f)] = int(counts.get(HalvesFace.pair_key(f), 0)) + 1
		for key: Variant in counts:
			assert_eq(int(counts[key]) % 2, 0, "level %d: pair key %s has an even count" % [data.level, str(key)])


func test_sampled_solutions_replay_through_try_pair() -> void:
	for n: int in range(1, 301, 7):
		assert_true(_replays(_levels[n - 1]), "level %d solution replays to a cleared board" % n)
	for n: int in [20, 100, 161, 162, 181, 200, 300]:
		assert_true(_replays(_levels[n - 1]), "level %d solution replays to a cleared board" % n)


func test_tips_on_the_levels_the_table_names() -> void:
	for n: int in TIPS:
		assert_eq(_levels[n - 1].tip, TIPS[n], "level %d tip" % n)


# ---- mechanics ----

func test_each_mechanic_first_appears_in_its_own_place() -> void:
	var first: Dictionary = {}
	for data: HalvesLevelData in _levels:
		var found: Array[String] = []
		if _count(data, "mist") > 0:
			found.append("mist")
		if _has_locks(data):
			found.append("lock")
		if _count(data, "lucky") > 0:
			found.append("lucky")
		if _count(data, "frost") > 0:
			found.append("frost")
		if _has_gold_pair(data):
			found.append("gold_pair")
		if _count(data, "turned") > 0:
			found.append("turned")
		for k: String in found:
			if not first.has(k):
				first[k] = data.level
	var want: Dictionary = {"mist": 61, "lock": 101, "lucky": 121, "frost": 141, "gold_pair": 161, "turned": 181}
	for k: String in want:
		assert_eq(first.get(k, -1), want[k], "%s first appears on level %d" % [k, want[k]])


func test_new_idea_levels_carry_it_and_mechanic_counts_hold() -> void:
	assert_eq(_count(_levels[60], "mist"), 2, "level 61: mist 2")
	assert_true(_has_locks(_levels[100]), "level 101: lock")
	assert_eq(_count(_levels[120], "lucky"), 2, "level 121: lucky 2")
	assert_eq(_count(_levels[140], "frost"), 2, "level 141: frost 2")
	assert_true(_has_gold_pair(_levels[160]), "level 161: gold pair")
	assert_true(_has_gold_pair(_levels[161]), "level 162: gold pair (mend)")
	assert_eq(_count(_levels[180], "turned"), 2, "level 181: turned 2")
	for data: HalvesLevelData in _levels:
		var n := data.level
		assert_lte(_count(data, "mist"), 2, "level %d mist at most 2" % n)
		if _count(data, "mist") > 0:
			assert_eq(data.role, "ramp" if n != 61 else data.role, "level %d: mist only on ramps" % n)
		assert_lte(_count(data, "lucky"), 3, "level %d lucky 1-3" % n)
		var turned := _count(data, "turned")
		assert_true(turned == 0 or (turned >= 2 and turned <= 6), "level %d turned 2-6 (has %d)" % [n, turned])


func test_positions_two_to_five_never_use_the_places_new_idea() -> void:
	for first: int in [61, 101, 121, 141, 161, 181]:
		for n: int in range(first + 1, first + 5):
			var d := _levels[n - 1]
			var has := false
			match first:
				61: has = _count(d, "mist") > 0
				101: has = _has_locks(d)
				121: has = _count(d, "lucky") > 0
				141: has = _count(d, "frost") > 0
				161: has = _has_gold_pair(d) and n != 162
				181: has = _count(d, "turned") > 0
			assert_false(has, "level %d must not use the idea introduced on %d" % [n, first])


func test_mechanic_frequencies_from_their_places() -> void:
	var lucky := 0
	var boards := 0
	var gold := 0
	var gold_boards := 0
	for data: HalvesLevelData in _levels:
		if data.place >= 7:
			boards += 1
			lucky += 1 if _count(data, "lucky") > 0 else 0
		if data.place >= 9:
			gold_boards += 1
			gold += 1 if _has_gold_pair(data) else 0
	assert_between(float(lucky) / boards, 0.3, 0.8, "lucky tiles on about half the boards from place 7")
	assert_between(float(gold) / gold_boards, 0.1, 0.5, "a gold pair on about one board in four from place 9")


# ---- stats against the role table ----

func test_stats_respect_the_role_floors_and_trap_ranges() -> void:
	for data: HalvesLevelData in _levels:
		var s := data.stats
		var n := data.level
		# Level 6, the trap tip, is the contract's one exception to the breather floor ("As built").
		var floor_wary := 0.95 if n == 6 else float(WARY_FLOOR[data.role])
		assert_gte(float(s.get("wary_win", -1)), floor_wary - 0.0001, "level %d (%s) wary floor" % [n, data.role])
		if data.role == "intro":
			assert_eq(float(s.get("random_win", 0)), 1.0, "intro random 1.0")
			assert_eq(float(s.get("trap_rate", 1)), 0.0, "intro has no traps")
		if data.place >= 2 and data.role != "intro":
			var r: Array = TRAP_RANGE[data.role]
			var tr := float(s.get("trap_rate", -1))
			assert_between(tr, float(r[0]) - 0.0001, float(r[1]) + 0.0001, "level %d (%s) trap_rate %s" % [n, data.role, str(tr)])
		if data.role == "hard" or data.role == "finale":
			assert_false(float(s.get("wary_win", 0)) == 1.0 and float(s.get("p3", 0)) > 0.9,
					"level %d: no hard/finale with wary_win 1.0 and p3 > 0.9" % n)


func test_p3_falls_with_role_difficulty() -> void:
	var sum: Dictionary = {}
	var cnt: Dictionary = {}
	for data: HalvesLevelData in _levels:
		if data.place == 1:
			continue
		var r := "rest" if data.role == "breather" else data.role
		sum[r] = float(sum.get(r, 0.0)) + float(data.stats.get("p3", 0.0))
		cnt[r] = int(cnt.get(r, 0)) + 1
	var m: Dictionary = {}
	for r: String in sum:
		m[r] = float(sum[r]) / int(cnt[r])
	assert_gt(m["rest"], m["ramp"], "mean p3: rest > ramp")
	assert_gt(m["ramp"], m["hard"], "mean p3: ramp > hard")
	assert_gt(m["hard"], m["finale"], "mean p3: hard > finale")
	assert_gte(m["rest"], 0.75, "rest levels aim at p3 0.85")
	assert_lte(m["finale"], 0.5, "finales aim at p3 0.35 down to 0.2")


func test_place_one_is_gentle() -> void:
	var sum := 0.0
	for data: HalvesLevelData in _levels:
		if data.place == 1:
			sum += float(data.stats.get("p3", 0.0))
	assert_gte(sum / 20.0, 0.7, "place 1 mean p3 (targets are at least 0.8)")


# ---- pools ----

func test_pool_sizes_versions_and_sample_solutions() -> void:
	var want: Dictionary = {HalvesPools.Kind.DAILY: 400, HalvesPools.Kind.ZEN: 150, HalvesPools.Kind.RUSH: 150}
	for kind: HalvesPools.Kind in want:
		assert_eq(HalvesPools.count(kind), want[kind], "pool %d size" % kind)
		assert_eq(HalvesPools.gen_version(kind), 3, "pool %d gen_version" % kind)
		for i: int in range(0, HalvesPools.count(kind), 13):
			var b := HalvesPools.get_board(kind, i)
			assert_not_null(b)
			if b == null:
				continue
			assert_true(_replays(b), "pool %d board %d solution replays" % [kind, i])
			var t := b.positions.size()
			assert_eq(t % 2, 0)
			match kind:
				HalvesPools.Kind.RUSH:
					assert_between(t, 12, 24, "rush board %d tiles" % i)
				HalvesPools.Kind.ZEN:
					assert_between(t, 36, 64, "zen board %d tiles" % i)
				HalvesPools.Kind.DAILY:
					assert_between(t, 28, 100, "daily board %d tiles" % i)


# ---- the PERCEPTIVE bot ----

func _slip_mean(s: HalvesState, runs: int, policy: HalvesBot.Policy = HalvesBot.Policy.PERCEPTIVE) -> float:
	var total := 0
	for i in runs:
		var rng := SeedService.make_rng(["v3bot", i], 3)
		var g := HalvesBot.play(s.geometry, s.faces, rng, policy)
		total += int(g.slips)
	return float(total) / runs


func _plain_board() -> HalvesState:
	return H.state([Vector3i(0, 0, 0), Vector3i(0, 4, 0), Vector3i(0, 8, 0), Vector3i(0, 12, 0)],
			["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b"])


func _twin_board() -> HalvesState:
	return H.state([Vector3i(0, 0, 0), Vector3i(0, 4, 0), Vector3i(0, 8, 0), Vector3i(0, 12, 0)],
			["circle:v:-:a", "circle:v:-:b", "circle:v:-:a", "circle:v:-:b"])


func _lookalike_board() -> HalvesState:
	return H.state([Vector3i(0, 0, 0), Vector3i(0, 4, 0), Vector3i(0, 8, 0), Vector3i(0, 12, 0)],
			["circle:v:-:a", "circle:v:-:b", "circle:h:-:a", "circle:h:-:b"])


func test_perceptive_never_slips_without_lookalikes() -> void:
	for i in 40:
		var s := _plain_board()
		var g := HalvesBot.play(s.geometry, s.faces, SeedService.make_rng(["v3plain", i], 3), HalvesBot.Policy.PERCEPTIVE)
		assert_eq(int(g.slips), 0, "no look-alikes, no slips")
		assert_true(g.cleared)


func test_perceptive_is_deterministic_for_a_seed() -> void:
	var data := _levels[149]
	for i in 3:
		var a := HalvesBot.play(data.geometry(), data.faces, SeedService.make_rng(["v3det", i], 3), HalvesBot.Policy.PERCEPTIVE)
		var b := HalvesBot.play(data.geometry(), data.faces, SeedService.make_rng(["v3det", i], 3), HalvesBot.Policy.PERCEPTIVE)
		assert_eq(a, b, "same seed, same game")
		assert_gte(int(a.slips), 0)


func test_other_policies_report_zero_slips() -> void:
	var s := _twin_board()
	for policy: HalvesBot.Policy in [HalvesBot.Policy.RANDOM, HalvesBot.Policy.CAREFUL, HalvesBot.Policy.WARY]:
		assert_eq(_slip_mean(s, 20, policy), 0.0, "policy %d never slips" % policy)


func test_twins_make_perceptive_slip_about_a_quarter_of_the_first_moves() -> void:
	# Four free twins: only the first move has non-mate look-alikes (p = 0.25 * 1); the second has none.
	var s := _twin_board()
	var m := _slip_mean(s, 400)
	assert_between(m, 0.12, 0.38, "mean slips about PERCEPTIVE_BASE = 0.25 (got %s)" % str(m))
	for i in 20:
		var g := HalvesBot.play(s.geometry, s.faces, SeedService.make_rng(["v3twin", i], 3), HalvesBot.Policy.PERCEPTIVE)
		assert_true(g.cleared, "a slip is a mistake, not a dead end, on an all-free board")


func test_slips_do_not_shrink_with_similarity() -> void:
	var twins := _slip_mean(_twin_board(), 400)
	var other := _slip_mean(_lookalike_board(), 400)
	assert_gte(twins, other - 0.05, "twins (similarity 1) slip at least as much as another cut")


func test_turned_tiles_raise_the_slip_chance() -> void:
	var base := _twin_board()
	var turned := _twin_board()
	turned.geometry = base.geometry.with_features({"turned": [0, 1, 2, 3]})
	var a := _slip_mean(base, 600)
	var b := _slip_mean(turned, 600)
	assert_gt(b, a + 0.04, "turned tiles: p x 1.5 (%s vs %s)" % [str(b), str(a)])


func test_rate_reports_perceptive_stats() -> void:
	var s := _twin_board()
	var r := HalvesBot.rate(s.geometry, s.faces, ["v3rate"], 40, 0)
	var r2 := HalvesBot.rate(s.geometry, s.faces, ["v3rate"], 40, 0)
	assert_eq(r, r2, "rate is deterministic")
	for k: String in ["perceptive_win", "perceptive_slips", "p3"]:
		assert_true(r.has(k), k)
	assert_between(float(r.p3), 0.0, 1.0)
	assert_lte(float(r.p3), float(r.perceptive_win) + 0.0001, "p3 counts only cleared runs")
	assert_eq(float(r.perceptive_win), 1.0, "all-free board always clears")
	# Level 1 is star-free (unlimited slips), so every cleared run counts toward p3.
	var free := HalvesBot.rate(s.geometry, s.faces, ["v3rate"], 40, 1)
	assert_eq(float(free.p3), float(free.perceptive_win), "star-free level: p3 == perceptive_win")
