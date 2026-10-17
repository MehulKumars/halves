extends SceneTree
## Plays a Halves level in a real window with injected taps (the same input path as a finger)
## and saves frames of the key moments to build/playtest/: pick, snap, mistake, shuffle, results.
## godot --path . -s tools/halves_playtest.gd [-- <level> [still]]   (needs a window, not --headless)
## "still" plays with Reduce Motion (Juice.motion_scale = 0) to check every change still reads.

const OUT_DIR: String = "res://build/playtest"
const SIZE: Vector2i = Vector2i(720, 1280)

var _out: String = ""
var _shot: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var level := int(args[0]) if args.size() > 0 else 10
	var still := args.size() > 1 and args[1] == "still"
	_out = ProjectSettings.globalize_path(OUT_DIR + ("_still" if still else ""))
	DirAccess.make_dir_recursive_absolute(_out)
	var marker := ProjectSettings.globalize_path("res://build/.gdignore")
	if not FileAccess.file_exists(marker):
		FileAccess.open(marker, FileAccess.WRITE).close()
	Progress.path = "user://playtest_progress.json"
	Progress.reset()
	Progress.add_coins(200)
	root.size = SIZE
	Screens.level = level
	change_scene_to_file(Screens.GAME)
	await _frames(30)
	root.size = SIZE
	if still:
		Juice.motion_scale = 0.0
	await _frames(10)
	var board := current_scene.get_node(^"%HalvesBoard") as HalvesBoardView
	var state := board.state
	await _save("start")

	# A mistake first (a twin or near-twin), if one is free.
	var decoy := _free_decoy(state)
	if decoy.x >= 0:
		await _tap(board, decoy.x)
		await _save("picked")
		await _tap(board, decoy.y, 4)
		await _save("mistake")
		await _frames(40)

	# Play the solution; the first snap is captured mid-flight.
	var first := true
	for pair in board.level_data.solution:
		if state.remaining & (1 << pair.x) == 0:
			continue
		await _tap(board, pair.x)
		await _tap(board, pair.y, 1)
		if first:
			await _wait(0.12)
			await _save("snap_flight")
			await _wait(0.12)
			await _save("snap_card")
			first = false
			await _wait(0.4)
			board.shuffle()
			await _wait(0.12)
			await _save("shuffle_flip")
			await _wait(0.5)
			await _save("after_shuffle")
			break
		await _frames(2)
	# The shuffle changed the faces: finish with the solver's moves.
	while not state.is_cleared():
		var result := HalvesSolver.solve(state.geometry, state.faces, state.remaining)
		var moves: Array[Vector2i] = result.moves
		if moves.is_empty():
			board.shuffle()
			await _wait(0.6)
			continue
		await _tap(board, moves[0].x)
		await _tap(board, moves[0].y, 1)
		await _frames(2)
	await _wait(1.2)
	await _save("cleared")
	await _wait(1.5)
	await _save("results")
	print("playtest: level %d, %d mistake(s), %d star(s), shots in %s" % [level, state.mistakes, state.stars(), _out])
	SaveStore.delete_save(Progress.path)
	quit()


## A press and release at the tile's centre, through Input like a real tap.
func _tap(board: HalvesBoardView, tile: int, settle_frames: int = 8) -> void:
	var at := board.get_global_transform_with_canvas() * board.tile_center(tile)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await _frames(1)
	await _frames(settle_frames)


func _free_decoy(state: HalvesState) -> Vector2i:
	var free := state.geometry.free_tiles(state.remaining)
	for i in free.size():
		for j in range(i + 1, free.size()):
			if HalvesFace.is_decoy(state.faces[free[i]], state.faces[free[j]]):
				return Vector2i(free[i], free[j])
	return Vector2i(-1, -1)


func _save(name: String) -> void:
	await _frames(1)
	_shot += 1
	var file := _out.path_join("%02d_%s.png" % [_shot, name])
	root.get_texture().get_image().save_png(file)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
