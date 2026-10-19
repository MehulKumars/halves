class_name HalvesChapters
extends RefCounted
## The five seasonal chapters of 20 levels: name, print (Hiroshige, public domain), colours, ambient
## effect, music and win burst. Read by the screens, ChapterBackground, Sound and the results.
## Swapping a print or track means changing one line here and baking with tools/art/.

const LEVELS_PER_CHAPTER: int = 20
const CHAPTERS: Array[Dictionary] = [
	{"id": "spring", "name": "Spring", "place": "Plum Garden", "ambient": "petals",
		"accent": Color("e8a3b8"), "tint": Color("24182e"), "focus": Vector2(0.55, 0.5),
		"title": "Plum Garden at Kameido", "year": "1857", "collection": "Rijksmuseum, Amsterdam"},
	{"id": "summer", "name": "Summer", "place": "Evening Shower", "ambient": "rain",
		"accent": Color("7cc4b8"), "tint": Color("0f2a33"), "focus": Vector2(0.45, 0.55),
		"title": "Sudden Shower over Shin-Ohashi Bridge and Atake", "year": "1857",
		"collection": "The Metropolitan Museum of Art"},
	{"id": "autumn", "name": "Autumn", "place": "Maple Hills", "ambient": "leaves",
		"accent": Color("e07a4f"), "tint": Color("2a1712"), "focus": Vector2(0.5, 0.45),
		"title": "Maple Trees at Mama, Tekona Shrine and Tsugi Bridge", "year": "1857",
		"collection": "The Metropolitan Museum of Art"},
	{"id": "winter", "name": "Winter", "place": "Temple Snow", "ambient": "snow",
		"accent": Color("a9cfe0"), "tint": Color("14223a"), "focus": Vector2(0.6, 0.55),
		"title": "Kinryuzan Temple at Asakusa", "year": "1856", "collection": "The Metropolitan Museum of Art"},
	{"id": "moon", "name": "Moon", "place": "Night Street", "ambient": "fireflies",
		"accent": Color("f0d58a"), "tint": Color("0a1430"), "focus": Vector2(0.4, 0.4),
		"title": "Night View of Saruwaka-machi", "year": "1856", "collection": "Library of Congress"},
]
const ARTIST: String = "Utagawa Hiroshige"
const SERIES: String = "One Hundred Famous Views of Edo"


static func count() -> int:
	return CHAPTERS.size()


## 0-based chapter of a level (levels past the last chapter stay in it).
static func index_for_level(level: int) -> int:
	return clampi((level - 1) / LEVELS_PER_CHAPTER, 0, CHAPTERS.size() - 1)


static func get_chapter(index: int) -> Dictionary:
	return CHAPTERS[posmod(index, CHAPTERS.size())]


static func first_level(index: int) -> int:
	return index * LEVELS_PER_CHAPTER + 1


static func last_level(index: int) -> int:
	return (index + 1) * LEVELS_PER_CHAPTER


static func background_path(index: int) -> String:
	return "res://assets/chapters/%s_bg.webp" % get_chapter(index).id


static func print_path(index: int) -> String:
	return "res://assets/chapters/%s_print.webp" % get_chapter(index).id


static func music_path(index: int) -> String:
	return "res://assets/audio/music/%s.ogg" % get_chapter(index).id


## "Plum Garden at Kameido, 1857 · Utagawa Hiroshige" for captions and credits.
static func credit_line(index: int) -> String:
	var c := get_chapter(index)
	return "%s, %s · %s" % [c.title, c.year, ARTIST]
