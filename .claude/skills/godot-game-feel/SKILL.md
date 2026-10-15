---
name: godot-game-feel
description: Add or tune game feel in this Godot 4.7 mobile template: juice (pop, squash, shake, hit-stop, trails, particles, flashes), UI motion, sound effects, music, haptics and reduced-motion settings, with the right amount for the game type and the real cost on low-end Android under the Compatibility renderer. Use this whenever the user asks to make something feel better, more satisfying, punchy, polished, "juicy" or "ASMR", to add particles, screen shake, sounds, vibration or animations, or when gameplay feedback feels flat, even if they don't say "game feel".
---

# Game feel in Godot 4.7 (this template)

Feel is a dial set per game type, and the evidence now favours **juice on success, calm otherwise**:
in a pre-registered CHI 2024 study (1,699 players) feedback tied to the player's success raised
competence and curiosity, while feedback amplified for its own sake lowered them. Priority order:
responsiveness first (no input lag, instant restart), clarity second, spectacle last. Any effect
that hides a piece, an enemy or the score is a bug.

## 1. Pick the register for the game type
| Register | Types | What it means |
|---|---|---|
| Calm / tactile | tile, sort, word, daily, idle numbers | Small lifts, clicks, soft pops on success; no screen shake |
| Crescendo-only | block puzzles | Quiet placement; clears and combos get the juice |
| Physical | physics toys | Impacts carry weight; the rest is quiet |
| Loud but readable | arcade, survivor-likes | Hit-stop, shake, trails; hazards keep the strongest contrast |

## 2. Use what the template already has
- `Juice.pop(node)` and `Juice.squash(node)` (`core/feel/juice.gd`): tween helpers that kill the
  previous tween on the same node and scale with `Juice.motion_scale`. Set `pivot_offset` to the
  centre before popping a Control.
- `Haptics.tick()` (12 ms), `Haptics.success()` (40 ms), `Haptics.big()` (80 ms)
  (`core/feel/haptics.gd`). Needs the VIBRATE permission (already on in the export presets).
- `core/feel/hit_flash.gdshader`: canvas_item flash. Call `material.set_shader_parameter("flash", 1.0)`
  first (on a fresh ShaderMaterial the tween property does not exist until set), then tween
  `"shader_parameter/flash"` to 0 over ~0.1 s. One material per flashing node, or they all flash.
- `Juice` restores a node's rest scale when an effect is retriggered mid-animation, so combo chains
  and rapid taps never leave nodes enlarged.
- Player settings: `AppLifecycle.apply_settings()` reads `GameSettings/ReduceMotion` and
  `GameSettings/Haptics` from Maaack's PlayerConfig and sets `Juice.motion_scale` / `Haptics.enabled`.
  New effects must respect both.

## 3. Build new effects with these recipes
- **Tweens:** `create_tween()` each time (tweens are not reusable and start immediately); kill an
  old tween on the same property first; infinite loops need a duration; UI tweens that must keep
  moving during slow motion use `set_ignore_time_scale(true)`.
- **Hit-stop:** `Engine.time_scale = 0.05` (stay above 0), restore with
  `get_tree().create_timer(t, true, false, true).timeout` (last argument ignores time scale).
  About 60-120 ms on impact. Time scale does not slow audio. For puzzle cascades a slight slowdown
  with rising pitch reads better than hit-stop.
- **Screen shake (trauma):** keep `trauma` in 0..1, decay it each frame, offset the Camera2D by
  `max_offset * trauma * trauma * noise`, scaled by `Juice.motion_scale`. Not in calm games.
- **Trails:** Line2D with a point history, or pooled afterimages. Particle trails do not work in
  the Compatibility renderer.
- **Bursts:** a pool of one-shot emitters fired with `restart()` and returned on `finished`
  (fires only when `one_shot` is on). `GPUParticles2D.emit_particle()` does not work in
  Compatibility; `CPUParticles2D` may perform better on low-end phones. Keep bursts small (6-30
  particles of a few pixels).
- **Glow:** pre-drawn additive sprites. HDR 2D is not supported in Compatibility, and additive
  sprites are much cheaper than Light2D.
- **UI motion:** buttons press to ~0.92 scale and spring back; counters roll; transitions are
  skippable by tapping, and the player never waits on an animation to make the next input.

## 4. Cost on the Compatibility renderer (mobile GPUs are fill-rate bound)
| Cost | Techniques |
|---|---|
| Negligible | Tweens on position/scale/rotation/modulate, Camera2D offset shake, time-scale hit-stop, audio pitch |
| Low | Per-sprite canvas_item shader (flash, tint, dissolve), small one-shot bursts, Line2D trails |
| Medium | Large or overlapping translucent particles, outline shaders sampling 4-8 neighbours, many emitters at once |
| High (avoid, or behind a "High" VFX setting) | Full-screen or screen-reading shaders (blur, shockwave), WorldEnvironment glow, big CanvasGroups, Light2D with shadows |
Transparent pixels cost the most. No public benchmark covers low-end Mali/Adreno phones, so check
on the cheapest test phone.

## 5. Sound and haptics
- Buses Master -> Music, SFX, UI; a Compressor on Music with `sidechain` = SFX ducks music under stingers.
- **WAV** (QOA, ~17 KB/s) for short, frequent effects; **Ogg** for music only (Ogg costs much more CPU
  with many sounds at once).
- `AudioStreamPlayer.max_polyphony` defaults to 1: use a pool of 8-16 players or raise it per sound and
  cap concurrency.
- `AudioStreamRandomizer` for +/-3-8% pitch on frequent sounds; never randomise sounds that carry
  musical meaning. Combo chains rise one semitone (x1.06) per step.
- **Never time gameplay to audio:** Android output latency is 165-500 ms on some phones and
  `audio/driver/output_latency` is ignored on Android. Pair every important sound with a visual and
  a haptic on the same frame.
- Haptics: 10-30 ms ticks for taps and matches, 50-100 ms for big moments; no constant buzzing;
  never the only signal.
- Sources: record real foley on a phone; Kenney (CC0); ChipTone (output CC0); jsfxr; Sonniss GDC
  bundles; Freesound CC0 only (never CC-BY-NC in an ad-funded game). Log every file in
  `ASSETS_LICENSES.md`. No AI-generated audio.

## 6. Before calling it done
- Name the register used and list each feel moment with its technique and cost row.
- Check `Juice.motion_scale = 0` still leaves every state change understandable.
- Run `powershell -ExecutionPolicy Bypass -File tools/check.ps1`.
- Feel is judged on a real phone by the human; say what they should look at.
