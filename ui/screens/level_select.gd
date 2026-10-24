extends Screen
## The journey map over the current place's photo: one stretch per place, a header card (thumbnail,
## name, stars and Swift medals; tap it for the photo) and, once the place is reached, its levels as
## stepping stones on a winding trail (JourneyPath). Places not reached yet show only a locked card,
## so the map grows with the player. The next level is scrolled into view; dev mode opens all.

@export var level_count: int = Progress.LEVEL_COUNT_DEFAULT


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	%Stars.value = Progress.total_stars()
	var next := Progress.next_level(level_count)
	ChapterBackground.install(self, HalvesChapters.index_for_level(next), true, 0.6)
	HalvesMusic.play()
	%Grid.queue_free()
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override(&"separation", 12)
	var scroll: ScrollContainer = %Scroll
	scroll.add_child(sections)
	sections.add_child(_book_card())
	var next_tile: LevelTile = null
	for chapter in HalvesChapters.count():
		var first := HalvesChapters.first_level(chapter)
		if first > level_count:
			break
		var reached := _reached(chapter, next)
		sections.add_child(_chapter_header(chapter, reached))
		if not reached:
			continue
		var path := JourneyPath.new()
		path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sections.add_child(path)
		path.build(first, mini(HalvesChapters.last_level(chapter), level_count), next, chapter * 1.7, _level_tile)
		if path.tile_for(next) != null:
			next_tile = path.tile_for(next)
	if next_tile != null:
		await get_tree().process_frame
		scroll.ensure_control_visible(next_tile)
		_breathe(next_tile)


## The Crest Book's card at the top of the map: how many crests the journey has restored.
func _book_card() -> Button:
	var button := Button.new()
	button.theme_type_variation = &"TileButton"
	button.custom_minimum_size = Vector2(0, 104)
	button.icon = Icons.STAR
	button.text = "Crest Book  ·  %d of %d restored" % [HalvesCrestBook.restored_total(), HalvesLevels.count()]
	button.pressed.connect(UI.goto.bind(Screens.CREST_BOOK))
	return button


## The next level's stone breathes gently, so the eye finds it (off with Reduce Motion).
func _breathe(tile: LevelTile) -> void:
	if Juice.motion_scale <= 0.0:
		return
	tile.pivot_offset_ratio = Vector2(0.5, 0.5)
	var breathe := tile.create_tween().set_loops()
	breathe.tween_property(tile, ^"scale", Vector2.ONE * 1.06, 0.7).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(tile, ^"scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)


## A place is open once its first level is the next one or already won (or in dev mode).
func _reached(chapter: int, next: int) -> bool:
	var first := HalvesChapters.first_level(chapter)
	return Settings.dev_mode() or next >= first or Progress.stars(first) > 0


func _level_tile(level: int, next: int) -> LevelTile:
	var tile := LevelTile.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.level = level
	tile.stars = Progress.stars(level)
	tile.locked = not (Progress.is_unlocked(level) or Settings.dev_mode())
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


## A tappable card: the place's thumbnail, its number and name, then stars and medals (or how to
## open it).
func _chapter_header(chapter: int, reached: bool) -> Control:
	var info := HalvesChapters.get_chapter(chapter)
	var button := Button.new()
	button.theme_type_variation = &"TileButton"
	button.custom_minimum_size = Vector2(0, 132 if reached else 100)
	button.pressed.connect(_on_header.bind(chapter, reached))
	if not reached:
		button.modulate = Color(1, 1, 1, 0.72)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 20)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	var art := TextureRect.new()
	art.texture = load(HalvesChapters.thumb_path(chapter)) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(108, 108) if reached else Vector2(76, 76)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not reached:
		art.modulate = Color(0.45, 0.45, 0.5)
	row.add_child(art)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override(&"separation", 2)
	row.add_child(text)
	var name := Label.new()
	name.theme_type_variation = &"HeaderLabel" if reached else &""
	name.text = info.name
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	text.add_child(name)
	var line := Label.new()
	line.theme_type_variation = &"CaptionLabel"
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var first := HalvesChapters.first_level(chapter)
	var last := HalvesChapters.last_level(chapter)
	if reached:
		var stars := 0
		var swift := 0
		for level in range(first, last + 1):
			stars += Progress.stars(level)
			swift += 1 if HalvesRecords.has_swift(HalvesRecords.level_board(level)) else 0
		line.text = "Levels %d–%d   ★ %d/%d   ⚡ %d" % [first, last, stars, HalvesChapters.LEVELS_PER_CHAPTER * 3, swift]
	else:
		line.text = "Clear level %d to open" % (first - 1)
	text.add_child(line)
	if not reached:
		var lock := TextureRect.new()
		lock.texture = Icons.LOCK
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.custom_minimum_size = Vector2(44, 44)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.modulate = get_theme_color(&"text_muted", &"Tokens")
		row.add_child(lock)
	return button


func _on_header(chapter: int, reached: bool) -> void:
	if not reached:
		UI.toast("%s opens after level %d" % [HalvesChapters.get_chapter(chapter).name,
				HalvesChapters.first_level(chapter) - 1], Icons.LOCK)
		return
	var popup := UI.open(load(Screens.CHAPTER) as PackedScene)
	popup.call(&"setup", chapter, false)


func _play(level: int) -> void:
	Screens.mode = Screens.Mode.LEVELS
	Screens.level = level
	UI.goto(Screens.GAME)
