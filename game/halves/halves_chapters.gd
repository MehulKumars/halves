class_name HalvesChapters
extends RefCounted
## The ten places of ten levels (one sawtooth pack each) plus the home screen's own: the background
## photo (tools/art/photos.json; or the same place drawn in code, HalvesScenery), ambient effect,
## colours and win jingle. Read by the screens, ChapterBackground, the win burst and the results.

const LEVELS_PER_CHAPTER: int = 10
## The home screen's background (not a chapter).
const MENU: Dictionary = {"id": "fuji", "name": "Mount Fuji", "place": "Lake Kawaguchi, Yamanashi",
	"ambient": "petals", "ambient_color": Color(1.0, 0.9, 0.93, 0.8), "accent": Color("f2b8a0"),
	"tint": Color("2e3558"), "focus": Vector2(0.5, 0.5), "win": "win_spring",
	"title": "Mount Fuji at sunset, March 2025", "author": "Romain Guy", "license": "CC0 1.0"}
const CHAPTERS: Array[Dictionary] = [
	{"id": "sakura", "name": "Sakura", "place": "Ashino Park, Aomori",
		"ambient": "petals", "ambient_color": Color(1.0, 0.9, 0.94, 0.85), "accent": Color("f0a8c0"),
		"tint": Color("2a2233"), "focus": Vector2(0.5, 0.5), "win": "win_spring",
		"title": "Rail tracks and cherry trees in Ashino Park", "author": "掬茶", "license": "CC BY-SA 4.0"},
	{"id": "kyoto", "name": "Old Kyoto", "place": "Yasaka-dori, Kyoto",
		"ambient": "motes", "ambient_color": Color(1.0, 0.92, 0.78, 0.55), "accent": Color("f0b878"),
		"tint": Color("2b2622"), "focus": Vector2(0.38, 0.5), "win": "win_spring",
		"title": "Yasaka-dori early morning, Kyoto", "author": "Basile Morin", "license": "CC BY-SA 4.0"},
	{"id": "bamboo", "name": "Bamboo Grove", "place": "Arashiyama, Kyoto",
		"ambient": "leaves", "ambient_color": Color(0.66, 0.84, 0.48, 0.85), "accent": Color("a8d27e"),
		"tint": Color("1d2a1c"), "focus": Vector2(0.5, 0.5), "win": "win_summer",
		"title": "Bamboo Grove, Arashiyama, Kyoto", "author": "Basile Morin", "license": "CC BY-SA 4.0"},
	{"id": "torii", "name": "Floating Gate", "place": "Miyajima, Hiroshima",
		"ambient": "motes", "ambient_color": Color(1.0, 0.86, 0.58, 0.75), "accent": Color("f39a6b"),
		"tint": Color("2a2026"), "focus": Vector2(0.5, 0.5), "win": "win_summer",
		"title": "Itsukushima-jinja torii at sunset, Miyajima", "author": "Jakub Hałun", "license": "CC BY 4.0"},
	{"id": "tokyo", "name": "City Lights", "place": "Tokyo Tower, Tokyo",
		"ambient": "rain", "ambient_color": Color(0.8, 0.9, 1.0, 0.22), "accent": Color("f6b452"),
		"tint": Color("101830"), "focus": Vector2(0.5, 0.5), "win": "win_moon",
		"title": "Tokyo Tower at night", "author": "kakidai", "license": "CC BY-SA 3.0"},
	{"id": "nara", "name": "Autumn Path", "place": "Nara Park, Nara",
		"ambient": "leaves", "ambient_color": Color(0.96, 0.66, 0.26, 0.85), "accent": Color("ecb64c"),
		"tint": Color("2a2214"), "focus": Vector2(0.5, 0.5), "win": "win_autumn",
		"title": "Nara Park, November 2016", "author": "Martin Falbisoner", "license": "CC BY-SA 4.0"},
	{"id": "kiyomizu", "name": "Night Glow", "place": "Kiyomizu-dera, Kyoto",
		"ambient": "leaves", "ambient_color": Color(0.95, 0.42, 0.26, 0.85), "accent": Color("f48c4e"),
		"tint": Color("160f1e"), "focus": Vector2(0.5, 0.5), "win": "win_autumn",
		"title": "Kiyomizu-dera, Kyoto, November 2016", "author": "Martin Falbisoner", "license": "CC BY-SA 4.0"},
	{"id": "kinkaku", "name": "Golden Snow", "place": "Kinkaku-ji, Kyoto",
		"ambient": "snow", "ambient_color": Color(1, 1, 1, 0.8), "accent": Color("ebc66c"),
		"tint": Color("1d2430"), "focus": Vector2(0.5, 0.5), "win": "win_winter",
		"title": "Kinkakuji temple in snow", "author": "Takeshi Kuboki", "license": "CC BY 2.0"},
	{"id": "ginzan", "name": "Snow Lanterns", "place": "Ginzan Onsen, Yamagata",
		"ambient": "snow", "ambient_color": Color(1, 1, 1, 0.75), "accent": Color("f6d8a2"),
		"tint": Color("101a33"), "focus": Vector2(0.5, 0.5), "win": "win_winter",
		"title": "Evening twilight in Ginzan Onsen town", "author": "さかおり", "license": "CC BY-SA 4.0"},
	{"id": "inari", "name": "Thousand Gates", "place": "Fushimi Inari, Kyoto",
		"ambient": "motes", "ambient_color": Color(1.0, 0.9, 0.7, 0.6), "accent": Color("f26a44"),
		"tint": Color("2a1510"), "focus": Vector2(0.5, 0.5), "win": "win_moon",
		"title": "Fushimi Inari, Kyoto", "author": "Jakub Hałun", "license": "CC BY 4.0"},
]


static func count() -> int:
	return CHAPTERS.size()


## 0-based chapter of a level (levels past the last chapter stay in it).
static func index_for_level(level: int) -> int:
	return clampi((level - 1) / LEVELS_PER_CHAPTER, 0, CHAPTERS.size() - 1)


## A chapter's data; ChapterBackground.MENU (-1) gives the home screen's.
static func get_chapter(index: int) -> Dictionary:
	if index < 0:
		return MENU
	return CHAPTERS[posmod(index, CHAPTERS.size())]


static func first_level(index: int) -> int:
	return index * LEVELS_PER_CHAPTER + 1


static func last_level(index: int) -> int:
	return (index + 1) * LEVELS_PER_CHAPTER


## The baked photo (1440 x 2880) and its 320 px square thumbnail.
static func photo_path(index: int) -> String:
	return "res://assets/backgrounds/%s.webp" % get_chapter(index).id


static func thumb_path(index: int) -> String:
	return "res://assets/backgrounds/%s_thumb.webp" % get_chapter(index).id


## "Photo: <title> · <author> · <licence>" under a chapter's picture.
static func credit_line(index: int) -> String:
	var c := get_chapter(index)
	return "Photo: %s · %s · %s" % [c.title, c.author, c.license]
