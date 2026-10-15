@tool
class_name UIStyle
extends Resource
## One visual style for the whole UI kit: colours, fonts, shapes and the animated background.
## tools/build_theme.gd turns every style in core/ui/styles/ into a Theme in core/ui/themes/;
## edit a style in the Inspector, rebuild, then check it with tools/snapshots.ps1.
## Text colours are checked for WCAG AA contrast by tests/test_theme.gd after every rebuild.

enum ButtonShape {
	FLAT,      ## Plain face, rounded corners.
	CHUNKY,    ## Face over a darker bottom edge that squashes when pressed (casual games).
	OUTLINE,   ## Glowing outline, fills in when pressed (arcade, neon).
	PIXEL,     ## Square corners, hard 1-colour borders, no anti-aliasing.
}

enum Pattern { NONE, DOTS, STRIPES, GRID, GRAIN, CHECKER }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Colours")
## Background gradient, top to bottom. Titles drawn straight on it use text_on_bg.
@export var bg_top: Color
@export var bg_bottom: Color
@export var text_on_bg: Color
## Cards, sheets and popups, and the text on them.
@export var surface: Color
@export var surface_border: Color
@export var text: Color
@export var text_muted: Color
## Secondary buttons, slider tracks, tiles.
@export var raised: Color
@export var raised_edge: Color
@export var text_on_raised: Color
## Primary buttons and selection.
@export var accent: Color
@export var accent_edge: Color
@export var on_accent: Color
## Stars, coins and rewards; success; destructive actions.
@export var gold: Color
@export var positive: Color
@export var danger: Color
@export var on_danger: Color
## Dims the screen behind popups.
@export var scrim: Color

@export_group("Type")
@export var body_font: Font
@export var display_font: Font
## Weights for variable fonts (100-900). Ignored by fonts without a weight axis.
@export_range(100, 900, 100) var body_weight: int = 500
@export_range(100, 900, 100) var display_weight: int = 700
@export var font_size: int = 32
@export var title_size: int = 80
## Scales the kit's other text sizes (captions, headers, numbers) for fonts that run small or large.
@export_range(0.75, 1.5, 0.05) var text_scale: float = 1.0
## Outline around titles and button text, in canvas pixels (0 = none). Casual styles use it.
@export var text_outline: int = 0
@export var text_outline_color: Color

@export_group("Shape")
@export var button_shape: ButtonShape = ButtonShape.FLAT
@export var radius: int = 20
@export var panel_radius: int = 32
@export var border_width: int = 2
## Height of the bottom edge on CHUNKY and PIXEL buttons.
@export var edge_depth: int = 8
@export var shadow_size: int = 0
@export var shadow_offset: Vector2 = Vector2(0, 6)
@export var shadow_color: Color = Color(0, 0, 0, 0.35)
## Draws a coloured glow around buttons and panels (OUTLINE shape).
@export var glow: bool = false
@export var anti_aliasing: bool = true

@export_group("Background")
@export var pattern: Pattern = Pattern.NONE
@export var pattern_color: Color
## Size of one pattern cell in canvas pixels.
@export var pattern_scale: float = 48.0
## Pattern drift in canvas pixels per second; 0 is still. Reduce Motion stops it.
@export var pattern_speed: float = 8.0
