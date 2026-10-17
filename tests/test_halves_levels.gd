extends GutTest
## The baked levels in data/levels/halves_v1.json, through HalvesLevels: count and version, every
## level's tiles, faces, solution and seed, the plan it came from, and a "same seed, same level" rebuild.
## Written from docs/HALVES.md alone. Fails (on purpose) until the generator has written the file.

const H := preload("res://tests/halves_helpers.gd")
const RATE_KEYS: Array[String] = ["runs", "random_win", "careful_win", "avg_free_pairs", "decoy_exposure", "difficulty"]


func _level(n: int) -> HalvesLevelData:
	var data := HalvesLevels.get_level(n)
	if data == null:
		fail_test("level %d missing from %s" % [n, HalvesLevels.PATH])
	return data


func test_file_has_30_levels_of_this_gen_version() -> void:
	assert_true(FileAccess.file_exists(HalvesLevels.PATH), "%s exists" % HalvesLevels.PATH)
	assert_eq(HalvesLevels.COUNT, 30)
	assert_eq(HalvesLevels.count(), HalvesLevels.COUNT)
	assert_eq(HalvesLevels.gen_version(), HalvesConfig.GEN_VERSION)


func test_levels_outside_the_range_are_null() -> void:
	assert_null(HalvesLevels.get_level(0))
	assert_null(HalvesLevels.get_level(31))
	assert_null(HalvesLevels.get_level(-1))


func test_every_level_follows_its_plan_slot() -> void:
	var all_masks := H.masks()
	for n: int in range(1, 31):
		var data := _level(n)
		if data == null:
			continue
		var slot := H.plan_slot(n)
		assert_eq(data.level, n)
		assert_eq(data.role, String(slot.get("role", "")), "level %d role" % n)
		assert_eq(data.mask, String(slot.get("mask", "")), "level %d mask" % n)
		var mask: Dictionary = all_masks.get(data.mask, {})
		var layers: Array = mask.get("layers", [])
		assert_eq(data.positions, HalvesMask.parse(layers), "level %d positions are its mask" % n)
		# Pair keys: the plan's types round-robin over tiles / 2 pairs, one side A each.
		var keys := H.round_robin(slot.get("types", []), int(data.positions.size() / 2.0))
		assert_eq(H.side_a_keys(-1, data.faces), H.sorted_ints(keys), "level %d pair types" % n)


func test_every_level_has_sorted_tiles_and_complete_pairs() -> void:
	for n: int in range(1, 31):
		var data := _level(n)
		if data == null:
			continue
		var count := data.positions.size()
		assert_eq(data.faces.size(), count, "level %d: one face per tile" % n)
		assert_eq(count % 2, 0, "level %d: even tile count" % n)
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


func test_every_solution_replays_as_matches() -> void:
	for n: int in range(1, 31):
		var data := _level(n)
		if data == null:
			continue
		assert_eq(data.solution.size(), int(data.positions.size() / 2.0), "level %d" % n)
		assert_eq(H.replay_error(data.new_state(), data.solution), "", "level %d" % n)


func test_every_level_has_its_seed_parts_and_stats() -> void:
	for n: int in range(1, 31):
		var data := _level(n)
		if data == null:
			continue
		assert_eq(data.seed_parts.size(), 3, "level %d: [\"halves\", level, candidate]" % n)
		if data.seed_parts.size() < 2:
			continue
		assert_eq(data.seed_parts[0], "halves")
		assert_eq(typeof(data.seed_parts[1]), TYPE_INT, "level %d: JSON numbers come back as ints" % n)
		assert_eq(data.seed_parts[1], n)
		for k: String in RATE_KEYS:
			assert_true(data.stats.has(k), "level %d stats have '%s'" % [n, k])
		assert_true(float(data.stats.get("careful_win", 0.0)) >= 0.5, "level %d: candidates with careful_win < 0.5 are rejected" % n)


func test_after_level_1_there_are_at_least_two_free_pairs_at_the_start() -> void:
	for n: int in range(2, 31):
		var data := _level(n)
		if data == null:
			continue
		assert_true(data.new_state().free_pairs().size() >= 2, "level %d" % n)


func test_tile_counts() -> void:
	var first := _level(1)
	var last := _level(30)
	if first == null or last == null:
		return
	assert_eq(first.positions.size(), 8)
	for n: int in range(1, 30):
		var data := _level(n)
		if data != null:
			assert_true(data.positions.size() <= last.positions.size(), "level 30 has the most tiles (vs %d)" % n)


func test_same_seed_same_level() -> void:
	for n: int in [1, 12]:
		var data := _level(n)
		if data == null:
			continue
		var slot := H.plan_slot(n)
		var g := HalvesGeometry.from_positions(H.mask_positions(String(slot.get("mask", ""))))
		var keys := H.round_robin(slot.get("types", []), int(g.size() / 2.0))
		var rng := SeedService.make_rng(data.seed_parts, HalvesLevels.gen_version())
		var dealt := HalvesFill.deal(g, keys, rng)
		assert_false(dealt.is_empty(), "level %d deals again" % n)
		assert_eq(dealt.get("faces"), data.faces, "level %d faces" % n)
		assert_eq(dealt.get("solution"), data.solution, "level %d solution" % n)
