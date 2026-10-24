extends Screen
## Home screen over its own photo (Mount Fuji; or drawn, see Settings): coins, Records and
## Settings on top, the Halves mark, the big Play button with Levels beside it, then Daily,
## Zen and Rush (unlocked by level). Play starts the next level not yet won. Back asks before quitting.

@onready var _coins: CurrencyPill = %Coins
@onready var _title: Label = %Title
@onready var _logo: Control = %Logo
@onready var _play: Button = %PlayButton
@onready var _daily_dot: Control = %DailyDot

var _mark: HalvesLogo
var _zen: Button
var _rush: Button


func _ready() -> void:
	var next := Progress.next_level()
	ChapterBackground.install(self, ChapterBackground.MENU, true, 1.0, true)
	HalvesShapes.bold = Settings.bold_tiles()
	HalvesMusic.play()
	_title.text = ProjectSettings.get_setting("application/config/name", "Halves")
	_coins.value = Progress.coins()
	_play.text = "Play  Level %d" % next
	_play.pressed.connect(_on_play)
	%SettingsButton.pressed.connect(_on_settings)
	%LevelsButton.pressed.connect(UI.goto.bind(Screens.LEVEL_SELECT))
	%DailyButton.pressed.connect(_on_daily)
	%RanksButton.pressed.connect(UI.open.bind(load(Screens.RANKS) as PackedScene))
	_build_mark()
	_build_top_bar()
	_build_modes()
	_refresh_daily_dot()
	_intro()


func on_back() -> void:
	if await UI.confirm("Quit the game?", "Your progress is saved.", "Quit"):
		get_tree().quit()


func _on_play() -> void:
	Screens.mode = Screens.Mode.LEVELS
	Screens.level = Progress.next_level()
	UI.goto(Screens.GAME)


func _on_settings() -> void:
	await UI.open(load(Screens.SETTINGS) as PackedScene).closed
	_coins.value = Progress.coins()


func _on_daily() -> void:
	var choice: Variant = await UI.open(load(Screens.DAILY) as PackedScene).closed
	if choice == "play":
		Screens.mode = Screens.Mode.DAILY
		UI.goto(Screens.GAME)


func _on_mode(mode: Screens.Mode, unlock_level: int, name: String) -> void:
	if not _unlocked(unlock_level):
		UI.toast("%s opens after level %d" % [name, unlock_level], Icons.LOCK)
		return
	Screens.mode = mode
	UI.goto(Screens.GAME)


func _unlocked(level: int) -> bool:
	return Progress.stars(level) > 0 or Settings.dev_mode()


## The daily dot shows until today's puzzle is cleared.
func _refresh_daily_dot() -> void:
	_daily_dot.visible = not bool(HalvesRecords.daily_state().done)


## Records becomes an icon next to Settings, so the bottom keeps one row of big buttons.
func _build_top_bar() -> void:
	var bar: Container = %SettingsButton.get_parent()
	for button: Button in [%RanksButton]:
		button.reparent(bar)
		bar.move_child(button, %SettingsButton.get_index())
		button.tooltip_text = button.text
		button.text = ""
		button.theme_type_variation = &"IconButton"
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size = Vector2.ZERO


## Levels sits beside Play as a square button (the map next to the next level); Daily, Zen and
## Rush make one row of three under them, icon above the word.
func _build_modes() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	var layout := _play.get_parent()
	layout.add_child(row)
	layout.move_child(row, _play.get_index())
	_play.reparent(row)
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var levels: Button = %LevelsButton
	levels.reparent(row)
	levels.tooltip_text = levels.text
	levels.text = ""
	levels.theme_type_variation = &"IconButton"
	levels.custom_minimum_size = Vector2(_play.get_combined_minimum_size().y, 0)
	levels.size_flags_horizontal = Control.SIZE_SHRINK_END
	levels.size_flags_vertical = Control.SIZE_FILL
	var links: GridContainer = %DailyButton.get_parent()
	links.columns = 3
	%DailyButton.text = "Daily"
	_zen = _mode_button("Zen", Icons.HEART, Screens.Mode.ZEN, HalvesConfig.ZEN_UNLOCK_LEVEL)
	_rush = _mode_button("Rush", Icons.BOLT, Screens.Mode.RUSH, HalvesConfig.RUSH_UNLOCK_LEVEL)
	links.add_child(_zen)
	links.add_child(_rush)
	for button: Button in [%DailyButton, _zen, _rush]:
		links.move_child(button, -1)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size.x = 0
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER



func _mode_button(name: String, icon: Texture2D, mode: Screens.Mode, unlock_level: int) -> Button:
	var button := Button.new()
	var open := _unlocked(unlock_level)
	button.text = name
	button.icon = icon if open else Icons.LOCK
	button.pressed.connect(_on_mode.bind(mode, unlock_level, name))
	if not open:
		button.modulate = Color(1, 1, 1, 0.7)
	return button


## The mark above the title; the title block sits high so the photo has room in the middle.
func _build_mark() -> void:
	_mark = HalvesLogo.new()
	_mark.custom_minimum_size = Vector2(170, 128)
	_mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_logo.add_child(_mark)
	_logo.move_child(_mark, 0)
	(_logo.get_parent().get_node(^"TopSpace") as Control).size_flags_stretch_ratio = 0.25
	(%Logo.get_node(^"Tagline") as Label).text = "Find each crest's other half"


## The mark snaps together, the logo settles, then Play breathes gently (off with Reduce Motion).
func _intro() -> void:
	if Juice.motion_scale <= 0.0:
		return
	_mark.snap(0.8)
	_logo.modulate.a = 0.0
	_logo.pivot_offset_ratio = Vector2(0.5, 0.5)
	_logo.scale = Vector2.ONE * 0.9
	var tween := create_tween().set_parallel()
	tween.tween_property(_logo, ^"modulate:a", 1.0, 0.35)
	tween.tween_property(_logo, ^"scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play.pivot_offset_ratio = Vector2(0.5, 0.5)
	var breathe := create_tween().set_loops()
	breathe.tween_interval(1.2)
	breathe.tween_property(_play, ^"scale", Vector2.ONE * (1.0 + 0.035 * Juice.motion_scale), 0.45).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(_play, ^"scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	_play.button_down.connect(breathe.kill, CONNECT_ONE_SHOT)
