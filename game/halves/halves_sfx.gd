class_name HalvesSfx
extends RefCounted
## Halves' way to the Sound autoload: looks it up at run time, so the board and game code still
## compile in tool scripts and tests where autoloads don't exist (they just stay silent there).
## Also hands playlists to it (HalvesMusic picks the one the player chose).


static func play(id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var sound := _sound()
	if sound != null:
		sound.call(&"play", id, pitch, volume_db)


## The combo ladder climbs a pentatonic scale (calmer than semitones): step k plays this many
## semitones up; the ladder stops at its top note.
const PENTATONIC: Array[int] = [0, 2, 4, 7, 9, 12, 14]


## Effect `id` raised to ladder step `step` (0 = its own pitch).
static func step(id: StringName, step_index: int, volume_db: float = 0.0) -> void:
	var sound := _sound()
	if sound != null:
		sound.call(&"play_step", id, PENTATONIC[clampi(step_index, 0, PENTATONIC.size() - 1)], volume_db)


## A snap's soft bell at its crest family's note (each family owns a note of the pentatonic
## scale, so a board of mixed families plays a little melody).
static func chime(face: int) -> void:
	var family := HalvesFace.family(face)
	var index := 0
	for i in HalvesCrests.FAMILIES.size():
		if HalvesCrests.FAMILIES[i].id == family:
			index = i + 1
	var semitones: int = 12 * (index / 5) + ([0, 2, 4, 7, 9][index % 5] as int) - 12
	play(&"chime", pow(2.0, semitones / 12.0), -12.0)


## Plays `paths` in turn (or each looping, rotating every `rotate_seconds`); keeps playing, with no
## restart, if that playlist already is. HalvesMusic.play() picks the player's chosen style.
static func playlist(paths: PackedStringArray, loops: bool, rotate_seconds: float) -> void:
	var sound := _sound()
	if sound != null:
		sound.call(&"play_playlist", paths, loops, rotate_seconds)


static func duck(seconds: float = 1.4) -> void:
	var sound := _sound()
	if sound != null:
		sound.call(&"duck", seconds)


static func _sound() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Sound")
