extends Screen
## Game screen: one Halves board in a mode (levels, daily, zen, rush) over its chapter print, with
## the HUD (title, clock, progress, stars), boosters, stuck card, tip cards and the end flow
## (results, chapter reveal). Zen and rush deal board after board in place; ads only at results.

const BOOSTERS: Array[String] = ["hint", "undo", "shuffle"]
const SHUFFLE_ICON: Texture2D = preload("res://game/halves/icons/shuffle.svg")
## Explain a blocked tap this many times per reason (locks and frost always explain the first time).
const BLOCK_HELP_LEVELS: int = 6
## How bright the place behind the board is (the tiles must stand out on any photo).
const BACKGROUND_DIM: float = 0.8

## Shared across levels so ad pacing (first session free, gaps, caps) works for the whole run.
static var ad_policy := AdPolicy.new()
static var _ad_session_started: bool = false
## Where zen is in its seeded pool order (kept between visits in one app session).
static var _zen_position: int = 0

var _mode: Screens.Mode = Screens.Mode.LEVELS
var _level: int = 1
var _data: HalvesLevelData
var _state: HalvesState
var _run: HalvesRun
var _chapter: int = 0
var _background: ChapterBackground
var _finished: bool = false
var _free_left: Dictionary[String, int] = {}
var _badges: Dictionary[String, Label] = {}
var _boosters_used: int = 0
var _combo_coins: int = 0
var _daily_date: String = ""
var _order: PackedInt32Array = PackedInt32Array()
var _rush_position: int = 0
var _rush_left_ms: int = 0
var _rush_score: int = 0
var _rush_boards: int = 0
var _shown_second: int = -1
var _explained: Dictionary[int, bool] = {}

var _caption: Label
var _clock: Label
var _progress: ProgressBar
var _stuck_undo: Button
## (v3) Mend: a booster-bar button shown while the board has mends, and its twin on the stuck card.
var _stuck_mend: Button
var _mend_button: Button
var _mend_badge: Label

@onready var _board: HalvesBoardView = %HalvesBoard
@onready var _stars: StarRating = %Stars


func _ready() -> void:
	_start_ad_session()
	_mode = Screens.mode
	_build_hud()
	%PauseButton.pressed.connect(_pause)
	%StuckButton.pressed.connect(_on_stuck_shuffle)
	for kind in BOOSTERS:
		_badges[kind] = _add_badge(_booster_button(kind))
		_booster_button(kind).pressed.connect(_use_booster.bind(kind))
		_booster_button(kind).set_meta(&"ui_sound", false)
	Events.debug_command.connect(_on_debug_command)
	_add_dev_skip()
	_board.changed.connect(_refresh_hud)
	_board.mistake_made.connect(_on_mistake)
	_board.mismatched.connect(_on_mismatched)
	_board.matched.connect(_on_matched)
	_board.combo.connect(_on_combo)
	_board.first_tap.connect(_on_first_tap)
	_board.blocked_tap.connect(_on_blocked_tap)
	_board.shuffled.connect(_on_shuffled)
	_board.stuck.connect(_on_stuck)
	_board.cleared.connect(_on_cleared)
	_board.show_mat = true
	HalvesShapes.bold = Settings.bold_tiles()
	Events.setting_changed.connect(_on_setting_changed)
	_apply_hand()
	_board.mended.connect(_on_mended)
	_board.mend_earned.connect(_on_mend_earned)
	var data := _first_board()
	if data == null:
		push_error("Halves: no board for mode %d (level %d)" % [_mode, _level])
		return
	var half := HalvesChapters.half_for_level(_level) if _mode == Screens.Mode.LEVELS else 0
	_background = ChapterBackground.install(self, _chapter, true, BACKGROUND_DIM, false, true, half)
	HalvesMusic.play()
	if _mode == Screens.Mode.LEVELS:
		# The next level may show the place's other photo or the next place's (every 10 levels).
		var next := _level + 1
		ChapterBackground.preload_chapter(HalvesChapters.index_for_level(next), true, HalvesChapters.half_for_level(next))
	_start_board(data)
	Events.level_started.emit(_board_id())
	_log_level_start()


func on_back() -> void:
	_pause()


func _process(delta: float) -> void:
	if _run == null or _finished or not _run.started or UI.has_modal():
		return
	var ms := roundi(delta * 1000.0)
	_run.advance(ms)
	if _mode == Screens.Mode.RUSH:
		_rush_left_ms -= mini(ms, HalvesRun.MAX_STEP_MS)
		if _rush_left_ms <= 0:
			_rush_left_ms = 0
			_finish_rush()
	_update_clock()


## Ends a levels or daily board and shows the results popup.
func finish(won: bool, stars: int) -> void:
	if _finished:
		return
	_finished = true
	_run.finish()
	ad_policy.record_level_result(won)
	var details := _record_clear(stars)
	var coins := int(details.coins)
	Events.level_finished.emit(_board_id(), won, stars)
	var popup := UI.open(load(Screens.RESULTS) as PackedScene)
	popup.call(&"show_win", _level, stars, coins, details)
	Events.results_shown.emit(_board_id(), won)
	_maybe_show_interstitial(won)
	var choice: Variant = await popup.closed
	match choice:
		"next":
			await _go_next()
		"retry":
			UI.goto(Screens.GAME)
		"home":
			UI.goto(Screens.MAIN_MENU)
		"continue":
			_finished = false


## The board that opens the screen, and the chapter whose art and music go with it.
func _first_board() -> HalvesLevelData:
	match _mode:
		Screens.Mode.DAILY:
			_daily_date = HalvesRecords.today()
			_chapter = posmod(HalvesPools.daily_number(_daily_date) - 1, HalvesChapters.count())
			return HalvesPools.daily_board(_daily_date)
		Screens.Mode.ZEN:
			_order = HalvesPools.run_order(HalvesPools.Kind.ZEN, ["zen", Progress.session_index()])
			_chapter = posmod(HalvesRecords.zen_boards() / 5, HalvesChapters.count())
			return _pool_board(HalvesPools.Kind.ZEN, _zen_position)
		Screens.Mode.RUSH:
			_order = HalvesPools.run_order(HalvesPools.Kind.RUSH, ["rush", Time.get_unix_time_from_system()])
			_rush_left_ms = HalvesConfig.RUSH_SECONDS * 1000
			_chapter = HalvesChapters.index_for_level(Progress.next_level())
			return _pool_board(HalvesPools.Kind.RUSH, 0)
	_level = clampi(Screens.level, 1, HalvesLevels.count())
	_chapter = HalvesChapters.index_for_level(_level)
	return HalvesLevels.get_level(_level)


func _pool_board(kind: HalvesPools.Kind, position: int) -> HalvesLevelData:
	if _order.is_empty():
		return HalvesPools.get_board(kind, position)
	return HalvesPools.get_board(kind, _order[posmod(position, _order.size())])


func _start_board(data: HalvesLevelData) -> void:
	_data = data
	_state = data.new_state()
	_state.strict = HalvesConfig.STRICT_MISTAKES
	var levels := _mode == Screens.Mode.LEVELS
	_state.free_mistakes = 1 if levels and _level <= HalvesConfig.TUTORIAL_FORGIVE_LEVELS else 0
	_board.show_mates = levels and _level <= HalvesConfig.MATE_PULSE_LEVELS
	_board.setup(_data, _state)
	_run = HalvesRun.new()
	_run.board = _board_id()
	_run.level = data.level
	_run.gen_version = HalvesLevels.gen_version() if levels else HalvesPools.gen_version(_pool_kind())
	_run.free_mistakes = _state.free_mistakes
	_run.strict = _state.strict
	_boosters_used = 0
	_combo_coins = 0
	_shown_second = -1
	for kind in BOOSTERS:
		_free_left[kind] = HalvesConfig.FREE_USES
	%StuckCenter.hide()
	_refresh_hud()
	_update_clock()
	if levels and _level == 1:
		_board.show_first_move()
	if levels and data.tip != "" and HalvesTips.has_tip(data.tip) and not HalvesRecords.tip_seen(data.tip):
		_show_tip.call_deferred(data.tip)


func _show_tip(id: String) -> void:
	if not is_inside_tree() or UI.has_modal():
		return
	var popup := UI.open(load(Screens.TIP) as PackedScene)
	popup.call(&"setup", id)
	await popup.closed


func _pause() -> void:
	if _finished or UI.has_modal():
		return
	var choice: Variant = await UI.open(load(Screens.PAUSE) as PackedScene).closed
	match choice:
		"restart":
			UI.goto(Screens.GAME)
		"home":
			UI.goto(Screens.MAIN_MENU)
		"rules":
			var tips := UI.open(load(Screens.TIP) as PackedScene)
			tips.call(&"setup_all")


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
	_boosters_used += 1
	match kind:
		"hint":
			_run.record(HalvesRun.Event.HINT, hint.x, hint.y)
			_board.show_hint(hint)
		"undo":
			if _board.undo():
				_run.record(HalvesRun.Event.UNDO)
				%StuckCenter.hide()
		"shuffle":
			%StuckCenter.hide()
			_board.shuffle(_state.is_stuck())
	Juice.pop(_booster_button(kind), 1.1, 0.16)
	_refresh_hud()


## Zen is free; otherwise the board's free use first, then coins.
func _pay_for(kind: String) -> bool:
	if _mode == Screens.Mode.ZEN:
		return true
	if _free_left[kind] > 0:
		_free_left[kind] -= 1
		return true
	var popup := UI.open(load(Screens.BOOSTER) as PackedScene)
	popup.call(&"setup", kind, _booster_title(kind), _booster_icon(kind), _booster_price(kind), Progress.coins())
	var choice: Variant = await popup.closed
	if choice == "coins":
		return Progress.spend_coins(_booster_price(kind))
	return false


func _on_first_tap() -> void:
	_run.start()


func _on_matched(a: int, b: int) -> void:
	_run.record(HalvesRun.Event.PAIR, a, b)
	if _mode == Screens.Mode.RUSH:
		_rush_score += 1


func _on_mismatched(a: int, b: int) -> void:
	_run.record(HalvesRun.Event.MISMATCH, a, b)
	if _mode == Screens.Mode.RUSH:
		_rush_left_ms = maxi(0, _rush_left_ms - HalvesConfig.RUSH_MISTAKE_PENALTY_S * 1000)
		UI.toast("-%d s" % HalvesConfig.RUSH_MISTAKE_PENALTY_S, Icons.TIMER, 0.8)


func _on_mistake(forgiven: bool) -> void:
	if not forgiven and _stars.visible:
		_stars.pivot_offset_ratio = Vector2(0.5, 0.5)
		Juice.pop(_stars, 1.12, 0.2)


func _on_combo(count: int, _at: Vector2) -> void:
	if count >= HalvesConfig.COMBO_COINS_AT and count % HalvesConfig.COMBO_COINS_AT == 0 and _mode != Screens.Mode.ZEN:
		_combo_coins += HalvesConfig.COMBO_COINS
		HalvesSfx.play(&"coin")


func _on_shuffled(count: int, was_stuck: bool) -> void:
	_run.record(HalvesRun.Event.SHUFFLE, count, 1 if was_stuck else 0)


## Look settings changed while playing (from the pause menu's settings).
func _on_setting_changed(key: StringName, value: Variant) -> void:
	match key:
		&"bold_tiles":
			HalvesShapes.bold = bool(value)
			_board.refresh_look()
		&"left_handed":
			_apply_hand()


## Left-handed: boosters at the bottom left, pause at the top right; otherwise centred, pause left.
func _apply_hand() -> void:
	var left := Settings.left_handed()
	var hud: Node = %PauseButton.get_parent()
	hud.move_child(%PauseButton, hud.get_child_count() - 1 if left else 0)
	var bar := %HintButton.get_parent() as BoxContainer
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN if left else BoxContainer.ALIGNMENT_CENTER


## The Mend button sits with the boosters (same look) and only shows once the gold pair is cleared.
func _build_mend_button() -> void:
	_mend_button = Button.new()
	_mend_button.icon = Icons.DIAMOND
	_mend_button.tooltip_text = "Mend: a free tile meets its other half, wherever it is"
	_mend_button.theme_type_variation = %HintButton.theme_type_variation
	_mend_button.size_flags_horizontal = %HintButton.size_flags_horizontal
	_mend_button.custom_minimum_size = %HintButton.custom_minimum_size
	_mend_button.visible = false
	_mend_button.set_meta(&"ui_sound", false)
	_mend_button.pressed.connect(_start_mend)
	%HintButton.get_parent().add_child(_mend_button)
	_mend_badge = _add_badge(_mend_button)


## Mend mode on (or off again): the next tap on a free tile mends it.
func _start_mend() -> void:
	if _finished or _state == null or _state.mends <= 0 or _board.is_busy():
		return
	%StuckCenter.hide()
	_board.mend_mode = not _board.mend_mode
	if _board.mend_mode:
		HalvesSfx.play(&"hint")
		UI.toast("Tap a free tile: its other half comes to it", Icons.DIAMOND)
	_refresh_hud()


func _on_mended(a: int, _b: int) -> void:
	_run.record(HalvesRun.Event.MEND, a)
	_refresh_hud()


func _on_mend_earned(_at: Vector2) -> void:
	_refresh_hud()
	_mend_button.pivot_offset_ratio = Vector2(0.5, 0.5)
	Juice.pop(_mend_button, 1.2, 0.3)
	if not HalvesRecords.tip_seen("mend"):
		_show_tip("mend")


## The first taps on a blocked tile say why (locks and frost always explain once per board).
func _on_blocked_tap(_tile: int, reason: int) -> void:
	if _explained.has(reason):
		return
	var special := reason == HalvesGeometry.Block.LOCKED or reason == HalvesGeometry.Block.FROSTED
	if not special and (_mode != Screens.Mode.LEVELS or _level > BLOCK_HELP_LEVELS):
		return
	_explained[reason] = true
	match reason:
		HalvesGeometry.Block.COVERED:
			UI.toast("Covered: clear the tile on top first", Icons.LOCK)
		HalvesGeometry.Block.SIDES:
			UI.toast("Blocked on both sides: open an end of the row", Icons.LOCK)
		HalvesGeometry.Block.LOCKED:
			UI.toast("Locked: clear every key tile to open it", Icons.LOCK)
		HalvesGeometry.Block.FROSTED:
			UI.toast("Frozen: clear a tile touching it to thaw it", Icons.LOCK)


func _on_stuck() -> void:
	if _finished:
		return
	if _mode == Screens.Mode.RUSH or _mode == Screens.Mode.ZEN:
		UI.toast("No pairs left: shuffling", SHUFFLE_ICON, 1.2)
		_board.shuffle(true)
		return
	%StuckCenter.show()
	_stuck_undo.visible = not _state.history.is_empty()
	_stuck_mend.visible = _state.mends > 0
	var card: Control = %StuckCenter.get_child(0)
	card.pivot_offset_ratio = Vector2(0.5, 0.5)
	Juice.pop(card, 1.06, 0.2)
	if not HalvesRecords.tip_seen("stuck"):
		_show_tip("stuck")


func _on_stuck_shuffle() -> void:
	%StuckCenter.hide()
	_board.shuffle(true)
	_refresh_hud()


func _on_cleared() -> void:
	match _mode:
		Screens.Mode.ZEN:
			_zen_cleared()
		Screens.Mode.RUSH:
			_rush_cleared()
		_:
			_celebrate()
			_stars.pivot_offset_ratio = Vector2(0.5, 0.5)
			Juice.pop(_stars, 1.2, 0.3)
			await get_tree().create_timer(0.9, false).timeout
			if is_inside_tree():
				finish(true, _state.stars(_allowance()))


## The chapter's burst over the cleared board, its little fanfare and a strong haptic.
func _celebrate() -> void:
	Haptics.big()
	HalvesSfx.duck(1.6)
	HalvesSfx.play(StringName(HalvesChapters.get_chapter(_chapter).win))
	var burst := HalvesWinBurst.new()
	add_child(burst)
	burst.play(_board.get_global_rect(), HalvesChapters.get_chapter(_chapter))


func _zen_cleared() -> void:
	var count := HalvesRecords.add_zen_board()
	_celebrate()
	UI.toast("Board %d cleared" % count, Icons.STAR, 1.2)
	await get_tree().create_timer(1.2, false).timeout
	if not is_inside_tree():
		return
	_zen_position += 1
	var chapter := posmod(count / 5, HalvesChapters.count())
	if chapter != _chapter:
		_chapter = chapter
		_background.set_chapter(_chapter)
	_start_board(_pool_board(HalvesPools.Kind.ZEN, _zen_position))


func _rush_cleared() -> void:
	if _finished:
		return
	_rush_boards += 1
	_rush_score += HalvesConfig.RUSH_BOARD_POINTS
	_rush_left_ms += HalvesConfig.RUSH_BOARD_BONUS_S * 1000
	HalvesSfx.play(&"swift")
	UI.toast("+%d s" % HalvesConfig.RUSH_BOARD_BONUS_S, Icons.TIMER, 0.8)
	_rush_position += 1
	var started := _run.started
	_start_board(_pool_board(HalvesPools.Kind.RUSH, _rush_position))
	if started:
		_run.start()


func _finish_rush() -> void:
	if _finished:
		return
	_finished = true
	_run.finish()
	var new_best := HalvesRecords.record_rush(_rush_score)
	Services.leaderboard.submit_score("rush", _rush_score)
	var coins := _rush_score / 10 + _combo_coins
	Progress.add_coins(coins)
	_celebrate()
	var popup := UI.open(load(Screens.RESULTS) as PackedScene)
	popup.call(&"show_win", 0, 0, coins, {"rush": true, "score": _rush_score, "best_score": HalvesRecords.rush_best(),
			"new_best": new_best, "boards": _rush_boards, "chapter": _chapter})
	_maybe_show_interstitial(true)
	var choice: Variant = await popup.closed
	match choice:
		"next", "retry":
			UI.goto(Screens.GAME)
		_:
			UI.goto(Screens.MAIN_MENU)


## Saves stars, the best time, medals and coins for a cleared levels or daily board; returns
## what the results popup shows.
func _record_clear(stars: int) -> Dictionary:
	var board := _board_id()
	var record := HalvesRecords.record_clear(board, _run, stars, _state.slips(), _data.par_ms(), _boosters_used > 0)
	var gold_coins := _state.gold_earned * HalvesConfig.GOLD_COINS
	var lucky_coins := _state.lucky_won * HalvesConfig.LUCKY_COINS
	var coins := stars * HalvesConfig.COINS_PER_STAR + gold_coins + lucky_coins + _combo_coins
	if bool(record.swift_new):
		coins += HalvesConfig.SWIFT_COINS
	var details := {"time_ms": _run.active_ms, "par_ms": _data.par_ms(), "best_ms": record.best_ms,
			"new_best": record.new_best, "swift": record.swift, "swift_new": record.swift_new, "chapter": _chapter,
			"gold_coins": gold_coins, "lucky_coins": lucky_coins, "combo_coins": _combo_coins, "slips": _state.slips(), "allowance": _allowance()}
	if _mode == Screens.Mode.DAILY:
		var daily := HalvesRecords.record_daily(_daily_date, _run.active_ms, stars)
		details.title = "Daily #%d complete!" % HalvesPools.daily_number(_daily_date)
		details.streak = daily.streak
		details.daily_reward = daily.reward
		details.share = HalvesRecords.share_line(_daily_date)
		details.next_text = "Done"
		Services.leaderboard.submit_time(board + "_time", _run.active_ms)
		Progress.add_coins(coins)
		return details.merged({"coins": coins + int(daily.reward)})
	if Progress.levels_won() == 0:
		Services.analytics.log_event("first_win", {"level": _level})
	Progress.record_win(_level, stars)
	Progress.add_coins(coins)
	Services.leaderboard.submit_score("stars", Progress.total_stars())
	Services.leaderboard.submit_time(board + "_time", _run.active_ms)
	if _level >= HalvesLevels.count():
		details.next_text = "All done!"
	elif _level == HalvesChapters.last_level(_chapter):
		details.next_text = "On to %s" % HalvesChapters.get_chapter(_chapter + 1).name
	return details.merged({"coins": coins})


## Next from the results: the chapter reveal after a chapter's last level, then the next level.
func _go_next() -> void:
	if _mode != Screens.Mode.LEVELS:
		UI.goto(Screens.MAIN_MENU)
		return
	if _level == HalvesChapters.last_level(_chapter) and not HalvesRecords.tip_seen("chapter_%d" % _chapter):
		HalvesRecords.mark_tip("chapter_%d" % _chapter)
		var reveal := UI.open(load(Screens.CHAPTER) as PackedScene)
		reveal.call(&"setup", _chapter, true)
		await reveal.closed
	if _level >= HalvesLevels.count():
		UI.goto(Screens.LEVEL_SELECT)
		UI.toast("All %d levels done. The Daily Puzzle has a new board every day!" % HalvesLevels.count(), Icons.STAR)
		return
	Screens.level = _level + 1
	UI.goto(Screens.GAME)


## Free slips on this board before a star goes (HalvesConfig.star_allowance; -1 = unlimited).
func _allowance() -> int:
	return HalvesConfig.star_allowance(_mode, _level, _state.geometry.size() / 2)


func _refresh_hud() -> void:
	if _state == null:
		return
	_stars.stars = _state.stars(_allowance())
	var total := _state.geometry.size()
	_progress.value = 100.0 * float(total - _state.tiles_left()) / maxf(1.0, float(total))
	%UndoButton.disabled = _state.history.is_empty()
	_mend_button.visible = _state.mends > 0 and _mode != Screens.Mode.RUSH
	_mend_badge.text = str(_state.mends)
	_mend_button.modulate = Color(1.0, 0.9, 0.55) if _board.mend_mode else Color.WHITE
	for kind in BOOSTERS:
		var free: int = _free_left.get(kind, 0)
		_badges[kind].get_parent().visible = _mode != Screens.Mode.ZEN
		_badges[kind].text = str(free) if free > 0 else str(_booster_price(kind))
	if _mode == Screens.Mode.RUSH:
		_caption.text = "Score %d · Board %d" % [_rush_score, _rush_boards + 1]
	elif _mode == Screens.Mode.ZEN:
		_caption.text = "%s · %d boards" % [HalvesChapters.get_chapter(_chapter).name, HalvesRecords.zen_boards()]


## The clock under the title: time played (par next to it), the rush countdown, nothing in zen.
func _update_clock() -> void:
	if _clock == null or _run == null:
		return
	var ms := _rush_left_ms if _mode == Screens.Mode.RUSH else _run.active_ms
	var second := ms / 1000
	if second == _shown_second:
		return
	_shown_second = second
	_clock.text = HalvesRecords.format_time(ms)
	if _mode == Screens.Mode.RUSH and second <= 10 and _run.started and not _finished:
		HalvesSfx.play(&"tick")
		Juice.pop(_clock, 1.15, 0.12)


func _build_hud() -> void:
	var hud: HBoxContainer = %LevelLabel.get_parent()
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override(&"separation", 2)
	hud.add_child(title_box)
	hud.move_child(title_box, %LevelLabel.get_index())
	%LevelLabel.reparent(title_box)
	%LevelLabel.add_theme_color_override(&"font_color", get_theme_color(&"gold", &"Tokens"))
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override(&"separation", 14)
	title_box.add_child(line)
	_caption = Label.new()
	_caption.theme_type_variation = &"CaptionLabel"
	_caption.add_theme_color_override(&"font_color", get_theme_color(&"text_on_bg", &"Tokens"))
	line.add_child(_caption)
	_clock = Label.new()
	_clock.theme_type_variation = &"CaptionLabel"
	_clock.add_theme_color_override(&"font_color", get_theme_color(&"text_on_bg", &"Tokens"))
	_clock.pivot_offset_ratio = Vector2(0.5, 0.5)
	line.add_child(_clock)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 8)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(_progress)
	_build_mend_button()
	_stuck_undo = Button.new()
	_stuck_undo.text = "Undo"
	_stuck_undo.icon = Icons.UNDO
	_stuck_undo.pressed.connect(_use_booster.bind("undo"))
	var stuck_box: Node = %StuckButton.get_parent()
	stuck_box.add_child(_stuck_undo)
	stuck_box.move_child(_stuck_undo, %StuckButton.get_index())
	stuck_box.get_node(^"StuckText").text = "Undo your last pairs, mend, or shuffle the board. A shuffle out of a dead end is a slip."
	%StuckButton.text = "Shuffle · a slip"
	_stuck_mend = Button.new()
	_stuck_mend.text = "Mend"
	_stuck_mend.icon = Icons.DIAMOND
	_stuck_mend.pressed.connect(_start_mend)
	stuck_box.add_child(_stuck_mend)
	stuck_box.move_child(_stuck_mend, %StuckButton.get_index())
	var show_time := Settings.show_timer()
	match _mode:
		Screens.Mode.DAILY:
			%LevelLabel.text = "DAILY #%d" % HalvesPools.daily_number(HalvesRecords.today())
			_caption.text = HalvesRecords.today()
			_clock.visible = show_time
		Screens.Mode.ZEN:
			%LevelLabel.text = "ZEN"
			_clock.visible = false
			_stars.visible = false
		Screens.Mode.RUSH:
			%LevelLabel.text = "RUSH"
			_stars.visible = false
			%HintButton.get_parent().visible = false
		_:
			var level := clampi(Screens.level, 1, HalvesLevels.count())
			%LevelLabel.text = "LEVEL %d" % level
			var chapter := HalvesChapters.get_chapter(HalvesChapters.index_for_level(level))
			_caption.text = chapter.name
			_clock.visible = show_time


## Dev mode (Settings, debug builds only): a Skip button by the boosters that wins the board with
## three stars and moves on, without recording a time.
func _add_dev_skip() -> void:
	if not Settings.dev_mode():
		return
	var skip := Button.new()
	skip.text = "Skip"
	skip.icon = Icons.ARROW_FORWARD
	skip.tooltip_text = "Dev mode: win this board"
	skip.theme_type_variation = %HintButton.theme_type_variation
	skip.size_flags_horizontal = %HintButton.size_flags_horizontal
	skip.modulate = Color(1.0, 0.85, 0.6)
	skip.pressed.connect(_dev_skip)
	%HintButton.get_parent().add_child(skip)


func _dev_skip() -> void:
	if _finished or _state == null:
		return
	match _mode:
		Screens.Mode.LEVELS:
			_finished = true
			Progress.record_win(_level, 3)
			await _go_next()
		Screens.Mode.ZEN:
			_zen_position += 1
			_start_board(_pool_board(HalvesPools.Kind.ZEN, _zen_position))
		Screens.Mode.RUSH:
			_finish_rush()
		_:
			finish(true, 3)


func _on_debug_command(command: StringName, _args: Array) -> void:
	match command:
		&"skip_level":
			if _state != null and (_mode == Screens.Mode.LEVELS or _mode == Screens.Mode.DAILY):
				finish(true, _state.stars(_allowance()))
			elif _mode == Screens.Mode.RUSH:
				_finish_rush()
		&"stats":
			for line in HalvesRecords.stats_lines():
				print(line)


func _board_id() -> String:
	match _mode:
		Screens.Mode.DAILY:
			return HalvesRecords.daily_board(_daily_date)
		Screens.Mode.ZEN:
			return "zen"
		Screens.Mode.RUSH:
			return "rush"
	return HalvesRecords.level_board(_level)


func _pool_kind() -> HalvesPools.Kind:
	match _mode:
		Screens.Mode.ZEN:
			return HalvesPools.Kind.ZEN
		Screens.Mode.RUSH:
			return HalvesPools.Kind.RUSH
	return HalvesPools.Kind.DAILY


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
	if _mode != Screens.Mode.LEVELS:
		return
	if _level == 1 and Progress.levels_won() == 0:
		Services.analytics.log_event("tutorial_step_1", {})
	if _level == 3:
		Services.analytics.log_event("level_3_start", {})


## Interstitials only on the results of the level journey and rush (never daily or zen).
func _maybe_show_interstitial(won: bool) -> void:
	if Progress.owns("remove_ads"):
		return
	var now := _now()
	var ritual := _mode == Screens.Mode.DAILY or _mode == Screens.Mode.ZEN
	if ad_policy.can_show_interstitial(_level, won, now, ritual) and Services.ads.is_interstitial_ready("results"):
		Services.ads.show_interstitial("results")
		ad_policy.record_interstitial_shown(now)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
