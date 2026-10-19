extends RefCounted
## Shared helpers for tests/test_halves_*.gd: typed position lists, the mask/plan JSON, and
## independent re-checks of removal orders and solvability, all re-derived from docs/HALVES.md.
## Not a test file (no test_ prefix, so GUT skips it); preload it. Written without reading game/halves/.

const MASKS_PATH := "res://tools/levelgen/halves_masks.json"
const PLAN_PATH := "res://tools/levelgen/halves_plan.json"


## Untyped list of Vector3i -> the typed array the Halves API takes.
static func positions(points: Array) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for p: Vector3i in points:
		out.append(p)
	return out


static func geometry(points: Array) -> HalvesGeometry:
	return HalvesGeometry.from_positions(positions(points))


## Text faces -> ints; "" stands for an empty slot (-1).
static func faces(texts: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for t: String in texts:
		out.append(-1 if t == "" else HalvesFace.from_text(t))
	return out


static func state(points: Array, texts: Array) -> HalvesState:
	return HalvesState.new(geometry(points), faces(texts))


## n tiles in one column, two half-units apart: no tile touches or covers another, so all are free.
static func column(n: int) -> Array:
	var out: Array = []
	for i: int in n:
		out.append(Vector3i(0, 2 * i, 0))
	return out


static func pairs(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p: Vector2i in list:
		out.append(p)
	return out


static func bit(i: int) -> int:
	return 1 << i


static func mask_of(ids: Array) -> int:
	var m := 0
	for i: int in ids:
		m |= 1 << i
	return m


## A pair with the lower id first, so tests do not depend on the order inside a pair.
static func norm(p: Vector2i) -> Vector2i:
	return Vector2i(mini(p.x, p.y), maxi(p.x, p.y))


static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return data
	return {}


static func masks() -> Dictionary:
	var data := load_json(MASKS_PATH)
	var out: Dictionary = data.get("masks", {})
	return out


static func plan_slots() -> Array:
	var data := load_json(PLAN_PATH)
	var out: Array = data.get("slots", [])
	return out


static func plan_slot(level: int) -> Dictionary:
	for slot: Dictionary in plan_slots():
		if int(slot.get("level", 0)) == level:
			return slot
	return {}


static func mask_positions(mask_name: String) -> Array[Vector3i]:
	var all := masks()
	var mask: Dictionary = all.get(mask_name, {})
	var layers: Array = mask.get("layers", [])
	return HalvesMask.parse(layers)


static func plan_geometry(level: int) -> HalvesGeometry:
	var slot := plan_slot(level)
	return HalvesGeometry.from_positions(mask_positions(String(slot.get("mask", ""))))


## docs/HALVES.md section 3: tiles/2 pairs spread over `types` round-robin in the listed order.
static func round_robin(types: Array, pair_count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in pair_count:
		out.append(HalvesFace.pair_from_text(String(types[i % types.size()])))
	return out


static func plan_keys(level: int, tile_count: int) -> PackedInt32Array:
	var slot := plan_slot(level)
	var types: Array = slot.get("types", [])
	return round_robin(types, int(tile_count / 2.0))


## "" when `order` is a valid removal order from `mask`: both tiles remaining and free at their
## step (checked before either is removed), every tile used once, and nothing left at the end.
static func order_error(geo: HalvesGeometry, mask: int, order: Array) -> String:
	var rem := mask
	for step: int in order.size():
		var p: Vector2i = order[step]
		if p.x == p.y:
			return "step %d pairs tile %d with itself" % [step, p.x]
		for t: int in [p.x, p.y]:
			if t < 0 or t >= geo.size():
				return "step %d: tile %d is out of range" % [step, t]
			if (rem & (1 << t)) == 0:
				return "step %d: tile %d is not remaining" % [step, t]
			if not geo.is_free(t, rem):
				return "step %d: tile %d is not free" % [step, t]
		rem &= ~((1 << p.x) | (1 << p.y))
	if rem != 0:
		return "%d tiles left at the end" % HalvesGeometry.popcount(rem)
	return ""


## "" when every move is a MATCH on `s` and the board ends clear.
static func replay_error(s: HalvesState, moves: Array) -> String:
	for step: int in moves.size():
		var p: Vector2i = moves[step]
		var r: int = s.try_pair(p.x, p.y)
		if r != HalvesState.Result.MATCH:
			return "step %d (%d, %d) gave result %d, not MATCH" % [step, p.x, p.y, r]
	if not s.is_cleared():
		return "%d tiles left after the moves" % s.tiles_left()
	return ""


## Brute-force check, independent of HalvesSolver: can `remaining` be cleared with `faces`?
static func solvable(geo: HalvesGeometry, face_list: PackedInt32Array, remaining: int) -> bool:
	return _solvable(geo, face_list, remaining, {})


static func _solvable(geo: HalvesGeometry, face_list: PackedInt32Array, rem: int, dead: Dictionary) -> bool:
	if rem == 0:
		return true
	if dead.has(rem):
		return false
	dead[rem] = true
	var free := geo.free_tiles(rem)
	for i: int in free.size():
		for j: int in range(i + 1, free.size()):
			var a: int = free[i]
			var b: int = free[j]
			if HalvesFace.matches(face_list[a], face_list[b]):
				if _solvable(geo, face_list, rem & ~((1 << a) | (1 << b)), dead):
					return true
	return false


## Sorted faces of the tiles in `mask` (a multiset).
static func faces_on(mask: int, face_list: PackedInt32Array) -> Array[int]:
	var out: Array[int] = []
	for i: int in face_list.size():
		if (mask & (1 << i)) != 0:
			out.append(face_list[i])
	out.sort()
	return out


## Sorted pair keys of the side-A faces among the tiles in `mask`.
static func side_a_keys(mask: int, face_list: PackedInt32Array) -> Array[int]:
	var out: Array[int] = []
	for i: int in face_list.size():
		if (mask & (1 << i)) != 0 and HalvesFace.side(face_list[i]) == HalvesFace.SIDE_A:
			out.append(HalvesFace.pair_key(face_list[i]))
	out.sort()
	return out


static func sorted_ints(values: PackedInt32Array) -> Array[int]:
	var out: Array[int] = []
	for v: int in values:
		out.append(v)
	out.sort()
	return out


# --- v2 helpers (contract v2), also written from docs/HALVES.md alone ---


## Untyped list of Vector4i -> the typed array trap_links returns.
static func links(list: Array) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	for l: Vector4i in list:
		out.append(l)
	return out


## JSON text with sorted keys: compares values and tells ints (3) from floats (3.0), whatever the
## container type (Array, typed Array or PackedInt32Array all print as [..]).
static func js(value: Variant) -> String:
	return JSON.stringify(value, "", true)


## Ids of the set bits of `mask`, ascending.
static func ids(mask: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in 64:
		if (mask & (1 << i)) != 0:
			out.append(i)
	return out


## step[t] = the step of `order` that removes tile t, or -1.
static func steps_of(order: Array, size: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(size)
	out.fill(-1)
	for k: int in order.size():
		var p: Vector2i = order[k]
		out[p.x] = k
		out[p.y] = k
	return out


## A free pair of tiles that would be a mistake (same shape, not mates), or (-1, -1).
static func free_decoy(s: HalvesState) -> Vector2i:
	var free := s.geometry.free_tiles(s.remaining)
	for i: int in free.size():
		for j: int in range(i + 1, free.size()):
			if HalvesFace.is_decoy(s.faces[free[i]], s.faces[free[j]]):
				return Vector2i(free[i], free[j])
	return Vector2i(-1, -1)


## A line of free matching pairs from the start of `data` that ends stuck (tiles left, no free
## pair), found by seeded random play; [] if none of `attempts` games got stuck.
static func stuck_line(data: HalvesLevelData, attempts: int = 20) -> Array[Vector2i]:
	for attempt: int in attempts:
		var rng := SeedService.make_rng(["halves_helpers", "stuck", data.level, attempt], 1)
		var s := data.new_state()
		var moves: Array[Vector2i] = []
		var pairs := s.free_pairs()
		while not pairs.is_empty():
			var p: Vector2i = pairs[rng.randi_range(0, pairs.size() - 1)]
			s.try_pair(p.x, p.y)
			moves.append(p)
			pairs = s.free_pairs()
		if not s.is_cleared():
			return moves
	return []


## docs/HALVES.md section 3: the slot's "features" spec with JSON floats cast back to ints.
static func slot_feature_spec(slot: Dictionary) -> Dictionary:
	var raw: Dictionary = slot.get("features", {})
	var out := {}
	for key: String in raw:
		out[key] = int(raw[key])
	return out


## docs/HALVES.md section 4: trap_rate = lo + (hi - lo) * (k % 4) / 3.0, "trap" defaulting to [0, 0].
static func slot_trap_rate(slot: Dictionary, k: int) -> float:
	var trap: Array = slot.get("trap", [0.0, 0.0])
	var lo := float(trap[0])
	var hi := float(trap[1])
	return lo + (hi - lo) * (k % 4) / 3.0


## docs/HALVES.md section 3: min_careful defaults to 0.8, or 0.6 for hard and finale; min_wary to 0.
static func slot_min_careful(slot: Dictionary) -> float:
	var role := String(slot.get("role", ""))
	var fallback := 0.6 if role == "hard" or role == "finale" else 0.8
	return float(slot.get("min_careful", fallback))


static func slot_min_wary(slot: Dictionary) -> float:
	return float(slot.get("min_wary", 0.0))
