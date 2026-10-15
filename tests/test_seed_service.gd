extends GutTest
## Seeds must be identical on every run, machine and engine version.

## First 8 bytes (little-endian int64) of SHA-256("halves|1|3|v1"), computed outside Godot.
const KNOWN_SEED: int = 3319350487049315658


func test_known_vector() -> void:
	assert_eq(SeedService.make_seed(["halves", 1, 3], 1), KNOWN_SEED)


func test_same_parts_same_seed() -> void:
	assert_eq(SeedService.make_seed(["sushi", 2, 7], 1), SeedService.make_seed(["sushi", 2, 7], 1))


func test_different_parts_or_version_change_seed() -> void:
	var base := SeedService.make_seed(["sushi", 2, 7], 1)
	assert_ne(SeedService.make_seed(["sushi", 2, 8], 1), base)
	assert_ne(SeedService.make_seed(["sushi", 2, 7], 2), base)


func test_seed_parts_survive_a_json_round_trip() -> void:
	var parts: Array = ["halves", 1, 3]
	var reloaded: Array = JSON.parse_string(JSON.stringify(parts))
	assert_eq(typeof(reloaded[1]), TYPE_FLOAT, "JSON should hand ints back as floats")
	assert_eq(SeedService.make_seed(reloaded, 1), KNOWN_SEED)


func test_fractional_floats_stay_distinct() -> void:
	assert_ne(SeedService.make_seed(["x", 1.5], 1), SeedService.make_seed(["x", 1], 1))


func test_rng_is_reproducible() -> void:
	var a := SeedService.make_rng(["daily", "2026-11-03"], 1)
	var b := SeedService.make_rng(["daily", "2026-11-03"], 1)
	for i in 5:
		assert_eq(a.randi(), b.randi())
