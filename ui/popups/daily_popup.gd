extends Modal
## Today's Daily Puzzle: its number and weekday difficulty, the streak with a 7-day strip, today's
## best time, Play and (once cleared) Share. Opened from the main menu; closes with "play" or null.
## Finishing the daily pays the streak reward (HalvesRecords.record_daily), not this popup.

const WEEKDAYS: Array[String] = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const LEVEL_WORDS: Array[String] = ["Hardest", "Gentle", "Easy", "Medium", "Tricky", "Hard", "Very hard"]

var _state: Dictionary = {}


func _ready() -> void:
	super._ready()
	_state = HalvesRecords.daily_state()
	var content: VBoxContainer = %Content
	var weekday: int = Time.get_datetime_dict_from_system().weekday
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Daily Puzzle #%d" % int(_state.number)
	content.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"CaptionLabel"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.text = "%s · %s · the same board for everyone today" % [WEEKDAYS[weekday], LEVEL_WORDS[weekday]]
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(sub)
	content.add_child(_week_strip())
	var streak := Label.new()
	streak.theme_type_variation = &"ValueLabel"
	streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var days := int(_state.streak)
	streak.text = "Streak: %d day%s" % [days, "" if days == 1 else "s"]
	content.add_child(streak)
	var note := Label.new()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bool(_state.done):
		note.text = "Cleared in %s. Play again to beat it." % HalvesRecords.format_time(int(_state.best_ms), true)
	else:
		var next_reward: int = Progress.DAILY_REWARDS[days % Progress.DAILY_REWARDS.size()]
		note.text = "Clear today's board for %d coins and keep your streak." % next_reward
	content.add_child(note)
	var play := Button.new()
	play.theme_type_variation = &"HeroButton"
	play.text = "Play again" if bool(_state.done) else "Play today's puzzle"
	play.icon = Icons.PLAY
	play.pressed.connect(close.bind("play"))
	content.add_child(play)
	if bool(_state.done):
		var share := Button.new()
		share.text = "Copy my result"
		share.theme_type_variation = &"GhostButton"
		share.pressed.connect(_share)
		content.add_child(share)
	refit()


func _week_strip() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 14)
	var week: Array = _state.week
	for i in week.size():
		var day := Label.new()
		day.theme_type_variation = &"BadgeLabel" if bool(week[i]) else &"CaptionLabel"
		day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day.custom_minimum_size = Vector2(56, 56)
		day.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var date := HalvesRecords.shift_date(str(_state.date), i - (week.size() - 1))
		var weekday: int = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_datetime_string(date + "T12:00:00"))).weekday
		day.text = ("✓" if bool(week[i]) else WEEKDAYS[weekday].substr(0, 1))
		var dot := PanelContainer.new()
		dot.theme_type_variation = &"BadgePanel"
		if not bool(week[i]):
			dot.modulate = Color(1, 1, 1, 0.35)
		dot.add_child(day)
		row.add_child(dot)
	return row


func _share() -> void:
	DisplayServer.clipboard_set(HalvesRecords.share_line(str(_state.date)))
	UI.toast("Result copied: paste it to your friends")
