---
name: mobile-performance-audit
description: Audit and fix performance, size and stability of a Godot 4.7 game from this template on Android phones, especially low-end ones: frame rate, fill rate and overdraw, batching, texture import settings, particles and shaders, GDScript CPU cost, memory, APK/AAB size, crash and ANR rates (Android vitals). Use this before every release build, and whenever the user mentions lag, stutter, low FPS, heat, battery drain, a big download size, crashes or ANRs, a cheap or old phone, or Play Console warnings, even if they don't say "performance".
---

# Mobile performance audit

Google Play may make a game "less discoverable" when its user-perceived **crash rate passes 1.09%**
or **ANR (frozen app) rate passes 0.47%** over 28 days, or **8% on any single phone model**. With
few installs, a handful of crashes on one popular budget phone can cross 8%. Performance work is
therefore visibility work, not polish.

## 1. Audit checklist (report each item as OK / problem / not checked)
**Renderer and project**
- Compatibility renderer (the template default). Godot's docs call it "usually good enough for 2D"
  and say the Vulkan Mobile renderer is slower on older or low-end phones; Vulkan driver crashes on
  specific Mali and Adreno models needed fixes as recently as 4.6. Only switch after on-device proof.
- Godot 4.7.2 pinned; target API 36; 16 KB page support (Godot 4.5+).

**GPU (mobile GPUs are fill-rate bound; transparency is the worst case)**
- No full-screen translucent layers (use an opaque panel instead of a dimmer). Hide unused overlays
  with `visible = false` rather than relying on transparency.
- 2D light shadows only appear where LightOccluder2D nodes exist; shadows enabled without occluders
  cost time for nothing.
- No Light2D with shadows, WorldEnvironment glow or full-screen shaders by default; fake glow with
  additive sprites.
- Sprites packed into atlases, shared materials, code-drawn shapes drawn once into an atlas.
- Particles: small one-shot bursts from a pool; no large overlapping translucent particles.
- CanvasGroup only over small areas (it reads the backbuffer).

**Imports and memory**
- 2D textures: Lossless (or Lossy for big images), mipmaps off, Size Limit 2048. VRAM compression
  "should be avoided for 2D" (artifacts).
- Budget GPU memory as width x height x 4 bytes per texture; mobile GPUs usually cannot display
  textures above 4096 x 4096.
- Audio: WAV (QOA) for short frequent sounds, Ogg only for music.

**CPU**
- Static typing everywhere (typed GDScript uses optimised opcodes).
- No per-frame allocations in hot loops; pooled spawns.
- Swarms as data arrays drawn with MultiMesh, not one CharacterBody2D per enemy (one developer hit
  15 FPS with 50 enemies).
- Physics games: physics interpolation on, movement in `_physics_process()`, 60 ticks for
  timing-critical games (below ~30 ticks input can feel less responsive).
- Ad and analytics SDK start-up kept off the first frames; heavy scenes loaded in the background.

**Frame-rate targets by type**
- Reaction games (arcade, survivor): a stable 60 fps on the cheapest test phone.
- Turn-based puzzles and idle: 30-60 fps; cap static menus with `application/run/max_fps`.
  `low_processor_mode` redraws only when needed but the docs advise leaving it off for most games;
  measure both ways.

**Size**
- Measure the release AAB. A blank Godot 4 Android export is roughly 19-30 MB in community reports.
  Keep ad-funded games well under 50 MB. Google's 2017 data: about 1% fewer installs per extra 6 MB
  (treat as direction, not a current figure).
- After 2-3 games, compile a 2D-only export template (`disable_3d`, `optimize=size_extra`,
  `debug_symbols=no`); not worth it for game one.

## 2. Measure on the phone, not the PC
1. Deploy a debug APK and use the editor's remote debugger and profiler over USB.
2. Fill-rate test: turn V-Sync off and compare FPS in a large and a tiny window; little change
   means the bottleneck is elsewhere.
3. For unexplained spikes: Perfetto (default Android tracer in 4.7) or Android GPU Inspector.
4. Test on one Mali and one Adreno phone (a 3-4 GB, Android 11-13 phone is a reasonable "low-end"
   target; about 83% of active Play devices ran Android 11+ in Dec 2025).
5. After launch, check Android vitals weekly for any phone model approaching 8%.

### Baseline and device-test notes (October 2026)
- OnePlus 10R (Mali-G610, debug APK): 60 fps on every template screen (the phone runs the app at
  60 Hz), 28-31 draw calls on menus, about 50 MB engine memory, cold start 0.85-1.1 s. APK 28 MB:
  engine 24 MB, template 1.4 MB, Android 2.2 MB. Compare new games against these.
- PNGs inside the project (screenshots) get imported and shipped: keep `build/.gdignore`,
  `docs/.gdignore` and the export exclude filters; check the APK with `unzip -l`.
- adb from a PC: `input tap x y` (device pixels), `input swipe x1 y1 x2 y2 ms`, `input keyevent 4`
  (Back), `keyevent 68` + `input text fps` + `keyevent 66` (console command), `exec-out screencap -p`,
  `am start -W` (start time). In Git Bash set `MSYS_NO_PATHCONV=1` for `/sdcard` paths.
- OnePlus/ColorOS: blocks `pm clear` (reinstall instead), shows a "HyperBoost" panel on launch, and
  typing into the debug console leaves the picture about 12% darker until restart (debug only).

## 3. Report format
```
## Summary
Overall: OK / risky / blocking, with the single biggest risk.

## Findings
| Area | Finding | Evidence (file, scene, measurement) | Fix | Cost to fix |

## Not checked
- <what needs a real phone or Play Console data>
```
Base findings on the actual project files and measurements; mark anything inferred without a
measurement as "needs on-device check". Finish code changes with
`powershell -ExecutionPolicy Bypass -File tools/check.ps1`.
