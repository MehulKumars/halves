# Halves

**A calm puzzle of mirror halves.** Tap a free tile, then its mirror-cut other half, and the two
snap into one whole shape. Never match twins. Stack-clearing like mahjong solitaire, played over
Hiroshige's woodblock prints as the seasons turn.

![Main menu, a level with locks and keys, the results, a chapter's print and the level select](docs/images/halves_screens.jpg)

Made with Godot 4.7 for Android phones (portrait). Version 1 is being shared with friends before a
Google Play closed test.

## How to play

- **Tap a free tile, then its mirror half.** Same shape, same cut and same mark, opposite side.
- **A tile is free** when nothing lies on it and its left or right side is open. Covered tiles look
  darker.
- **Never match twins.** Two left halves (or two halves with different marks) are a mistake.
- **Plan ahead.** A half lying on top of its own mate can never meet it. Getting stuck is allowed
  (a shuffle always gets you out), but it costs a star.
- **Stars:** 3 for a clean clear, 2 for one or two slips (a mistake or a shuffle out of a dead end),
  1 otherwise. Beat the level's **par time** for the ⚡ Swift medal.

New rules arrive one at a time, each with a short card:

| Level | New idea |
|---|---|
| 1-5 | Pairs, stacked layers, open ends, twins, the first trap |
| 6-11 | Horizontal cuts, diamonds, dot and line marks, gold tiles |
| 21 | **Mist:** faces stay hidden until the tile is free |
| 41 | **Locks and keys:** padlocked tiles open when every key tile is cleared |
| 61 | **Frost:** frozen tiles thaw when a tile touching them is cleared |

## What's in version 1

- **100 levels in five chapters:**

  | Chapter | Levels | Print |
  |---|---|---|
  | Spring | 1-20 | Plum Garden at Kameido |
  | Summer | 21-40 | Sudden Shower over Shin-Ōhashi |
  | Autumn | 41-60 | Maple Trees at Mama |
  | Winter | 61-80 | Kinryūzan Temple in snow |
  | Moon | 81-100 | Night View of Saruwaka-machi |

  Each chapter has its own Hiroshige print, music, falling petals, rain, leaves, snow or fireflies,
  and its own celebration. Finishing a chapter reveals the whole print.
- **A sawtooth difficulty curve.** Every pack of 10 has a gentle level that brings a new idea, a
  climb, a hard level at 5 and a finale at 10.
- **Modes:**
  - **Daily Puzzle:** the same board for everyone each day, gentle on Monday and hardest on Sunday,
    with a streak and a result to copy.
  - **Zen:** endless calm boards with no clock, stars or ads; opens after level 10.
  - **Rush:** clear as many small boards as you can in three minutes; opens after level 15.
- **A clock that only runs while you play.** Your best time per level is saved with its moves, so a
  future friends leaderboard can check it.
- **Feel:**
  - porcelain-and-wood clacks, combo chains that climb in pitch, shards, and pops as tiles come free;
  - mist flips, padlocks springing open, frost cracking, gold coins;
  - a gentle haptic tick on each snap.
- **Kind to every player:** Reduce Motion, vibration on/off, a hideable clock, and shapes that
  never rely on colour alone. No lives and no fail screen: a board can always be finished.

## Build and run

You need Godot 4.7.2, and the Android SDK for phone builds. Steps are in
[Getting started](docs/GETTING_STARTED.md).

```powershell
godot --path . -e                                   # open in the editor (F5 to play)
powershell -ExecutionPolicy Bypass -File tools/check.ps1                  # boot + every test
godot --headless --path . --export-debug "Android Debug APK" build/game-debug.apk
adb install -r build/game-debug.apk                 # put it on a phone
```

## How it's made

| Part | Where |
|---|---|
| Rules, logic and data contract (the tests are written from it) | [docs/HALVES.md](docs/HALVES.md), `game/halves/` |
| Board view, feel and effects | `game/halves/halves_board_view.gd`, `halves_tile_view.gd`, `halves_snap_fx.gd` |
| Game screen, modes, clock and records | `ui/screens/game.gd`, `game/halves/halves_records.gd` |
| Chapters, prints and ambience | `game/halves/halves_chapters.gd`, `chapter_background.gd`, `tools/art/` |
| Sound and music | `core/audio/sound.gd` (autoload `Sound`), `tools/audio/build_audio.sh` |
| Levels and daily, zen and rush boards | `tools/levelgen/` → `data/levels/*_v2.json` |

**Levels are generated offline and baked; nothing is made up at run time.**
1. Hand-drawn stack masks plus a plan give each level its role (rest, ramp, hard, finale), its pair
   types and its new feature.
2. A reverse-removal fill makes every board solvable. Trap-seeding then gives some stacked tiles
   mated faces, so careless play can strand a half on top of its own mate.
3. Three bots rate every candidate:
   - **random:** taps any free pair;
   - **careful:** frees the most tiles;
   - **wary:** a human-like player who avoids obvious traps.
4. The candidate closest to the level's target wins. Hard levels and finales must still be fair for
   the wary bot.

```powershell
powershell -ExecutionPolicy Bypass -File tools/levelgen/generate_parallel.ps1   # all levels and pools
godot --headless --path . -s tools/levelgen/generate_halves.gd -- 41           # preview one level
godot --headless --path . -s tools/levelgen/bench_halves.gd                    # timings
```

Reports land in `tools/levelgen/reports/`. Other tools:
- `tools/snapshots.ps1 -Styles halves`: screenshots of every screen.
- `godot --path . -s tools/halves_playtest.gd -- 41`: plays a level with real taps and saves key frames.

Halves is built on the studio's Godot mobile template: a UI kit, services with mocks, ad rules,
saves and the test setup. The template's guides are in [docs/](docs/): [UI kit](docs/UI_KIT.md),
[Architecture](docs/ARCHITECTURE.md), [Services](docs/SERVICES.md),
[Testing](docs/TESTING_AND_DEBUGGING.md).

## Credits

A game by **Mehul Kumar**, built with [Godot Engine](https://godotengine.org) and
[Maaack's Godot Game Template](https://github.com/Maaack/Godot-Game-Template) (MIT).

- **Art:** woodblock prints by **Utagawa Hiroshige**, *One Hundred Famous Views of Edo*
  (1856-58), public domain. Scans from the Rijksmuseum, The Metropolitan Museum of Art (Open
  Access, CC0) and the Library of Congress. Tiles, shapes and effects are drawn in code.
- **Music (CC0):**
  - "Oriental Somber" by Tozan;
  - "Hot Springs Town" by Kistol;
  - "Another August", "Vaporware", "November Snow" and "Lifewave 2k" by The Cynic Project.
- **Sounds (CC0):** [Kenney](https://kenney.nl) Casino Audio, Impact Sounds, Interface Sounds and
  Music Jingles.
- **Fonts and icons:** Outfit (SIL OFL 1.1); Material Symbols (Apache 2.0).

Every third-party file, with its licence and source, is listed in
[ASSETS_LICENSES.md](ASSETS_LICENSES.md). No AI-generated art, music or sound is used.
