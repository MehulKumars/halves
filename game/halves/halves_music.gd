class_name HalvesMusic
extends RefCounted
## The music the player picks in Settings: lo-fi and calm playlists (songs in turn), and rain, nature
## and focus soundscapes (seamless loops, nature rotating between its three). Files are baked by
## tools/audio/build_music.sh from tools/audio/music.tsv (credits in ATTRIBUTION.md).

const KEY: String = "MusicStyle"
const DEFAULT: String = "lofi"
const DIR: String = "res://assets/audio/music/%s.ogg"
## A soundscape with several loops moves on to the next after this long.
const ROTATE_SECONDS: float = 240.0
## In Settings order. loop: each file loops (soundscapes); otherwise songs play once, in turn.
const STYLES: Dictionary = {
	"lofi": {"label": "Lo-fi", "loop": false,
		"tracks": ["roof_tops", "ocean_breeze", "cafe_weather", "bubbles", "evening_glow"]},
	"calm": {"label": "Calm", "loop": false, "tracks": ["up_in_the_sky", "early_morning", "autumn_sunshine"]},
	"rain": {"label": "Rain", "loop": true, "tracks": ["rain_leaves"]},
	"nature": {"label": "Nature", "loop": true, "tracks": ["waves", "forest_stream", "night_crickets"]},
	"focus": {"label": "Focus", "loop": true, "tracks": ["focus_tones"]},
}


static func ids() -> Array:
	return STYLES.keys()


static func label(id: String) -> String:
	return str(STYLES.get(id, {}).get("label", id))


## The saved choice (Settings), or the default if it is unknown.
static func current() -> String:
	var id := Settings.choice(KEY, DEFAULT)
	return id if STYLES.has(id) else DEFAULT


static func choose(id: String) -> void:
	if STYLES.has(id):
		Settings.set_choice(KEY, id)
		play()


## Starts the chosen style (screens call this on entry; it carries on if already playing).
static func play() -> void:
	var id := current()
	HalvesSfx.playlist(paths(id), loops(id), ROTATE_SECONDS)


static func paths(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for track: String in STYLES.get(id, {}).get("tracks", []):
		out.append(DIR % track)
	return out


static func loops(id: String) -> bool:
	return bool(STYLES.get(id, {}).get("loop", false))
