# Accessibility

Accessible games are also easier to play one-handed, on a bus, muted, or on a cheap phone, which is
most of this audience. Puzzle players skew 35+, so readable text and generous touch targets matter.

## Built into the template

| Feature | Where | Detail |
|---|---|---|
| Large touch targets | `core/ui/mobile_theme.tres` | Buttons padded to about 96 px tall and toggles to 96 px tap areas on the 720 px canvas (= Android's 48 dp minimum, which also meets Apple's 44 pt and WCAG) |
| Readable text | `core/ui/mobile_theme.tres` | 32 px default text (about 16-18 sp on a phone) |
| Reduce Motion | Options > Game; `AppLifecycle`, `Juice.motion_scale` | When on, `Juice` effects are skipped. Your own effects must check `Juice.motion_scale` too |
| Haptics toggle | Options > Game; `Haptics.enabled` | Vibration can be turned off; never the only signal |
| Notch-safe layout | `SafeAreaMargin` | Keeps UI clear of camera cut-outs and system bars |
| Interruptions | `AppLifecycle` > `Events.app_paused` / `back_requested` | Save on pause; Back goes to the pause menu instead of quitting |
| Separate volume controls | Options > Audio | Master, Music, SFX sliders and Mute |
| Offline play | design | Everything except ads works offline |

## Each game must still do

- **Never carry information by colour alone.** About 1 in 12 men has red-green colour blindness.
  Pair every meaningful colour with a shape, symbol or pattern, and check screenshots in greyscale
  and a colour-blind simulator.
- **Contrast:** text at least 4.5:1 against its background (3:1 for large text); game pieces at
  least 3:1 against the board.
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

- **Volume sliders are thin** (Godot's default slider artwork), below the 48 dp target. Restyle them
  per game (slider grabber icons and track style).
- **Toggle switch graphics are small** (default artwork), although their tap areas are 96 px.
- **Screen readers:** Godot's AccessKit support for Android TalkBack was merged for Godot 4.8,
  which is still in development. Plan a TalkBack test for menu-heavy games once 4.8 is stable.
- **No text-size setting yet.** Word games should add one (an `OptionControl` that changes the
  theme's font size).

## Checklist before release

- [ ] Every button and tile at least 96 px on the 720 canvas
- [ ] Text contrast at least 4.5:1; pieces at least 3:1
- [ ] Game playable in greyscale and with sound off
- [ ] Reduce Motion removes or softens every effect
- [ ] Back button and app switching tested on a phone
- [ ] No important UI under the notch or system bars
