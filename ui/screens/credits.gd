extends Screen
## Credits from ATTRIBUTION.md (Maaack's credits label turns the markdown into text), then the
## licence texts the shipped code requires: Godot's MIT licence and its third-party parts, and
## the MIT licence of Maaack's template. Links are shown as plain text, so a tap never opens a
## browser by accident.

const MAAACK_LICENSE: String = "res://LICENSE.txt"


func _ready() -> void:
	back_scene = Screens.MAIN_MENU
	%BackButton.pressed.connect(on_back)
	var label: RichTextLabel = %CreditsText
	label.append_text("\n\n" + _licences())


## Licence notices. The font (OFL) and icon (Apache) licence files ship in the app as well.
func _licences() -> String:
	var lines: PackedStringArray = ["[font_size=40][b]Licences[/b][/font_size]", ""]
	lines.append("[b]Godot Engine[/b]")
	lines.append("[font_size=22]%s[/font_size]" % _unwrap(Engine.get_license_text()))
	lines.append("")
	if FileAccess.file_exists(MAAACK_LICENSE):
		lines.append("[b]Godot Game Template (Maaack)[/b]")
		lines.append("[font_size=22]%s[/font_size]" % _unwrap(FileAccess.get_file_as_string(MAAACK_LICENSE)))
		lines.append("")
	lines.append("[b]Parts of Godot Engine[/b]")
	var parts: PackedStringArray = []
	for info: Dictionary in Engine.get_copyright_info():
		var licenses: PackedStringArray = []
		for part: Dictionary in info.parts:
			if not licenses.has(part.license):
				licenses.append(part.license)
		parts.append("%s: %s" % [info.name, ", ".join(licenses)])
	lines.append("[font_size=22]%s[/font_size]" % "\n".join(parts))
	return "\n".join(lines)


## Licence files break lines at 80 characters; join them into paragraphs so they wrap cleanly.
static func _unwrap(text: String) -> String:
	var paragraphs := text.strip_edges().replace("\r\n", "\n").split("\n\n")
	var joined: PackedStringArray = []
	for paragraph in paragraphs:
		joined.append(" ".join(paragraph.split("\n")).strip_edges())
	return "\n\n".join(joined)
