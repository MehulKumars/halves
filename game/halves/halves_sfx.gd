class_name HalvesSfx
extends RefCounted
## Halves' way to the Sound autoload: looks it up at run time, so the board and game code still
## compile in tool scripts and tests where autoloads don't exist (they just stay silent there).
## Also picks the music for a chapter or the menus.

const MENU_MUSIC: String = "res://assets/audio/music/menu.ogg"


static func play(id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var sound := _sound()
	if sound != null:
		sound.call(&"play", id, pitch, volume_db)


## Effect `id` raised by `semitones` (the combo ladder).
static func step(id: StringName, semitones: int, volume_db: float = 0.0) -> void:
	var sound := _sound()
	if sound != null:
		sound.call(&"play_step", id, semitones, volume_db)


static func chapter_music(chapter: int) -> void:
	_music(HalvesChapters.music_path(chapter))


static func menu_music() -> void:
	_music(MENU_MUSIC)


static func duck(seconds: float = 1.4) -> void:
	var sound := _sound()
	if sound != null:
		sound.call(&"duck", seconds)


static func _music(path: String) -> void:
	var sound := _sound()
	if sound != null:
		sound.call(&"play_music", path)


static func _sound() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Sound")
