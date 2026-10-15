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

Tests live in `tests/`, named `test_*.gd`. The template ships 25:

| File | Covers |
|---|---|
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

## The debug console

Debug builds only (disabled in release; `addons/limbo_console.cfg`).

- Open: `` ` `` on PC, or tap with **three fingers** at once on a phone.
- Template commands: `set_seed <text>`, `skip_level`, `ads_grant <true|false>`,
  `motion <0..1>`, `reset_save`.
- Built-in: `help`, `commands`, `fps_max <n>`, `log`, and more.
- Your game listens to `Events.debug_command` for `set_seed` and `skip_level`, and can register its
  own commands in `core/dev_tools.gd` style:
  ```gdscript
  LimboConsole.register_command(_cmd_give_coins, "give_coins", "add coins: give_coins <amount>")
  ```

## Debugging on a phone

- **Remote debugger:** deploy from the editor (Android button) and the Debugger panel shows the
  phone's errors, the Profiler, Monitors (FPS, memory, draw calls) and the live scene tree.
- **Logs:** `adb logcat -s godot`.
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
Both presets exclude `tests/` and `addons/gut/`. `build/` and `android/` are ignored by git.

## Recording video for the store

Record real gameplay only. Options: `scrcpy --record=file.mp4` (free; mirrors and records the
phone) or Godot's `--write-movie` for clean frames from the PC build.
