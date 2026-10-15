extends Screen
## Game screen: a real HUD (pause, level, coins, goal bar, boosters) around a placeholder board.
## Replace %Board's content with your game and call finish(won, stars) when a level ends; keep
## the flow: results popup -> next / retry / home. Back opens the pause menu.
## Interstitials are only considered when the results popup opens, and only if AdPolicy agrees.

const COINS_PER_STAR: int = 10
const START_MOVES: int = 12

## Shared across levels so ad pacing (first session free, gaps, caps) works for the whole run.
static var ad_policy := AdPolicy.new()

var _level: int = 1
var _moves: int = START_MOVES
var _finished: bool = false


func _ready() -> void:
	_level = Screens.level
	%LevelLabel.text = "Level %d" % _level
	%Coins.value = Progress.coins()
	%GoalIcon.modulate = get_theme_color(&"gold", &"Tokens")
	%BoardIcon.modulate = Color(get_theme_color(&"text_muted", &"Tokens"), 0.45)
	%PauseButton.pressed.connect(_pause)
	%Win3Button.pressed.connect(finish.bind(true, 3))
	%Win1Button.pressed.connect(finish.bind(true, 1))
	%LoseButton.pressed.connect(finish.bind(false, 0))
	%MoveButton.pressed.connect(_use_move)
	%HintButton.pressed.connect(UI.toast.bind("Hints go here", Icons.HINT))
	%UndoButton.pressed.connect(UI.toast.bind("Undo goes here", Icons.UNDO))
	%ShuffleButton.pressed.connect(UI.toast.bind("Shuffle goes here", Icons.RESTART))
	_update_goal()
	Events.level_started.emit(str(_level))


func on_back() -> void:
	_pause()


## Ends the level and shows the results popup.
func finish(won: bool, stars: int) -> void:
	if _finished:
		return
	_finished = true
	ad_policy.record_level_result(won)
	var coins := stars * COINS_PER_STAR if won else 0
	if won:
		Progress.record_win(_level, stars)
		Progress.add_coins(coins)
		Services.leaderboard.submit_score("stars", Progress.total_stars())
		# Instant: the results popup pauses the game, which would freeze a count-up here.
		%Coins.value = Progress.coins()
	Events.level_finished.emit(str(_level), won, stars)
	var popup := UI.open(load(Screens.RESULTS) as PackedScene)
	if won:
		popup.call(&"show_win", _level, stars, coins)
	else:
		popup.call(&"show_lose", _level)
	Events.results_shown.emit(str(_level), won)
	_maybe_show_interstitial(won)
	var choice: Variant = await popup.closed
	match choice:
		"next":
			Screens.level = mini(_level + 1, Progress.LEVEL_COUNT_DEFAULT)
			UI.goto(Screens.GAME)
		"retry":
			UI.goto(Screens.GAME)
		"home":
			UI.goto(Screens.MAIN_MENU)
		"continue":
			_finished = false
			_moves += 5
			_update_goal()


func _pause() -> void:
	if _finished or UI.has_modal():
		return
	var choice: Variant = await UI.open(load(Screens.PAUSE) as PackedScene).closed
	match choice:
		"restart":
			UI.goto(Screens.GAME)
		"home":
			UI.goto(Screens.MAIN_MENU)


func _use_move() -> void:
	_moves -= 1
	_update_goal()
	Juice.pop(%MoveButton, 1.06, 0.15)
	if _moves <= 0:
		finish(false, 0)


func _update_goal() -> void:
	%MovesLabel.text = "%d moves" % _moves
	var bar: ProgressBar = %Goal
	bar.max_value = maxi(START_MOVES, _moves)
	var tween := create_tween()
	tween.tween_property(bar, ^"value", float(_moves), 0.25 * Juice.motion_scale)


func _maybe_show_interstitial(won: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if ad_policy.can_show_interstitial(_level, won, now) and Services.ads.is_interstitial_ready("results"):
		Services.ads.show_interstitial("results")
		ad_policy.record_interstitial_shown(now)
