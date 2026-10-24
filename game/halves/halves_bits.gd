class_name HalvesBits
extends RefCounted
## A set of tile ids 0..127: a PackedInt64Array of two words, tile i = bit (i & 63) of word (i >> 6).
## Every set of tiles in the Halves logic, view, tools and tests is one (remaining, free, cover ...).
## Arrays pass by reference: only set_bit/clear_bit change an argument. Ids outside 0..127 are ignored.

const WORDS := 2
const MAX := 128

const _M1: int = 0x5555555555555555
const _M2: int = 0x3333333333333333
const _M4: int = 0x0F0F0F0F0F0F0F0F
const _LOW63: int = 0x7FFFFFFFFFFFFFFF


static func empty() -> PackedInt64Array:
	var s := PackedInt64Array()
	s.resize(WORDS)
	return s


## Tiles 0..count-1 (count is clamped to 0..128).
static func full(count: int) -> PackedInt64Array:
	var s := empty()
	s[0] = _low_bits(count)
	s[1] = _low_bits(count - 64)
	return s


## The set of `ids` (ints, or whole floats as JSON gives them).
static func of(ids: Array) -> PackedInt64Array:
	var s := empty()
	for id: Variant in ids:
		set_bit(s, int(id))
	return s


static func has(s: PackedInt64Array, i: int) -> bool:
	if i < 0 or i >= MAX:
		return false
	return s[i >> 6] & (1 << (i & 63)) != 0


static func added(s: PackedInt64Array, i: int) -> PackedInt64Array:
	var out := s.duplicate()
	set_bit(out, i)
	return out


static func removed(s: PackedInt64Array, i: int) -> PackedInt64Array:
	var out := s.duplicate()
	clear_bit(out, i)
	return out


## In place.
static func set_bit(s: PackedInt64Array, i: int) -> void:
	if i >= 0 and i < MAX:
		s[i >> 6] |= 1 << (i & 63)


## In place.
static func clear_bit(s: PackedInt64Array, i: int) -> void:
	if i >= 0 and i < MAX:
		s[i >> 6] &= ~(1 << (i & 63))


static func union(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var s := empty()
	s[0] = a[0] | b[0]
	s[1] = a[1] | b[1]
	return s


static func intersection(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var s := empty()
	s[0] = a[0] & b[0]
	s[1] = a[1] & b[1]
	return s


## The tiles of `a` that are not in `b`.
static func minus(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var s := empty()
	s[0] = a[0] & ~b[0]
	s[1] = a[1] & ~b[1]
	return s


static func is_empty(s: PackedInt64Array) -> bool:
	return s[0] == 0 and s[1] == 0


static func intersects(a: PackedInt64Array, b: PackedInt64Array) -> bool:
	return a[0] & b[0] != 0 or a[1] & b[1] != 0


## True when every tile of `a` is in `b`.
static func is_subset(a: PackedInt64Array, b: PackedInt64Array) -> bool:
	return a[0] & ~b[0] == 0 and a[1] & ~b[1] == 0


static func equal(a: PackedInt64Array, b: PackedInt64Array) -> bool:
	return a[0] == b[0] and a[1] == b[1]


static func count(s: PackedInt64Array) -> int:
	return _count_word(s[0]) + _count_word(s[1])


## Set bits of one 64-bit word (SWAR popcount; the sign bit is taken off first so no step overflows).
static func _count_word(w: int) -> int:
	if w == 0:
		return 0
	var n := 0
	if w < 0:
		n = 1
		w &= _LOW63
	w -= (w >> 1) & _M1
	w = (w & _M2) + ((w >> 2) & _M2)
	w = (w + (w >> 4)) & _M4
	w += w >> 8
	w += w >> 16
	w += w >> 32
	return n + (w & 0x7F)


## The ids in `s`, ascending.
static func ids(s: PackedInt64Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for word in WORDS:
		var w := s[word]
		var base := word << 6
		for bit in 64:
			if w == 0:
				break
			var mask := 1 << bit
			if w & mask != 0:
				out.append(base + bit)
				w &= ~mask
	return out


## The lowest id in `s`, or -1 when it is empty.
static func first(s: PackedInt64Array) -> int:
	for word in WORDS:
		var w := s[word]
		if w == 0:
			continue
		for bit in 64:
			if w & (1 << bit) != 0:
				return (word << 6) + bit
	return -1


## A word with its lowest `n` bits set (n clamped to 0..64).
static func _low_bits(n: int) -> int:
	if n <= 0:
		return 0
	if n >= 64:
		return -1
	if n == 63:
		return _LOW63
	return (1 << n) - 1
