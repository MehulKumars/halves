extends Modal
## Settings in three groups: Sound (volumes and the music style: lo-fi, calm, rain, nature, focus),
## Look and feel (photo or drawn backgrounds, vibration, reduce motion, the clock) and More (links,
## version). Debug builds add Developer: dev mode (every level open, Skip in play), FPS, styles.

## Replace with your game's privacy policy page before publishing (Google Play requires one).
const PRIVACY_URL: String = "https://example.com/privacy"
## Space before a row's text (its 48 px icon and the row gap), for captions under a row.
const INDENT: int = 68

@export var show_style_picker: bool = false

var _dev_extras: Array[Control] = []


func _ready() -> void:
	super._ready()
	_bind_slider(%MusicSlider, Settings.MUSIC_BUS)
	_bind_slider(%SoundSlider, Settings.SFX_BUS)
	%HapticsToggle.button_pressed = Settings.haptics()
	%HapticsToggle.toggled.connect(Settings.set_haptics)
	%MotionToggle.button_pressed = Settings.reduce_motion()
	%MotionToggle.toggled.connect(Settings.set_reduce_motion)
	%CloseButton.pressed.connect(close)
	%CreditsButton.pressed.connect(UI.goto.bind(Screens.CREDITS))
	%PrivacyButton.pressed.connect(OS.shell_open.bind(PRIVACY_URL))
	%ResetButton.pressed.connect(_on_reset)
	%GalleryButton.pressed.connect(UI.goto.bind(Screens.GALLERY))
	%Version.text = "Version %s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	for icon: TextureRect in [%MusicIcon, %SoundIcon, %HapticsIcon, %MotionIcon]:
		icon.modulate = get_theme_color(&"text_muted", &"Tokens")
	_organize()
	refit()


## Puts the rows in their groups, adding the music and background choices, captions and the
## developer switches.
func _organize() -> void:
	var music_row: Control = %MusicSlider.get_parent()
	var rows: VBoxContainer = music_row.get_parent()
	var order: Array[Control] = [
		_section("Sound"), music_row,
		_chips(_music_options(), HalvesMusic.current(), HalvesMusic.choose, true),
		%SoundSlider.get_parent() as Control,
		_section("Look and feel"),
		_row(Icons.PALETTE, "Backgrounds", null),
		_chips([["photo", "Photos"], ["drawn", "Drawn"]], ChapterBackground.style(), ChapterBackground.set_style, true),
		%HapticsToggle.get_parent() as Control, %MotionToggle.get_parent() as Control,
		_caption("Fewer animations and no falling petals, for comfort or to save battery."),
		_row(Icons.TIMER, "Show timer", _toggle(Settings.show_timer(), Settings.set_show_timer)),
		rows.get_node(^"Separator") as Control, _section("More"), %CreditsButton.get_parent() as Control,
	]
	if OS.is_debug_build():
		var dev := _toggle(Settings.dev_mode(), _on_dev_mode)
		order.append_array([_section("Developer (test builds only)"), _row(Icons.ARROW_FORWARD, "Dev mode", dev),
			_caption("Every level open and a Skip button in play. Always off in release builds.")])
		var dev_tools := get_node_or_null(^"/root/DevTools")
		if dev_tools != null:
			var fps := _row(Icons.INFO, "Show FPS", _toggle(bool(dev_tools.call(&"fps_visible")),
				func(on: bool) -> void: dev_tools.call(&"set_fps_visible", on)))
			order.append(fps)
			_dev_extras.append(fps)
		order.append(%StyleSection as Control)
		_dev_extras.append(%StyleSection as Control)
		%StyleChips.get_parent().get_node(^"StyleLabel").text = "Style (developer)"
		_build_style_chips()
	else:
		%StyleSection.visible = show_style_picker
		if show_style_picker:
			_build_style_chips()
	order.append(%Version as Control)
	for i in order.size():
		if order[i].get_parent() == null:
			rows.add_child(order[i])
		rows.move_child(order[i], i)
	_show_dev_extras(Settings.dev_mode() or show_style_picker)


func _music_options() -> Array:
	var options: Array = []
	for id: String in HalvesMusic.ids():
		options.append([id, HalvesMusic.label(id)])
	return options


func _section(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.text = text.to_upper()
	label.add_theme_color_override(&"font_color", get_theme_color(&"text_muted", &"Tokens"))
	return label


## A row like the scene's own: muted icon, label, then `control` (a switch) at the end.
func _row(icon_texture: Texture2D, text: String, control: Control) -> HBoxContainer:
	var model: HBoxContainer = %MotionToggle.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", model.get_theme_constant(&"separation"))
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = %MotionIcon.custom_minimum_size
	icon.expand_mode = %MotionIcon.expand_mode
	icon.stretch_mode = %MotionIcon.stretch_mode
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = get_theme_color(&"text_muted", &"Tokens")
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if control != null:
		row.add_child(control)
	return row


func _toggle(on: bool, changed: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.button_pressed = on
	toggle.toggled.connect(changed)
	return toggle


func _caption(text: String) -> Control:
	var box := MarginContainer.new()
	box.add_theme_constant_override(&"margin_left", INDENT)
	var label := Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	box.add_child(label)
	return box


## One choice of several as chips under a row (`options` = [[id, label], ...]).
func _chips(options: Array, current: String, picked: Callable, indent: bool) -> Control:
	var box := MarginContainer.new()
	box.add_theme_constant_override(&"margin_left", INDENT if indent else 0)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 12)
	flow.add_theme_constant_override(&"v_separation", 12)
	box.add_child(flow)
	var group := ButtonGroup.new()
	for option: Array in options:
		var chip := Button.new()
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.button_group = group
		chip.text = str(option[1])
		chip.button_pressed = str(option[0]) == current
		chip.pressed.connect(picked.bind(str(option[0])))
		flow.add_child(chip)
	return box


func _on_dev_mode(on: bool) -> void:
	Settings.set_dev_mode(on)
	_show_dev_extras(on)
	refit()


func _show_dev_extras(on: bool) -> void:
	for extra in _dev_extras:
		extra.visible = on


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


func _on_reset() -> void:
	if await UI.confirm("Reset progress?", "Stars, coins and the daily streak on this phone are deleted.", "Reset", true):
		Progress.reset()
		UI.goto(Screens.MAIN_MENU)
