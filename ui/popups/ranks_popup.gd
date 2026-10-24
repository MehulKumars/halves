extends Modal
## Records: the player's own stats and bests (stars, levels, coins, Swift medals, rush best,
## daily streak). Opened from the main menu. Halves v1 has no online leaderboard, so nothing
## here is anyone else's.


func _ready() -> void:
	super._ready()
	%CloseButton.pressed.connect(close)
	%StarsValue.text = str(Progress.total_stars())
	%LevelsValue.text = str(Progress.levels_won())
	%CoinsValue.text = CurrencyPill.format_number(Progress.coins())
	_build_records()
	refit()


## A second row of records under the stats.
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
