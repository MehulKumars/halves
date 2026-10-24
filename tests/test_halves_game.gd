extends GutTest
## The Halves game screen end to end: faces stay 96 px or more on every level and size, a level
## played through the board reaches the results, mistakes, undo, boosters, shuffle and the stuck card work.
## Uses its own save file; popups open on the UI autoload, so each test closes them again.
## (v2) Levels are picked by what their data holds ("the first level with a free decoy ...") instead
## of fixed numbers; TUTORIAL_FORGIVE_LEVELS is 4; a stuck shuffle counts as a slip; coins add Swift and gold.
## (v3) The HUD's stars use HalvesConfig.star_allowance: no star goes on levels 1-10.

const H := preload("res://tests/halves_helpers.gd")
const SIZES: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(960, 1280)]
const NOTCH: Vector4i = Vector4i(0, 64, 0, 32)
const TOUCH: float = 96.0


func before_all() -> void:
	Progress.path = "user://test_halves_game.json"
	Progress.reset()


func after_each() -> void:
	UI.close_all()
	SafeAreaMargin.set_simulated_insets(get_tree(), Vector4i.ZERO)


func after_all() -> void:
	Progress.reset()
	Progress.path = SaveStore.DEFAULT_PATH
	Progress.load_from_disk()
	Screens.level = 1
	Screens.mode = Screens.Mode.LEVELS


## The first level in [from, to] whose baked data passes `pred`, or -1.
func _first_level(from: int, to: int, pred: Callable) -> int:
	for n: int in range(from, mini(to, HalvesLevels.COUNT) + 1):
		var data := HalvesLevels.get_level(n)
		if data != null and pred.call(data):
			return n
	return -1


func _has_free_decoy(data: HalvesLevelData) -> bool:
	return H.free_decoy(data.new_state()).x >= 0


## A level past the tutorial without a tip card, with more than three pairs.
func _plain_level(data: HalvesLevelData) -> bool:
	return data.level > HalvesConfig.TUTORIAL_FORGIVE_LEVELS and data.tip == "" and data.solution.size() > 3


func test_level_counts_agree() -> void:
	assert_eq(Progress.LEVEL_COUNT_DEFAULT, HalvesLevels.COUNT, "level select and Play use the Halves count")
	assert_eq(HalvesLevels.count(), HalvesLevels.COUNT, "every level is baked")


func test_faces_are_touch_sized_on_every_level_and_size() -> void:
	for size in SIZES:
		await _check_every_level(size, Vector4i.ZERO)
	await _check_every_level(Vector2i(720, 1280), NOTCH)


func test_level_one_played_through_reaches_the_results() -> void:
	Progress.reset()
	var game := await _open_game(1)
	var board := _board(game)
	var gold := HalvesBits.count(board.state.gold)
	for pair in board.level_data.solution:
		board.tap(pair.x)
		board.tap(pair.y)
	assert_true(board.state.is_cleared(), "the baked solution clears the board through taps")
	assert_eq(board.state.gold_earned, gold, "every gold tile was cleared")
	await _wait(1.6)
	assert_true(UI.has_modal(), "the results popup opens after the clear")
	assert_eq(Progress.stars(1), 3, "no slips: flawless")
	# (v2) Stars give COINS_PER_STAR each, gold tiles GOLD_COINS each, and an instant clear is under par,
	# so the first Swift medal adds SWIFT_COINS. Combo coins may come on top (their rule is not in the doc).
	var least := 3 * HalvesConfig.COINS_PER_STAR + gold * HalvesConfig.GOLD_COINS
	if board.level_data.par_ms() > 0:
		least += HalvesConfig.SWIFT_COINS
	assert_gte(Progress.coins(), least)
	_close(game)


## (v3) A star goes only when the slips pass the board's allowance,
## HalvesConfig.star_allowance(LEVELS, level, pairs), on levels after STAR_FREE_LEVELS.
func test_a_slip_past_the_allowance_costs_a_star_and_undo_gives_it_back() -> void:
	var level := _first_level(HalvesConfig.STAR_FREE_LEVELS + 1, HalvesLevels.COUNT,
			func(d: HalvesLevelData) -> bool: return d.tip == "" and _has_free_decoy(d))
	assert_ne(level, -1, "some level after the free levels offers a twin or near-twin to tap at the start")
	if level == -1:
		return
	var data := HalvesLevels.get_level(level)
	var allowance := HalvesConfig.star_allowance(Screens.Mode.LEVELS, level, int(data.positions.size() / 2.0))
	assert_gte(allowance, 1, "test setup: level %d has a limited allowance" % level)
	var game := await _open_game(level)
	var board := _board(game)
	var stars := game.get_node(^"%Stars") as StarRating
	var decoy := H.free_decoy(board.state)
	assert_ne(decoy, Vector2i(-1, -1), "level %d offers a twin or near-twin to tap" % level)
	for i: int in allowance:
		board.tap(decoy.x)
		board.tap(decoy.y)
	assert_eq(board.state.mistakes, allowance)
	assert_eq(stars.stars, 3, "level %d: %d slips are within the allowance" % [level, allowance])
	board.tap(decoy.x)
	board.tap(decoy.y)
	assert_eq(board.state.mistakes, allowance + 1)
	assert_eq(stars.stars, 2, "one slip past the allowance: the HUD drops to two stars")
	(game.get_node(^"%UndoButton") as Button).pressed.emit()
	await _wait(0.2)
	assert_eq(board.state.mistakes, allowance, "the free undo takes the last mistake back")
	assert_eq(stars.stars, 3)
	_close(game)


## (v3) Levels 1..STAR_FREE_LEVELS of the LEVELS mode have an unlimited allowance.
func test_the_first_levels_never_drop_a_star() -> void:
	assert_eq(HalvesConfig.STAR_FREE_LEVELS, 10)
	var level := _first_level(1, HalvesConfig.STAR_FREE_LEVELS, _has_free_decoy)
	if level == -1:
		pending("no level up to %d has a free decoy at the start" % HalvesConfig.STAR_FREE_LEVELS)
		return
	var game := await _open_game(level)
	var board := _board(game)
	var decoy := H.free_decoy(board.state)
	for i: int in 6:
		board.tap(decoy.x)
		board.tap(decoy.y)
	assert_gte(board.state.mistakes, 5, "real slips (the tutorial forgives at most one)")
	assert_eq((game.get_node(^"%Stars") as StarRating).stars, 3, "level %d keeps three stars" % level)
	_close(game)


func test_the_tutorial_forgives_the_first_mistake() -> void:
	assert_eq(HalvesConfig.TUTORIAL_FORGIVE_LEVELS, 4)
	var level := _first_level(1, HalvesConfig.TUTORIAL_FORGIVE_LEVELS, _has_free_decoy)
	if level == -1:
		pending("no tutorial level has a free decoy at the start")
		return
	var game := await _open_game(level)
	var board := _board(game)
	var decoy := H.free_decoy(board.state)
	board.tap(decoy.x)
	board.tap(decoy.y)
	assert_eq(board.state.mistakes, 0, "the first mistake on tutorial level %d is free" % level)
	assert_eq(board.state.free_mistakes, 0)
	_close(game)


func test_a_second_hint_costs_coins() -> void:
	var level := _first_level(1, HalvesLevels.COUNT, _plain_level)
	assert_ne(level, -1, "a level past the tutorial without a tip")
	if level == -1:
		return
	Progress.reset()
	Progress.add_coins(100)
	var game := await _open_game(level)
	var hint := game.get_node(^"%HintButton") as Button
	hint.pressed.emit()
	await _wait(0.2)
	assert_false(UI.has_modal(), "the first hint of a level is free")
	hint.pressed.emit()
	await _wait(0.5)
	var popup := UI.top_modal()
	assert_not_null(popup, "the second hint asks how to pay")
	if popup != null:
		popup.call(&"close", "coins")
		await _wait(0.5)
	assert_eq(Progress.coins(), 100 - HalvesConfig.PRICE_HINT)
	_close(game)


func test_shuffle_keeps_every_tile_and_the_board_solvable() -> void:
	var level := _first_level(1, HalvesLevels.COUNT, _plain_level)
	assert_ne(level, -1, "a level past the tutorial without a tip")
	if level == -1:
		return
	var game := await _open_game(level)
	var board := _board(game)
	for step in 3:
		var pair := board.level_data.solution[step]
		board.tap(pair.x)
		board.tap(pair.y)
	var left := board.state.tiles_left()
	assert_false(board.state.is_stuck(), "test setup: on the solution line, never stuck")
	board.shuffle()
	await _wait(0.5)
	assert_eq(board.state.tiles_left(), left)
	var result := HalvesSolver.solve(board.state.geometry, board.state.faces, board.state.remaining)
	assert_eq(result.status, HalvesSolver.Status.SOLVED)
	assert_eq(board.shuffles, 1)
	assert_eq(board.state.stuck_shuffles, 0, "a shuffle on a board that is not stuck is not a slip")
	assert_eq(board.state.slips(), 0)
	_close(game)


func test_the_stuck_card_offers_a_free_shuffle_that_is_a_slip() -> void:
	var level := -1
	var line: Array[Vector2i] = []
	for n: int in range(1, HalvesLevels.COUNT + 1):
		var data := HalvesLevels.get_level(n)
		if data == null or data.tip != "":
			continue
		line = H.stuck_line(data, 10)
		if not line.is_empty():
			level = n
			break
	if level == -1:
		pending("no random line of play got stuck")
		return
	var game := await _open_game(level)
	var board := _board(game)
	var center := game.get_node(^"%StuckCenter") as Control
	assert_false(center.visible)
	for pair in line:
		board.tap(pair.x)
		board.tap(pair.y)
	assert_true(board.state.is_stuck(), "test setup: level %d is stuck" % level)
	await _wait(1.0)
	assert_true(center.visible, "being stuck shows the card within a second")
	var coins := Progress.coins()
	(game.get_node(^"%StuckButton") as Button).pressed.emit()
	assert_false(center.visible)
	assert_eq(board.shuffles, 1, "the card shuffles")
	await _wait(0.5)
	assert_eq(board.state.stuck_shuffles, 1, "a shuffle while stuck counts")
	assert_eq(board.state.slips(), board.state.mistakes + 1)
	assert_false(board.state.is_stuck(), "the shuffled board has a free pair")
	assert_eq(Progress.coins(), coins, "the card's shuffle is free")
	_close(game)


func _check_every_level(size: Vector2i, insets: Vector4i) -> void:
	SafeAreaMargin.set_simulated_insets(get_tree(), insets)
	var game := await _open_game(1, size)
	var area := _board(game).size
	for level in range(1, HalvesLevels.COUNT + 1):
		var geometry := HalvesLevels.get_level(level).geometry()
		var unit := HalvesBoardView.unit_for(area, geometry.bounds(), geometry.max_z())
		var face := unit * HalvesBoardView.FACE_W
		assert_gte(face, TOUCH, "level %d at %s (insets %s): faces %.0f px" % [level, size, insets, face])
		var used := HalvesBoardView.board_size(unit, geometry.bounds(), geometry.max_z())
		assert_true(used.x <= area.x + 0.5 and used.y <= area.y + 0.5, "level %d fits the board area at %s" % [level, size])
	_close(game)


## Opens the game on `level`. A tip card (v2) may open as a popup on some levels: it is closed so
## the test starts on the bare board.
func _open_game(level: int, size: Vector2i = Vector2i(720, 1280)) -> Node:
	Screens.mode = Screens.Mode.LEVELS
	Screens.level = level
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	add_child(viewport)
	var game := (load(Screens.GAME) as PackedScene).instantiate()
	viewport.add_child(game)
	await _wait(0.3)
	if UI.has_modal():
		UI.close_all()
		await _wait(0.2)
	return game


func _board(game: Node) -> HalvesBoardView:
	return game.get_node(^"%HalvesBoard") as HalvesBoardView


func _close(game: Node) -> void:
	UI.close_all()
	game.get_parent().free()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
