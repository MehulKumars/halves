# Testing and debugging

## The done check

```powershell
powershell -ExecutionPolicy Bypass -File tools/check.ps1
```

1. **Warm-up import:** on a fresh clone the first import can print script errors before Godot has
   built its class-name cache, so its output is not judged.
2. **Boot:** runs the game headless for 300 frames (`-Frames` changes this) and fails on script
   errors.
3. **Tests:** runs every GUT test in `tests/`.

It prints `CHECK PASSED` or `CHECK FAILED` with the relevant output, and exits 0 or 1. Pass
`-Godot <path>` if `godot` is not on PATH.

## Unit tests (GUT 9.7.1)

Tests live in `tests/`, named `test_*.gd`. The template ships 59 tests (463 checks):

| File | Covers |
|---|---|
| `test_theme.gd` | Every style: tokens present, WCAG AA text contrast (cards, background, every button state), 48 dp buttons, switches and sliders |
| `test_screens.gd` | Every screen and popup at 720×1280, 720×1600 and 960×1280: tappable controls at least 96 px, on screen, not overlapping; level select shows every level |
| `test_ui.gd` | Style switching, Back closes only the top popup (and not the results popup), confirm answers, button squash and its Reduce Motion and opt-out, focus rings after touch vs keys, Back key mapped to `ui_cancel` |
| `test_progress.gd` | Best stars, unlocks, coins, purchases, reload, daily streak (same day, next day, missed day, 7-day cycle, month ends) |
| `test_responsive.gd` | Grid columns per width, the max-width column, simulated safe-area insets |
| `test_ad_policy.gd` | Every interstitial rule (first session, level, wins, gaps, caps, rewarded cooldown, daily/zen) |
| `test_seed_service.gd` | A known SHA-256 vector, reproducibility, JSON round-trips |
| `test_save_store.gd` | Round trip, missing file, corrupt file |
| `test_app_lifecycle.gd` | Settings applied from PlayerConfig; lifecycle signals reach Events |
| `test_juice.gd` | Effects settle back to rest scale, including rapid retriggers; reduced motion |

Run them:
```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```
Or in the editor: the **GUT** panel at the bottom.

A new test:
```gdscript
extends GutTest

func test_three_matches_clear_the_board() -> void:
	var board := Board.new()
	board.place(["a", "a", "a"])
	assert_true(board.is_cleared())
```
Useful GUT tools: `assert_eq`, `assert_true`, `assert_almost_eq`, `watch_signals` +
`assert_signal_emitted`, `add_child_autofree(node)` for nodes, `await wait_seconds(t)` for tweens
and timers, `assert_push_warning("text")` when a warning is expected.

Check one script without running anything:
```powershell
godot --headless --path . -s tools/hooks/check_script.gd -- res://game/board.gd
```

## Looking at the UI

```powershell
powershell -ExecutionPolicy Bypass -File tools/snapshots.ps1                     # project style, 4 sizes
powershell -ExecutionPolicy Bypass -File tools/snapshots.ps1 -Styles all -Sizes 720x1600
powershell -ExecutionPolicy Bypass -File tools/snapshots.ps1 -Only "main_menu,pause" -Inset "0,64,0,32"
```
Renders every screen and popup (in a real window for a minute) to
`build/snapshots/<style>_<w>x<h>_<screen>.png`, plus a contact sheet per style and size. `-Inset`
fakes a camera hole and gesture bar in canvas pixels. It uses its own demo save. Claude Code reads
these PNGs to check its own UI work.

Change scene properties without opening the editor (Godot writes the file, then the tool reloads it
and checks every change):
```powershell
godot --headless --path . -s tools/scene_edit.gd -- res://ui/screens/shop.tscn Safe extra_margin 24
```

## The debug console

Debug builds only (disabled in release; `addons/limbo_console.cfg`).

- Open: `` ` `` on PC, or tap with **three fingers** at once on a phone.
- Template commands: `set_seed <text>`, `skip_level`, `ads_grant <true|false>`,
  `motion <0..1>`, `reset_save`, `fps` (overlay: FPS, frame time, draw calls, memory),
  `log_input` (prints every key, touch and action event to the log), `display_info` (screen, safe
  area, cut-outs, refresh rate), `safe_area <left> <top> <right> <bottom>` (fake a notch on PC).
- From a PC over USB: `adb shell input keyevent 68` toggles the console, then
  `adb shell input text fps` and `adb shell input keyevent 66` (Enter).
- Built-in: `help`, `commands`, `fps_max <n>`, `log`, and more.
- Your game listens to `Events.debug_command` for `set_seed` and `skip_level`, and can register its
  own commands in `core/dev_tools.gd` style:
  ```gdscript
  LimboConsole.register_command(_cmd_give_coins, "give_coins", "add coins: give_coins <amount>")
  ```

## Debugging on a phone

- **Remote debugger:** deploy from the editor (Android button) and the Debugger panel shows the
  phone's errors, the Profiler, Monitors (FPS, memory, draw calls) and the live scene tree.
- **Logs:** `adb logcat -s godot`. Debug builds print one `[display]` line at start-up (screen size,
  safe area, camera cut-outs).
- **Screenshots and taps from the PC:** `adb exec-out screencap -p > shot.png`,
  `adb shell input tap <x> <y>` (device pixels), Back: `adb shell input keyevent 4`.
- **Start-up time:** `adb shell am start -W -n <package>/com.godot.game.GodotAppLauncher` prints
  `TotalTime` in ms.
- **Fill-rate test:** turn V-Sync off and compare FPS in a large and a small window; little change
  means the bottleneck is elsewhere.
- **Deeper:** Perfetto (Godot 4.7's default Android tracer) or Android GPU Inspector for GPU spikes.
- Test on one Mali and one Adreno phone when you can; the `mobile-performance-audit` skill has the
  full checklist and Google Play's crash and ANR limits.

## Exports

| Preset | Output | Use |
|---|---|---|
| Android Debug APK | `build/game-debug.apk` | Your phone and friends' phones (`adb install -r`) |
| Android Release AAB | `build/game-release.aab` | Google Play (needs the game's release keystore; see `play-release`) |

```powershell
godot --headless --path . --export-debug "Android Debug APK" build/game-debug.apk
godot --headless --path . --install-android-build-template --export-release "Android Release AAB" build/game-release.aab
```
Both presets leave out `build/`, `tests/`, `tools/`, GUT, Maaack's examples and editor-only addons,
and pack `ATTRIBUTION.md` and the font and icon licences. `build/` and `android/` are ignored by git
(`build/.gdignore` also stops Godot importing screenshots there). The debug APK is about 30 MB.

## Recording video for the store

Record real gameplay only. Options: `scrcpy --record=file.mp4` (free; mirrors and records the
phone) or Godot's `--write-movie` for clean frames from the PC build.
