class_name HalvesFill
extends RefCounted
## Reverse-removal fill: finds an order in which the tiles can be removed two at a time, then gives
## each pair of the order matching faces, so the board is solvable by construction. Used offline by
## the level generator and at runtime by Shuffle (re-deal, or reseat into the baked solution).

## How many different pairs one search step tries before backing up.
const BRANCH: int = 3


## Pairs of tiles in `mask` that can be removed in this order (both free at their step).
## Empty when none was found within the budget, or when `mask` is empty.
static func removal_order(geometry: HalvesGeometry, mask: PackedInt64Array, rng: RandomNumberGenerator,
		budget: int = 4000, restarts: int = 30) -> Array[Vector2i]:
	var order: Array[Vector2i] = []
	if HalvesBits.is_empty(mask) or HalvesBits.count(mask) % 2 != 0:
		return order
	var weights := _blocking_weights(geometry)
	for _attempt in restarts:
		order.clear()
		var spent: Array[int] = [0]
		if _search(geometry, mask, rng, weights, order, spent, budget):
			return order
	order.clear()
	return order


## Faces for every tile of `order`: pair k gets one of `pair_keys` (shuffled), one side each.
## Tiles not in `order` get -1.
static func assign_faces(order: Array[Vector2i], pair_keys: PackedInt32Array,
		rng: RandomNumberGenerator, tile_count: int) -> PackedInt32Array:
	assert(pair_keys.size() == order.size(), "one pair key per pair of the order")
	var keys := pair_keys.duplicate()
	shuffle_ints(keys, rng)
	var faces := PackedInt32Array()
	faces.resize(tile_count)
	faces.fill(-1)
	for k in order.size():
		var first_side := rng.randi_range(0, 1)
		faces[order[k].x] = keys[k] << 1 | first_side
		faces[order[k].y] = keys[k] << 1 | (1 - first_side)
	return faces


## Places where a trap can be built: (q, p, x, y) with x (step q) covering y (step p > q) while the
## other tile of step p is already free before step q. Sorted ascending.
static func trap_links(geometry: HalvesGeometry, order: Array[Vector2i]) -> Array[Vector4i]:
	var links: Array[Vector4i] = []
	var before := _free_before(geometry, order)
	for q in order.size():
		var free_q := before[q]
		for p in range(q + 1, order.size()):
			for x: int in [order[q].x, order[q].y]:
				for y: int in [order[p].x, order[p].y]:
					var on_y := geometry.cover[y]
					if on_y[x >> 6] & (1 << (x & 63)) == 0:
						continue
					var other := _other(order[p], y)
					if free_q[other >> 6] & (1 << (other & 63)) != 0:
						links.append(Vector4i(q, p, x, y))
	links.sort_custom(func(a: Vector4i, b: Vector4i) -> bool: return a < b)
	return links


## assign_faces, but about trap_rate * pairs / 2 links of trap_links get mated faces on their
## stacked tiles: pairing the two outer halves first strands a half on top of its only mate.
static func assign_faces_trapped(geometry: HalvesGeometry, order: Array[Vector2i],
		pair_keys: PackedInt32Array, rng: RandomNumberGenerator, tile_count: int,
		trap_rate: float) -> PackedInt32Array:
	assert(pair_keys.size() == order.size(), "one pair key per pair of the order")
	var links := trap_links(geometry, order)
	for i in range(links.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held := links[i]
		links[i] = links[j]
		links[j] = held
	var keys := pair_keys.duplicate()
	shuffle_ints(keys, rng)
	var faces := PackedInt32Array()
	faces.resize(tile_count)
	faces.fill(-1)
	var key_used := PackedByteArray()
	key_used.resize(keys.size())
	var step_done := PackedByteArray()
	step_done.resize(order.size())
	var wanted := roundi(trap_rate * order.size() / 2.0)
	var made := 0
	for link in links:
		if made >= wanted:
			break
		if step_done[link.x] != 0 or step_done[link.y] != 0:
			continue
		var key := _take_key_twice(keys, key_used)
		if key < 0:
			break
		var s := rng.randi_range(0, 1)
		faces[link.z] = key << 1 | s
		faces[_other(order[link.x], link.z)] = key << 1 | (1 - s)
		faces[link.w] = key << 1 | (1 - s)
		faces[_other(order[link.y], link.w)] = key << 1 | s
		step_done[link.x] = 1
		step_done[link.y] = 1
		made += 1
	var next := 0
	for k in order.size():
		if step_done[k] != 0:
			continue
		while key_used[next] != 0:
			next += 1
		key_used[next] = 1
		var first_side := rng.randi_range(0, 1)
		faces[order[k].x] = keys[next] << 1 | first_side
		faces[order[k].y] = keys[next] << 1 | (1 - first_side)
	return faces


## How many trap links carry a real trap with these faces.
static func live_traps(geometry: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array) -> int:
	var count := 0
	for link in trap_links(geometry, order):
		if is_live_link(order, faces, link):
			count += 1
	return count


## True when the four tiles of a trap link carry two mated pairs (x with y, and the other two).
static func is_live_link(order: Array[Vector2i], faces: PackedInt32Array, link: Vector4i) -> bool:
	return HalvesFace.matches(faces[link.z], faces[link.w]) \
			and HalvesFace.matches(faces[_other(order[link.x], link.z)], faces[_other(order[link.y], link.w)])


## A full, solvable board: {"faces", "solution"}, or {} if no removal order was found.
static func deal(geometry: HalvesGeometry, pair_keys: PackedInt32Array, rng: RandomNumberGenerator) -> Dictionary:
	if pair_keys.size() * 2 != geometry.size():
		return {}
	var order := removal_order(geometry, geometry.full_mask(), rng)
	if order.is_empty():
		return {}
	return {"faces": assign_faces(order, pair_keys, rng, geometry.size()), "solution": order}


## A v2 board: removal order, trap-seeded faces, then features, all from one rng.
## {"faces", "solution", "features", "traps"}, or {} if no removal order was found.
static func deal_v2(geometry: HalvesGeometry, pair_keys: PackedInt32Array, rng: RandomNumberGenerator,
		trap_rate: float, feature_spec: Dictionary) -> Dictionary:
	if pair_keys.size() * 2 != geometry.size():
		return {}
	var plain := geometry.with_features({}) if geometry.has_features() else geometry
	var order := removal_order(plain, plain.full_mask(), rng)
	if order.is_empty():
		return {}
	var faces := assign_faces_trapped(plain, order, pair_keys, rng, plain.size(), trap_rate)
	var features := HalvesFeatures.place(plain, order, faces, feature_spec, rng)
	return {"faces": faces, "solution": order, "features": features, "traps": live_traps(plain, order, faces)}


## (v3) A copy of `faces` where the two tiles of one step of `order` carry the gold pair (motif
## kin): a step in [n / 3, 2n / 3) (at least one), preferring steps whose two tiles are both not
## free at the start, picked with one rng draw. The side-a tile stays side a, so `order` still solves.
static func with_gold_pair(geometry: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array,
		rng: RandomNumberGenerator) -> PackedInt32Array:
	var out := faces.duplicate()
	var n := order.size()
	if n == 0:
		return out
	var start := HalvesBits.empty()
	for pair in order:
		HalvesBits.set_bit(start, pair.x)
		HalvesBits.set_bit(start, pair.y)
	var start_free := geometry.free_mask(start)
	var lo := n / 3
	var hidden := PackedInt32Array()
	var open := PackedInt32Array()
	for k in range(lo, maxi((2 * n) / 3, lo + 1)):
		if HalvesBits.has(start_free, order[k].x) or HalvesBits.has(start_free, order[k].y):
			open.append(k)
		else:
			hidden.append(k)
	var steps := hidden if not hidden.is_empty() else open
	var pick := order[steps[rng.randi_range(0, steps.size() - 1)]]
	var gold := HalvesCrests.pair_of(HalvesCrests.motif_index(&"kin"), 0)
	var x_side := HalvesFace.SIDE_A if HalvesFace.side(faces[pick.x]) == HalvesFace.SIDE_A else HalvesFace.SIDE_B
	out[pick.x] = gold << 1 | x_side
	out[pick.y] = gold << 1 | (1 - x_side)
	return out


## The pair key of every remaining side-A face, sorted: what a re-deal has to place.
static func remaining_pair_keys(state: HalvesState) -> PackedInt32Array:
	var keys := PackedInt32Array()
	for i in state.geometry.size():
		if HalvesBits.has(state.remaining, i) and HalvesFace.side(state.faces[i]) == HalvesFace.SIDE_A:
			keys.append(HalvesFace.pair_key(state.faces[i]))
	keys.sort()
	return keys


## Re-deals the remaining faces into a solvable board: {"remaining", "faces", "reseated"}.
## Keeps the tile positions when they can still be cleared; otherwise reseats the tiles into the
## positions `solution` leaves after the same number of pairs (solvable by the rest of it).
static func shuffle(state: HalvesState, solution: Array[Vector2i], rng: RandomNumberGenerator) -> Dictionary:
	if HalvesBits.is_empty(state.remaining):
		return {}
	var geometry := state.geometry
	var keys := remaining_pair_keys(state)
	var target := state.remaining.duplicate()
	var order := removal_order(geometry, target, rng)
	if order.is_empty():
		var done := (geometry.size() - state.tiles_left()) / 2
		target = geometry.full_mask()
		for step in done:
			HalvesBits.clear_bit(target, solution[step].x)
			HalvesBits.clear_bit(target, solution[step].y)
		order = removal_order(geometry, target, rng)
		if order.is_empty():
			order = solution.slice(done)
	return {
		"remaining": target,
		"faces": assign_faces(order, keys, rng, geometry.size()),
		"reseated": not HalvesBits.equal(target, state.remaining),
	}


static func shuffle_rng(level: int, count: int) -> RandomNumberGenerator:
	return SeedService.make_rng(["halves", level, "shuffle", count], HalvesConfig.GEN_VERSION)


## Fisher-Yates with the given rng (Array.shuffle() would use the global, unseeded one).
static func shuffle_ints(values: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held := values[i]
		values[i] = values[j]
		values[j] = held


## Depth-first search for a removal order; `spent[0]` counts expanded states against `budget`.
static func _search(geometry: HalvesGeometry, remaining: PackedInt64Array, rng: RandomNumberGenerator,
		weights: PackedInt32Array, order: Array[Vector2i], spent: Array[int], budget: int) -> bool:
	if HalvesBits.is_empty(remaining):
		return true
	spent[0] += 1
	if spent[0] > budget:
		return false
	var free := geometry.free_tiles(remaining)
	if free.size() < 2:
		return false
	var tried: Dictionary[int, bool] = {}
	var possible := free.size() * (free.size() - 1) / 2
	for _branch in mini(BRANCH, possible):
		var pair := _pick_pair(free, weights, rng, tried)
		if pair.x < 0:
			break
		order.append(pair)
		var after := remaining.duplicate()
		HalvesBits.clear_bit(after, pair.x)
		HalvesBits.clear_bit(after, pair.y)
		if _search(geometry, after, rng, weights, order, spent, budget):
			return true
		order.pop_back()
		if spent[0] > budget:
			return false
	return false


## Two different free tiles, weighted towards tiles that block others (they are better removed
## early, which avoids ending on a stack that can't be split). Skips pairs already tried here.
static func _pick_pair(free: PackedInt32Array, weights: PackedInt32Array, rng: RandomNumberGenerator,
		tried: Dictionary[int, bool]) -> Vector2i:
	for _attempt in 8:
		var a := _weighted_pick(free, weights, rng, -1)
		var b := _weighted_pick(free, weights, rng, a)
		var key := mini(a, b) * HalvesGeometry.MAX_TILES + maxi(a, b)
		if not tried.has(key):
			tried[key] = true
			return Vector2i(mini(a, b), maxi(a, b))
	return Vector2i(-1, -1)


static func _weighted_pick(free: PackedInt32Array, weights: PackedInt32Array,
		rng: RandomNumberGenerator, skip: int) -> int:
	var total := 0
	for tile in free:
		if tile != skip:
			total += weights[tile]
	var roll := rng.randi_range(0, total - 1)
	for tile in free:
		if tile == skip:
			continue
		roll -= weights[tile]
		if roll < 0:
			return tile
	return free[free.size() - 1] if free[free.size() - 1] != skip else free[0]


## The free mask before each step of `order`, starting from the tiles `order` uses.
static func _free_before(geometry: HalvesGeometry, order: Array[Vector2i]) -> Array[PackedInt64Array]:
	var left_over := HalvesBits.empty()
	for pair in order:
		HalvesBits.set_bit(left_over, pair.x)
		HalvesBits.set_bit(left_over, pair.y)
	var before: Array[PackedInt64Array] = []
	for pair in order:
		before.append(geometry.free_mask(left_over))
		HalvesBits.clear_bit(left_over, pair.x)
		HalvesBits.clear_bit(left_over, pair.y)
	return before


static func _other(pair: Vector2i, tile: int) -> int:
	return pair.y if pair.x == tile else pair.x


## The first key value in `keys` with two unused copies; marks both used. -1 if none.
static func _take_key_twice(keys: PackedInt32Array, used: PackedByteArray) -> int:
	for i in keys.size():
		if used[i] != 0:
			continue
		for j in range(i + 1, keys.size()):
			if used[j] == 0 and keys[j] == keys[i]:
				used[i] = 1
				used[j] = 1
				return keys[i]
	return -1


## 1 + how many tiles each tile covers or flanks on the full board.
static func _blocking_weights(geometry: HalvesGeometry) -> PackedInt32Array:
	var weights := PackedInt32Array()
	weights.resize(geometry.size())
	weights.fill(1)
	for i in geometry.size():
		var blockers := HalvesBits.union(HalvesBits.union(geometry.cover[i], geometry.left[i]), geometry.right[i])
		for j in HalvesBits.ids(blockers):
			weights[j] += 1
	return weights
