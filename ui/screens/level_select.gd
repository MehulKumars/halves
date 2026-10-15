extends Screen
## Level select: a grid of tiles with best stars and locks, 4 columns on phones and up to 6
## on tablets. The next level to play is highlighted and scrolled into view. Tap to play.

@export var level_count: int = Progress.LEVEL_COUNT_DEFAULT


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	%Stars.value = Progress.total_stars()
	var next := Progress.next_level(level_count)
	var next_tile: LevelTile = null
	for level in range(1, level_count + 1):
		var tile := LevelTile.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%Grid.add_child(tile)
		tile.level = level
		tile.stars = Progress.stars(level)
		tile.locked = not Progress.is_unlocked(level)
		tile.current = level == next
		tile.pressed.connect(_play.bind(level))
		if level == next:
			next_tile = tile
	if next_tile != null:
		await get_tree().process_frame
		(%Scroll as ScrollContainer).ensure_control_visible(next_tile)


func _play(level: int) -> void:
	Screens.level = level
	UI.goto(Screens.GAME)
