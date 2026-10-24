class_name HalvesCrestBook
extends RefCounted
## The Crest Book: every level restores one crest, its signature (the pair with the most tiles on
## the board; ties: the lowest pair), and each place is a page of its levels' crests. Read by the
## Crest Book screen and the journey map; a crest counts as restored once its level is won.

static var _signature: Dictionary[int, int] = {}


## The pair a level restores (-1 if the level doesn't exist).
static func signature_pair(level: int) -> int:
	if _signature.has(level):
		return _signature[level]
	var data := HalvesLevels.get_level(level)
	var pair := -1
	if data != null:
		var counts: Dictionary[int, int] = {}
		for face in data.faces:
			var key := HalvesFace.pair_key(face)
			counts[key] = counts.get(key, 0) + 1
		var best := -1
		for key: int in counts:
			if counts[key] > best or (counts[key] == best and key < pair):
				best = counts[key]
				pair = key
	_signature[level] = pair
	return pair


static func is_restored(level: int) -> bool:
	return Progress.stars(level) > 0


## Restored crests on a page (a place's levels) and in the whole book.
static func restored_on_page(chapter: int) -> int:
	var n := 0
	for level in range(HalvesChapters.first_level(chapter), mini(HalvesChapters.last_level(chapter), HalvesLevels.count()) + 1):
		n += 1 if is_restored(level) else 0
	return n


static func restored_total() -> int:
	var n := 0
	for level in range(1, HalvesLevels.count() + 1):
		n += 1 if is_restored(level) else 0
	return n
