class_name HalvesBot
extends RefCounted
## Headless players that rate a Halves board: RANDOM takes any free pair, CAREFUL takes the pair
## that frees the most tiles. The generator uses rate() to put levels on the sawtooth curve.
## Bots never make mistakes; "decoy" measures how many tempting near-twins sit beside real pairs.

enum Policy { RANDOM, CAREFUL }


## One game from a full board until clear or stuck:
## {"cleared": bool, "steps": int, "free_pairs": float, "decoy": float} (means over every state seen).
static func play(geometry: HalvesGeometry, faces: PackedInt32Array, rng: RandomNumberGenerator,
		policy: Policy) -> Dictionary:
	var remaining := geometry.full_mask()
	var steps := 0
	var looks := 0
	var pair_sum := 0.0
	var decoy_sum := 0.0
	while remaining != 0:
		var free := geometry.free_tiles(remaining)
		var pairs: Array[Vector2i] = []
		var decoys := 0
		for i in free.size():
			for j in range(i + 1, free.size()):
				var a := faces[free[i]]
				var b := faces[free[j]]
				if HalvesFace.matches(a, b):
					pairs.append(Vector2i(free[i], free[j]))
				elif HalvesFace.is_decoy(a, b):
					decoys += 1
		looks += 1
		pair_sum += pairs.size()
		decoy_sum += float(decoys) / maxi(1, pairs.size())
		if pairs.is_empty():
			break
		var pick := pairs[rng.randi_range(0, pairs.size() - 1)] if policy == Policy.RANDOM \
				else _careful_pick(geometry, remaining, pairs, rng)
		remaining &= ~(1 << pick.x) & ~(1 << pick.y)
		steps += 1
	return {
		"cleared": remaining == 0,
		"steps": steps,
		"free_pairs": pair_sum / looks,
		"decoy": decoy_sum / looks,
	}


## `runs` RANDOM games then `runs` CAREFUL games from one rng seeded by `seed_parts + ["rate"]`.
static func rate(geometry: HalvesGeometry, faces: PackedInt32Array, seed_parts: Array, runs: int = 50) -> Dictionary:
	var rng := SeedService.make_rng(seed_parts + ["rate"], HalvesConfig.GEN_VERSION)
	var random_wins := 0
	var careful_wins := 0
	var pair_sum := 0.0
	var decoy_sum := 0.0
	for _run in runs:
		var game := play(geometry, faces, rng, Policy.RANDOM)
		random_wins += 1 if game.cleared else 0
		pair_sum += game.free_pairs
		decoy_sum += game.decoy
	for _run in runs:
		careful_wins += 1 if play(geometry, faces, rng, Policy.CAREFUL).cleared else 0
	var random_win := float(random_wins) / runs
	var avg_free_pairs := pair_sum / runs
	var decoy_exposure := decoy_sum / runs
	return {
		"runs": runs,
		"random_win": random_win,
		"careful_win": float(careful_wins) / runs,
		"avg_free_pairs": avg_free_pairs,
		"decoy_exposure": decoy_exposure,
		"difficulty": difficulty(random_win, decoy_exposure, avg_free_pairs),
	}


## 0 (trivial) to 100: getting stuck weighs most, then decoys, then having few choices.
static func difficulty(random_win: float, decoy_exposure: float, avg_free_pairs: float) -> float:
	return 100.0 * (0.6 * (1.0 - random_win) + 0.25 * minf(decoy_exposure / 1.5, 1.0)
			+ 0.15 * (1.0 - minf(avg_free_pairs, 6.0) / 6.0))


static func _careful_pick(geometry: HalvesGeometry, remaining: int, pairs: Array[Vector2i],
		rng: RandomNumberGenerator) -> Vector2i:
	var best: Array[Vector2i] = []
	var best_free := -1
	for pair in pairs:
		var free := HalvesGeometry.popcount(geometry.free_mask(remaining & ~(1 << pair.x) & ~(1 << pair.y)))
		if free > best_free:
			best_free = free
			best = [pair]
		elif free == best_free:
			best.append(pair)
	return best[rng.randi_range(0, best.size() - 1)]
