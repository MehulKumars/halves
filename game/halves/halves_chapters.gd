class_name HalvesChapters
extends RefCounted
## The fifteen places of twenty levels (v3, docs/HALVES.md 4b) plus the home screen's own: the
## background photos ("photos": one for levels 1-10 and one for 11-20, files in assets/backgrounds;
## a place with one photo shows it for both halves), the drawn scene ("scene", HalvesScenery),
## ambient effect, colours and jingle. Credits for every photo are in tools/art/photos.json too.

const LEVELS_PER_CHAPTER: int = 20
## Levels shown with each photo of a place.
const LEVELS_PER_PHOTO: int = 10
## The home screen's background (not a chapter).
const MENU: Dictionary = {"id": "fuji", "name": "Mount Fuji", "place": "Lake Kawaguchi, Yamanashi",
	"ambient": "petals", "ambient_color": Color(1.0, 0.9, 0.93, 0.8), "accent": Color("f2b8a0"),
	"tint": Color("2e3558"), "focus": Vector2(0.5, 0.5), "win": "win_spring",
	"photos": [{"id": "fuji_lake_a", "title": "Kawaguchiko, Part II", "author": "lumoplank", "license": "CC0 1.0"}]}
const CHAPTERS: Array[Dictionary] = [
	{"id": "fuji_lake", "name": "Fuji Lake", "place": "Lake Kawaguchi, Yamanashi", "scene": "fuji",
		"ambient": "petals", "ambient_color": Color(1.0, 0.9, 0.93, 0.8), "accent": Color("f2b8a0"),
		"tint": Color("2e3558"), "focus": Vector2(0.5, 0.5), "win": "win_spring",
		"photos": [
			{"id": "fuji_lake_a", "title": "Kawaguchiko, Part II", "author": "lumoplank", "license": "CC0 1.0"},
			{"id": "fuji_lake_b", "title": "Kawaguchiko, Part I", "author": "lumoplank", "license": "CC0 1.0"}]},
	{"id": "sakura", "name": "Sakura", "place": "Ueno Park and Fukuokazeki", "scene": "sakura",
		"ambient": "petals", "ambient_color": Color(1.0, 0.9, 0.94, 0.85), "accent": Color("f0a8c0"),
		"tint": Color("2a2233"), "focus": Vector2(0.5, 0.5), "win": "win_spring",
		"photos": [
			{"id": "sakura_a", "title": "Blossom, Ueno Park", "author": "Don Kawahigashi", "license": "CC0 1.0"},
			{"id": "sakura_b", "title": "Cherry blossom in Fukuokazeki sakura park", "author": "On-chan", "license": "CC0 1.0"}]},
	{"id": "bamboo", "name": "Bamboo Grove", "place": "Hokokuji, Kamakura", "scene": "bamboo",
		"ambient": "leaves", "ambient_color": Color(0.66, 0.84, 0.48, 0.85), "accent": Color("a8d27e"),
		"tint": Color("1d2a1c"), "focus": Vector2(0.5, 0.5), "win": "win_summer",
		"photos": [
			{"id": "bamboo_a", "title": "Hokokuji Bamboo Forest, Kamakura", "author": "Urashimataro", "license": "Public domain"},
			{"id": "bamboo_b", "title": "Impressive bamboo canopy", "author": "Jason Ortego", "license": "CC0 1.0"}]},
	{"id": "kyoto", "name": "Old Kyoto", "place": "Higashiyama and Gion, Kyoto", "scene": "kyoto",
		"ambient": "motes", "ambient_color": Color(1.0, 0.92, 0.78, 0.55), "accent": Color("f0b878"),
		"tint": Color("2b2622"), "focus": Vector2(0.5, 0.5), "win": "win_spring",
		"photos": [
			{"id": "kyoto_a", "title": "Higashiyama streets", "author": "lumoplank", "license": "CC0 1.0"},
			{"id": "kyoto_b", "title": "Streets of Gion, Kyoto", "author": "lumoplank", "license": "CC0 1.0"}]},
	{"id": "torii", "name": "Floating Gate", "place": "Miyajima, Hiroshima", "scene": "torii",
		"ambient": "motes", "ambient_color": Color(1.0, 0.86, 0.58, 0.75), "accent": Color("f39a6b"),
		"tint": Color("2a2026"), "focus": Vector2(0.5, 0.5), "win": "win_summer",
		"photos": [
			{"id": "torii", "title": "Itsukushima-jinja torii at sunset, Miyajima", "author": "Jakub Hałun", "license": "CC BY 4.0"}]},
	{"id": "nara", "name": "Deer Park", "place": "Nara", "scene": "nara",
		"ambient": "leaves", "ambient_color": Color(0.96, 0.66, 0.26, 0.85), "accent": Color("ecb64c"),
		"tint": Color("2a2214"), "focus": Vector2(0.5, 0.5), "win": "win_autumn",
		"photos": [
			{"id": "nara_a", "title": "Nara (7619)", "author": "lumoplank", "license": "CC0 1.0"},
			{"id": "nara_b", "title": "Nara (7598)", "author": "lumoplank", "license": "CC0 1.0"}]},
	{"id": "tokyo", "name": "City Lights", "place": "Tokyo Tower, Tokyo", "scene": "tokyo",
		"ambient": "rain", "ambient_color": Color(0.8, 0.9, 1.0, 0.22), "accent": Color("f6b452"),
		"tint": Color("101830"), "focus": Vector2(0.5, 0.5), "win": "win_moon",
		"photos": [
			{"id": "tokyo_a", "title": "Tokyo Tower at night", "author": "Daderot", "license": "CC0 1.0"},
			{"id": "tokyo_b", "title": "Azabudai Hills and Tokyo Tower at night", "author": "Syced", "license": "CC0 1.0"}]},
	{"id": "autumn", "name": "Autumn Path", "place": "Eikando and Nanzen-ji, Kyoto", "scene": "kiyomizu",
		"ambient": "leaves", "ambient_color": Color(0.95, 0.42, 0.26, 0.85), "accent": Color("f48c4e"),
		"tint": Color("160f1e"), "focus": Vector2(0.5, 0.5), "win": "win_autumn",
		"photos": [
			{"id": "autumn_a", "title": "Eikando, Kyoto", "author": "lumoplank", "license": "CC0 1.0"},
			{"id": "autumn_b", "title": "Nanzen-ji, Kyoto", "author": "lumoplank", "license": "CC0 1.0"}]},
	{"id": "kinkaku", "name": "Golden Pavilion", "place": "Kinkaku-ji, Kyoto", "scene": "kinkaku",
		"ambient": "snow", "ambient_color": Color(1, 1, 1, 0.8), "accent": Color("ebc66c"),
		"tint": Color("1d2430"), "focus": Vector2(0.5, 0.5), "win": "win_winter",
		"photos": [
			{"id": "kinkaku", "title": "Kinkakuji temple in snow", "author": "Takeshi Kuboki", "license": "CC BY 2.0"}]},
	{"id": "moon", "name": "Moon Night", "place": "Matsumoto and Tokyo by night", "scene": "kiyomizu",
		"ambient": "fireflies", "ambient_color": Color(1.0, 0.95, 0.7, 0.8), "accent": Color("e8d9a0"),
		"tint": Color("0e1226"), "focus": Vector2(0.5, 0.5), "win": "win_moon",
		"photos": [
			{"id": "moon_a", "title": "Matsumoto Castle at night", "author": "Hiroaki Kikuchi", "license": "CC0 1.0"},
			{"id": "moon_b", "title": "Tokyo Tower and moon seen from Shibuya Stream", "author": "Syced", "license": "CC0 1.0"}]},
	{"id": "ginzan", "name": "Snow Lanterns", "place": "Otaru and Ginzan Onsen", "scene": "ginzan",
		"ambient": "snow", "ambient_color": Color(1, 1, 1, 0.75), "accent": Color("f6d8a2"),
		"tint": Color("101a33"), "focus": Vector2(0.5, 0.5), "win": "win_winter",
		"photos": [
			{"id": "ginzan_a", "title": "Otaru Canal Cruise", "author": "Fumikas Sagisavas", "license": "CC0 1.0"},
			{"id": "ginzan_b", "title": "Ginzan Onsen, the other side", "author": "lumoplank", "license": "CC0 1.0"}]},
	{"id": "inari", "name": "Thousand Gates", "place": "Fushimi Inari, Kyoto", "scene": "inari",
		"ambient": "motes", "ambient_color": Color(1.0, 0.9, 0.7, 0.6), "accent": Color("f26a44"),
		"tint": Color("2a1510"), "focus": Vector2(0.5, 0.5), "win": "win_moon",
		"photos": [
			{"id": "inari", "title": "Fushimi Inari, Kyoto", "author": "Jakub Hałun", "license": "CC BY 4.0"}]},
	{"id": "himeji", "name": "White Castle", "place": "Himeji, Hyogo", "scene": "kinkaku",
		"ambient": "petals", "ambient_color": Color(1.0, 0.92, 0.95, 0.8), "accent": Color("f4c7cf"),
		"tint": Color("1e2a3a"), "focus": Vector2(0.5, 0.5), "win": "win_spring",
		"photos": [
			{"id": "himeji_a", "title": "Himeji", "author": "lumoplank", "license": "CC0 1.0"},
			{"id": "himeji_b", "title": "Himeji Castle", "author": "Loggieloggie", "license": "CC0 1.0"}]},
	{"id": "shirakawa", "name": "Snow Village", "place": "Shirakawa-go, Gifu", "scene": "ginzan",
		"ambient": "snow", "ambient_color": Color(1, 1, 1, 0.85), "accent": Color("dfe8f2"),
		"tint": Color("141c2c"), "focus": Vector2(0.5, 0.5), "win": "win_winter",
		"photos": [
			{"id": "shirakawa_a", "title": "Shirakawa-go", "author": "lumoplank", "license": "CC0 1.0"},
			{"id": "shirakawa_b", "title": "View of Shirakawa-go from Ogimachi Joseki Observatory", "author": "Jason Ortego", "license": "CC0 1.0"}]},
	{"id": "hokkaido", "name": "Northern Fields", "place": "Hokkaido", "scene": "fuji",
		"ambient": "petals", "ambient_color": Color(0.85, 0.8, 1.0, 0.8), "accent": Color("c9b6f0"),
		"tint": Color("1f2240"), "focus": Vector2(0.5, 0.5), "win": "win_summer",
		"photos": [
			{"id": "hokkaido_a", "title": "Field of flowers in Hokkaido", "author": "TheOneMattMan", "license": "CC0 1.0"},
			{"id": "hokkaido_b", "title": "Historical Village of Hokkaido", "author": "lumoplank", "license": "CC0 1.0"}]},
]


static func count() -> int:
	return CHAPTERS.size()


## 0-based chapter of a level (levels past the last chapter stay in it).
static func index_for_level(level: int) -> int:
	return clampi((level - 1) / LEVELS_PER_CHAPTER, 0, CHAPTERS.size() - 1)


## Which of its place's photos a level shows: 0 for levels 1-10 of the place, 1 for 11-20.
static func half_for_level(level: int) -> int:
	return posmod(level - 1, LEVELS_PER_CHAPTER) / LEVELS_PER_PHOTO


## A chapter's data; ChapterBackground.MENU (-1) gives the home screen's.
static func get_chapter(index: int) -> Dictionary:
	if index < 0:
		return MENU
	return CHAPTERS[posmod(index, CHAPTERS.size())]


static func first_level(index: int) -> int:
	return index * LEVELS_PER_CHAPTER + 1


static func last_level(index: int) -> int:
	return (index + 1) * LEVELS_PER_CHAPTER


## The baked photo (1440 x 2880) of a chapter's `half` and its 320 px square thumbnail.
static func photo_path(index: int, half: int = 0) -> String:
	return "res://assets/backgrounds/%s.webp" % photo_info(index, half).id


static func thumb_path(index: int, half: int = 0) -> String:
	return "res://assets/backgrounds/%s_thumb.webp" % photo_info(index, half).id


## (v3) The soft 720 x 1440 copy baked for behind the board (tools/art/process_photos.gd).
static func play_path(index: int, half: int = 0) -> String:
	return "res://assets/backgrounds/%s_play.webp" % photo_info(index, half).id


## The drawn scene (HalvesScenery) for a chapter; the home screen's is "fuji".
static func scene_id(index: int) -> String:
	var c := get_chapter(index)
	return str(c.get("scene", c.id))


## "Photo: <title> · <author> · <licence>" under a chapter's picture.
static func credit_line(index: int, half: int = 0) -> String:
	var p := photo_info(index, half)
	return "Photo: %s · %s · %s" % [p.title, p.author, p.license]


## The {id, title, author, license} of a chapter's photo for `half` (its last one if it has fewer).
static func photo_info(index: int, half: int = 0) -> Dictionary:
	var photos: Array = get_chapter(index).photos
	return photos[clampi(half, 0, photos.size() - 1)]
