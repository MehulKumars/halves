class_name HalvesGeometry
extends RefCounted
## Where the tiles of one level sit, and which tiles block which: positions are (x, y, z) in
## half-tile units; a set of tiles is an int bitmask, so "is tile i free?" is O(1). Used by every
## piece of Halves logic. At most 64 tiles: bit 63 makes the int negative, so test bits with != 0.
## Features (locks, frost) are extra blocking rules; every rule is monotone (docs/HALVES.md).

const MAX_TILES: int = 64

## Why a tile is not free, in the order blocked_reason() checks.
enum Block { FREE, COVERED, SIDES, LOCKED, FROSTED }

var positions: Array[Vector3i] = []
## cover[i]: tiles that lie on top of tile i. left[i] / right[i]: its side neighbours.
var cover: PackedInt64Array = PackedInt64Array()
var left: PackedInt64Array = PackedInt64Array()
var right: PackedInt64Array = PackedInt64Array()
## touch[i]: tiles touching tile i (cover, side neighbours, same-layer tiles straight above/below).
var touch: PackedInt64Array = PackedInt64Array()
## Empty without features. lock_need[i]: key tiles that must be gone; frost_need[i]: touch[i] for
## frosted tiles (one of them must be gone), 0 for the others.
var lock_need: PackedInt64Array = PackedInt64Array()
var frost_need: PackedInt64Array = PackedInt64Array()
var features: Dictionary = {}


static func from_positions(tile_positions: Array[Vector3i]) -> HalvesGeometry:
	assert(tile_positions.size() <= MAX_TILES, "Halves boards hold at most 64 tiles")
	var geometry := HalvesGeometry.new()
	geometry.positions = tile_positions.duplicate()
	var count := tile_positions.size()
	geometry.cover.resize(count)
	geometry.left.resize(count)
	geometry.right.resize(count)
	geometry.touch.resize(count)
	for i in count:
		var a := tile_positions[i]
		var covered_by := 0
		var left_of := 0
		var right_of := 0
		var stacked := 0
		for j in count:
			if i == j:
				continue
			var b := tile_positions[j]
			if b.z == a.z and absi(b.x - a.x) < 2 and absi(b.y - a.y) == 2:
				stacked |= 1 << j
			if absi(b.y - a.y) >= 2:
				continue
			if b.z > a.z and absi(b.x - a.x) < 2:
				covered_by |= 1 << j
			elif b.z == a.z and b.x == a.x - 2:
				left_of |= 1 << j
			elif b.z == a.z and b.x == a.x + 2:
				right_of |= 1 << j
		geometry.cover[i] = covered_by
		geometry.left[i] = left_of
		geometry.right[i] = right_of
		geometry.touch[i] = covered_by | left_of | right_of | stacked
	return geometry


## A new geometry on the same positions with the lock and frost rules of `tile_features`
## (see HalvesFeatures for the format). Never changes this one.
func with_features(tile_features: Dictionary) -> HalvesGeometry:
	var geometry := HalvesGeometry.new()
	geometry.positions = positions.duplicate()
	geometry.cover = cover.duplicate()
	geometry.left = left.duplicate()
	geometry.right = right.duplicate()
	geometry.touch = touch.duplicate()
	geometry.features = HalvesFeatures.normalize(tile_features)
	if geometry.features.is_empty():
		return geometry
	var count := positions.size()
	geometry.lock_need.resize(count)
	geometry.frost_need.resize(count)
	for group: Dictionary in geometry.features.get("locks", []):
		var keys := HalvesFeatures.mask(group.keys)
		for tile: int in group.locked:
			if tile >= 0 and tile < count:
				geometry.lock_need[tile] |= keys
	for tile: int in geometry.features.get("frost", []):
		if tile >= 0 and tile < count:
			geometry.frost_need[tile] = touch[tile]
	return geometry


func has_features() -> bool:
	return not features.is_empty()


func size() -> int:
	return positions.size()


func full_mask() -> int:
	var mask := 0
	for i in positions.size():
		mask |= 1 << i
	return mask


func is_free(i: int, remaining: int) -> bool:
	if remaining & cover[i] != 0 or (remaining & left[i] != 0 and remaining & right[i] != 0):
		return false
	if lock_need.is_empty():
		return true
	return remaining & lock_need[i] == 0 and (frost_need[i] == 0 or frost_need[i] & ~remaining != 0)


func blocked_reason(i: int, remaining: int) -> Block:
	if remaining & cover[i] != 0:
		return Block.COVERED
	if remaining & left[i] != 0 and remaining & right[i] != 0:
		return Block.SIDES
	if not lock_need.is_empty():
		if remaining & lock_need[i] != 0:
			return Block.LOCKED
		if frost_need[i] != 0 and frost_need[i] & ~remaining == 0:
			return Block.FROSTED
	return Block.FREE


func free_mask(remaining: int) -> int:
	var mask := 0
	for i in positions.size():
		if remaining & (1 << i) != 0 and is_free(i, remaining):
			mask |= 1 << i
	return mask


func free_tiles(remaining: int) -> PackedInt32Array:
	var tiles := PackedInt32Array()
	for i in positions.size():
		if remaining & (1 << i) != 0 and is_free(i, remaining):
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


## Tiles in `mask` (all 64 bits; arithmetic shifts are fine because the loop is bounded).
static func popcount(mask: int) -> int:
	var count := 0
	var bits := mask
	for _i in 64:
		count += bits & 1
		bits >>= 1
	return count
