extends GutTest
## The baked levels in data/levels/halves_v3.json, through HalvesLevels: count and version, every
## level's tiles, faces, solution, features, tip, stats and par, the plan slot it came from, and a
## "same seed, same level" rebuild. Written from docs/HALVES.md alone; counts come from the plan file.
## (v2) Contract changes from v1: 100 levels from the plan instead of 30, the careful_win >= 0.5 pin is
## now the slot's min_careful / min_wary floors, and levels are rebuilt with HalvesFill.deal_v2.
## (v3) 300 levels in 15 places of 20 from halves_plan_v3.json; roles add breather; levels carry
## their place and the PERCEPTIVE stats; features add turned and lucky; a slot's gold_pair turns one
## pair gold; levels are rebuilt through HalvesGenerator.deal with HalvesGenerator.feature_spec
## (the generator's class in tools/levelgen/, which the rebuild is about).

const H := preload("res://tests/halves_helpers.gd")
const RATE_KEYS: Array[String] = ["runs", "random_win", "careful_win", "wary_win", "avg_free_pairs", "decoy_exposure",
		"difficulty", "start_free_pairs", "traps", "trap_rate", "par_ms", "perceptive_win", "perceptive_slips", "p3"]
const ROLES: Array[String] = ["intro", "ramp", "hard", "rest", "breather", "finale"]
const FEATURE_KEYS: Array[String] = ["locks", "frost", "mist", "gold", "turned", "lucky"]


func _level(n: int) -> HalvesLevelData:
	var data := HalvesLevels.get_level(n)
	if data == null:
		fail_test("level %d missing from %s" % [n, HalvesLevels.PATH])
	return data


func _all_levels() -> Array[HalvesLevelData]:
	var out: Array[HalvesLevelData] = []
	for n: int in range(1, HalvesLevels.COUNT + 1):
		var data := _level(n)
		if data != null:
			out.append(data)
	return out


func test_file_has_every_plan_level_of_this_gen_version() -> void:
	assert_eq(HalvesLevels.PATH, "res://data/levels/halves_v3.json")
	assert_true(FileAccess.file_exists(HalvesLevels.PATH), "%s exists" % HalvesLevels.PATH)
	assert_eq(HalvesLevels.COUNT, 300)
	assert_eq(HalvesLevels.count(), HalvesLevels.COUNT)
	assert_eq(H.level_plan_slots().size(), HalvesLevels.COUNT, "one plan slot per level")
	assert_eq(HalvesLevels.gen_version(), HalvesConfig.GEN_VERSION)
	assert_eq(HalvesConfig.GEN_VERSION, 3)


## (v3) 15 places of HalvesChapters.LEVELS_PER_CHAPTER (20) levels; each level knows its place.
func test_every_level_is_in_its_place() -> void:
	assert_eq(HalvesChapters.LEVELS_PER_CHAPTER, 20)
	for data: HalvesLevelData in _all_levels():
		var want := int((data.level - 1) / float(HalvesChapters.LEVELS_PER_CHAPTER)) + 1
		assert_eq(data.place, want, "level %d place" % data.level)
		assert_eq(int(H.level_plan_slot(data.level).get("place", 0)), want, "level %d: the plan's place" % data.level)


func test_levels_outside_the_range_are_null() -> void:
	assert_null(HalvesLevels.get_level(0))
	assert_null(HalvesLevels.get_level(HalvesLevels.COUNT + 1))
	assert_null(HalvesLevels.get_level(-1))


func test_every_level_follows_its_plan_slot() -> void:
	var all_masks := H.masks()
	for data: HalvesLevelData in _all_levels():
		var n := data.level
		var slot := H.level_plan_slot(n)
		assert_false(slot.is_empty(), "level %d has a plan slot" % n)
		assert_has(ROLES, data.role, "level %d role" % n)
		assert_eq(data.role, String(slot.get("role", "")), "level %d role" % n)
		assert_eq(data.mask, String(slot.get("mask", "")), "level %d mask" % n)
		assert_eq(data.tip, String(slot.get("tip", "")), "level %d tip" % n)
		var mask: Dictionary = all_masks.get(data.mask, {})
		var layers: Array = mask.get("layers", [])
		assert_eq(data.positions, HalvesMask.parse(layers), "level %d positions are its mask" % n)
		# Pair keys: the plan's types round-robin over tiles / 2 pairs, one side A each; (v3) with the
		# slot's gold_pair, one of those pairs became the gold pair.
		var keys := H.sorted_ints(H.round_robin(slot.get("types", []), int(data.positions.size() / 2.0)))
		var got := H.side_a_keys(HalvesBits.full(HalvesBits.MAX), data.faces)
		if int(slot.get("gold_pair", 0)) > 0:
			var gold := got.filter(func(k: int) -> bool: return HalvesCrests.family_of(k) == &"gold")
			assert_eq(gold.size(), 1, "level %d has one gold pair" % n)
			var rest := got.filter(func(k: int) -> bool: return HalvesCrests.family_of(k) != &"gold")
			var missing := keys.duplicate()
			for k: int in rest:
				var at := missing.find(k)
				assert_ne(at, -1, "level %d: pair type %s is in the plan" % [n, HalvesFace.pair_to_text(k)])
				if at != -1:
					missing.remove_at(at)
			assert_eq(missing.size(), 1, "level %d: the gold pair took the place of one planned pair" % n)
		else:
			assert_eq(got, keys, "level %d pair types" % n)


func test_levels_are_numbered_in_order() -> void:
	var all := _all_levels()
	assert_eq(all.size(), HalvesLevels.COUNT)
	for i: int in all.size():
		assert_eq(all[i].level, i + 1)


func test_every_level_has_sorted_tiles_and_complete_pairs() -> void:
	for data: HalvesLevelData in _all_levels():
		var n := data.level
		var count := data.positions.size()
		assert_eq(data.faces.size(), count, "level %d: one face per tile" % n)
		assert_eq(count % 2, 0, "level %d: even tile count" % n)
		assert_true(count <= HalvesGeometry.MAX_TILES, "level %d: at most %d tiles" % [n, HalvesGeometry.MAX_TILES])
		for i: int in range(1, count):
			var a: Vector3i = data.positions[i - 1]
			var b: Vector3i = data.positions[i]
			var ordered := a.z < b.z or (a.z == b.z and (a.y < b.y or (a.y == b.y and a.x < b.x)))
			assert_true(ordered, "level %d: tiles %d and %d sorted by (z, y, x)" % [n, i - 1, i])
		var balance := {}
		for f: int in data.faces:
			assert_true(HalvesFace.is_valid(f), "level %d: face %d is valid" % [n, f])
			var key := HalvesFace.pair_key(f)
			balance[key] = int(balance.get(key, 0)) + (1 if HalvesFace.side(f) == HalvesFace.SIDE_A else -1)
		for key: int in balance:
			assert_eq(balance[key], 0, "level %d: as many A as B halves of %s" % [n, HalvesFace.pair_to_text(key)])
		assert_eq(data.geometry().size(), count)
		assert_eq(data.new_state().tiles_left(), count)


func test_every_solution_replays_as_matches_under_the_features() -> void:
	for data: HalvesLevelData in _all_levels():
		var n := data.level
		assert_eq(data.solution.size(), int(data.positions.size() / 2.0), "level %d" % n)
		assert_eq(data.geometry().features, data.features, "level %d: geometry() carries the features" % n)
		assert_eq(H.replay_error(data.new_state(), data.solution), "", "level %d" % n)


func test_every_level_has_valid_normalised_features() -> void:
	for data: HalvesLevelData in _all_levels():
		var n := data.level
		for key: String in data.features:
			assert_has(FEATURE_KEYS, key, "level %d: feature '%s'" % [n, key])
		assert_eq(H.js(data.features), H.js(HalvesFeatures.normalize(data.features)), "level %d: normalised" % n)
		var plain := HalvesGeometry.from_positions(data.positions)
		var errors := HalvesFeatures.validate(plain, data.features, data.solution)
		assert_true(errors.is_empty(), "level %d: %s" % [n, ", ".join(errors)])


func test_to_dict_and_from_dict() -> void:
	for data: HalvesLevelData in _all_levels():
		var n := data.level
		var d := data.to_dict()
		assert_eq(d.has("features"), not data.features.is_empty(), "level %d: features written only when not empty" % n)
		assert_eq(d.has("tip"), data.tip != "", "level %d: tip written only when not empty" % n)
		var parsed: Variant = JSON.parse_string(JSON.stringify(d))
		var back := HalvesLevelData.from_dict(parsed as Dictionary)
		assert_eq(back.level, n)
		assert_eq(back.positions, data.positions, "level %d positions" % n)
		assert_eq(back.faces, data.faces, "level %d faces" % n)
		assert_eq(back.solution, data.solution, "level %d solution" % n)
		assert_eq(H.js(back.features), H.js(data.features), "level %d features (ints after JSON)" % n)
		assert_eq(back.tip, data.tip, "level %d tip" % n)
		assert_eq(back.par_ms(), data.par_ms(), "level %d par" % n)


func test_every_level_has_its_seed_parts_and_stats() -> void:
	for data: HalvesLevelData in _all_levels():
		var n := data.level
		assert_eq(data.seed_parts.size(), 3, "level %d: [\"halves\", level, candidate]" % n)
		if data.seed_parts.size() < 3:
			continue
		assert_eq(data.seed_parts[0], "halves")
		assert_eq(typeof(data.seed_parts[1]), TYPE_INT, "level %d: JSON numbers come back as ints" % n)
		assert_eq(data.seed_parts[1], n)
		assert_eq(typeof(data.seed_parts[2]), TYPE_INT)
		for k: String in RATE_KEYS:
			assert_true(data.stats.has(k), "level %d stats have '%s'" % [n, k])
		var slot := H.level_plan_slot(n)
		var careful := float(data.stats.get("careful_win", -1.0))
		var wary := float(data.stats.get("wary_win", -1.0))
		assert_between(wary, 0.0, 1.0, "level %d wary_win" % n)
		assert_true(careful >= H.slot_min_careful(slot) - 1e-9,
				"level %d: careful_win %.2f under the slot's floor %.2f" % [n, careful, H.slot_min_careful(slot)])
		assert_true(wary >= H.slot_min_wary(slot) - 1e-9,
				"level %d: wary_win %.2f under the slot's floor %.2f" % [n, wary, H.slot_min_wary(slot)])
		var k := int(data.seed_parts[2])
		var trap: Array = slot.get("trap", [0.0, 0.0])
		var rate := float(data.stats.get("trap_rate", -1.0))
		# 1e-3: the file may round floats; neighbouring candidates differ by (hi - lo) / 3.
		assert_almost_eq(rate, H.slot_trap_rate(slot, k), 1e-3, "level %d: trap_rate of candidate %d" % [n, k])
		assert_between(rate, float(trap[0]) - 1e-3, float(trap[1]) + 1e-3, "level %d: trap_rate within the slot's range" % n)
		var plain := HalvesGeometry.from_positions(data.positions)
		assert_eq(int(data.stats.get("traps", -1)), HalvesFill.live_traps(plain, data.solution, data.faces),
				"level %d: traps = live_traps of the baked board" % n)


func test_par_follows_the_formula() -> void:
	for data: HalvesLevelData in _all_levels():
		var n := data.level
		var par := data.par_ms()
		assert_eq(par, int(data.stats.get("par_ms", -1)), "level %d: par_ms() is stats.par_ms" % n)
		assert_gt(par, 0, "level %d has a par" % n)
		var round_ms: int = int(HalvesConfig.PAR_ROUND_S) * 1000
		assert_eq(par % round_ms, 0, "level %d: par is a multiple of %d ms" % [n, round_ms])
		var pairs := int(data.positions.size() / 2.0)
		var types := {}
		for f: int in data.faces:
			types[HalvesFace.pair_key(f)] = true
		var layers := HalvesGeometry.from_positions(data.positions).max_z() + 1
		var feature_tiles := HalvesFeatures.tile_count(data.features)
		var difficulty := float(data.stats.get("difficulty", 0.0))
		var s := (HalvesConfig.PAR_BASE_S + pairs * HalvesConfig.PAR_PER_PAIR_S + types.size() * HalvesConfig.PAR_PER_TYPE_S
				+ layers * HalvesConfig.PAR_PER_LAYER_S + feature_tiles * HalvesConfig.PAR_PER_FEATURE_S) \
				* (1.0 + difficulty * HalvesConfig.PAR_DIFFICULTY_SCALE)
		var steps := s / HalvesConfig.PAR_ROUND_S
		var want := ceili(steps) * round_ms
		if absf(steps - roundf(steps)) < 5e-3:
			# The stored difficulty may be rounded: within 0.025 s of a boundary, either side is fair.
			assert_has([roundi(steps) * round_ms, (roundi(steps) + 1) * round_ms], par, "level %d par (at a boundary)" % n)
		else:
			assert_eq(par, want, "level %d par: s = %.3f" % [n, s])


func test_after_level_1_there_are_at_least_two_free_pairs_at_the_start() -> void:
	for data: HalvesLevelData in _all_levels():
		if data.level >= 2:
			assert_true(data.new_state().free_pairs().size() >= 2, "level %d" % data.level)


func test_tile_counts_follow_the_plan_masks() -> void:
	var biggest_mask := 0
	for slot: Dictionary in H.level_plan_slots():
		biggest_mask = maxi(biggest_mask, H.mask_positions(String(slot.get("mask", ""))).size())
	var biggest_level := 0
	for data: HalvesLevelData in _all_levels():
		var slot := H.level_plan_slot(data.level)
		assert_eq(data.positions.size(), H.mask_positions(String(slot.get("mask", ""))).size(), "level %d" % data.level)
		biggest_level = maxi(biggest_level, data.positions.size())
	assert_eq(biggest_level, biggest_mask, "the biggest level is the plan's biggest mask")


## Level 1, the first level whose slot asks for features, the first with a trap range and (v3) the
## first with a gold pair, turned tiles and lucky tiles, and the last level (the biggest place).
func _rebuild_levels() -> Array[int]:
	var out: Array[int] = [1]
	for want: String in ["features", "trap", "gold_pair", "turned", "lucky"]:
		for slot: Dictionary in H.level_plan_slots():
			var n := int(slot.get("level", 0))
			var has_it := false
			if want == "features":
				has_it = not (slot.get("features", {}) as Dictionary).is_empty()
			elif want == "trap":
				has_it = float((slot.get("trap", [0.0, 0.0]) as Array)[1]) > 0.0
			else:
				has_it = int(slot.get(want, 0)) > 0
			if has_it:
				if not out.has(n):
					out.append(n)
				break
	if not out.has(HalvesLevels.COUNT):
		out.append(HalvesLevels.COUNT)
	return out


## (v3) Rebuilt through HalvesGenerator.deal (HalvesFill.deal_v2, or with the slot's gold_pair the
## same steps with HalvesFill.with_gold_pair) and the slot's HalvesGenerator.feature_spec.
func test_same_seed_same_level() -> void:
	for n: int in _rebuild_levels():
		var data := _level(n)
		if data == null:
			continue
		var slot := H.level_plan_slot(n)
		var g := HalvesGeometry.from_positions(H.mask_positions(String(slot.get("mask", ""))))
		var keys := H.round_robin(slot.get("types", []), int(g.size() / 2.0))
		var k := int(data.seed_parts[2])
		var rng := SeedService.make_rng(data.seed_parts, HalvesLevels.gen_version())
		var dealt := HalvesGenerator.deal(g, keys, rng, H.slot_trap_rate(slot, k), HalvesGenerator.feature_spec(slot),
				int(slot.get("gold_pair", 0)) > 0)
		assert_false(dealt.is_empty(), "level %d deals again" % n)
		assert_eq(dealt.get("faces"), data.faces, "level %d faces" % n)
		assert_eq(dealt.get("solution"), data.solution, "level %d solution" % n)
		assert_eq(H.js(dealt.get("features", {})), H.js(data.features), "level %d features" % n)
		assert_eq(dealt.get("traps"), int(data.stats.get("traps", -1)), "level %d traps" % n)
