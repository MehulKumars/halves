class_name Screens
extends RefCounted
## Paths of every screen and popup in the UI kit, so code never repeats them.
## Screens change with UI.goto(Screens.LEVEL_SELECT); popups open with UI.open(load(Screens.PAUSE)).

const SPLASH: String = "res://ui/screens/splash.tscn"
const MAIN_MENU: String = "res://ui/screens/main_menu.tscn"
const LEVEL_SELECT: String = "res://ui/screens/level_select.tscn"
const GAME: String = "res://ui/screens/game.tscn"
const CREDITS: String = "res://ui/screens/credits.tscn"
const CREST_BOOK: String = "res://ui/screens/crest_book.tscn"
const GALLERY: String = "res://ui/screens/ui_gallery.tscn"

const PAUSE: String = "res://ui/popups/pause_popup.tscn"
const RESULTS: String = "res://ui/popups/results_popup.tscn"
const SETTINGS: String = "res://ui/popups/settings_popup.tscn"
const CONFIRM: String = "res://ui/popups/confirm_popup.tscn"
const RANKS: String = "res://ui/popups/ranks_popup.tscn"
const BOOSTER: String = "res://ui/popups/booster_popup.tscn"
const TIP: String = "res://ui/popups/tip_popup.tscn"
const CHAPTER: String = "res://ui/popups/chapter_popup.tscn"
const DAILY: String = "res://ui/popups/daily_popup.tscn"

## What the game screen plays: the level journey, today's daily, endless zen or a timed rush.
enum Mode { LEVELS, DAILY, ZEN, RUSH }

## Level the game screen plays next. Set it before UI.goto(Screens.GAME).
static var level: int = 1
## The mode the game screen plays next (with `level` for LEVELS).
static var mode: Mode = Mode.LEVELS
