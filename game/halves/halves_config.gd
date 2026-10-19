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

## Rewards: coins per gold tile cleared, for the first Swift medal, and for a combo of COMBO_COINS_AT.
const GOLD_COINS: int = 5
const SWIFT_COINS: int = 10
## Snaps closer together than this (seconds) build a combo chain.
const COMBO_WINDOW: float = 2.5
const COMBO_COINS_AT: int = 5
const COMBO_COINS: int = 5

## Modes: unlock levels and the Rush clock (seconds).
const ZEN_UNLOCK_LEVEL: int = 10
const RUSH_UNLOCK_LEVEL: int = 15
const RUSH_SECONDS: int = 180
const RUSH_BOARD_BONUS_S: int = 5
const RUSH_MISTAKE_PENALTY_S: int = 3
const RUSH_BOARD_POINTS: int = 10

## Par time (docs/HALVES.md section 4), for the human to tune after real plays.
const PAR_BASE_S: float = 10.0
const PAR_PER_PAIR_S: float = 2.2
const PAR_PER_TYPE_S: float = 1.5
const PAR_PER_LAYER_S: float = 3.0
const PAR_PER_FEATURE_S: float = 1.0
const PAR_DIFFICULTY_SCALE: float = 0.005
const PAR_ROUND_S: int = 5
