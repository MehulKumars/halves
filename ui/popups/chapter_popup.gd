extends Modal
## A chapter's print, full colour, with its title and credit: shown when a chapter is completed
## (and from the level select). setup(chapter, completed) fills it; closes with "next" or null.
## The print comes from tools/art (Hiroshige, public domain); stars and medals are summed here.

var _chapter: int = 0


func _ready() -> void:
	super._ready()


func setup(chapter: int, completed: bool) -> void:
	_chapter = chapter
	var info := HalvesChapters.get_chapter(chapter)
	var content: VBoxContainer = %Content
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = ("%s complete" if completed else "%s") % info.name
	content.add_child(title)
	var print_art := TextureRect.new()
	print_art.texture = load(HalvesChapters.print_path(chapter)) as Texture2D
	print_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	print_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	print_art.custom_minimum_size = Vector2(0, 600)
	content.add_child(print_art)
	var caption := Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text = "%s, %s" % [info.title, info.year]
	content.add_child(caption)
	var credit := Label.new()
	credit.theme_type_variation = &"CaptionLabel"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit.text = "%s · %s · %s" % [HalvesChapters.ARTIST, HalvesChapters.SERIES, info.collection]
	content.add_child(credit)
	var stats := Label.new()
	stats.theme_type_variation = &"OnBgLabel"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.text = _stats_text(chapter)
	content.add_child(stats)
	var button := Button.new()
	button.theme_type_variation = &"HeroButton"
	var next := chapter + 1
	button.text = "On to %s" % HalvesChapters.get_chapter(next).name if completed and next < HalvesChapters.count() else "Continue"
	button.pressed.connect(close.bind("next"))
	content.add_child(button)
	refit()
	if completed:
		Haptics.big()
		HalvesSfx.play(&"chapter")
		HalvesSfx.duck(2.0)
	if Juice.motion_scale > 0.0:
		print_art.modulate.a = 0.0
		print_art.pivot_offset_ratio = Vector2(0.5, 0.5)
		print_art.scale = Vector2.ONE * 0.94
		var tween := print_art.create_tween().set_parallel()
		tween.tween_property(print_art, ^"modulate:a", 1.0, 0.6).set_delay(0.15)
		tween.tween_property(print_art, ^"scale", Vector2.ONE, 0.9).set_delay(0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _stats_text(chapter: int) -> String:
	var stars := 0
	var swift := 0
	for level in range(HalvesChapters.first_level(chapter), HalvesChapters.last_level(chapter) + 1):
		stars += Progress.stars(level)
		swift += 1 if HalvesRecords.has_swift(HalvesRecords.level_board(level)) else 0
	return "★ %d / %d     ⚡ %d / %d" % [stars, HalvesChapters.LEVELS_PER_CHAPTER * 3, swift,
			HalvesChapters.LEVELS_PER_CHAPTER]
