class_name HalvesBot
extends RefCounted
## Headless players that rate a Halves board: RANDOM takes any free pair, CAREFUL the pair that
## frees the most tiles, WARY any pair that is not an obvious trap, and (v3) PERCEPTIVE plays as
## WARY but sometimes taps a look-alike first (a slip). The generator uses rate() to put levels on
## the sawtooth curve. (v3) Every policy spends a mend it earned (gold pair) when stuck, then carries on.

enum Policy { RANDOM, CAREFUL, WARY, PERCEPTIVE }


## Per-board lookups shared by the games of one rating, so the hot loop compares ints: each tile's
## pair key, look-alike group id (-1 for an invalid face), gold and turned flags, the tiles of each
## pair key, and a cache of HalvesCrests.similarity between pair keys.
class Board:
	extends RefCounted
	var geometry: HalvesGeometry
	var faces: PackedInt32Array
	var keys: PackedInt32Array = PackedInt32Array()
	var groups: PackedInt32Array = PackedInt32Array()
	var gold: PackedByteArray = PackedByteArray()
	var turned: PackedByteArray = PackedByteArray()
	var tiles_of_key: Dictionary[int, PackedInt32Array] = {}
	var _similar: Dictionary[int, float] = {}

	func _init(board_geometry: HalvesGeometry, board_faces: PackedInt32Array) -> void:
		geometry = board_geometry
		faces = board_faces
		var n := geometry.size()
		keys.resize(n)
		groups.resize(n)
		gold.resize(n)
		turned.resize(n)
		var group_ids: Dictionary[StringName, int] = {}
		for i in n:
			var face := faces[i]
			keys[i] = HalvesFace.pair_key(face)
			var group := HalvesFace.group(face) if face >= 0 else &""
			if group == &"":
				groups[i] = -1
			else:
				if not group_ids.has(group):
					group_ids[group] = group_ids.size()
				groups[i] = group_ids[group]
			gold[i] = 1 if face >= 0 and HalvesFace.is_crest(face) and HalvesState.is_gold(face) else 0
			if not tiles_of_key.has(keys[i]):
				tiles_of_key[keys[i]] = PackedInt32Array()
			tiles_of_key[keys[i]].append(i)
		for t: Variant in geometry.features.get("turned", []):
			if int(t) >= 0 and int(t) < n:
				turned[int(t)] = 1

	func similarity(key_a: int, key_b: int) -> float:
		var id := key_a * 4096 + key_b
		if not _similar.has(id):
			_similar[id] = HalvesCrests.similarity(key_a, key_b)
		return _similar[id]

	## True if tile x lies on tile y or y on x.
	func stacked(x: int, y: int) -> bool:
		var on_y := geometry.cover[y]
		var on_x := geometry.cover[x]
		return on_y[x >> 6] & (1 << (x & 63)) != 0 or on_x[y >> 6] & (1 << (y & 63)) != 0


## One game from a full board until clear or stuck (with no mend left):
## {"cleared": bool, "steps": int, "free_pairs": float, "decoy": float, "slips": int} (means over
## every state seen; slips are PERCEPTIVE's mistaps, 0 for the other policies).
static func play(geometry: HalvesGeometry, faces: PackedInt32Array, rng: RandomNumberGenerator,
		policy: Policy) -> Dictionary:
	return _play(Board.new(geometry, faces), rng, policy)


## `runs` RANDOM, then CAREFUL, then WARY, then (v3) PERCEPTIVE games from one rng seeded by
## `seed_parts + ["rate"]`. `level` (v3) picks the slip allowance for p3:
## HalvesConfig.star_allowance(LEVELS, level, pairs); 0 means no particular level.
static func rate(geometry: HalvesGeometry, faces: PackedInt32Array, seed_parts: Array, runs: int = 50,
		level: int = 0) -> Dictionary:
	var rng := SeedService.make_rng(seed_parts + ["rate"], HalvesConfig.GEN_VERSION)
	var board := Board.new(geometry, faces)
	var random_wins := 0
	var careful_wins := 0
	var pair_sum := 0.0
	var decoy_sum := 0.0
	for _run in runs:
		var game := _play(board, rng, Policy.RANDOM)
		random_wins += 1 if game.cleared else 0
		pair_sum += game.free_pairs
		decoy_sum += game.decoy
	for _run in runs:
		careful_wins += 1 if _play(board, rng, Policy.CAREFUL).cleared else 0
	var wary_wins := 0
	for _run in runs:
		wary_wins += 1 if _play(board, rng, Policy.WARY).cleared else 0
	var allowance := HalvesConfig.star_allowance(Screens.Mode.LEVELS, level, geometry.size() / 2)
	var perceptive_wins := 0
	var slip_sum := 0
	var three_stars := 0
	for _run in runs:
		var game := _play(board, rng, Policy.PERCEPTIVE)
		slip_sum += int(game.slips)
		if game.cleared:
			perceptive_wins += 1
			if allowance < 0 or int(game.slips) <= allowance:
				three_stars += 1
	var random_win := float(random_wins) / runs
	var avg_free_pairs := pair_sum / runs
	var decoy_exposure := decoy_sum / runs
	return {
		"runs": runs,
		"random_win": random_win,
		"careful_win": float(careful_wins) / runs,
		"wary_win": float(wary_wins) / runs,
		"avg_free_pairs": avg_free_pairs,
		"decoy_exposure": decoy_exposure,
		"difficulty": difficulty(random_win, decoy_exposure, avg_free_pairs),
		"perceptive_win": float(perceptive_wins) / runs,
		"perceptive_slips": float(slip_sum) / runs,
		"p3": float(three_stars) / runs,
	}


## 0 (trivial) to 100: getting stuck weighs most, then decoys, then having few choices.
static func difficulty(random_win: float, decoy_exposure: float, avg_free_pairs: float) -> float:
	return 100.0 * (0.6 * (1.0 - random_win) + 0.25 * minf(decoy_exposure / 1.5, 1.0)
			+ 0.15 * (1.0 - minf(avg_free_pairs, 6.0) / 6.0))


## True if taking `pair` leads straight into a dead end a human learns to see: no free pair left
## with tiles remaining, or a pair type whose last two tiles sit one on top of the other.
static func is_trap_move(geometry: HalvesGeometry, faces: PackedInt32Array, remaining: PackedInt64Array,
		pair: Vector2i) -> bool:
	var after := _without(remaining, pair)
	if HalvesBits.is_empty(after):
		return false
	var by_key: Dictionary[int, PackedInt32Array] = {}
	var a0 := after[0]
	var a1 := after[1]
	for i in geometry.size():
		if (a0 if i < 64 else a1) & (1 << (i & 63)) != 0:
			var key := HalvesFace.pair_key(faces[i])
			if not by_key.has(key):
				by_key[key] = PackedInt32Array()
			by_key[key].append(i)
	for tiles: PackedInt32Array in by_key.values():
		if tiles.size() != 2:
			continue
		var x := tiles[0]
		var y := tiles[1]
		var on_x := geometry.cover[x]
		var on_y := geometry.cover[y]
		if on_x[y >> 6] & (1 << (y & 63)) != 0 or on_y[x >> 6] & (1 << (x & 63)) != 0:
			return true
	var free := geometry.free_tiles(after)
	for i in free.size():
		for j in range(i + 1, free.size()):
			if HalvesFace.matches(faces[free[i]], faces[free[j]]):
				return false
	return true


## The game loop behind play(). Keeps, as it goes, the remaining tile count of every pair key and
## the number of keys whose last two tiles are stacked, so the WARY trap test needs no rescan.
static func _play(board: Board, rng: RandomNumberGenerator, policy: Policy) -> Dictionary:
	var geometry := board.geometry
	var faces := board.faces
	var keys := board.keys
	var groups := board.groups
	var remaining := geometry.full_mask()
	var counts: Dictionary[int, int] = {}
	for key: int in board.tiles_of_key:
		counts[key] = board.tiles_of_key[key].size()
	var stacked_keys := 0
	for key: int in counts:
		if counts[key] == 2 and board.stacked(board.tiles_of_key[key][0], board.tiles_of_key[key][1]):
			stacked_keys += 1
	var seen := PackedInt32Array()
	seen.resize(_max_face(faces) + 2)
	var stamp := [0]
	var steps := 0
	var looks := 0
	var pair_sum := 0.0
	var decoy_sum := 0.0
	var mends := 0
	var slips := 0
	var wary := policy == Policy.WARY or policy == Policy.PERCEPTIVE
	while not HalvesBits.is_empty(remaining):
		var free := geometry.free_tiles(remaining)
		var pairs: Array[Vector2i] = []
		var decoys := 0
		var nf := free.size()
		for i in nf:
			var a := free[i]
			var key_a := keys[a]
			var group_a := groups[a]
			var face_a := faces[a]
			for j in range(i + 1, nf):
				var b := free[j]
				if keys[b] == key_a:
					if faces[b] != face_a:
						pairs.append(Vector2i(a, b))
					elif group_a >= 0:
						decoys += 1
				elif group_a >= 0 and groups[b] == group_a:
					decoys += 1
		looks += 1
		pair_sum += pairs.size()
		decoy_sum += float(decoys) / maxi(1, pairs.size())
		var pick: Vector2i
		if pairs.is_empty():
			pick = _mend_pick(geometry, faces, remaining) if mends > 0 else Vector2i(-1, -1)
			if pick.x < 0:
				break
			mends -= 1
		else:
			match policy:
				Policy.CAREFUL:
					pick = _careful_pick(geometry, remaining, pairs, rng)
				Policy.WARY, Policy.PERCEPTIVE:
					var safe: Array[Vector2i] = []
					for pair in pairs:
						if not _is_trap(board, remaining, counts, stacked_keys, pair, seen, stamp):
							safe.append(pair)
					var pool := safe if not safe.is_empty() else pairs
					pick = pool[rng.randi_range(0, pool.size() - 1)]
				_:
					pick = pairs[rng.randi_range(0, pairs.size() - 1)]
			if policy == Policy.PERCEPTIVE and _slips_before(board, free, pick.x, rng):
				slips += 1
		if board.gold[pick.x] == 1:
			mends += 1
		if wary:
			var key := keys[pick.x]
			var before: int = counts[key]
			if before == 2:
				if board.stacked(pick.x, pick.y):
					stacked_keys -= 1
			elif before == 4:
				var left := _other_two(board, remaining, key, pick)
				if board.stacked(left.x, left.y):
					stacked_keys += 1
			counts[key] = before - 2
		HalvesBits.clear_bit(remaining, pick.x)
		HalvesBits.clear_bit(remaining, pick.y)
		steps += 1
	return {
		"cleared": HalvesBits.is_empty(remaining),
		"steps": steps,
		"free_pairs": pair_sum / looks,
		"decoy": decoy_sum / looks,
		"slips": slips,
	}


## is_trap_move for the game loop, from the kept counts: after taking `pair` (two tiles of one
## key), is some key down to two stacked tiles, or is there no free matching pair?
static func _is_trap(board: Board, remaining: PackedInt64Array, counts: Dictionary[int, int], stacked_keys: int,
		pair: Vector2i, seen: PackedInt32Array, stamp: Array) -> bool:
	var after := _without(remaining, pair)
	if after[0] == 0 and after[1] == 0:
		return false
	var key := board.keys[pair.x]
	var before: int = counts[key]
	var stacked_after := stacked_keys
	if before == 2:
		if board.stacked(pair.x, pair.y):
			stacked_after -= 1
	elif before == 4:
		var left := _other_two(board, remaining, key, pair)
		if board.stacked(left.x, left.y):
			stacked_after += 1
	if stacked_after > 0:
		return true
	stamp[0] += 1
	var mark: int = stamp[0]
	var faces := board.faces
	for t in board.geometry.free_tiles(after):
		var face := faces[t]
		if seen[face ^ 1] == mark:
			return false
		seen[face] = mark
	return true


## The two tiles of `key` still remaining besides the two of `pair` (the key has four left).
static func _other_two(board: Board, remaining: PackedInt64Array, key: int, pair: Vector2i) -> Vector2i:
	var out := Vector2i(-1, -1)
	for t in board.tiles_of_key[key]:
		if t == pair.x or t == pair.y or remaining[t >> 6] & (1 << (t & 63)) == 0:
			continue
		if out.x < 0:
			out.x = t
		else:
			out.y = t
	return out


## (v3) PERCEPTIVE's slip before a move whose first tile is `t` (docs/HALVES.md 4b): D = the free
## tiles of t's look-alike group that are not mates of t (twins included); with probability
## min(0.9, PERCEPTIVE_BASE * the best similarity, * (1 + PERCEPTIVE_TURNED) if t or that most
## similar decoy (lowest id on ties) is turned) it taps that decoy first. The rng is drawn only
## when D is not empty.
static func _slips_before(board: Board, free: PackedInt32Array, t: int, rng: RandomNumberGenerator) -> bool:
	var group := board.groups[t]
	if group < 0:
		return false
	var mate_face := board.faces[t] ^ 1
	var key_t := board.keys[t]
	var best := -1
	var best_similarity := -1.0
	for d in free:
		if d == t or board.groups[d] != group or board.faces[d] == mate_face:
			continue
		var s := board.similarity(key_t, board.keys[d])
		if s > best_similarity:
			best_similarity = s
			best = d
	if best < 0:
		return false
	var p := HalvesConfig.PERCEPTIVE_BASE * best_similarity
	if board.turned[t] == 1 or board.turned[best] == 1:
		p *= 1.0 + HalvesConfig.PERCEPTIVE_TURNED
	return rng.randf() < minf(0.9, p)


static func _max_face(faces: PackedInt32Array) -> int:
	var top := 0
	for face in faces:
		top = maxi(top, face)
	return top


## (v3) The mend a bot makes when stuck: Vector2i(a, b) with `a` the free tile whose remaining mate
## `b` (the lowest-id remaining tile with the mate face) has the most remaining tiles on top of it
## (ties: lowest a); (-1, -1) if no free tile has a remaining mate.
static func _mend_pick(geometry: HalvesGeometry, faces: PackedInt32Array, remaining: PackedInt64Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_cover := -1
	var tiles := HalvesBits.ids(remaining)
	for a in geometry.free_tiles(remaining):
		var want := HalvesFace.mate(faces[a])
		for b in tiles:
			if faces[b] != want:
				continue
			var on_b := HalvesBits.count(HalvesBits.intersection(geometry.cover[b], remaining))
			if on_b > best_cover:
				best_cover = on_b
				best = Vector2i(a, b)
			break
	return best


static func _careful_pick(geometry: HalvesGeometry, remaining: PackedInt64Array, pairs: Array[Vector2i],
		rng: RandomNumberGenerator) -> Vector2i:
	var best: Array[Vector2i] = []
	var best_free := -1
	for pair in pairs:
		var free := HalvesBits.count(geometry.free_mask(_without(remaining, pair)))
		if free > best_free:
			best_free = free
			best = [pair]
		elif free == best_free:
			best.append(pair)
	return best[rng.randi_range(0, best.size() - 1)]


## `remaining` without the two tiles of `pair` (valid tile ids), as a new set.
static func _without(remaining: PackedInt64Array, pair: Vector2i) -> PackedInt64Array:
	var after := remaining.duplicate()
	after[pair.x >> 6] &= ~(1 << (pair.x & 63))
	after[pair.y >> 6] &= ~(1 << (pair.y & 63))
	return after
