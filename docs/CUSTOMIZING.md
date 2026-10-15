# Customizing the template for a new game

What to change for every game, what you can change if the game needs it, and what to leave alone.

## Must change for every game

| What | Where | Notes |
|---|---|---|
| Game name | `project.godot` > `config/name` | Shown as the main menu title |
| Package name | `export_presets.cfg` > `package/unique_name` (both presets) | For example `com.yourstudio.halves`. Never ship `com.changeme.template`; it can never change after the first upload |
| App name on the phone | `export_presets.cfg` > `package/name` | |
| Version | `version/code` (raise for every upload) and `version/name` | In both presets |
| Launcher icons | *Project > Export > Android* > Launcher Icons | The template's `icon.png` is a 64×64 placeholder. Main icon at least 192×192; adaptive foreground and background at least 432×432 (optional monochrome 432×432); keep important artwork inside the centred 66 dp circle (264 px) |
| Opening scene | `scenes/opening/opening.tscn` | Shows the Godot logo. Replace with your studio logo, or point `run/main_scene` straight at the main menu |
| Credits | `ATTRIBUTION.md` | The credits screen is built from this file (then open and save `scenes/credits/credits_label.tscn`). Replace Maaack's example entries and logos with your game's credits; keep the MIT notices for Maaack's template and Godot as text |
| Main menu subtitle | `scenes/menus/main_menu/main_menu.tscn` | The "Subtitle" label; edit in the editor |
| Release keystore | outside the repo | See the `play-release` skill |
| Licence register | `ASSETS_LICENSES.md` | One row per asset you add |

## The game scene

Maaack's example game lives in `scenes/game/game.tscn`. It contains a `LevelManager` and
`LevelLoader` (load levels in order from a `SceneLister`), a pause menu controller, and the
level won / level lost / game won windows in `scenes/windows/`. Read
`addons/maaacks_game_template/docs/GameSceneSetup.md` before changing it.

- **Level-based game:** replace the example levels in `scenes/game/levels/` (they include 3D
  examples you will not need) with your own, or load baked levels from `data/`.
- **Single-scene game:** remove `LevelLoader`, `LevelManager` and `LevelLoadingScreen`, put your
  scene in the container, and use `win_lose_manager.gd` as Maaack's guide describes.
- **Results screen:** `scenes/windows/level_won_window.tscn` (and `level_lost_window.tscn`) is
  where the interstitial slot belongs: when it opens, ask `AdPolicy.can_show_interstitial()` (see
  [ARCHITECTURE.md](ARCHITECTURE.md)). Never on its Restart or Continue buttons.
- **Pause:** Maaack's pause menu opens on `ui_cancel` (Esc). On the phone, connect
  `Events.back_requested` to it if Back does not already open it, and save on `Events.app_paused`.

## Look and feel

| What | Where | How |
|---|---|---|
| UI colours, corners, text size | `core/ui/mobile_theme.tres` | Edit the StyleBoxFlat `bg_color`, corner radii and `default_font_size` in the Inspector. Keep buttons and toggles at least 96 px tall |
| Font | `core/ui/mobile_theme.tres` > Default Font | Use a readable font with an open licence (for example from Google Fonts); log it in `ASSETS_LICENSES.md` |
| Background colour | Project Settings > Rendering > Environment > Default Clear Color | |
| Palette | per game | Five colours; text contrast at least 4.5:1, game pieces at least 3:1 against their background; pair every meaningful colour with a shape or pattern; check in greyscale and a colour-blind simulator |
| Juice | your gameplay code | Pick the register for the game type (calm, crescendo-only, physical, loud-but-readable). The `godot-game-feel` skill has the details |
| Music and sounds | `BackgroundMusicPlayer` nodes on bus **Music**; effects on bus **SFX** | Buses are Master, Music, SFX (`default_bus_layout.tres`). WAV for short effects, Ogg for music |

## Options menu

- `scenes/menus/options_menu/master_options_menu_with_tabs.tscn`: tabs Controls, Inputs, Audio,
  Video, Game. The script hides the desktop tabs (Controls, Inputs, Video) on mobile; set
  **Show Desktop Tabs** on the MasterOptionsMenu node for a PC build.
- `scenes/menus/options_menu/game/game_options_menu.tscn`: Reduce Motion, Haptics, Reset Game.
- Add your own option: instance an `OptionControl` scene (toggle, slider or list) with section
  `GameSettings` and a key, then read it with `PlayerConfig.get_config("GameSettings", "YourKey", default)`.
  Maaack's `AddingCustomOptions.md` explains the controls.

## Ad rules

`AdPolicy`'s defaults follow the research. You can tune them per game on your instance:

```gdscript
ad_policy.min_level = 6            # first interstitial after level 6 instead of 8
ad_policy.won_levels_between = 3   # gentler
ad_policy.max_per_session = 2
```

Do not change the rules Google Play and the research treat as hard: no interstitials at level
start, during play, on Retry / Next / Play again, or in the first session.

## Screen and orientation

The canvas is 720×1280 portrait with `canvas_items` stretch and `expand` aspect, so taller phones
show a little more vertically. The PC window is 405×720 (`window_width_override` /
`window_height_override`). Landscape is possible (change the viewport size and
`display/window/handheld/orientation`) but every menu and touch-size rule here assumes portrait.

## Change only on purpose

- `core/`: shared by every game. Improve it in the **template** repo, then copy the change into
  games that need it. Ask before changing it in a game.
- `CLAUDE.md` rules: they encode the research; change them deliberately, not to make a task easier.
- `addons/`: never edit vendored plugins; update them as a whole to a pinned version.
- `export_presets.cfg` exclude filters: tests and GUT must stay out of builds.
