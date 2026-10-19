extends Screen
## Level select over the current chapter's print: one section per chapter (a header with a slice of
## its print, stars and Swift medals, tap it to see the whole print) and a grid of level tiles with
## best stars, locks and a ⚡ on levels cleared within par. The next level is scrolled into view.

@export var level_count: int = Progress.LEVEL_COUNT_DEFAULT


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	%Stars.value = Progress.total_stars()
	var next := Progress.next_level(level_count)
	ChapterBackground.install(self, HalvesChapters.index_for_level(next))
	HalvesSfx.menu_music()
	var template: Container = %Grid
	# A blank copy made before any tile is added: every later chapter grid starts from it.
	var blank := template.duplicate() as Container
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override(&"separation", 28)
	var scroll: ScrollContainer = %Scroll
	scroll.add_child(sections)
	var next_tile: LevelTile = null
	for chapter in HalvesChapters.count():
		var first := HalvesChapters.first_level(chapter)
		if first > level_count:
			break
		sections.add_child(_chapter_header(chapter, next))
		var grid := template if chapter == 0 else blank.duplicate() as Container
		if chapter == 0:
			grid.reparent(sections)
		else:
			sections.add_child(grid)
		for level in range(first, mini(HalvesChapters.last_level(chapter), level_count) + 1):
			var tile := _level_tile(level, next)
			grid.add_child(tile)
			if level == next:
				next_tile = tile
	blank.free()
	if next_tile != null:
		await get_tree().process_frame
		scroll.ensure_control_visible(next_tile)


func _level_tile(level: int, next: int) -> LevelTile:
	var tile := LevelTile.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.level = level
	tile.stars = Progress.stars(level)
	tile.locked = not Progress.is_unlocked(level)
	tile.current = level == next
	tile.pressed.connect(_play.bind(level))
	if HalvesRecords.has_swift(HalvesRecords.level_board(level)):
		var bolt := Label.new()
		bolt.text = "⚡"
		bolt.theme_type_variation = &"CaptionLabel"
		bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(bolt)
		bolt.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	return tile


## A tappable header: a slice of the chapter's print, its name and place, stars and medals.
func _chapter_header(chapter: int, next: int) -> Control:
	var info := HalvesChapters.get_chapter(chapter)
	var reached := next >= HalvesChapters.first_level(chapter) or Progress.stars(HalvesChapters.first_level(chapter)) > 0
	var button := Button.new()
	button.theme_type_variation = &"TileButton"
	button.custom_minimum_size = Vector2(0, 176)
	button.disabled = not reached
	button.pressed.connect(_show_print.bind(chapter))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 20)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	var art := TextureRect.new()
	art.texture = load(HalvesChapters.print_path(chapter)) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(120, 0)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = true
	if not reached:
		art.modulate = Color(0.35, 0.35, 0.4)
	row.add_child(art)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name := Label.new()
	name.theme_type_variation = &"HeaderLabel"
	name.text = "%d · %s" % [chapter + 1, info.name]
	text.add_child(name)
	var place := Label.new()
	place.theme_type_variation = &"CaptionLabel"
	place.text = info.place if reached else "Opens at level %d" % HalvesChapters.first_level(chapter)
	text.add_child(place)
	var stars := 0
	var swift := 0
	for level in range(HalvesChapters.first_level(chapter), HalvesChapters.last_level(chapter) + 1):
		stars += Progress.stars(level)
		swift += 1 if HalvesRecords.has_swift(HalvesRecords.level_board(level)) else 0
	var score := Label.new()
	score.theme_type_variation = &"CaptionLabel"
	score.text = "★ %d / %d    ⚡ %d" % [stars, HalvesChapters.LEVELS_PER_CHAPTER * 3, swift]
	text.add_child(score)
	return button


func _show_print(chapter: int) -> void:
	var popup := UI.open(load(Screens.CHAPTER) as PackedScene)
	popup.call(&"setup", chapter, false)


func _play(level: int) -> void:
	Screens.mode = Screens.Mode.LEVELS
	Screens.level = level
	UI.goto(Screens.GAME)
