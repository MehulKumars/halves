class_name HalvesGeometry
extends RefCounted
## Where the tiles of one level sit, and which tiles block which: positions are (x, y, z) in
## half-tile units; a set of tiles is a HalvesBits set (two 64-bit words, at most 128 tiles), so
## "is tile i free?" is O(1). Used by every piece of Halves logic. The public per-tile sets are
## read-only: the hot loops read flat copies (_cover etc., words 2i and 2i + 1 for tile i).
## Features (locks, frost) are extra blocking rules; every rule is monotone (docs/HALVES.md).

const MAX_TILES: int = 128

## Why a tile is not free, in the order blocked_reason() checks.
enum Block { FREE, COVERED, SIDES, LOCKED, FROSTED }

var positions: Array[Vector3i] = []
## cover[i]: tiles that lie on top of tile i. left[i] / right[i]: its side neighbours.
var cover: Array[PackedInt64Array] = []
var left: Array[PackedInt64Array] = []
var right: Array[PackedInt64Array] = []
## touch[i]: tiles touching tile i (cover, side neighbours, same-layer tiles straight above/below).
var touch: Array[PackedInt64Array] = []
## Empty without features. lock_need[i]: key tiles that must be gone; frost_need[i]: touch[i] for
## frosted tiles (one of them must be gone), the empty set for the others.
var lock_need: Array[PackedInt64Array] = []
var frost_need: Array[PackedInt64Array] = []
var features: Dictionary = {}

## Flat words of cover, left, right, lock_need and frost_need: tile i is at 2i (ids 0..63) and
## 2i + 1 (ids 64..127). _lock and _frost are empty without features.
var _cover: PackedInt64Array = PackedInt64Array()
var _left: PackedInt64Array = PackedInt64Array()
var _right: PackedInt64Array = PackedInt64Array()
var _lock: PackedInt64Array = PackedInt64Array()
var _frost: PackedInt64Array = PackedInt64Array()


static func from_positions(tile_positions: Array[Vector3i]) -> HalvesGeometry:
	assert(tile_positions.size() <= MAX_TILES, "Halves boards hold at most 128 tiles")
	var geometry := HalvesGeometry.new()
	geometry.positions = tile_positions.duplicate()
	var count := tile_positions.size()
	for i in count:
		var a := tile_positions[i]
		var covered_by := HalvesBits.empty()
		var left_of := HalvesBits.empty()
		var right_of := HalvesBits.empty()
		var stacked := HalvesBits.empty()
		for j in count:
			if i == j:
				continue
			var b := tile_positions[j]
			if b.z == a.z and absi(b.x - a.x) < 2 and absi(b.y - a.y) == 2:
				HalvesBits.set_bit(stacked, j)
			if absi(b.y - a.y) >= 2:
				continue
			if b.z > a.z and absi(b.x - a.x) < 2:
				HalvesBits.set_bit(covered_by, j)
			elif b.z == a.z and b.x == a.x - 2:
				HalvesBits.set_bit(left_of, j)
			elif b.z == a.z and b.x == a.x + 2:
				HalvesBits.set_bit(right_of, j)
		geometry.cover.append(covered_by)
		geometry.left.append(left_of)
		geometry.right.append(right_of)
		geometry.touch.append(HalvesBits.union(HalvesBits.union(covered_by, left_of), HalvesBits.union(right_of, stacked)))
	geometry._cover = _flat(geometry.cover)
	geometry._left = _flat(geometry.left)
	geometry._right = _flat(geometry.right)
	return geometry


## A new geometry on the same positions with the lock and frost rules of `tile_features`
## (see HalvesFeatures for the format). Never changes this one.
func with_features(tile_features: Dictionary) -> HalvesGeometry:
	var geometry := HalvesGeometry.new()
	geometry.positions = positions.duplicate()
	geometry.cover = cover.duplicate(true)
	geometry.left = left.duplicate(true)
	geometry.right = right.duplicate(true)
	geometry.touch = touch.duplicate(true)
	geometry._cover = _cover.duplicate()
	geometry._left = _left.duplicate()
	geometry._right = _right.duplicate()
	geometry.features = HalvesFeatures.normalize(tile_features)
	if geometry.features.is_empty():
		return geometry
	var count := positions.size()
	for i in count:
		geometry.lock_need.append(HalvesBits.empty())
		geometry.frost_need.append(HalvesBits.empty())
	for group: Dictionary in geometry.features.get("locks", []):
		var keys := HalvesFeatures.mask(group.keys)
		for tile: int in group.locked:
			if tile >= 0 and tile < count:
				geometry.lock_need[tile] = HalvesBits.union(geometry.lock_need[tile], keys)
	for tile: int in geometry.features.get("frost", []):
		if tile >= 0 and tile < count:
			geometry.frost_need[tile] = touch[tile].duplicate()
	geometry._lock = _flat(geometry.lock_need)
	geometry._frost = _flat(geometry.frost_need)
	return geometry


func has_features() -> bool:
	return not features.is_empty()


func size() -> int:
	return positions.size()


func full_mask() -> PackedInt64Array:
	return HalvesBits.full(positions.size())


func is_free(i: int, remaining: PackedInt64Array) -> bool:
	var r0 := remaining[0]
	var r1 := remaining[1]
	var k := i << 1
	if _cover[k] & r0 != 0 or _cover[k + 1] & r1 != 0:
		return false
	if (_left[k] & r0 != 0 or _left[k + 1] & r1 != 0) and (_right[k] & r0 != 0 or _right[k + 1] & r1 != 0):
		return false
	if _lock.is_empty():
		return true
	return _rules_allow(k, r0, r1)


func blocked_reason(i: int, remaining: PackedInt64Array) -> Block:
	var r0 := remaining[0]
	var r1 := remaining[1]
	var k := i << 1
	if _cover[k] & r0 != 0 or _cover[k + 1] & r1 != 0:
		return Block.COVERED
	if (_left[k] & r0 != 0 or _left[k + 1] & r1 != 0) and (_right[k] & r0 != 0 or _right[k + 1] & r1 != 0):
		return Block.SIDES
	if not _lock.is_empty():
		if _lock[k] & r0 != 0 or _lock[k + 1] & r1 != 0:
			return Block.LOCKED
		var f0 := _frost[k]
		var f1 := _frost[k + 1]
		if (f0 != 0 or f1 != 0) and f0 & ~r0 == 0 and f1 & ~r1 == 0:
			return Block.FROSTED
	return Block.FREE


## The free tiles among `remaining` (the same rules as is_free, inlined: this is the hot loop of
## the solver, the bots and the fill).
func free_mask(remaining: PackedInt64Array) -> PackedInt64Array:
	var r0 := remaining[0]
	var r1 := remaining[1]
	var free0 := 0
	var free1 := 0
	var cov := _cover
	var lft := _left
	var rgt := _right
	var lck := _lock
	var frs := _frost
	var rules := not lck.is_empty()
	for i in positions.size():
		var bit := 1 << (i & 63)
		var low := i < 64
		if (r0 if low else r1) & bit == 0:
			continue
		var k := i << 1
		if cov[k] & r0 != 0 or cov[k + 1] & r1 != 0:
			continue
		if (lft[k] & r0 != 0 or lft[k + 1] & r1 != 0) and (rgt[k] & r0 != 0 or rgt[k + 1] & r1 != 0):
			continue
		if rules:
			if lck[k] & r0 != 0 or lck[k + 1] & r1 != 0:
				continue
			var f0 := frs[k]
			var f1 := frs[k + 1]
			if (f0 != 0 or f1 != 0) and f0 & ~r0 == 0 and f1 & ~r1 == 0:
				continue
		if low:
			free0 |= bit
		else:
			free1 |= bit
	var out := HalvesBits.empty()
	out[0] = free0
	out[1] = free1
	return out


## The free tiles among `remaining`, ascending (free_mask's loop, collecting ids).
func free_tiles(remaining: PackedInt64Array) -> PackedInt32Array:
	var r0 := remaining[0]
	var r1 := remaining[1]
	var tiles := PackedInt32Array()
	var cov := _cover
	var lft := _left
	var rgt := _right
	var lck := _lock
	var frs := _frost
	var rules := not lck.is_empty()
	for i in positions.size():
		if (r0 if i < 64 else r1) & (1 << (i & 63)) == 0:
			continue
		var k := i << 1
		if cov[k] & r0 != 0 or cov[k + 1] & r1 != 0:
			continue
		if (lft[k] & r0 != 0 or lft[k + 1] & r1 != 0) and (rgt[k] & r0 != 0 or rgt[k + 1] & r1 != 0):
			continue
		if rules:
			if lck[k] & r0 != 0 or lck[k + 1] & r1 != 0:
				continue
			var f0 := frs[k]
			var f1 := frs[k + 1]
			if (f0 != 0 or f1 != 0) and f0 & ~r0 == 0 and f1 & ~r1 == 0:
				continue
		tiles.append(i)
	return tiles


## The x/y extent in half-units, from (0, 0) to the far edge of the last tile.
func bounds() -> Rect2i:
	var far := Vector2i.ZERO
	for p in positions:
		far = Vector2i(maxi(far.x, p.x + 2), maxi(far.y, p.y + 2))
	return Rect2i(Vector2i.ZERO, far)


func max_z() -> int:
	var top := 0
	for p in positions:
		top = maxi(top, p.z)
	return top


## Lock and frost for the tile at flat index `k`: no key of its groups remains, and if it is
## frosted, some tile touching it is gone.
func _rules_allow(k: int, r0: int, r1: int) -> bool:
	if _lock[k] & r0 != 0 or _lock[k + 1] & r1 != 0:
		return false
	var f0 := _frost[k]
	var f1 := _frost[k + 1]
	return (f0 == 0 and f1 == 0) or f0 & ~r0 != 0 or f1 & ~r1 != 0


## Per-tile sets -> one flat array, tile i at 2i and 2i + 1.
static func _flat(sets: Array[PackedInt64Array]) -> PackedInt64Array:
	var out := PackedInt64Array()
	out.resize(sets.size() * HalvesBits.WORDS)
	for i in sets.size():
		out[i << 1] = sets[i][0]
		out[(i << 1) + 1] = sets[i][1]
	return out
