extends SceneTree
## Renders the app icons from the game's own art (HalvesLogo: a whole circle snapped on an ivory
## card) into assets/icon/: launcher 192, adaptive foreground/background/monochrome 432, splash 512
## and the project icon.png. Needs a window: godot --path . -s tools/art/render_icon.gd

const OUT_DIR: String = "res://assets/icon"
## Android keeps adaptive-icon content inside the middle 66% of the 432 px canvas.
const SAFE: float = 0.62


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var foreground := await _render_logo(432, SAFE)
	var background := _gradient(432)
	_save(foreground, "icon_foreground_432")
	_save(background, "icon_background_432")
	_save(_monochrome(foreground), "icon_monochrome_432")
	_save(_composite(background, await _render_logo(432, 0.74), 192), "icon_main_192")
	_save(await _render_logo(512, 0.7), "icon_splash_512")
	var desktop := _composite(background, await _render_logo(432, 0.74), 256)
	desktop.save_png(ProjectSettings.globalize_path("res://icon.png"))
	print("render_icon: wrote assets/icon/*.png and icon.png")
	quit()


## The mark centred on a transparent square, `fill` of its width.
func _render_logo(size: int, fill: float) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size, size)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var logo := HalvesLogo.new()
	var width := size * fill
	logo.custom_minimum_size = Vector2(width, width * 0.78)
	logo.size = logo.custom_minimum_size
	logo.position = (Vector2(size, size) - logo.size) * 0.5
	viewport.add_child(logo)
	for i in 4:
		await process_frame
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _gradient(size: int) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var top := HalvesPalette.COBALT.lightened(0.08)
	var bottom := HalvesPalette.SIDE
	for y in size:
		var row := top.lerp(bottom, float(y) / (size - 1))
		for x in size:
			image.set_pixel(x, y, row)
	return image


## White where the mark is, transparent elsewhere (Android tints it for themed icons).
func _monochrome(image: Image) -> Image:
	var out := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			out.set_pixel(x, y, Color(1, 1, 1, image.get_pixel(x, y).a))
	return out


func _composite(background: Image, foreground: Image, size: int) -> Image:
	var out := background.duplicate() as Image
	out.blend_rect(foreground, Rect2i(Vector2i.ZERO, foreground.get_size()), Vector2i.ZERO)
	out.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return out


func _save(image: Image, name: String) -> void:
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, name]))
