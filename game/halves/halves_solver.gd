class_name HalvesSolver
extends RefCounted
## Exact solver for a Halves board (depth-first search with a dead-state memo and a node budget),
## used by the Hint booster and by tests. Pairs of a type whose remaining tiles are all free are
## taken without branching: removing them can never hurt, which keeps the search small.

enum Status { SOLVED, UNSOLVABLE, UNKNOWN }

enum _Outcome { SOLVED, DEAD, OUT_OF_BUDGET }


## {"status": Status, "moves": Array[Vector2i]}; the moves clear `remaining` when SOLVED.
static func solve(geometry: HalvesGeometry, faces: PackedInt32Array, remaining: int,
		budget: int = 20000) -> Dictionary:
	var moves: Array[Vector2i] = []
	var dead: Dictionary[int, bool] = {}
	var spent: Array[int] = [0]
	var outcome := _search(geometry, faces, remaining, dead, moves, spent, budget)
	match outcome:
		_Outcome.SOLVED:
			return {"status": Status.SOLVED, "moves": moves}
		_Outcome.DEAD:
			return {"status": Status.UNSOLVABLE, "moves": [] as Array[Vector2i]}
	return {"status": Status.UNKNOWN, "moves": [] as Array[Vector2i]}


## A free pair that keeps the board solvable; if the solver ran out of budget, the most freeing
## pair that is not a trap move (or of all pairs); (-1, -1) if unsolvable or no free pair.
static func hint(state: HalvesState, budget: int = 5000) -> Vector2i:
	var result := solve(state.geometry, state.faces, state.remaining, budget)
	var moves: Array[Vector2i] = result.moves
	if result.status == Status.SOLVED and not moves.is_empty():
		return moves[0]
	if result.status == Status.UNSOLVABLE:
		return Vector2i(-1, -1)
	var pairs := state.free_pairs()
	var safe: Array[Vector2i] = []
	for pair in pairs:
		if not HalvesBot.is_trap_move(state.geometry, state.faces, state.remaining, pair):
			safe.append(pair)
	return most_freeing_pair(state.geometry, state.remaining, safe if not safe.is_empty() else pairs)


## The pair (from `pairs`) that leaves the most free tiles; ties keep the earliest.
static func most_freeing_pair(geometry: HalvesGeometry, remaining: int, pairs: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_free := -1
	for pair in pairs:
		var after := remaining & ~(1 << pair.x) & ~(1 << pair.y)
		var free := HalvesGeometry.popcount(geometry.free_mask(after))
		if free > best_free:
			best_free = free
			best = pair
	return best


static func _search(geometry: HalvesGeometry, faces: PackedInt32Array, remaining: int,
		dead: Dictionary[int, bool], moves: Array[Vector2i], spent: Array[int], budget: int) -> _Outcome:
	if remaining == 0:
		return _Outcome.SOLVED
	if dead.has(remaining):
		return _Outcome.DEAD
	spent[0] += 1
	if spent[0] > budget:
		return _Outcome.OUT_OF_BUDGET
	var candidates := _candidates(geometry, faces, remaining)
	for pair in candidates:
		moves.append(pair)
		var outcome := _search(geometry, faces, remaining & ~(1 << pair.x) & ~(1 << pair.y), dead, moves, spent, budget)
		if outcome != _Outcome.DEAD:
			if outcome == _Outcome.OUT_OF_BUDGET:
				moves.pop_back()
			return outcome
		moves.pop_back()
	dead[remaining] = true
	return _Outcome.DEAD


## The moves worth trying from `remaining`: one forced safe pair if a pair type is entirely free,
## else every free pair, most freeing first.
static func _candidates(geometry: HalvesGeometry, faces: PackedInt32Array, remaining: int) -> Array[Vector2i]:
	var free_mask := geometry.free_mask(remaining)
	var pairs: Array[Vector2i] = []
	var key_total: Dictionary[int, int] = {}
	var key_free: Dictionary[int, int] = {}
	for i in geometry.size():
		if remaining & (1 << i) == 0:
			continue
		var key := HalvesFace.pair_key(faces[i])
		key_total[key] = key_total.get(key, 0) + 1
		if free_mask & (1 << i) != 0:
			key_free[key] = key_free.get(key, 0) + 1
	var free := geometry.free_tiles(remaining)
	for i in free.size():
		for j in range(i + 1, free.size()):
			if HalvesFace.matches(faces[free[i]], faces[free[j]]):
				var pair := Vector2i(free[i], free[j])
				var key := HalvesFace.pair_key(faces[free[i]])
				if key_free.get(key, 0) == key_total[key]:
					return [pair] as Array[Vector2i]
				pairs.append(pair)
	if pairs.size() < 2:
		return pairs
	var scored: Array[Vector3i] = []
	for pair in pairs:
		var after := remaining & ~(1 << pair.x) & ~(1 << pair.y)
		scored.append(Vector3i(-HalvesGeometry.popcount(geometry.free_mask(after)), pair.x, pair.y))
	scored.sort()
	var ordered: Array[Vector2i] = []
	for s in scored:
		ordered.append(Vector2i(s.y, s.z))
	return ordered
