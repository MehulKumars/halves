class_name HalvesConfig
extends RefCounted
## Halves tunables in one place: generator version, booster prices, star thresholds, tutorial help.
## Read by the game screen, the board view and the logic in game/halves/ (see docs/HALVES.md).
## Changing GEN_VERSION means baking a new data/levels/halves_v<N>.json; never edit a shipped file.

const GEN_VERSION: int = 1

## Boosters: free uses per level, then coins or a rewarded video for one more use.
const FREE_USES: int = 1
const PRICE_HINT: int = 30
const PRICE_UNDO: int = 30
const PRICE_SHUFFLE: int = 40

## Stars: 3 with no mistakes, 2 with up to this many, else 1.
const STAR2_MAX_MISTAKES: int = 2

## Levels 1..N forgive the first mistake (and show the mate) so the rule is taught, not punished.
const TUTORIAL_FORGIVE_LEVELS: int = 3
## Levels 1..N pulse the mate of the selected tile.
const MATE_PULSE_LEVELS: int = 2

## When true, any non-matching pair is a mistake (not only twins and near-twins). For playtests.
const STRICT_MISTAKES: bool = false

## Seconds after the last snap before the stuck card appears.
const STUCK_DELAY: float = 0.5

## Coins per star at the end of a level (the template's default economy).
const COINS_PER_STAR: int = 10
