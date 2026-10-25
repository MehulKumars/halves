extends Screen
## The Crest Book: one page per place, its levels' crests (HalvesCrestBook) restored on ivory cards
## or waiting as faint outlines. Pages of places not reached yet show only their name and a lock.
## Opened from the journey map; Back returns there.


func _ready() -> void:
	back_scene = Screens.LEVEL_SELECT
	%BackButton.pressed.connect(on_back)
	var next := Progress.next_level()
	ChapterBackground.install(self, HalvesChapters.index_for_level(next), true, 0.5, false,
		HalvesChapters.half_for_level(next))
	var pages: VBoxContainer = %Pages
	var summary := Label.new()
	summary.theme_type_variation = &"CaptionLabel"
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.text = "%d of %d crests restored" % [HalvesCrestBook.restored_total(), HalvesLevels.count()]
	pages.add_child(summary)
	for chapter in HalvesChapters.count():
		var first := HalvesChapters.first_level(chapter)
		if first > HalvesLevels.count():
			break
		pages.add_child(_page_title(chapter))
		if next < first and not Settings.dev_mode():
			continue
		var grid := AdaptiveGridContainer.new()
		grid.min_cell_width = 120.0
		grid.max_columns = 5
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pages.add_child(grid)
		for level in range(first, mini(HalvesChapters.last_level(chapter), HalvesLevels.count()) + 1):
			var card := HalvesCrestCard.new()
			card.level = level
			card.pair = HalvesCrestBook.signature_pair(level)
			card.restored = HalvesCrestBook.is_restored(level)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(card)


func _page_title(chapter: int) -> Label:
	var info := HalvesChapters.get_chapter(chapter)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	var open := Progress.next_level() >= HalvesChapters.first_level(chapter) or Settings.dev_mode()
	title.text = "%s   %d / %d" % [info.name, HalvesCrestBook.restored_on_page(chapter), HalvesChapters.LEVELS_PER_CHAPTER] \
			if open else "%s   🔒" % info.name
	if not open:
		title.modulate = Color(1, 1, 1, 0.6)
	return title
