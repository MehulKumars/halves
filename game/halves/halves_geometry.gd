class_name HalvesGeometry
extends RefCounted
## Where the tiles of one level sit, and which tiles block which: positions are (x, y, z) in
## half-tile units; a set of tiles is an int bitmask, so "is tile i free?" is O(1). Used by every
## piece of Halves logic. At most 64 tiles: bit 63 makes the int negative, so test bits with != 0.

const MAX_TILES: int = 64

var positions: Array[Vector3i] = []
## cover[i]: tiles that lie on top of tile i. left[i] / right[i]: its side neighbours.
var cover: PackedInt64Array = PackedInt64Array()
var left: PackedInt64Array = PackedInt64Array()
var right: PackedInt64Array = PackedInt64Array()


static func from_positions(tile_positions: Array[Vector3i]) -> HalvesGeometry:
	assert(tile_positions.size() <= MAX_TILES, "Halves boards hold at most 64 tiles")
	var geometry := HalvesGeometry.new()
	geometry.positions = tile_positions.duplicate()
	var count := tile_positions.size()
	geometry.cover.resize(count)
	geometry.left.resize(count)
	geometry.right.resize(count)
	for i in count:
		var a := tile_positions[i]
		var covered_by := 0
		var left_of := 0
		var right_of := 0
		for j in count:
			if i == j:
				continue
			var b := tile_positions[j]
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
	return geometry


func size() -> int:
	return positions.size()


func full_mask() -> int:
	var mask := 0
	for i in positions.size():
		mask |= 1 << i
	return mask


func is_free(i: int, remaining: int) -> bool:
	return remaining & cover[i] == 0 and (remaining & left[i] == 0 or remaining & right[i] == 0)


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
