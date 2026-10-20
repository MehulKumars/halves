class_name ChapterBackground
extends Control
## The place behind a screen: the chapter's photo (one opaque cover-cropped draw, dimmed by its
## modulate, so no overlay layer) or the same place drawn in code (HalvesScenery), as the player
## chose in Settings; plus ambient particles. Screens call install(), which hides "Background".

## The home screen's own place (HalvesChapters.MENU).
const MENU: int = -1
const STYLE_KEY: String = "Backgrounds"
const STYLES: Array[String] = ["photo", "drawn"]
## Ambient particles at most; off when Reduce Motion is on.
const MAX_PARTICLES: int = 30
## Menus drift: a zoom of this much, there and back over DRIFT_SECONDS.
const DRIFT_ZOOM: float = 0.04
const DRIFT_SECONDS: float = 60.0

## The one photo kept loaded between screens.
static var _loaded_path: String = ""
static var _loaded_texture: Texture2D
static var _particle_textures: Dictionary[String, Texture2D] = {}

var chapter: int = -2
var ambient_enabled: bool = true
## 1 = full brightness; gameplay dims so the tiles stand out.
var dim: float = 1.0
## Darkens the top and bottom edges a little for titles and buttons (menus).
var scrim: bool = false
## A slow zoom so a menu's photo is never quite still.
var drift: bool = false
var _texture: Texture2D
var _scenery: HalvesScenery
var _scrim: Control
var _particles: CPUParticles2D
var _time: float = 0.0


func _init() -> void:
	name = "ChapterBackground"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	add_to_group(&"chapter_backgrounds")
	_scrim = Control.new()
	_scrim.name = "Scrim"
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.draw.connect(_draw_scrim)
	add_child(_scrim)


## Puts `chapter_index`'s place (MENU for the home screen) behind `screen`'s content and hides
## its "Background" node.
static func install(screen: Control, chapter_index: int, ambient: bool = true, dim_to: float = 1.0,
		menu_look: bool = false) -> ChapterBackground:
	var bg := ChapterBackground.new()
	bg.ambient_enabled = ambient
	bg.dim = dim_to
	bg.scrim = menu_look
	bg.drift = menu_look
	var old := screen.get_node_or_null("Background") as CanvasItem
	var at := 0
	if old != null:
		old.visible = false
		at = old.get_index() + 1
	screen.add_child(bg)
	screen.move_child(bg, at)
	bg.set_chapter(chapter_index)
	return bg


## "photo" or "drawn" (Settings).
static func style() -> String:
	var id := Settings.choice(STYLE_KEY, STYLES[0])
	return id if STYLES.has(id) else STYLES[0]


## Saves the choice and redraws every background on screen.
static func set_style(id: String) -> void:
	Settings.set_choice(STYLE_KEY, id)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.call_group(&"chapter_backgrounds", &"refresh")


## Starts loading a chapter's photo on a thread (call before it is needed).
static func preload_chapter(chapter_index: int) -> void:
	var path := HalvesChapters.photo_path(chapter_index)
	if style() == "photo" and path != _loaded_path and ResourceLoader.exists(path):
		ResourceLoader.load_threaded_request(path)


func set_chapter(chapter_index: int) -> void:
	if chapter_index == chapter:
		return
	chapter = chapter_index
	refresh()


## Rebuilds for the current style (after Settings changes it).
func refresh() -> void:
	var id: String = HalvesChapters.get_chapter(chapter).id
	if style() == "drawn" and HalvesScenery.has_scene(id):
		_texture = null
		if _scenery == null:
			_scenery = HalvesScenery.new()
			add_child(_scenery)
			move_child(_scenery, 0)
		_scenery.set_scene(id)
		_scenery.modulate = Color(dim, dim, dim)
	else:
		if _scenery != null:
			_scenery.queue_free()
			_scenery = null
		_texture = _load(HalvesChapters.photo_path(chapter))
	set_process(drift and _texture != null and Juice.motion_scale > 0.0)
	queue_redraw()
	_scrim.queue_redraw()
	_build_ambient()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		_fit_ambient()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _scenery != null:
		return
	var info := HalvesChapters.get_chapter(chapter)
	if _texture == null:
		draw_rect(Rect2(Vector2.ZERO, size), info.tint)
		return
	var tex_size := _texture.get_size()
	var zoom := 1.0 + DRIFT_ZOOM * (0.5 - 0.5 * cos(TAU * _time / DRIFT_SECONDS)) if drift else 1.0
	var fit := maxf(size.x / tex_size.x, size.y / tex_size.y) * zoom
	var view := size / fit
	var focus: Vector2 = info.focus
	var origin := (tex_size * focus - view * 0.5).clamp(Vector2.ZERO, tex_size - view)
	draw_texture_rect_region(_texture, Rect2(Vector2.ZERO, size), Rect2(origin, view), Color(dim, dim, dim))


## Menus: a soft shade under the title at the top and the buttons at the bottom (not full screen).
func _draw_scrim() -> void:
	if not scrim:
		return
	var top := HalvesScenery.gradient([Color(0, 0, 0, 0.42), Color(0, 0, 0, 0.0)])
	var bottom := HalvesScenery.gradient([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.5)])
	_scrim.draw_texture_rect(top, Rect2(0, 0, size.x, size.y * 0.32), false)
	_scrim.draw_texture_rect(bottom, Rect2(0, size.y * 0.55, size.x, size.y * 0.45), false)


static func _load(path: String) -> Texture2D:
	if path == _loaded_path and _loaded_texture != null:
		return _loaded_texture
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		texture = ResourceLoader.load_threaded_get(path) as Texture2D
	if texture == null:
		texture = load(path) as Texture2D
	_loaded_path = path
	_loaded_texture = texture
	return texture


func _build_ambient() -> void:
	if _particles != null:
		_particles.queue_free()
		_particles = null
	if not ambient_enabled or Juice.motion_scale <= 0.0:
		return
	var info := HalvesChapters.get_chapter(chapter)
	var kind: String = info.ambient
	var colour: Color = info.get("ambient_color", Color.WHITE)
	var p := CPUParticles2D.new()
	p.texture = particle_texture(kind)
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.spread = 25.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	match kind:
		"rain":
			_setup(p, 24, 1.3, Vector2(-0.22, 1.0), 650.0, 850.0, Vector2.ZERO, colour)
			p.particle_flag_align_y = true
			p.spread = 2.0
		"snow":
			_setup(p, MAX_PARTICLES, 14.0, Vector2(0.1, 1.0), 20.0, 45.0, Vector2(4, 6), colour)
			p.spread = 40.0
		"fireflies", "motes":
			var slow := kind == "motes"
			_setup(p, 16 if slow else 14, 9.0 if slow else 7.0, Vector2(0.2, 1.0) if slow else Vector2(0, -1),
				4.0 if slow else 6.0, 12.0 if slow else 18.0, Vector2(0, 1) if slow else Vector2(0, -2), colour)
			p.spread = 180.0
			p.scale_amount_min = 0.35 if slow else 0.6
			p.scale_amount_max = 0.9 if slow else 1.2
			var ramp := Gradient.new()
			ramp.set_color(0, Color(1, 1, 1, 0))
			ramp.set_color(1, Color(1, 1, 1, 0))
			ramp.add_point(0.3, Color(1, 1, 1, 1))
			ramp.add_point(0.7, Color(1, 1, 1, 0.8))
			p.color_ramp = ramp
		"leaves":
			_setup(p, 10, 11.0, Vector2(0.35, 1.0), 25.0, 50.0, Vector2(6, 14), colour)
			p.angular_velocity_min = -90.0
			p.angular_velocity_max = 90.0
			p.angle_min = 0.0
			p.angle_max = 360.0
		_:
			_setup(p, 14, 10.0, Vector2(0.4, 1.0), 20.0, 40.0, Vector2(5, 10), colour)
			p.angular_velocity_min = -70.0
			p.angular_velocity_max = 70.0
			p.angle_min = 0.0
			p.angle_max = 360.0
	_particles = p
	add_child(p)
	_fit_ambient()


func _setup(p: CPUParticles2D, amount: int, lifetime: float, direction: Vector2, speed_min: float,
		speed_max: float, gravity: Vector2, colour: Color) -> void:
	p.amount = mini(amount, MAX_PARTICLES)
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.direction = direction
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = gravity
	p.color = colour


## Particles fall in from above the top edge (fireflies and motes drift from anywhere).
func _fit_ambient() -> void:
	if _particles == null:
		return
	var kind: String = HalvesChapters.get_chapter(chapter).ambient
	if kind == "fireflies" or kind == "motes":
		_particles.position = global_position + size * 0.5
		_particles.emission_rect_extents = size * 0.5
	else:
		_particles.position = global_position + Vector2(size.x * 0.5, -20.0)
		_particles.emission_rect_extents = Vector2(size.x * 0.6, 10.0)


## Tiny textures drawn in code once: a petal, a rain streak, a leaf, a snowflake, a glow.
static func particle_texture(kind: String) -> Texture2D:
	if kind == "motes":
		kind = "fireflies"
	if _particle_textures.has(kind):
		return _particle_textures[kind]
	var image: Image
	match kind:
		"rain":
			image = Image.create_empty(3, 34, false, Image.FORMAT_RGBA8)
			for y in 34:
				for x in 3:
					image.set_pixel(x, y, Color(1, 1, 1, (1.0 - absf(x - 1.0)) * float(y) / 34.0))
		"snow", "fireflies":
			var r := 6.0 if kind == "snow" else 9.0
			var n := int(r * 2)
			image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
			for y in n:
				for x in n:
					var d := Vector2(x + 0.5 - r, y + 0.5 - r).length() / r
					var a := clampf(1.0 - d, 0.0, 1.0)
					image.set_pixel(x, y, Color(1, 1, 1, a * a if kind == "fireflies" else smoothstep(0.0, 0.5, a)))
		"leaves":
			image = Image.create_empty(18, 18, false, Image.FORMAT_RGBA8)
			for y in 18:
				for x in 18:
					var v := Vector2(x + 0.5 - 9.0, y + 0.5 - 9.0)
					var lobes := 6.5 + 2.5 * cos(5.0 * v.angle())
					image.set_pixel(x, y, Color(1, 1, 1, clampf(lobes - v.length(), 0.0, 1.0)))
		_:
			image = Image.create_empty(14, 10, false, Image.FORMAT_RGBA8)
			for y in 10:
				for x in 14:
					var v := Vector2((x + 0.5 - 7.0) / 7.0, (y + 0.5 - 5.0) / 5.0)
					image.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - v.length()) * 3.0, 0.0, 1.0)))
	var texture := ImageTexture.create_from_image(image)
	_particle_textures[kind] = texture
	return texture
