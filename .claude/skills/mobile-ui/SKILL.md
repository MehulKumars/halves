---
name: mobile-ui
description: Build, change or review mobile game UI in this Godot 4.7 template with its UI kit: screens, popups, HUDs, menus, shops, reward screens, buttons, styles and themes. Covers the kit's building blocks (UI autoload, Screen, Modal, theme types, Tokens, responsive containers), mobile layout rules (thumb zone, 48 dp targets, safe areas, phones to tablets), the five styles and making new ones, and how to verify with tests and screenshots before saying it works. Use whenever the user asks to add or change any screen, popup, button, HUD element, menu, colour, font or visual style, or says the UI looks wrong, cramped, ugly or broken, even if they do not say "UI".
---

# Mobile UI with the template's UI kit

Read `docs/UI_KIT.md` first: it lists every screen, theme type, token and building block.
This skill is how to work with them and how to check the result.

## 1. Pick the right base
| Need | Use |
|---|---|
| A full page (menu, shop, map, leaderboard) | New scene in `ui/screens/`, script `extends Screen`; copy `shop.tscn`'s layout |
| Something over the current page (dialog, reward, pause, tutorial step) | New scene in `ui/popups/`, script `extends Modal`; copy `confirm_popup.tscn` |
| A short message | `UI.toast("text", Icons.COIN)` |
| A yes/no question | `if await UI.confirm(title, message, "Delete", true):` |
| Part of the gameplay HUD | Add to `ui/screens/game.tscn` (`Hud`, `GoalCard`, `Boosters`) |
| A reusable piece (counter, card) | `core/ui/widgets/`, build children in `_init`, follow `CurrencyPill` |

Screen layout, always: `Background` (StyledBackground) → `Safe` (SafeAreaMargin, extra 32) →
`Column` (MaxWidthContainer 680-960) → `Layout` (VBox). Popup layout: `Safe` → `Center` →
`%Sheet` (SheetPanel); set `mouse_filter = Ignore` on Safe and Center.

Register every new page in `ui/screens.gd`, `tests/test_screens.gd` (`PAGES`) and
`tools/snapshots.gd` (`SCREENS` plus a `_show_<name>()` function).

## 2. Style it only through the theme
- Set `theme_type_variation`: `HeroButton` for the one main action, `AccentButton` for primary,
  `Button` for secondary, `GhostButton` for "Not now", `IconButton` for icon-only, `DangerButton`
  for destructive. Labels: `TitleLabel` / `ScreenHeaderLabel` / `OnBgLabel` on the background,
  `HeaderLabel` / plain / `CaptionLabel` / `ValueLabel` on cards. Panels: card, `SheetPanel`,
  `TilePanel`, `HighlightPanel`, `PillPanel`, `BadgePanel`, `DotPanel`.
- Colours in code come from Tokens: `get_theme_color(&"gold", &"Tokens")` (tint icons with
  `modulate`). Never write a hex colour or font size into a screen: it breaks the other four styles.
- Icons: `Icons.*` (white SVG, tint them). New icon: steps in `core/ui/icons.gd`.
- A new look for a component in every style: change `tools/build_theme.gd`, rebuild. A new style:
  duplicate `core/ui/styles/<id>.tres`, edit, rebuild (`godot --headless --path . -s tools/build_theme.gd`).

## 3. Mobile layout rules
- 720 px wide canvas, 2 px = 1 dp on a 360 dp phone; phones are 1280-1700 px tall; tablets get a
  wider canvas (960-1100), not a taller one.
- Every tappable thing at least 96×96 px (the theme gives this; do not shrink with
  `custom_minimum_size` or font overrides).
- Thumb zone: the main action in the bottom third; pause, settings and back at the top.
- One primary action per screen; secondary actions visibly weaker.
- Text: 32 px body, 26 px minimum; numbers in `ValueLabel` (some display fonts have unclear
  digits: Orbitron's slashed zero, Pixelify Sans's 5).
- Long content scrolls in a `TouchScrollContainer` (never a plain `ScrollContainer`) with
  `horizontal_scroll_mode = 0`; popups get a `%Scroll`
  and `refit()` after adding content in code.
- Lists and grids: `AdaptiveGridContainer` (set `min_cell_width`), so tablets get more columns.
- Feedback: buttons already squash and tick. Rewards pop (`Juice.pop`, `StarRating.reveal`,
  `CurrencyPill.set_value`). Everything respects `Juice.motion_scale`.
- Back: `Screen.on_back()`; a popup the player must answer sets `dismissible = false`.
- Ads: rewarded only behind a button that says what it gives ("+5 moves (watch ad)");
  interstitials only when a results popup opens, through `AdPolicy`.

## 4. Verify before saying it works
1. `powershell -ExecutionPolicy Bypass -File tools/check.ps1`. `test_theme.gd` fails on low contrast
   or small controls in any style; `test_screens.gd` fails on small, off-screen or overlapping
   controls at 720×1280, 720×1600 and 960×1280.
2. `powershell -ExecutionPolicy Bypass -File tools/snapshots.ps1 -Styles all -Only "<screen>"` and
   **open the PNGs** (Read tool): `build/snapshots/<style>_<w>x<h>_<screen>.png`. Check at least the
   default style at 720x1280 and 960x1280, and one light style (`cozy_paper`). Look for: clipped
   or wrapped text, crowded rows, empty-looking areas, alignment, the thumb zone.
3. Notch: add `-Inset "0,64,0,32"` (a real phone: 64 px camera hole, 32 px gesture bar).
4. On a phone (debug build): Settings > style chips and the UI kit gallery; `adb exec-out screencap -p`.
State what was checked and on which sizes; say so if a phone check is still missing.

## 5. Pitfalls already hit in this template
- `CheckButton` falls back to `Button` theme items: a Button `icon_max_width` shrank the switches.
  Set CheckButton items explicitly.
- Theme variations fall back to their base type: switch inherited items off explicitly (an
  inherited outline on dark text looked smudged).
- A static function named `reload()` is shadowed by `Script.reload()` and resets static variables.
- Child nodes created as member variables and added in `_ready` leak if the node never enters the
  tree (the exporter does that). Add them in `_init`.
- `@tool` scripts that set properties at run time get those values saved into scenes; hide them
  with `_validate_property` (see `StyledBackground`).
- A popup that pauses the game must unpause however it leaves (`Modal._exit_tree`), or tests and
  scene changes freeze.
- `override.cfg` in the project root overrides project settings on PC only. Keep it deleted.
- Snapshots of popups need time for the pop-in (0.3 s) and reveal animations before capture.
- Godot's ScrollContainer does not scroll on a phone when the drag starts on a button or text
  (they take the press). `TouchScrollContainer` fixes it and cancels the press; snapshots and
  layout tests cannot catch this, so drag-test lists on a phone.
- RichTextLabel links fire when tapping near them on a centred line; credits show URLs as text.
