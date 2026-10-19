extends Node
## Autoload Sound: named one-shot effects from a pool of players (pitch variation, semitone steps
## for combos), a click on every button press, and looping music handed to ProjectMusicController
## so it crossfades between tracks and keeps playing across scenes. Volumes are the Settings buses.

const SFX_PATH: String = "res://assets/audio/sfx/%s.wav"
const POOL_SIZE: int = 12
const MUSIC_FADE: float = 1.2
## Sounds that carry a meaning players learn (confirm tones, the combo ladder) keep their pitch.
const STEADY: Array[StringName] = [&"star", &"best", &"swift", &"chapter", &"tick", &"click"]

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _streams: Dictionary[StringName, AudioStream] = {}
var _music_path: String = ""
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)


func _ready() -> void:
	_rng.randomize()
	get_tree().node_added.connect(_on_node_added)
	var music := _music_controller()
	if music != null:
		music.set(&"fade_in_duration", MUSIC_FADE)
		music.set(&"fade_out_duration", MUSIC_FADE)


## Plays effect `id` (a file in assets/audio/sfx/). `pitch` multiplies the natural pitch.
func play(id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream := _stream(id)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch if STEADY.has(id) else pitch * _rng.randf_range(0.96, 1.04)
	player.play()


## The same effect `semitones` higher (combo chains climb one step per snap).
func play_step(id: StringName, semitones: int, volume_db: float = 0.0) -> void:
	var stream := _stream(id)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pow(2.0, semitones / 12.0)
	player.play()


## Loops the Ogg at `path`, crossfading from whatever plays now. Same path: keeps playing.
func play_music(path: String) -> void:
	if path == _music_path or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamOggVorbis
	var music := _music_controller()
	if stream == null or music == null:
		return
	stream.loop = true
	_music_path = path
	music.call(&"play_stream", stream)


func stop_music() -> void:
	var music := _music_controller()
	_music_path = ""
	if music != null:
		music.call(&"fade_out", MUSIC_FADE)


## Lowers the music for a moment so a fanfare reads clearly, then brings it back.
func duck(seconds: float = 1.4, depth_db: float = -8.0) -> void:
	var music := _music_controller()
	if music == null:
		return
	music.call(&"blend_to", depth_db, 0.15)
	await get_tree().create_timer(seconds).timeout
	music.call(&"blend_to", 0.0, 0.8)


## At quit the music controller would clone its player while the tree is torn down (an engine
## error). Sound leaves the tree first, so it lets go of the player for it.
func _exit_tree() -> void:
	var music := _music_controller()
	if music != null:
		music.set(&"music_stream_player", null)


func _stream(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := SFX_PATH % id
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[id] = stream
	return stream


func _music_controller() -> Node:
	return get_node_or_null(^"/root/ProjectMusicController")


## A soft click on every button press; buttons opt out with the meta `ui_sound = false`.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_pressed(button: BaseButton) -> void:
	if is_instance_valid(button) and button.get_meta(&"ui_sound", true):
		play(&"click", 1.0, -2.0)
