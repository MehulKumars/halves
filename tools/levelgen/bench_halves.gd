extends SceneTree
## Times the costly Halves logic on the biggest baked board (deal, bot games, solver, hint) so the
## generator's budget and the hint's thread decision rest on numbers. Prints a small table.
## Usage: godot --headless --path . -s tools/levelgen/bench_halves.gd [-- <level>]  (default: the last level)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var started := Time.get_ticks_usec()
	var count := HalvesLevels.count()
	var parse_ms := (Time.get_ticks_usec() - started) / 1000.0
	var level := int(args[0]) if args.size() > 0 else count
	var data := HalvesLevels.get_level(level)
	if data == null:
		printerr("bench_halves: no level %d" % level)
		quit(1)
		return
	var geometry := data.geometry()
	print("level %d: %d tiles, %d layers; level file parsed in %.1f ms (%d levels)" % [
		level, geometry.size(), geometry.max_z() + 1, parse_ms, count])
	var rng := SeedService.make_rng(["bench", level], HalvesConfig.GEN_VERSION)
	var keys := PackedInt32Array()
	for i in geometry.size():
		if HalvesFace.side(data.faces[i]) == HalvesFace.SIDE_A:
			keys.append(HalvesFace.pair_key(data.faces[i]))
	_time("removal_order", 20, func() -> void: HalvesFill.removal_order(geometry, geometry.full_mask(), rng))
	_time("deal", 20, func() -> void: HalvesFill.deal(geometry, keys, rng))
	_time("bot RANDOM game", 50, func() -> void: HalvesBot.play(geometry, data.faces, rng, HalvesBot.Policy.RANDOM))
	_time("bot CAREFUL game", 50, func() -> void: HalvesBot.play(geometry, data.faces, rng, HalvesBot.Policy.CAREFUL))
	_time("rate (10 runs)", 3, func() -> void: HalvesBot.rate(geometry, data.faces, ["bench"], 10))
	_time("solve (full board)", 5, func() -> void: HalvesSolver.solve(geometry, data.faces, geometry.full_mask()))
	var state := data.new_state()
	_time("hint (full board)", 5, func() -> void: HalvesSolver.hint(state))
	for step in mini(8, data.solution.size()):
		state.try_pair(data.solution[step].x, data.solution[step].y)
	_time("hint (after 8 pairs)", 5, func() -> void: HalvesSolver.hint(state))
	quit()


func _time(label: String, repeats: int, work: Callable) -> void:
	var started := Time.get_ticks_usec()
	for _i in repeats:
		work.call()
	var each := (Time.get_ticks_usec() - started) / 1000.0 / repeats
	print("  %-22s %8.2f ms each (%d runs)" % [label, each, repeats])
