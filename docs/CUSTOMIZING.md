# Customizing the template for a new game

What to change for every game, what you can change if the game needs it, and what to leave alone.

## Must change for every game

| What | Where | Notes |
|---|---|---|
| Game name | `project.godot` > `config/name` | Shown as the main menu title |
| Style | Project Settings > GUI > Theme > Custom | Pick one of the five themes in `core/ui/themes/`, or make your own ([UI_KIT.md](UI_KIT.md)) |
| Tagline | `ui/screens/main_menu.tscn` > `Tagline` | Or hide the label |
| Package name | `export_presets.cfg` > `package/unique_name` (both presets) | For example `com.yourstudio.halves`. Never ship `com.changeme.template`; it can never change after the first upload |
| App name on the phone | `export_presets.cfg` > `package/name` | |
| Version | `version/code` (raise for every upload) and `version/name` in both presets; `config/version` in `project.godot` (shown in Settings) | |
| App icon | `assets/template_icon/` and `icon.png` | The template ships its own placeholder (a play mark). Replace every file with your game's icon at the same sizes (the README there lists them); both export presets already point at them. Keep important artwork inside the centred 264 px circle of the 432 px adaptive foreground |
| Splash | `ui/screens/splash.tscn` | Shows the game name and "Made with Godot" for about a second. Add your studio logo to `%Logo` if you have one |
| Credits | `ATTRIBUTION.md` | Replace "Your Studio" and "Your Name" with your team; keep the "Made with", font and icon entries. The licence texts are added below automatically |
| Privacy policy | `ui/popups/settings_popup.gd` > `PRIVACY_URL` | Google Play requires one; a GitHub Pages page works |
| Release keystore | outside the repo | See the `play-release` skill |
| Licence register | `ASSETS_LICENSES.md` | One row per asset you add |

## The game screen

`ui/screens/game.tscn` is a real HUD around a placeholder board:

- Replace the content of `%Board` with your game (or instance your game scene in it).
- When a level ends, call `finish(won, stars)`. It records progress and coins, opens the results
  popup, considers an interstitial through `AdPolicy`, and handles Next / Retry / Home / Continue.
- `%Goal` and `%MovesLabel` show moves left; replace them with your goal (score, time, targets).
- The three booster buttons (`%HintButton`, `%UndoButton`, `%ShuffleButton`) only show a toast.
- `Screens.level` is the level to play; `Progress.LEVEL_COUNT_DEFAULT` (24) is the number of levels
  in level select (`level_count` on the level select screen).
- Back opens the pause popup. Save on `Events.app_paused` if your game holds state that
  `Progress` does not.

## Rewards

| What | Where |
|---|---|
| Coins per star | `game/halves/halves_config.gd` > `COINS_PER_STAR` |
| Daily puzzle streak coins | `core/progress.gd` > `DAILY_REWARDS` (7 days, paid by `HalvesRecords` when the daily is cleared) |

Remove screens you do not need by deleting the scene, its button and its
entry in `ui/screens.gd`, `tests/test_screens.gd` and `tools/snapshots.gd`.

## Look and feel

| What | Where | How |
|---|---|---|
| Colours, fonts, corners, button shape, background pattern | `core/ui/styles/<style>.tres` | Edit in the Inspector, run `tools/build_theme.gd`, check with `tools/check.ps1` and `tools/snapshots.ps1` |
| How a component looks in every style | `tools/build_theme.gd` | The design system; rebuild after changes |
| Icons | `core/ui/icons/`, `core/ui/icons.gd` | Material Symbols; how to add one is in `icons.gd` |
| Palette for game pieces | per game | Text contrast at least 4.5:1 and game pieces at least 3:1 against their background; pair every meaningful colour with a shape or pattern; check in greyscale and a colour-blind simulator. Reuse the style's Tokens where you can |
| Juice | your gameplay code | Pick the register for the game type (calm, crescendo-only, physical, loud-but-readable). The `godot-game-feel` skill has the details |
| Music and sounds | `AudioStreamPlayer` nodes on bus **Music** or **SFX** | Buses are Master, Music, SFX (`default_bus_layout.tres`); the Settings sliders control Music and SFX. WAV for short effects, Ogg for music |

## Settings

`ui/popups/settings_popup.tscn` has Music and Sound volume, Vibration, Reduce motion, Credits,
Privacy, Reset progress and the version. To add a setting, add a row (icon,
label, control) and read/write it with `PlayerConfig.get_config("GameSettings", "YourKey", default)` /
`PlayerConfig.set_config(...)`, the way `core/settings.gd` does. Set `show_style_picker` to let
players choose the style.

## Ad rules

`AdPolicy`'s defaults follow the research. Tune them on the shared instance in `game.gd`:

```gdscript
ad_policy.min_level = 6            # first interstitial after level 6 instead of 8
ad_policy.won_levels_between = 3   # gentler
ad_policy.max_per_session = 2
```

Do not change the rules Google Play and the research treat as hard: no interstitials at level
start, during play, on Retry / Next / Play again, or in the first session.

## Screen and orientation

The canvas is 720 px wide, portrait, with `canvas_items` stretch and `expand` aspect: taller phones
show more vertically (up to about 1700 px), tablets and foldables get a wider canvas (about
960-1100 px). Every screen keeps its content in a `MaxWidthContainer` and its grids adaptive, and
`tests/test_screens.gd` checks three sizes. The PC window is 405×720. Landscape would need every
screen rearranged; it is not supported.

## Change only on purpose

- `core/`: shared by every game. Improve it in the **template** repo, then copy the change into
  games that need it. Ask before changing it in a game.
- `CLAUDE.md` rules: they encode the research; change them deliberately, not to make a task easier.
- `addons/`: never edit vendored plugins; update them as a whole to a pinned version.
- `export_presets.cfg` filters: tests, tools and editor-only addons must stay out of builds; the
  font and icon licence files must stay in.
