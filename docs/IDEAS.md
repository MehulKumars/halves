# Halves: review and ideas

A design review of Halves as of 2026-10-19 (30 levels, `gen_version` 1), and the ideas for making it
more unique and more of a hook. Nothing here is built yet; these are proposals to prototype and
playtest, not decisions.

## 1. Review

### What is strong
- **The hook is a real twist.** Mahjong solitaire is a memory game; "match the mirror half, never
  the twin" makes it a game of reading carefully. A new skill in a familiar genre.
- **Calm fits the audience.** No timer, no lives and no fail state suit mahjong players, who tend
  to be older, stay for months and are valuable to ad networks.
- **The level pipeline is the real asset.** Seeded, solver-checked, bot-rated generation
  (`tools/levelgen/`) means levels scale; most indie puzzle games die on hand-made content.

### Concerns (from `tools/levelgen/reports/halves_v1.csv`)

| # | Concern | Evidence | Direction |
|---|---|---|---|
| 1 | Too easy to hold interest | A random tapper clears 54-100% of levels, a careful one 70-100%; levels 1-4, 6, 11 and 21 are cleared 100% even at random. With no fail state, only the third star is at stake. | Bring near-twins (other cut, other mark) in earlier; lower `target_win` by about 10-15 points across the plan. |
| 2 | Too little content | 30 levels; the genre expects hundreds. | 100+ levels before launch (new masks plus plan entries); add a daily puzzle seeded by the date. |
| 3 | The economy has no pull | `careful_win` is about 1.0, so boosters are rarely needed and coins and rewarded ads have little purpose. | Star-gated packs, a "remove ads" purchase, rewarded ads as a bonus (double coins) rather than a rescue. Never lives or energy. |
| 4 | Readability on small phones | Level 30: 64 tiles on 4 layers, near-twins that differ only by a small dot or line mark. | Faces of at least 96 px are already tested; still play it on a cheap 5.5" phone at arm's length. |

## 2. Ideas for uniqueness and hook

Today the game reads as "mahjong with mirror halves". To stand out it needs a theme that gives the
matching meaning, one mechanic only it has, and a reason to come back tomorrow.

### 2.1 Theme: kintsugi
Kintsugi is the Japanese art of mending broken pottery with gold. It matches the rules exactly:
two broken halves become one whole, and the player mends instead of destroys.
- **Every snap leaves a gold seam** where the halves join. This is the signature effect and the
  store-video moment.
- **Each level is a broken vessel.** Clearing the board restores a bowl, vase or teacup, which
  goes on a shelf; each pack is a room of the collection.
- **The palette already fits:** cobalt, ivory, sand, terracotta and teal are glaze colours.
- Before committing, search the Play Store for "kintsugi" to avoid a name or look clash.

### 2.2 Signature mechanic: fold-up merges
Today a matched pair disappears, so there is little to plan.
- **Quarter tiles:** two matching quarters snap into a half that stays on the board; two halves
  snap into a whole.
- Every match now changes the board: it frees tiles and creates one that is needed later, so the
  player plans ahead ("this half's mate is still buried"). Plain mahjong never asks that.
- Introduce it as pack 2's big idea. It also answers concern 1 without adding pressure.
- Logic impact: `HalvesFace` needs a quarter level, `HalvesState.try_pair` must add the merged tile,
  and the fill, solver and bot must handle tiles that appear during play.

Smaller variations, one per later pack:
- **Rotated halves:** the mate is turned 90°, so the player recognises the shape, not just the mirror.
- **Hidden tiles:** face-down until free (a light memory element).
- **Mirror line:** tiles beyond a line on the board show their reflection.

### 2.3 Sound that rewards good play
- Each shape has a note; a snap plays a soft chord.
- Matches in a row without a mistake climb a scale.
- The results screen plays back the melody the player's matches made.

### 2.4 Reasons to come back
- **Daily vessel:** one special puzzle a day (`SeedService` with the date), with a rare piece for
  the shelf. A streak calendar that never punishes a missed day.
- **Collections with gaps:** "4 of 6 vessels in the Tea Room".

### 2.5 The first 30 seconds
- Level 1 is playable within about 3 seconds of opening the app, with no text.
- The player makes the twin mistake once (free on tutorial levels) and feels the rule.
- The first gold seam happens within 10 seconds.

### 2.6 Not to add
Lives, energy, timers and fail screens. Calm is the selling point.

## 3. Plan

1. Play the current build on a phone; watch 3-5 people play without helping. Note boredom and
   misreads.
2. Prototype **fold-up merges**: rules in `docs/HALVES.md` first, tests written from them by a
   separate session (see `CLAUDE.md`), then the logic and a few test levels on the phone. It is
   the riskiest idea and the one most likely to make the game unique.
3. Prototype the **gold seam snap** to check the kintsugi look.
4. If both work, commit to the theme: vessel art, the shelf, the sound.
5. Retune difficulty and grow to 100+ levels with the generator.
6. Store basics: real icon, real package name (replace `com.changeme.template`), release keystore,
   studio name in the credits.
7. Then real ads and purchases (still mocks, see [SERVICES.md](SERVICES.md)) and the daily vessel.

Release note: as far as we know, new personal Google Play developer accounts must run a closed test
with at least 12 testers for 14 days before publishing to production. Check Play Console for the
current rule and start recruiting testers early.
