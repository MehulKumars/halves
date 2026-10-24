# Accessibility

Accessible games are also easier to play one-handed, on a bus, muted, or on a cheap phone, which is
most of this audience. Puzzle players skew 35+, so readable text and generous touch targets matter.

## Built into the template

| Feature | Where | Detail |
|---|---|---|
| Large touch targets | every theme (`tools/build_theme.gd`) | Every button, switch, slider and tile is at least 96 px on the 720 px canvas (= Android's 48 dp minimum, which also meets Apple's 44 pt and WCAG 2.2's 24 px). Checked for every style by `tests/test_theme.gd` and on every screen at three sizes by `tests/test_screens.gd` |
| Text contrast | every theme | WCAG AA: 4.5:1 for normal text, 3:1 for large text, in all five styles (`tests/test_theme.gd`). Outlined text is measured against its outline |
| Readable text | every theme | 32 px body text (16 dp on a 360 dp phone), 26 px minimum for captions |
| State not by colour alone | switches, level tiles, daily reward | Switches change knob size and position; locked levels show a lock; claimed days show a tick |
| Reduce Motion | Settings; `AppLifecycle`, `Juice.motion_scale` | Turns off button squash, popup pop-ins, the logo intro, Play button breathing, star pops, coin count-ups and background drift. Your own effects must check `Juice.motion_scale` too |
| Vibration toggle | Settings; `Haptics.enabled` | Haptics can be turned off; never the only signal |
| Notch-safe layout | `SafeAreaMargin` on every screen and popup | Keeps UI clear of camera holes, rounded corners and the gesture bar |
| Back button | `ui_cancel` includes Android Back | Closes the top popup, then goes back a screen; the game opens pause; the main menu asks before quitting |
| Focus rings for keyboard and gamepad | `UI` autoload | Rings appear after a key or pad press and hide again after a tap |
| Interruptions | `AppLifecycle` > `Events.app_paused` | Progress saves on every change; pause state is restored when popups close |
| Separate volume controls | Settings | Music and Sound sliders, plus quick toggles in the pause menu |
| Offline play | design | Everything except ads works offline |

## In Halves (v3)

- **Shape first, colour second.** Every tile is told apart by its crest's shape; each crest family
  also has its own ink, but no rule depends on colour. Look-alikes differ in shape (petal count,
  notch, ring), never in colour alone.
- **Bold tiles** (Settings > Look and feel): darker crest ink, a dark edge round every tile face,
  and blocked tiles dimmed further, for low light or low vision. Applies at once, mid-level too.
- **Left-handed** (Settings): the boosters sit at the bottom left and pause at the top right.
- **Reduce Motion** stops the falling petals, drift, snaps' flight and shakes at once (no restart
  needed); the snap still shows its card for a moment, so a match is never missed.
- **Every event is visual.** Snaps show a gold seam, mistakes shake and ring the tiles red, lucky
  tiles glow with dots that count down by pairs (never by seconds), a mend flies the mate out of the
  stack. Sounds (pentatonic chimes, a wooden knock) and haptics only add to these.
- **Calm stars.** Levels 1-10 never lose a star; later boards allow a few free slips, and nothing
  runs on a timer except the optional Swift medal and the Rush mode.
- **No TalkBack promise:** Godot's screen-reader support does not reach Android yet (see Known gaps).

## Each game must still do

- **Never carry information by colour alone.** About 1 in 12 men has red-green colour blindness.
  Pair every meaningful colour with a shape, symbol or pattern, and check screenshots in greyscale
  and a colour-blind simulator.
- **Contrast for game pieces:** at least 3:1 against the board.
- **Never carry information by sound or vibration alone.** Many players play muted and phones can
  block haptics. Every important event needs a visual on the same frame.
- **No held buttons or button-mashing**; keep tap targets still while the player is aiming at them.
- **Primary actions in the bottom third** of the screen (one-thumb reach); pause and rare actions
  away from the thumb.
- **Teach by doing** in the first minute; no walls of text.
- **No flashing** effects that could trigger photosensitivity; keep screen shake out of calm games
  and scale it by `Juice.motion_scale` in loud ones.
- **Forgiveness:** undo, hints and free paths on hard levels.

## Known gaps

- **Screen readers:** Godot's AccessKit support for Android TalkBack was merged for Godot 4.8,
  which is still in development. Plan a TalkBack test for menu-heavy games once 4.8 is stable.
- **No text-size setting yet.** Word games should add one (a setting that raises the style's
  `font_size` and `text_scale` and rebuilds, or scales the theme at runtime).
- **No translations yet.** Strings live in scenes and scripts.

## Checklist before release

- [ ] `tools/check.ps1` passes (contrast, touch sizes, every screen at three sizes)
- [ ] Your game screens added to `tests/test_screens.gd` and pass
- [ ] Game pieces at least 3:1 against the board
- [ ] Game playable in greyscale and with sound off
- [ ] Reduce Motion removes or softens every effect
- [ ] Back button and app switching tested on a phone
- [ ] No important UI under the camera hole or the gesture bar (`safe_area` console command on PC, a
      real phone before release)
