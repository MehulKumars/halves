extends Modal
## Pause menu: resume, restart, settings, main menu, and quick music/sound/vibration toggles.
## Opened by the game screen's pause button and by Back; pauses the game while open.
## Closes with "resume", "restart", "rules" (How to play) or "home"; the game screen acts on it.


func _ready() -> void:
	super._ready()
	_bind_volume_toggle(%MusicToggle, Settings.MUSIC_BUS)
	_bind_volume_toggle(%SoundToggle, Settings.SFX_BUS)
	%HapticsToggle.button_pressed = Settings.haptics()
	%HapticsToggle.toggled.connect(Settings.set_haptics)
	%ResumeButton.pressed.connect(close.bind("resume"))
	%RestartButton.pressed.connect(close.bind("restart"))
	%HomeButton.pressed.connect(close.bind("home"))
	%SettingsButton.pressed.connect(func() -> void: UI.open(load(Screens.SETTINGS) as PackedScene))
	var rules := Button.new()
	rules.text = "How to play"
	rules.icon = Icons.HINT
	rules.pressed.connect(close.bind("rules"))
	%SettingsButton.get_parent().add_child(rules)
	%SettingsButton.get_parent().move_child(rules, %SettingsButton.get_index())


## Icon toggle that mutes or restores a bus (full volume when turned back on).
func _bind_volume_toggle(toggle: Button, bus: StringName) -> void:
	toggle.button_pressed = Settings.volume(bus) > 0.0
	toggle.toggled.connect(func(on: bool) -> void: Settings.set_volume(bus, 1.0 if on else 0.0))
