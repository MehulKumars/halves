extends Modal
## A place's picture, full size, with its name and the photo credit: shown when its ten levels are
## completed (and from the level select). setup(chapter, completed) fills it; closes with "next" or
## null. The photo (or its drawn version) follows the Backgrounds setting; stars and medals summed here.

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
	var drawn := ChapterBackground.style() == "drawn" and HalvesScenery.has_scene(HalvesChapters.scene_id(chapter))
	var picture: Control
	if drawn:
		var scenery := HalvesScenery.new()
		scenery.set_scene(HalvesChapters.scene_id(chapter))
		picture = scenery
	else:
		var photo := TextureRect.new()
		photo.texture = load(HalvesChapters.photo_path(chapter)) as Texture2D
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.clip_contents = true
		picture = photo
	picture.custom_minimum_size = Vector2(0, 600)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(picture)
	var caption := Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text = info.place
	content.add_child(caption)
	if not drawn:
		var credit := Label.new()
		credit.theme_type_variation = &"CaptionLabel"
		credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		credit.text = HalvesChapters.credit_line(chapter)
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
		picture.modulate.a = 0.0
		picture.pivot_offset_ratio = Vector2(0.5, 0.5)
		picture.scale = Vector2.ONE * 0.94
		var tween := picture.create_tween().set_parallel()
		tween.tween_property(picture, ^"modulate:a", 1.0, 0.6).set_delay(0.15)
		tween.tween_property(picture, ^"scale", Vector2.ONE, 0.9).set_delay(0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _stats_text(chapter: int) -> String:
	var stars := 0
	var swift := 0
	for level in range(HalvesChapters.first_level(chapter), HalvesChapters.last_level(chapter) + 1):
		stars += Progress.stars(level)
		swift += 1 if HalvesRecords.has_swift(HalvesRecords.level_board(level)) else 0
	return "★ %d / %d     ⚡ %d / %d" % [stars, HalvesChapters.LEVELS_PER_CHAPTER * 3, swift,
			HalvesChapters.LEVELS_PER_CHAPTER]
