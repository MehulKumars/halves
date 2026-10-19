extends SceneTree
## Bakes the chapter images from the downloaded prints (tools/art/src/, see fetch_prints.ps1):
## assets/chapters/<id>_bg.webp, a softened, dusk-washed background with the vignette baked in (no
## runtime overlay), and <id>_print.webp, the full-colour print for the chapter reveal.
## Usage: godot --headless --path . -s tools/art/process_prints.gd

const LIST_PATH: String = "res://tools/art/prints.json"
const SRC_DIR: String = "res://tools/art/src"
const OUT_DIR: String = "res://assets/chapters"
## Background height in pixels; the width follows the print (about 2:3), so screens of any shape
## can cover-crop it around the print's focus point.
const BG_HEIGHT: int = 1640
const PRINT_WIDTH: int = 720
## How far the background is washed toward the chapter tint, and how dark the edges get.
const WASH: float = 0.42
const DIM: float = 0.62
const VIGNETTE: float = 0.35


func _initialize() -> void:
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIST_PATH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for p: Dictionary in list.prints:
		var src := "%s/%s.jpg" % [SRC_DIR, p.id]
		var image := Image.load_from_file(ProjectSettings.globalize_path(src))
		if image == null or image.is_empty():
			printerr("process_prints: missing %s (run tools/art/fetch_prints.ps1)" % src)
			quit(1)
			return
		image.convert(Image.FORMAT_RGB8)
		var inner: Array = p.inner
		var region := Rect2i(
			roundi(image.get_width() * float(inner[0])), roundi(image.get_height() * float(inner[1])),
			roundi(image.get_width() * (float(inner[2]) - float(inner[0]))),
			roundi(image.get_height() * (float(inner[3]) - float(inner[1]))))
		var art := image.get_region(region)
		var print_image := art.duplicate() as Image
		print_image.resize(PRINT_WIDTH, roundi(PRINT_WIDTH * float(art.get_height()) / art.get_width()), Image.INTERPOLATE_LANCZOS)
		print_image.save_webp(ProjectSettings.globalize_path("%s/%s_print.webp" % [OUT_DIR, p.id]), true, 0.9)
		var bg := _background(art, Color.html(str(p.tint)))
		bg.save_webp(ProjectSettings.globalize_path("%s/%s_bg.webp" % [OUT_DIR, p.id]), true, 0.85)
		print("process_prints: %s -> bg %dx%d, print %dx%d" % [p.id, bg.get_width(), bg.get_height(),
				print_image.get_width(), print_image.get_height()])
	quit()


## Soft focus (down then up), a little less saturation, then a wash toward `tint`, a dim and a
## vignette, so ivory tiles and text stay readable over any part of the print.
func _background(art: Image, tint: Color) -> Image:
	var width := roundi(BG_HEIGHT * float(art.get_width()) / art.get_height())
	var bg := art.duplicate() as Image
	bg.resize(width / 3, BG_HEIGHT / 3, Image.INTERPOLATE_LANCZOS)
	bg.resize(width, BG_HEIGHT, Image.INTERPOLATE_CUBIC)
	bg.adjust_bcs(1.0, 0.92, 0.85)
	var centre := Vector2(width, BG_HEIGHT) * 0.5
	var reach := centre.length()
	for y in BG_HEIGHT:
		for x in width:
			var c := bg.get_pixel(x, y).lerp(tint, WASH)
			var edge := clampf(Vector2(x, y).distance_to(centre) / reach, 0.0, 1.0)
			var shade := DIM * (1.0 - VIGNETTE * edge * edge)
			bg.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade))
	return bg
