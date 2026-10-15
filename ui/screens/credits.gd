extends Screen
## Credits, built from ATTRIBUTION.md by Maaack's credits label (markdown headings, links,
## images). Keep ATTRIBUTION.md and ASSETS_LICENSES.md complete; the export presets include it.


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	%CreditsText.meta_clicked.connect(func(meta: Variant) -> void: OS.shell_open(str(meta)))
