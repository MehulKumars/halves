extends Modal
## Settings: music and sound volume, vibration, reduce motion, the game clock, links and version.
## The style picker shows in debug builds so you can compare the five styles on a phone;
## turn on `show_style_picker` to let players choose. Values are saved through Settings.

## Replace with your game's privacy policy page before publishing (Google Play requires one).
const PRIVACY_URL: String = "https://example.com/privacy"

@export var show_style_picker: bool = false


func _ready() -> void:
	super._ready()
	_bind_slider(%MusicSlider, Settings.MUSIC_BUS)
	_bind_slider(%SoundSlider, Settings.SFX_BUS)
	%HapticsToggle.button_pressed = Settings.haptics()
	%HapticsToggle.toggled.connect(Settings.set_haptics)
	%MotionToggle.button_pressed = Settings.reduce_motion()
	%MotionToggle.toggled.connect(Settings.set_reduce_motion)
	_add_timer_row()
	%CloseButton.pressed.connect(close)
	%CreditsButton.pressed.connect(UI.goto.bind(Screens.CREDITS))
	%PrivacyButton.pressed.connect(OS.shell_open.bind(PRIVACY_URL))
	%RestoreButton.pressed.connect(_on_restore)
	%ResetButton.pressed.connect(_on_reset)
	%GalleryButton.pressed.connect(UI.goto.bind(Screens.GALLERY))
	%Version.text = "Version %s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	for icon: TextureRect in [%MusicIcon, %SoundIcon, %HapticsIcon, %MotionIcon]:
		icon.modulate = get_theme_color(&"text_muted", &"Tokens")
	%StyleSection.visible = show_style_picker or OS.is_debug_build()
	if %StyleSection.visible:
		_build_style_chips()
	refit()


## "Show timer": the game clock in the HUD (built like the Reduce Motion row under it).
func _add_timer_row() -> void:
	var model: HBoxContainer = %MotionToggle.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", model.get_theme_constant(&"separation"))
	var icon := TextureRect.new()
	icon.texture = Icons.TIMER
	icon.custom_minimum_size = %MotionIcon.custom_minimum_size
	icon.expand_mode = %MotionIcon.expand_mode
	icon.stretch_mode = %MotionIcon.stretch_mode
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = get_theme_color(&"text_muted", &"Tokens")
	row.add_child(icon)
	var label := Label.new()
	label.text = "Show timer"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var toggle := CheckButton.new()
	toggle.button_pressed = Settings.show_timer()
	toggle.toggled.connect(Settings.set_show_timer)
	row.add_child(toggle)
	model.get_parent().add_child(row)
	model.get_parent().move_child(row, model.get_index() + 1)


func _bind_slider(slider: HSlider, bus: StringName) -> void:
	slider.value = Settings.volume(bus)
	slider.value_changed.connect(func(value: float) -> void: Settings.set_volume(bus, value))


func _build_style_chips() -> void:
	var group := ButtonGroup.new()
	for id in UI.list_styles():
		var style := load("res://core/ui/styles/%s.tres" % id) as UIStyle
		var chip := Button.new()
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.button_group = group
		chip.text = style.display_name if style != null else String(id)
		chip.button_pressed = id == UI.current_style
		chip.pressed.connect(_on_style_chosen.bind(id))
		%StyleChips.add_child(chip)


func _on_style_chosen(id: StringName) -> void:
	if id == UI.current_style:
		return
	UI.apply_style(id)
	# Rebuild the screen underneath and this popup so everything picks up the new style.
	close()
	get_tree().reload_current_scene()


func _on_restore() -> void:
	# Real stores re-deliver past purchases here; the mock IAP keeps them in memory only.
	UI.toast("Purchases restored", Icons.CHECK_CIRCLE)


func _on_reset() -> void:
	if await UI.confirm("Reset progress?", "Stars, coins and the daily streak on this phone are deleted.", "Reset", true):
		Progress.reset()
		UI.goto(Screens.MAIN_MENU)
