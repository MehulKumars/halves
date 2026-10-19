extends Screen
## Home screen over the current chapter's print: the Halves mark, the big Play button, then the
## modes (Daily Puzzle, Zen, Rush, unlocked by level) and links (Levels, Ranks, Shop).
## Play starts the next level not yet won. Back asks before quitting (Android convention).

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
	var chapter := HalvesChapters.index_for_level(next)
	ChapterBackground.install(self, chapter)
	HalvesSfx.menu_music()
	_title.text = ProjectSettings.get_setting("application/config/name", "Halves")
	_coins.value = Progress.coins()
	_play.text = "Play  Level %d" % next
	_play.pressed.connect(_on_play)
	%SettingsButton.pressed.connect(_on_settings)
	%LevelsButton.pressed.connect(UI.goto.bind(Screens.LEVEL_SELECT))
	%ShopButton.pressed.connect(UI.goto.bind(Screens.SHOP))
	%DailyButton.pressed.connect(_on_daily)
	%RanksButton.pressed.connect(_on_ranks)
	_build_mark(chapter)
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


## Google Play Games shows its own leaderboard screen; until it is connected, show ours.
func _on_ranks() -> void:
	if Services.leaderboard.has_native_ui():
		Services.leaderboard.show_board("stars")
	else:
		UI.open(load(Screens.RANKS) as PackedScene)


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
	return Progress.stars(level) > 0


## The daily dot shows until today's puzzle is cleared.
func _refresh_daily_dot() -> void:
	_daily_dot.visible = not bool(HalvesRecords.daily_state().done)


## Daily, Zen and Rush on the first row of a 3-column grid; Levels, Ranks and Shop under them.
func _build_modes() -> void:
	var links: GridContainer = %LevelsButton.get_parent()
	links.columns = 3
	%DailyButton.text = "Daily"
	_zen = _mode_button("Zen", Icons.HEART, Screens.Mode.ZEN, HalvesConfig.ZEN_UNLOCK_LEVEL)
	_rush = _mode_button("Rush", Icons.BOLT, Screens.Mode.RUSH, HalvesConfig.RUSH_UNLOCK_LEVEL)
	links.add_child(_zen)
	links.add_child(_rush)
	for button: Button in [%DailyButton, _zen, _rush, %LevelsButton, %RanksButton, %ShopButton]:
		links.move_child(button, -1)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Three to a row must fit 720 px: let the label shrink rather than push the screen wider.
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size.x = 0
		# Icon above the label: three buttons a row fit 720 px without cutting words.
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


## The mark above the title, and the chapter under the tagline.
func _build_mark(chapter: int) -> void:
	_mark = HalvesLogo.new()
	_mark.custom_minimum_size = Vector2(200, 150)
	_mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_logo.add_child(_mark)
	_logo.move_child(_mark, 0)
	var info := HalvesChapters.get_chapter(chapter)
	var place := Label.new()
	place.theme_type_variation = &"CaptionLabel"
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place.add_theme_color_override(&"font_color", info.accent)
	place.text = "%s · %s" % [info.name, info.place]
	_logo.add_child(place)


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
