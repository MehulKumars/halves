class_name HalvesGenerator
extends RefCounted
## Pure steps of the Halves level generator: pair keys for a plan slot, seeded candidate deals,
## scoring against the slot's targets, and picking the winner. Driven by generate_halves.gd;
## lives in tools/ so it never ships. Seeds are ["halves", level, candidate] + gen_version.

const CANDIDATES: int = 60
const QUICK_RUNS: int = 10
const FINAL_RUNS: int = 50
const SHORTLIST: int = 5
## A careful player should rarely need the free shuffle; hard levels and finales may bite more.
const MIN_CAREFUL_WIN: float = 0.8
const MIN_CAREFUL_WIN_HARD: float = 0.6


## `pair_count` pair keys spread over `types` round-robin, in the listed order.
static func pair_keys_for(types: Array, pair_count: int) -> PackedInt32Array:
	var keys := PackedInt32Array()
	for k in pair_count:
		keys.append(HalvesFace.pair_from_text(str(types[k % types.size()])))
	return keys


static func seed_parts(level: int, candidate: int) -> Array:
	return ["halves", level, candidate]


## A seeded full deal for one candidate, or {} if the mask could not be filled.
static func deal_candidate(geometry: HalvesGeometry, keys: PackedInt32Array, level: int, candidate: int) -> Dictionary:
	var rng := SeedService.make_rng(seed_parts(level, candidate), HalvesConfig.GEN_VERSION)
	return HalvesFill.deal(geometry, keys, rng)


## Lower is better: the win target counts four times as much as the decoy target (decoys depend
## mostly on the plan's pair types, which candidates share).
static func score(stats: Dictionary, target_win: float, target_decoy: float) -> float:
	return 2.0 * absf(float(stats.random_win) - target_win) + 0.5 * absf(float(stats.decoy_exposure) - target_decoy)


static func start_free_pairs(geometry: HalvesGeometry, faces: PackedInt32Array) -> int:
	return HalvesState.new(geometry, faces).free_pairs().size()


static func accept(stats: Dictionary, level: int, role: String, free_pairs_at_start: int) -> bool:
	var min_careful := MIN_CAREFUL_WIN_HARD if role in ["hard", "finale"] else MIN_CAREFUL_WIN
	if float(stats.careful_win) < min_careful:
		return false
	return level == 1 or free_pairs_at_start >= 2


## Builds one level from its plan slot and mask layers; null if no candidate was acceptable.
## Appends readable notes to `log`.
static func build_level(slot: Dictionary, layers: Array, log: PackedStringArray, candidates: int = CANDIDATES) -> HalvesLevelData:
	var level := int(slot.level)
	var positions := HalvesMask.parse(layers)
	var problems := HalvesMask.validate(positions)
	if not problems.is_empty():
		log.append("level %d (%s): mask invalid: %s" % [level, slot.mask, "; ".join(problems)])
		return null
	var geometry := HalvesGeometry.from_positions(positions)
	var keys := pair_keys_for(slot.types, positions.size() / 2)
	var target_win := float(slot.target_win)
	var target_decoy := float(slot.target_decoy)
	var quick: Array[Dictionary] = []
	for k in candidates:
		var dealt := deal_candidate(geometry, keys, level, k)
		if dealt.is_empty():
			continue
		var faces: PackedInt32Array = dealt.faces
		var stats := HalvesBot.rate(geometry, faces, seed_parts(level, k), QUICK_RUNS)
		var free_pairs := start_free_pairs(geometry, faces)
		if not accept(stats, level, str(slot.role), free_pairs):
			continue
		quick.append({"k": k, "deal": dealt, "score": score(stats, target_win, target_decoy)})
	if quick.is_empty():
		log.append("level %d (%s): no acceptable candidate out of %d" % [level, slot.mask, candidates])
		return null
	quick.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.score < b.score or (a.score == b.score and a.k < b.k))
	var best: Dictionary = {}
	for entry in quick.slice(0, SHORTLIST):
		var dealt: Dictionary = entry.deal
		var stats := HalvesBot.rate(geometry, dealt.faces, seed_parts(level, entry.k), FINAL_RUNS)
		var s := score(stats, target_win, target_decoy)
		if best.is_empty() or s < best.score or (s == best.score and int(entry.k) < int(best.k)):
			best = {"k": entry.k, "deal": dealt, "stats": stats, "score": s}
	var data := HalvesLevelData.new()
	data.level = level
	data.role = str(slot.role)
	data.mask = str(slot.mask)
	data.seed_parts = seed_parts(level, int(best.k))
	data.positions = positions
	data.faces = best.deal.faces
	data.solution = best.deal.solution
	var stats: Dictionary = best.stats
	stats["start_free_pairs"] = start_free_pairs(geometry, data.faces)
	for key: String in ["random_win", "careful_win", "avg_free_pairs", "decoy_exposure", "difficulty"]:
		stats[key] = snappedf(float(stats[key]), 0.001)
	data.stats = stats
	log.append("level %2d %-7s %-15s tiles %2d  cand %2d  win %.2f (target %.2f)  careful %.2f  decoy %.2f (target %.2f)  pairs %.1f  diff %5.1f" % [
		level, data.role, data.mask, positions.size(), int(best.k), stats.random_win, target_win,
		stats.careful_win, stats.decoy_exposure, target_decoy, stats.avg_free_pairs, stats.difficulty])
	return data
