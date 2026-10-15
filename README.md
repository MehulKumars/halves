# Mobile Game Template

A reusable Godot 4.7.2 template for small 2D portrait games on Android. Every new game starts here, so each one only adds gameplay, data and art.

Built on [Maaack's Godot Game Template](https://github.com/Maaack/Godot-Game-Template) v1.7.0 (MIT), which provides the menus, options, loading screen, credits, music and UI sound controllers.

## What this template adds
| Part | Where | What it does |
|---|---|---|
| Signal bus | `core/events.gd` (autoload `Events`) | Systems talk through signals, not direct references |
| Services | `core/services/` (autoload `Services`) | Ads, purchases, analytics, leaderboards and reviews behind interfaces. Mock versions run on PC |
| Ad rules | `core/ad_policy.gd` | Interstitials only on a results screen, never in the first session, capped and spaced out |
| Seeds | `core/seed_service.gd` | Stable SHA-256 seeds for levels and daily puzzles |
| Save | `core/save_store.gd` | Versioned JSON save with crash-safe writes and migrations |
| Feel | `core/feel/` | `Juice.pop/squash` tweens and `Haptics` pulses, both respecting player settings |
| Notch-safe UI | `core/ui/safe_area_margin.gd` | Keeps the HUD clear of camera cut-outs |
| Dev console | `core/dev_tools.gd` + LimboConsole | Debug builds only. Press `` ` `` on PC or tap with 3 fingers on a phone |
| Tests | `tests/` + GUT 9.7.1 | Unit tests for the logic above |
| Done check | `tools/check.ps1` | Import, headless boot, all tests |
| Android presets | `export_presets.cfg` | Debug APK for phone testing; release AAB for Google Play |

## Requirements
Godot 4.7.2 · OpenJDK 17 · Android SDK Platform 36, Build-Tools 36.1.0, NDK 29.0.14206865 · a real Android phone for testing.

## Start a new game
```
gh repo create <game-name> --template MehulKumars/godot-mobile-template --private --clone
```
Then:
1. Set `package/unique_name` (for example `com.yourstudio.halves`) and the names in `export_presets.cfg` and `project.godot`.
2. Create a release keystore with `keytool`, store it and its passwords in 1Password, never commit it.
3. Write the game's keep/kill lines before building.
4. Replace the Godot and Git logos in the opening scene (see `ASSETS_LICENSES.md`).

## Check your work
```
powershell -ExecutionPolicy Bypass -File tools/check.ps1
```

## Licences
See `ASSETS_LICENSES.md`, `ATTRIBUTION.md` and `LICENSE.txt` (Maaack's MIT licence, kept as required).
