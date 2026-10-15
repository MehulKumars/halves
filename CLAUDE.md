# Mobile Game Template: rules for Claude Code

Godot **4.7.2** (pinned) · GDScript only · 2D portrait, 720×1280 · Android first · Compatibility renderer.
The human owns fun, feel, art, balance, the store page and release decisions. Claude builds code with a checkable answer.

## Project map
- `core/` shared template systems. Change only on purpose and ask first.
  - `events.gd` autoload **Events**: global signal bus.
  - `services/` autoload **Services**: `ads`, `iap`, `analytics`, `leaderboard`, `review` as interfaces with mocks.
  - `ad_policy.gd` (when interstitials may show), `seed_service.gd` (stable seeds), `save_store.gd` (versioned JSON save).
  - `feel/juice.gd` (pop, squash; honours `Juice.motion_scale`), `feel/haptics.gd` (honours `Haptics.enabled`).
  - `ui/safe_area_margin.gd` (notch-safe container), `dev_tools.gd` autoload **DevTools** (debug-only console commands).
- `scenes/`, `scripts/`, `resources/`, `assets/`: Maaack's Game Template menus, options, loading and credits. Edit per game.
- `game/` gameplay scenes and scripts (create per game). `data/` baked levels and configs (create per game).
- `tests/` GUT tests named `test_*.gd`. `tools/` scripts. `addons/` vendored plugins.

## Never
- Godot 3 APIs. Use the right column:
  | Godot 3 (wrong) | Godot 4 (right) |
  |---|---|
  | `yield(...)` | `await ...` |
  | `KinematicBody2D`, `move_and_slide(vel, UP)` | `CharacterBody2D`, set `velocity`, `move_and_slide()` |
  | `deg2rad`, `rad2deg`, `rand_range` | `deg_to_rad`, `rad_to_deg`, `randf_range` / `randi_range` |
  | `export var`, `onready var`, `.instance()` | `@export var`, `@onready var`, `.instantiate()` |
  | `connect("sig", self, "fn")` | `sig.connect(fn)` |
  | `File.new()`, `Directory.new()` | `FileAccess.open()`, `DirAccess.open()` |
  | `set_shader_param` | `set_shader_parameter` |
  | `BUTTON_LEFT` (fails silently) | `MOUSE_BUTTON_LEFT` |
  | `TileMap` | `TileMapLayer` |
- Call a plugin singleton (AdMob, Billing, Play Games) outside `core/services/`.
- Show an interstitial anywhere except when a results screen opens, and only if `AdPolicy.can_show_interstitial()` is true.
  Never on Next / Retry / Play again, at level start, during play, after a fail with a continue offer, or in daily/zen modes.
- Generate shipped levels at runtime. Generate offline, rate with a bot, bake to `data/` with a `gen_version`.
- Hand-write `uid://` values or restructure `.tscn` files as text. Small property edits only; structural scene work happens in the editor.
- Edit anything in `addons/`.
- Commit keystores, passwords or `build/` outputs.
- Weaken, skip or delete a test to make it pass.
- Add AI-generated art, audio or text content.

## Always
- Static typing everywhere: `var speed: float = 2.0`, `func f(a: String) -> void:`, `:=` when the type is obvious.
  `class_name` on reusable scripts. Untyped declarations raise a warning (project setting).
- "Call down, signal up": parents call children, children emit signals, cross-system events go through `Events`.
- New script = a 3-line header comment: what it does, who uses it, anything surprising.
- Tweens: `create_tween()` each time; kill an old tween on the same property first (see `Juice`).
- Touch targets at least 96 px on the 720-px canvas (48 dp). Primary actions in the bottom third.
- Every important event has a visual. Sound and haptics are extras, never the only signal.
- Juice goes on player success. Calm games stay calm. Respect `Juice.motion_scale` and `Haptics.enabled`.
- Never time gameplay to audio: Android audio lags 165–500 ms on some phones.
- Performance: no full-screen translucent layers, no Light2D or HDR glow by default, pooled one-shot
  `CPUParticles2D`, sprite atlases, no per-enemy physics nodes for swarms, Lossless textures without mipmaps.
- Save on `NOTIFICATION_APPLICATION_PAUSED`; Android Back opens the pause menu.
- Work in small steps: plan first, one feature at a time, run the done check, then commit.

## Ask the human first
- A new autoload or addon, any change in `core/`, project settings, export presets, signing, package names.

## Done = this passes
```
powershell -ExecutionPolicy Bypass -File tools/check.ps1
```
It runs a warm-up import, boots the game headless for 300 frames, and runs every GUT test.
Test cases for generators and solvers are written by the human or a separate session, not the one writing the code.

## Commands
- Run the game: `godot --path .`  · Editor: `godot --path . -e`
- Tests only: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
- Debug APK: `godot --headless --path . --export-debug "Android Debug APK" build/game-debug.apk`
- Release AAB (after signing is set up for the game):
  `godot --headless --path . --install-android-build-template --export-release "Android Release AAB" build/game-release.aab`
- Version-exact API reference to search: `godot --doctool docs/api` (ignored by git)

## Google Play rules this template assumes (Oct 2026)
- Target API 36 (Godot 4.7.2 default), AAB uploads, 16 KB page support (Godot 4.5+).
- Rewarded ads are opt-in; full-screen ads never at level start or during play.
- Audience 13+ with adult-looking art, to stay out of the Families policy.
- Billing plugin 3.3.0+ when IAP is added (Billing Library 8+ required).
