extends Screen
## Home screen: logo up top, the big Play button and quick links in the thumb zone.
## Play starts the next level not yet won. Back asks before quitting (Android convention).
## Shows the daily reward once per launch when it can be claimed.

static var _daily_shown_this_launch: bool = false

@onready var _coins: CurrencyPill = %Coins
@onready var _title: Label = %Title
@onready var _logo: Control = %Logo
@onready var _play: Button = %PlayButton
@onready var _daily_dot: Control = %DailyDot


func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name", "Mobile Game")
	_coins.value = Progress.coins()
	_play.text = "Play  Level %d" % Progress.next_level()
	_play.pressed.connect(_on_play)
	%SettingsButton.pressed.connect(_on_settings)
	%LevelsButton.pressed.connect(UI.goto.bind(Screens.LEVEL_SELECT))
	%ShopButton.pressed.connect(UI.goto.bind(Screens.SHOP))
	%DailyButton.pressed.connect(_on_daily)
	%RanksButton.pressed.connect(_on_ranks)
	_refresh_daily_dot()
	_intro()
	if not _daily_shown_this_launch and Progress.daily_status().can_claim:
		_daily_shown_this_launch = true
		_on_daily.call_deferred()


func on_back() -> void:
	if await UI.confirm("Quit the game?", "Your progress is saved.", "Quit"):
		get_tree().quit()


func _on_play() -> void:
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
	await UI.open(load(Screens.DAILY_REWARD) as PackedScene).closed
	_coins.set_value(Progress.coins())
	_refresh_daily_dot()


func _refresh_daily_dot() -> void:
	_daily_dot.visible = Progress.daily_status().can_claim


## Logo drops in, then the Play button breathes gently to draw the eye (off with Reduce Motion).
func _intro() -> void:
	if Juice.motion_scale <= 0.0:
		return
	_logo.modulate.a = 0.0
	_logo.pivot_offset_ratio = Vector2(0.5, 0.5)
	_logo.scale = Vector2.ONE * 0.85
	var tween := create_tween().set_parallel()
	tween.tween_property(_logo, ^"modulate:a", 1.0, 0.35)
	tween.tween_property(_logo, ^"scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play.pivot_offset_ratio = Vector2(0.5, 0.5)
	var breathe := create_tween().set_loops()
	breathe.tween_interval(1.2)
	breathe.tween_property(_play, ^"scale", Vector2.ONE * (1.0 + 0.035 * Juice.motion_scale), 0.45).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(_play, ^"scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	_play.button_down.connect(breathe.kill, CONNECT_ONE_SHOT)
