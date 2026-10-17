extends GutTest
## The Halves game screen end to end: faces stay 96 px or more on every level and size, a level
## played through the board reaches the results, mistakes, undo, boosters and shuffle work.
## Uses its own save file; popups open on the UI autoload, so each test closes them again.

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
	for pair in board.level_data.solution:
		board.tap(pair.x)
		board.tap(pair.y)
	assert_true(board.state.is_cleared(), "the baked solution clears the board through taps")
	await _wait(1.6)
	assert_true(UI.has_modal(), "the results popup opens after the clear")
	assert_eq(Progress.stars(1), 3, "no mistakes: flawless")
	assert_eq(Progress.coins(), 3 * HalvesConfig.COINS_PER_STAR)
	_close(game)


func test_a_mistake_costs_the_flawless_star_and_undo_gives_it_back() -> void:
	var game := await _open_game(10)
	var board := _board(game)
	var decoy := _free_decoy(board)
	assert_ne(decoy, Vector2i(-1, -1), "level 10 offers a twin or near-twin to tap")
	board.tap(decoy.x)
	board.tap(decoy.y)
	assert_eq(board.state.mistakes, 1)
	assert_eq((game.get_node(^"%Stars") as StarRating).stars, 2, "the HUD drops to two stars")
	(game.get_node(^"%UndoButton") as Button).pressed.emit()
	await _wait(0.2)
	assert_eq(board.state.mistakes, 0, "the free undo takes the mistake back")
	assert_eq((game.get_node(^"%Stars") as StarRating).stars, 3)
	_close(game)


func test_the_tutorial_forgives_the_first_mistake() -> void:
	var game := await _open_game(2)
	var board := _board(game)
	var decoy := _free_decoy(board)
	if decoy.x < 0:
		_close(game)
		pending("level 2 has no free decoy at the start")
		return
	board.tap(decoy.x)
	board.tap(decoy.y)
	assert_eq(board.state.mistakes, 0, "the first mistake on a tutorial level is free")
	assert_eq(board.state.free_mistakes, 0)
	_close(game)


func test_a_second_hint_costs_coins() -> void:
	Progress.reset()
	Progress.add_coins(100)
	var game := await _open_game(12)
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
	var game := await _open_game(12)
	var board := _board(game)
	for step in 3:
		var pair := board.level_data.solution[step]
		board.tap(pair.x)
		board.tap(pair.y)
	var left := board.state.tiles_left()
	board.shuffle()
	await _wait(0.5)
	assert_eq(board.state.tiles_left(), left)
	var result := HalvesSolver.solve(board.state.geometry, board.state.faces, board.state.remaining)
	assert_eq(result.status, HalvesSolver.Status.SOLVED)
	assert_eq(board.shuffles, 1)
	_close(game)


func test_the_stuck_card_offers_a_free_shuffle() -> void:
	var game := await _open_game(5)
	var board := _board(game)
	var center := game.get_node(^"%StuckCenter") as Control
	assert_false(center.visible)
	board.stuck.emit()
	assert_true(center.visible, "being stuck shows the card")
	(game.get_node(^"%StuckButton") as Button).pressed.emit()
	assert_false(center.visible)
	assert_eq(board.shuffles, 1, "the card shuffles")
	await _wait(0.5)
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


func _open_game(level: int, size: Vector2i = Vector2i(720, 1280)) -> Node:
	Screens.level = level
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	add_child(viewport)
	var game := (load(Screens.GAME) as PackedScene).instantiate()
	viewport.add_child(game)
	await _wait(0.3)
	return game


func _board(game: Node) -> HalvesBoardView:
	return game.get_node(^"%HalvesBoard") as HalvesBoardView


func _close(game: Node) -> void:
	UI.close_all()
	game.get_parent().free()


## A free pair of tiles that would be a mistake (same shape, not mates), or (-1, -1).
func _free_decoy(board: HalvesBoardView) -> Vector2i:
	var free := board.state.geometry.free_tiles(board.state.remaining)
	for i in free.size():
		for j in range(i + 1, free.size()):
			if HalvesFace.is_decoy(board.state.faces[free[i]], board.state.faces[free[j]]):
				return Vector2i(free[i], free[j])
	return Vector2i(-1, -1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
