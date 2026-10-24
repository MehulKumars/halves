class_name HalvesFeatures
extends RefCounted
## Level features (lock groups, frost, mist, gold): the format, checks, and placing them on a dealt
## board after its removal order is known so the order stays a solution. Used by the generator,
## HalvesGeometry.with_features and the level data. All features are positional (tile ids).

const LISTS: Array[String] = ["frost", "mist", "gold"]


## Ints everywhere, every list sorted and without duplicates, empty lists and groups dropped.
static func normalize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var groups: Array = []
	for entry: Variant in raw.get("locks", []):
		if not entry is Dictionary:
			continue
		var group: Dictionary = entry
		var keys := _ids(group.get("keys", []))
		var locked := _ids(group.get("locked", []))
		if keys.is_empty() or locked.is_empty():
			continue
		groups.append({"keys": keys, "locked": locked})
	if not groups.is_empty():
		out["locks"] = groups
	for list in LISTS:
		var ids := _ids(raw.get(list, []))
		if not ids.is_empty():
			out[list] = ids
	return out


## Readable problems with `features` on `geometry` (and with `solution` under its rules, if given).
static func validate(geometry: HalvesGeometry, features: Dictionary,
		solution: Array[Vector2i] = []) -> PackedStringArray:
	var problems := PackedStringArray()
	var f := normalize(features)
	var count := geometry.size()
	var all_keys := HalvesBits.empty()
	var all_locked := HalvesBits.empty()
	var groups: Array = f.get("locks", [])
	for g in groups.size():
		var group: Dictionary = groups[g]
		for list: String in ["keys", "locked"]:
			for tile: int in group[list]:
				if tile < 0 or tile >= count:
					problems.append("lock group %d: %s tile %d is not on the board (0..%d)" % [g + 1, list, tile, count - 1])
		var keys := mask(group.keys)
		var locked := mask(group.locked)
		for tile in HalvesBits.ids(HalvesBits.intersection(keys, locked)):
			problems.append("lock group %d: tile %d is both a key and locked" % [g + 1, tile])
		all_keys = HalvesBits.union(all_keys, keys)
		all_locked = HalvesBits.union(all_locked, locked)
	for tile in HalvesBits.ids(HalvesBits.intersection(all_keys, all_locked)):
		problems.append("tile %d is a key in one lock group and locked in another" % tile)
	for list in LISTS:
		for tile: int in f.get(list, []):
			if tile < 0 or tile >= count:
				problems.append("%s tile %d is not on the board (0..%d)" % [list, tile, count - 1])
	if solution.is_empty() or not problems.is_empty():
		return problems
	var rules := geometry.with_features(f)
	var remaining := rules.full_mask()
	for k in solution.size():
		var pair := solution[k]
		if pair.x == pair.y or not HalvesBits.has(remaining, pair.x) or not HalvesBits.has(remaining, pair.y):
			problems.append("solution step %d (%d, %d) uses a tile that is not on the board" % [k, pair.x, pair.y])
			return problems
		for tile in [pair.x, pair.y]:
			if not rules.is_free(tile, remaining):
				problems.append("solution step %d (%d, %d): tile %d is not free" % [k, pair.x, pair.y, tile])
				return problems
		HalvesBits.clear_bit(remaining, pair.x)
		HalvesBits.clear_bit(remaining, pair.y)
	if not HalvesBits.is_empty(remaining):
		problems.append("the solution leaves %d tiles" % HalvesBits.count(remaining))
	return problems


## Adds features to a dealt board without breaking `order` as a solution (see docs/HALVES.md).
## spec: {"key_pairs", "locked", "frost", "mist", "gold"} (ints, default 0).
static func place(geometry: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array,
		spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n := order.size()
	var count := geometry.size()
	var step := PackedInt32Array()
	step.resize(count)
	step.fill(-1)
	var left_over := HalvesBits.empty()
	for k in n:
		step[order[k].x] = k
		step[order[k].y] = k
		HalvesBits.set_bit(left_over, order[k].x)
		HalvesBits.set_bit(left_over, order[k].y)
	var free_before: Array[PackedInt64Array] = []
	for k in n:
		free_before.append(geometry.free_mask(left_over))
		HalvesBits.clear_bit(left_over, order[k].x)
		HalvesBits.clear_bit(left_over, order[k].y)
	var start_free: PackedInt64Array = free_before[0] if n > 0 else HalvesBits.empty()
	var used := HalvesBits.empty()
	var result: Dictionary = {}

	var key_pairs := int(spec.get("key_pairs", 0))
	var locked_wanted := int(spec.get("locked", 0))
	if key_pairs > 0 and locked_wanted > 0 and n > 0:
		var key_steps := PackedInt32Array()
		for k in range(n / 3, (2 * n) / 3):
			key_steps.append(k)
		HalvesFill.shuffle_ints(key_steps, rng)
		var keys: Array = []
		var last := -1
		for s in mini(key_pairs, key_steps.size()):
			var k := key_steps[s]
			keys.append(order[k].x)
			keys.append(order[k].y)
			last = maxi(last, k)
		var reachable := PackedInt32Array()
		var others := PackedInt32Array()
		for tile in count:
			if step[tile] <= last:
				continue
			var seen := false
			for k in last + 1:
				if HalvesBits.has(free_before[k], tile):
					seen = true
					break
			if seen:
				reachable.append(tile)
			else:
				others.append(tile)
		var locked := _take(reachable, others, locked_wanted, rng)
		if not keys.is_empty() and not locked.is_empty():
			result["locks"] = [{"keys": keys, "locked": locked}]
			used = HalvesBits.union(used, HalvesBits.union(mask(keys), mask(locked)))

	var frost_wanted := int(spec.get("frost", 0))
	if frost_wanted > 0:
		var open := PackedInt32Array()
		var others := PackedInt32Array()
		for tile in count:
			if step[tile] < 0 or HalvesBits.has(used, tile):
				continue
			var thawed := false
			for other in HalvesBits.ids(geometry.touch[tile]):
				if step[other] >= 0 and step[other] < step[tile]:
					thawed = true
					break
			if not thawed:
				continue
			if HalvesBits.has(start_free, tile):
				open.append(tile)
			else:
				others.append(tile)
		var frost := _take(open, others, frost_wanted, rng)
		if not frost.is_empty():
			result["frost"] = frost
			used = HalvesBits.union(used, mask(frost))

	var mist_wanted := int(spec.get("mist", 0))
	if mist_wanted > 0:
		var trap_tops := HalvesBits.empty()
		for link in HalvesFill.trap_links(geometry, order):
			if HalvesFill.is_live_link(order, faces, link):
				HalvesBits.set_bit(trap_tops, link.w)
		var skip := HalvesBits.union(used, trap_tops)
		var hidden := PackedInt32Array()
		for tile in count:
			if step[tile] >= 0 and not HalvesBits.has(start_free, tile) and not HalvesBits.has(skip, tile):
				hidden.append(tile)
		var mist := _take(hidden, PackedInt32Array(), mist_wanted, rng)
		if not mist.is_empty():
			result["mist"] = mist
			used = HalvesBits.union(used, mask(mist))

	var gold_wanted := int(spec.get("gold", 0))
	if gold_wanted > 0:
		var upper := PackedInt32Array()
		var lower := PackedInt32Array()
		for tile in count:
			if step[tile] < 0 or HalvesBits.has(used, tile):
				continue
			if geometry.positions[tile].z >= 1:
				upper.append(tile)
			else:
				lower.append(tile)
		var gold := _take(upper, lower, gold_wanted, rng)
		if not gold.is_empty():
			result["gold"] = gold
	return normalize(result)


## Distinct tiles that are a key, locked, frosted or misted (gold doesn't slow a player down).
static func tile_count(features: Dictionary) -> int:
	var f := normalize(features)
	var tiles := HalvesBits.union(mask(f.get("frost", [])), mask(f.get("mist", [])))
	for group: Dictionary in f.get("locks", []):
		tiles = HalvesBits.union(tiles, HalvesBits.union(mask(group.keys), mask(group.locked)))
	return HalvesBits.count(tiles)


## The set of tile `ids` (JSON floats are cast).
static func mask(ids: Array) -> PackedInt64Array:
	return HalvesBits.of(ids)


## The first `count` of `preferred` then `rest`, each group in a random order (both always shuffled).
static func _take(preferred: PackedInt32Array, rest: PackedInt32Array, count: int,
		rng: RandomNumberGenerator) -> Array:
	var a := preferred.duplicate()
	var b := rest.duplicate()
	HalvesFill.shuffle_ints(a, rng)
	HalvesFill.shuffle_ints(b, rng)
	var picked: Array = []
	for tile in a + b:
		if picked.size() >= count:
			break
		picked.append(tile)
	return picked


static func _ids(values: Variant) -> Array:
	var seen: Dictionary[int, bool] = {}
	if values is Array:
		for v: Variant in values:
			seen[int(v)] = true
	var ids: Array = seen.keys()
	ids.sort()
	return ids
