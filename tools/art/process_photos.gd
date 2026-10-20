extends SceneTree
## Bakes the background photos (tools/art/src/photos/, see fetch_photos.ps1) into
## assets/backgrounds/<id>.webp, a sharp 1440x2880 portrait crop around the photo's focus (no blur or
## tint: screens dim it at run time), and <id>_thumb.webp, a 320 px square for the level select.
## Usage: godot --headless --path . -s tools/art/process_photos.gd [-- <id> ...]

const LIST_PATH: String = "res://tools/art/photos.json"
const SRC_DIR: String = "res://tools/art/src/photos"
const OUT_DIR: String = "res://assets/backgrounds"
## 1.5x the 720 x 1920 canvas of a tall phone: a 1080 x 2400 screen shows it at or under 1:1.
const SIZE := Vector2i(1440, 2880)
const THUMB: int = 320
## Source quality of the baked files; the import re-encodes them (Lossy WebP, see the .import files).
const QUALITY: float = 0.95


func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIST_PATH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for p: Dictionary in list.photos:
		if not only.is_empty() and not only.has(str(p.id)):
			continue
		var src := "%s/%s.jpg" % [SRC_DIR, p.id]
		var image := Image.load_from_file(ProjectSettings.globalize_path(src))
		if image == null or image.is_empty():
			printerr("process_photos: missing %s (run tools/art/fetch_photos.ps1)" % src)
			quit(1)
			return
		image.convert(Image.FORMAT_RGB8)
		var focus := Vector2(float(p.focus[0]), float(p.focus[1]))
		var crop := _portrait(image.get_size(), focus)
		var bg := image.get_region(crop)
		bg.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		bg.save_webp(ProjectSettings.globalize_path("%s/%s.webp" % [OUT_DIR, p.id]), true, QUALITY)
		var side := crop.size.x
		var centre := Vector2(crop.get_center().x, image.get_height() * focus.y)
		var square := Rect2i(Vector2i(centre - Vector2(side, side) * 0.5), Vector2i(side, side))
		square.position = square.position.clamp(Vector2i.ZERO, image.get_size() - square.size)
		var thumb := image.get_region(square)
		thumb.resize(THUMB, THUMB, Image.INTERPOLATE_LANCZOS)
		thumb.save_webp(ProjectSettings.globalize_path("%s/%s_thumb.webp" % [OUT_DIR, p.id]), true, 0.9)
		print("process_photos: %s %s -> crop %s" % [p.id, image.get_size(), crop])
	quit()


## The largest 1:2 region of `size` around `focus` (0..1 on each axis).
static func _portrait(size: Vector2i, focus: Vector2) -> Rect2i:
	var aspect := float(SIZE.x) / SIZE.y
	var w := size.x
	var h := size.y
	if float(w) / h > aspect:
		w = roundi(h * aspect)
	else:
		h = roundi(w / aspect)
	return Rect2i(roundi((size.x - w) * focus.x), roundi((size.y - h) * focus.y), w, h)
