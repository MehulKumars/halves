extends Modal
## Today's Daily Puzzle, kept short: the number, the streak with a flame, the last 7 days (today
## outlined, cleared days ticked, missed days faded) and Play. Opened from the main menu; closes
## with "play" or null. Finishing the daily pays the streak reward (HalvesRecords.record_daily).

const WEEKDAYS: Array[String] = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

var _state: Dictionary = {}


func _ready() -> void:
	super._ready()
	_state = HalvesRecords.daily_state()
	var content: VBoxContainer = %Content
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Daily Puzzle #%d" % int(_state.number)
	content.add_child(title)
	content.add_child(_streak_row(int(_state.streak)))
	content.add_child(_week_strip())
	var play := Button.new()
	play.theme_type_variation = &"HeroButton"
	play.text = "Play again" if bool(_state.done) else "Play"
	play.icon = Icons.PLAY
	play.pressed.connect(close.bind("play"))
	content.add_child(play)
	refit()


## A flame and "N day streak"; the flame is lit (accent) once there is a streak.
func _streak_row(days: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 10)
	var flame := TextureRect.new()
	flame.texture = Icons.FIRE
	flame.custom_minimum_size = Vector2(44, 44)
	flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if days > 0:
		flame.modulate = get_theme_color(&"accent", &"Tokens")
	else:
		flame.modulate = Color(1, 1, 1, 0.35)
	row.add_child(flame)
	var streak := Label.new()
	streak.theme_type_variation = &"ValueLabel"
	streak.text = "%d day streak" % days
	row.add_child(streak)
	return row


## The last 7 days in two rows (4 over 3) so the strip stays narrow on phones: today outlined,
## cleared days as ticked badges, missed days faded.
func _week_strip() -> Control:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 10)
	var row: HBoxContainer
	var week: Array = _state.week
	for i in week.size():
		if i == 0 or i == 4:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override(&"separation", 14)
			rows.add_child(row)
		var today := i == week.size() - 1
		var done := bool(week[i])
		var day := Label.new()
		day.theme_type_variation = &"BadgeLabel" if done else &""
		day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		day.custom_minimum_size = Vector2(56, 56)
		var date := HalvesRecords.shift_date(str(_state.date), i - (week.size() - 1))
		var weekday: int = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_datetime_string(date + "T12:00:00"))).weekday
		day.text = "✓" if done else WEEKDAYS[weekday].substr(0, 1)
		var dot := PanelContainer.new()
		dot.theme_type_variation = &"BadgePanel"
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if today:
			dot.add_theme_stylebox_override(&"panel", _today_badge(done))
		elif not done:
			dot.modulate = Color(1, 1, 1, 0.35)
		dot.add_child(day)
		row.add_child(dot)
	return rows


## Today's badge: the same pill as the others with an accent ring (filled once it is cleared).
func _today_badge(done: bool) -> StyleBox:
	var badge := get_theme_stylebox(&"panel", &"BadgePanel")
	var flat := badge.duplicate() as StyleBoxFlat
	if flat == null:
		return badge
	flat.set_border_width_all(3)
	flat.border_color = get_theme_color(&"accent", &"Tokens")
	if not done:
		flat.bg_color = get_theme_color(&"surface", &"Tokens")
	return flat
