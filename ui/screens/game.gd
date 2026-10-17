extends Screen
## Game screen: one Halves level (board, HUD stars, boosters, stuck card) inside the template's
## level flow: results popup -> next / retry / home; Back opens the pause menu. Boosters are free
## once per level, then cost coins or a rewarded video. Interstitials only at results, via AdPolicy.

const BOOSTERS: Array[String] = ["hint", "undo", "shuffle"]
const SHUFFLE_ICON: Texture2D = preload("res://game/halves/icons/shuffle.svg")

## Shared across levels so ad pacing (first session free, gaps, caps) works for the whole run.
static var ad_policy := AdPolicy.new()
static var _ad_session_started: bool = false

var _level: int = 1
var _data: HalvesLevelData
var _state: HalvesState
var _finished: bool = false
var _free_left: Dictionary[String, int] = {}
var _badges: Dictionary[String, Label] = {}

@onready var _board: HalvesBoardView = %HalvesBoard
@onready var _stars: StarRating = %Stars


func _ready() -> void:
	_start_ad_session()
	_level = clampi(Screens.level, 1, HalvesLevels.COUNT)
	%LevelLabel.text = "LEVEL %d" % _level
	%LevelLabel.add_theme_color_override(&"font_color", get_theme_color(&"gold", &"Tokens"))
	%PauseButton.pressed.connect(_pause)
	%StuckButton.pressed.connect(_on_stuck_shuffle)
	for kind in BOOSTERS:
		_free_left[kind] = HalvesConfig.FREE_USES
		_badges[kind] = _add_badge(_booster_button(kind))
		_booster_button(kind).pressed.connect(_use_booster.bind(kind))
	Events.debug_command.connect(_on_debug_command)
	_data = HalvesLevels.get_level(_level)
	if _data == null:
		push_error("Halves: level %d is missing from %s" % [_level, HalvesLevels.PATH])
		return
	_state = _data.new_state()
	_state.strict = HalvesConfig.STRICT_MISTAKES
	_state.free_mistakes = 1 if _level <= HalvesConfig.TUTORIAL_FORGIVE_LEVELS else 0
	_board.show_mates = _level <= HalvesConfig.MATE_PULSE_LEVELS
	_board.setup(_data, _state)
	_board.changed.connect(_refresh_hud)
	_board.mistake_made.connect(_on_mistake)
	_board.stuck.connect(_on_stuck)
	_board.cleared.connect(_on_cleared)
	_refresh_hud()
	if _level == 1:
		_board.show_first_move()
	Events.level_started.emit(str(_level))
	_log_level_start()


func on_back() -> void:
	_pause()


## Ends the level and shows the results popup.
func finish(won: bool, stars: int) -> void:
	if _finished:
		return
	_finished = true
	ad_policy.record_level_result(won)
	var coins := stars * HalvesConfig.COINS_PER_STAR if won else 0
	if won:
		if Progress.levels_won() == 0:
			Services.analytics.log_event("first_win", {"level": _level})
		Progress.record_win(_level, stars)
		Progress.add_coins(coins)
		Services.leaderboard.submit_score("stars", Progress.total_stars())
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
			if _level >= HalvesLevels.COUNT:
				UI.goto(Screens.LEVEL_SELECT)
				UI.toast("All %d levels done. More are on the way!" % HalvesLevels.COUNT, Icons.STAR)
			else:
				Screens.level = _level + 1
				UI.goto(Screens.GAME)
		"retry":
			UI.goto(Screens.GAME)
		"home":
			UI.goto(Screens.MAIN_MENU)
		"continue":
			_finished = false


func _pause() -> void:
	if _finished or UI.has_modal():
		return
	var choice: Variant = await UI.open(load(Screens.PAUSE) as PackedScene).closed
	match choice:
		"restart":
			UI.goto(Screens.GAME)
		"home":
			UI.goto(Screens.MAIN_MENU)


func _use_booster(kind: String) -> void:
	if _finished or _state == null or _board.is_busy() or UI.has_modal():
		return
	var hint := Vector2i(-1, -1)
	match kind:
		"hint":
			hint = HalvesSolver.hint(_state)
			if hint.x < 0:
				if _state.is_stuck():
					_on_stuck()
				else:
					UI.toast("No safe pair left: try a shuffle", SHUFFLE_ICON)
				return
		"undo":
			if _state.history.is_empty():
				UI.toast("Nothing to undo yet", Icons.UNDO)
				return
	if not await _pay_for(kind) or _finished:
		return
	match kind:
		"hint":
			_board.show_hint(hint)
		"undo":
			_board.undo()
		"shuffle":
			%StuckCenter.hide()
			_board.shuffle()
	Juice.pop(_booster_button(kind), 1.1, 0.16)
	_refresh_hud()


## The level's free use first, then coins or a rewarded video (the player's choice).
func _pay_for(kind: String) -> bool:
	if _free_left[kind] > 0:
		_free_left[kind] -= 1
		return true
	var popup := UI.open(load(Screens.BOOSTER) as PackedScene)
	popup.call(&"setup", kind, _booster_title(kind), _booster_icon(kind), _booster_price(kind), Progress.coins())
	var choice: Variant = await popup.closed
	match choice:
		"coins":
			return Progress.spend_coins(_booster_price(kind))
		"video":
			ad_policy.record_rewarded_shown(_now())
			return true
	return false


func _on_mistake(forgiven: bool) -> void:
	if not forgiven:
		_stars.pivot_offset_ratio = Vector2(0.5, 0.5)
		Juice.pop(_stars, 1.12, 0.2)


func _on_stuck() -> void:
	if _finished:
		return
	%StuckCenter.show()
	var card: Control = %StuckCenter.get_child(0)
	card.pivot_offset_ratio = Vector2(0.5, 0.5)
	Juice.pop(card, 1.06, 0.2)


func _on_stuck_shuffle() -> void:
	%StuckCenter.hide()
	_board.shuffle()


## The board is clear: a short pause on the empty board, then the results.
func _on_cleared() -> void:
	_stars.pivot_offset_ratio = Vector2(0.5, 0.5)
	Juice.pop(_stars, 1.2, 0.3)
	await get_tree().create_timer(0.6, false).timeout
	if is_inside_tree():
		finish(true, _state.stars())


func _refresh_hud() -> void:
	if _state == null:
		return
	_stars.stars = _state.stars()
	%UndoButton.disabled = _state.history.is_empty()
	for kind in BOOSTERS:
		var free := _free_left[kind]
		_badges[kind].text = str(free) if free > 0 else str(_booster_price(kind))


func _on_debug_command(command: StringName, _args: Array) -> void:
	if command == &"skip_level" and _state != null:
		finish(true, _state.stars())


func _booster_button(kind: String) -> Button:
	match kind:
		"hint":
			return %HintButton
		"undo":
			return %UndoButton
	return %ShuffleButton


func _booster_title(kind: String) -> String:
	return {"hint": "One more hint", "undo": "One more undo", "shuffle": "One more shuffle"}[kind]


func _booster_icon(kind: String) -> Texture2D:
	return {"hint": Icons.HINT, "undo": Icons.UNDO, "shuffle": SHUFFLE_ICON}[kind]


func _booster_price(kind: String) -> int:
	return {"hint": HalvesConfig.PRICE_HINT, "undo": HalvesConfig.PRICE_UNDO, "shuffle": HalvesConfig.PRICE_SHUFFLE}[kind]


## A small count in the button's top-right corner: free uses left, else the coin price.
func _add_badge(button: Button) -> Label:
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"BadgePanel"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.theme_type_variation = &"BadgeLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	button.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.position += Vector2(10, -10)
	return label


func _start_ad_session() -> void:
	if _ad_session_started:
		return
	_ad_session_started = true
	ad_policy.start_session(maxi(1, Progress.session_index()))


func _log_level_start() -> void:
	if _level == 1 and Progress.levels_won() == 0:
		Services.analytics.log_event("tutorial_step_1", {})
	if _level == 3:
		Services.analytics.log_event("level_3_start", {})


func _maybe_show_interstitial(won: bool) -> void:
	if Progress.owns("remove_ads"):
		return
	var now := _now()
	if ad_policy.can_show_interstitial(_level, won, now) and Services.ads.is_interstitial_ready("results"):
		Services.ads.show_interstitial("results")
		ad_policy.record_interstitial_shown(now)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
