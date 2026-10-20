extends SceneTree
## Renders every drawn place (HalvesScenery) at phone size to build/scenery/<id>.png and a contact
## sheet, so the code-drawn backgrounds can be reviewed next to the photos. Needs a window.
## Usage: godot --path . -s tools/art/preview_scenery.gd [-- <id> ...]

const SIZE := Vector2i(720, 1600)
const OUT: String = "build/scenery"


func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	for attempt in 5:
		root.size = SIZE
		for i in 3:
			await process_frame
		if root.size == SIZE:
			break
	var out := ProjectSettings.globalize_path("res://").path_join(OUT)
	DirAccess.make_dir_recursive_absolute(out)
	var ids: Array = [HalvesChapters.MENU.id]
	for chapter: Dictionary in HalvesChapters.CHAPTERS:
		ids.append(chapter.id)
	var shots: Array[Image] = []
	for id: String in ids:
		if not only.is_empty() and not only.has(id):
			continue
		var scenery := HalvesScenery.new()
		root.add_child(scenery)
		scenery.set_scene(id)
		for i in 6:
			await process_frame
		var image := root.get_texture().get_image()
		image.save_png(out.path_join("%s.png" % id))
		image.resize(SIZE.x / 4, SIZE.y / 4, Image.INTERPOLATE_LANCZOS)
		shots.append(image)
		scenery.queue_free()
		await process_frame
	if shots.size() > 1:
		var w := SIZE.x / 4
		var h := SIZE.y / 4
		var sheet := Image.create_empty(w * mini(6, shots.size()), h * ceili(shots.size() / 6.0), false, Image.FORMAT_RGBA8)
		for i in shots.size():
			shots[i].convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 6) * w, (i / 6) * h))
		sheet.save_png(out.path_join("contact.png"))
	print("preview_scenery: %d places -> %s" % [shots.size(), out])
	quit()
