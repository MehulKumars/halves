extends Modal
## Ranks: the player's own stats and records (Swift medals, rush best, daily streak) and a star
## leaderboard with the player's row highlighted.
## Until Google Play Games is connected the board shows sample players, labelled as such. With
## Play Games, the main menu opens Google's own leaderboard screen instead (has_native_ui()).

const BOARD_ID: String = "stars"
const SAMPLE_PLAYERS: Array[Array] = [
	["Aiko", 64], ["Mateo", 58], ["Priya", 51], ["Lukas", 44], ["Zara", 37],
	["Kenji", 29], ["Sofia", 22], ["Omar", 15], ["Lena", 9],
]


func _ready() -> void:
	super._ready()
	%CloseButton.pressed.connect(close)
	%StarsValue.text = str(Progress.total_stars())
	%LevelsValue.text = str(Progress.levels_won())
	%CoinsValue.text = CurrencyPill.format_number(Progress.coins())
	_build_records()
	_build_board(Progress.total_stars())
	refit()


## A second row of records under the stats, and a word on friends' boards.
func _build_records() -> void:
	var stats: HBoxContainer = %StarsValue.get_parent().get_parent().get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", stats.get_theme_constant(&"separation"))
	var daily := HalvesRecords.daily_state()
	for entry: Array in [[str(HalvesRecords.swift_count()), "Swift ⚡"], [str(HalvesRecords.rush_best()), "Rush best"],
			[str(int(daily.streak)), "Daily streak"]]:
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"TilePanel"
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		tile.add_child(box)
		var value := Label.new()
		value.theme_type_variation = &"ValueLabel"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.text = entry[0]
		box.add_child(value)
		var caption := Label.new()
		caption.theme_type_variation = &"CaptionLabel"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text = entry[1]
		box.add_child(caption)
		row.add_child(tile)
	stats.get_parent().add_child(row)
	stats.get_parent().move_child(row, stats.get_index() + 1)
	var note := Label.new()
	note.theme_type_variation = &"CaptionLabel"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Friends' boards are coming. Your best times keep their moves, so they can be checked."
	stats.get_parent().add_child(note)
	stats.get_parent().move_child(note, row.get_index() + 1)


func _build_board(my_score: int) -> void:
	var rows: Array[Array] = []
	for entry in SAMPLE_PLAYERS:
		rows.append([entry[0], entry[1], false])
	rows.append(["You", my_score, true])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[2]))
	var gold := get_theme_color(&"gold", &"Tokens")
	for i in rows.size():
		var mine: bool = rows[i][2]
		var row := PanelContainer.new()
		row.theme_type_variation = &"HighlightPanel" if mine else &"TilePanel"
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 16)
		row.add_child(line)
		var rank := Label.new()
		rank.theme_type_variation = &"ValueLabel"
		rank.text = str(i + 1)
		rank.custom_minimum_size.x = 56
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(rank)
		var name := Label.new()
		name.text = rows[i][0]
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(name)
		var star := TextureRect.new()
		star.texture = Icons.STAR
		star.modulate = gold
		star.custom_minimum_size = Vector2(36, 36)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(star)
		var score := Label.new()
		score.theme_type_variation = &"ValueLabel"
		score.text = str(rows[i][1])
		score.custom_minimum_size.x = 64
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(score)
		%Board.add_child(row)
