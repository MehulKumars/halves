class_name HalvesFill
extends RefCounted
## Reverse-removal fill: finds an order in which the tiles can be removed two at a time, then gives
## each pair of the order matching faces, so the board is solvable by construction. Used offline by
## the level generator and at runtime by Shuffle (re-deal, or reseat into the baked solution).

## How many different pairs one search step tries before backing up.
const BRANCH: int = 3


## Pairs of tiles in `mask` that can be removed in this order (both free at their step).
## Empty when none was found within the budget, or when `mask` is empty.
static func removal_order(geometry: HalvesGeometry, mask: int, rng: RandomNumberGenerator,
		budget: int = 4000, restarts: int = 30) -> Array[Vector2i]:
	var order: Array[Vector2i] = []
	if mask == 0 or HalvesGeometry.popcount(mask) % 2 != 0:
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


## A full, solvable board: {"faces", "solution"}, or {} if no removal order was found.
static func deal(geometry: HalvesGeometry, pair_keys: PackedInt32Array, rng: RandomNumberGenerator) -> Dictionary:
	if pair_keys.size() * 2 != geometry.size():
		return {}
	var order := removal_order(geometry, geometry.full_mask(), rng)
	if order.is_empty():
		return {}
	return {"faces": assign_faces(order, pair_keys, rng, geometry.size()), "solution": order}


## The pair key of every remaining side-A face, sorted: what a re-deal has to place.
static func remaining_pair_keys(state: HalvesState) -> PackedInt32Array:
	var keys := PackedInt32Array()
	for i in state.geometry.size():
		if state.remaining & (1 << i) != 0 and HalvesFace.side(state.faces[i]) == HalvesFace.SIDE_A:
			keys.append(HalvesFace.pair_key(state.faces[i]))
	keys.sort()
	return keys


## Re-deals the remaining faces into a solvable board: {"remaining", "faces", "reseated"}.
## Keeps the tile positions when they can still be cleared; otherwise reseats the tiles into the
## positions `solution` leaves after the same number of pairs (solvable by the rest of it).
static func shuffle(state: HalvesState, solution: Array[Vector2i], rng: RandomNumberGenerator) -> Dictionary:
	if state.remaining == 0:
		return {}
	var geometry := state.geometry
	var keys := remaining_pair_keys(state)
	var target := state.remaining
	var order := removal_order(geometry, target, rng)
	if order.is_empty():
		var done := (geometry.size() - state.tiles_left()) / 2
		target = geometry.full_mask()
		for step in done:
			target &= ~(1 << solution[step].x) & ~(1 << solution[step].y)
		order = removal_order(geometry, target, rng)
		if order.is_empty():
			order = solution.slice(done)
	return {
		"remaining": target,
		"faces": assign_faces(order, keys, rng, geometry.size()),
		"reseated": target != state.remaining,
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
static func _search(geometry: HalvesGeometry, remaining: int, rng: RandomNumberGenerator,
		weights: PackedInt32Array, order: Array[Vector2i], spent: Array[int], budget: int) -> bool:
	if remaining == 0:
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
		if _search(geometry, remaining & ~(1 << pair.x) & ~(1 << pair.y), rng, weights, order, spent, budget):
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


## 1 + how many tiles each tile covers or flanks on the full board.
static func _blocking_weights(geometry: HalvesGeometry) -> PackedInt32Array:
	var weights := PackedInt32Array()
	weights.resize(geometry.size())
	weights.fill(1)
	for i in geometry.size():
		var blockers := geometry.cover[i] | geometry.left[i] | geometry.right[i]
		for j in geometry.size():
			if blockers & (1 << j) != 0:
				weights[j] += 1
	return weights
