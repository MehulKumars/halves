extends Modal
## End-of-board popup. show_win(level, stars, coins, details) plays the reveal: stars with rising
## chimes, the time against par and best, "New best" / "Swift" ribbons, then coins; rush shows its
## score. Closes with "next", "retry" or "home".

var _stats: VBoxContainer
var _time: Label
var _time_note: Label
var _ribbons: HFlowContainer


func _ready() -> void:
	super._ready()
	%NextButton.pressed.connect(close.bind("next"))
	%RetryButton.pressed.connect(close.bind("retry"))
	%HomeButton.pressed.connect(close.bind("home"))
	_build_stats()


func show_win(level: int, stars: int, coins: int, details: Dictionary = {}) -> void:
	var rush := bool(details.get("rush", false))
	%Headline.text = str(details.get("title", "Time's up!" if rush else "Level %d complete!" % level))
	%Message.text = _message(stars, details)
	%NextButton.show()
	%NextButton.text = str(details.get("next_text", "Play again" if rush else "Next level"))
	%Stars.visible = not rush
	%RewardRow.show()
	%Reward.value = 0
	_stats.visible = details.has("time_ms") or rush
	_time_note.text = _time_text(details)
	_time.text = "0" if rush else "0:00"
	refit()
	Haptics.big()
	var still := Juice.motion_scale <= 0.0
	if not rush:
		%Stars.reveal(stars, 0.25)
		for i in stars:
			_chime(0.25 * i + 0.05, i)
		await _wait(0.25 * stars + 0.15)
	if not is_inside_tree():
		return
	if _stats.visible:
		var target := int(details.get("score", 0)) if rush else int(details.get("time_ms", 0))
		await _count_up(target, rush, still)
		_ribbon_pops(details)
		await _wait(0.2)
	if is_inside_tree():
		%Reward.set_value(coins)
		if coins > 0:
			HalvesSfx.play(&"coin")


func _message(stars: int, details: Dictionary) -> String:
	if bool(details.get("rush", false)):
		return "%d boards cleared" % int(details.get("boards", 0))
	var slips := int(details.get("slips", 0))
	var text: String = "Flawless!" if stars >= 3 and slips == 0 else ["Done!", "Done!", "Nice!", "Great!"][clampi(stars, 0, 3)]
	if slips > 0:
		text += "  (%d slip%s" % [slips, "" if slips == 1 else "s"]
		var allowance := int(details.get("allowance", -1))
		text += ", %d free)" % allowance if allowance >= 0 else ")"
	if details.has("streak"):
		text += "\nStreak: %d day%s" % [int(details.streak), "" if int(details.streak) == 1 else "s"]
		if int(details.get("daily_reward", 0)) > 0:
			text += "  ·  +%d coins" % int(details.daily_reward)
	return text


func _time_text(details: Dictionary) -> String:
	if bool(details.get("rush", false)):
		return "Best %d" % int(details.get("best_score", 0))
	var parts := PackedStringArray()
	if int(details.get("par_ms", 0)) > 0:
		parts.append("Par %s" % HalvesRecords.format_time(int(details.par_ms)))
	var best := int(details.get("best_ms", 0))
	if best > 0 and best < int(details.get("time_ms", 0)):
		parts.append("Best %s" % HalvesRecords.format_time(best, true))
	return "  ·  ".join(parts)


## The time (or score) rolls up from zero; motionless with Reduce Motion.
func _count_up(target: int, rush: bool, still: bool) -> void:
	var show := func(value: float) -> void:
		_time.text = str(int(value)) if rush else HalvesRecords.format_time(int(value), true)
	if still:
		show.call(float(target))
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(show, 0.0, float(target), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	Juice.pop(_time, 1.1, 0.14)


func _ribbon_pops(details: Dictionary) -> void:
	for child in _ribbons.get_children():
		child.queue_free()
	var shown := false
	if bool(details.get("new_best", false)):
		_add_ribbon("New best!" if not bool(details.get("rush", false)) else "New high score!")
		HalvesSfx.play(&"best")
		shown = true
	if bool(details.get("swift", false)):
		_add_ribbon("⚡ Swift" + (" +%d" % HalvesConfig.SWIFT_COINS if bool(details.get("swift_new", false)) else ""))
		HalvesSfx.play(&"swift")
		shown = true
	if int(details.get("gold_coins", 0)) > 0:
		_add_ribbon("Gold +%d" % int(details.gold_coins))
	if int(details.get("combo_coins", 0)) > 0:
		_add_ribbon("Combos +%d" % int(details.combo_coins))
	if shown:
		HalvesSfx.duck(1.0)
	refit()


func _add_ribbon(text: String) -> void:
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"BadgePanel"
	var label := Label.new()
	label.theme_type_variation = &"BadgeLabel"
	label.text = text
	badge.add_child(label)
	_ribbons.add_child(badge)
	badge.pivot_offset_ratio = Vector2(0.5, 0.5)
	Juice.pop(badge, 1.25, 0.25)


func _chime(delay: float, step: int) -> void:
	await _wait(delay)
	if is_inside_tree():
		HalvesSfx.play(&"star", pow(2.0, (step * 4) / 12.0))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _build_stats() -> void:
	var content: VBoxContainer = %Message.get_parent()
	_stats = VBoxContainer.new()
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_stats.add_theme_constant_override(&"separation", 6)
	content.add_child(_stats)
	content.move_child(_stats, %Message.get_index() + 1)
	_time = Label.new()
	_time.theme_type_variation = &"TitleLabel"
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.pivot_offset_ratio = Vector2(0.5, 0.5)
	_stats.add_child(_time)
	_time_note = Label.new()
	_time_note.theme_type_variation = &"CaptionLabel"
	_time_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_child(_time_note)
	_ribbons = HFlowContainer.new()
	_ribbons.alignment = FlowContainer.ALIGNMENT_CENTER
	_ribbons.add_theme_constant_override(&"h_separation", 12)
	_ribbons.add_theme_constant_override(&"v_separation", 10)
	_stats.add_child(_ribbons)
