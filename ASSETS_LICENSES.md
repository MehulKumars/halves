# Assets and code licences

Every third-party file in a shipped game must be listed here with its author, licence and source.
Allowed: CC0, MIT, Apache 2.0, CC-BY (with credit in the Credits screen), SIL OFL for fonts.
Never: CC-BY-NC (bars ad-supported games), CC-BY-ND, GPL or CC-BY-SA in closed-source games, AI-generated assets.

## Code (addons)
| Item | Version | Author | Licence | Ships in release? |
|---|---|---|---|---|
| Maaack's Game Template, Scene Loader, Music Controller, UI Sound Controller | 1.7.0 | Marek Belski and contributors | MIT (`LICENSE.txt`, packed into builds and shown in the credits) | Yes (examples folder and logos excluded) |
| Maaack's Plugin Updater, Clean Copy Examples | 1.7.0 | Marek Belski and contributors | MIT | No (editor only, excluded) |
| GUT (Godot Unit Test) | 9.7.1 | Butch Wesley and contributors | MIT (`addons/gut/LICENSE.md`) | No (excluded) |
| LimboConsole | 0.8.0 | Serhii Snitsaruk | MIT (`addons/limbo_console/LICENSE.md`) | Yes, but disabled in release builds; its Monaspace fonts are excluded (the console uses `addons/limbo_console_theme.tres`) |

## Written for this template
| Item | Notes |
|---|---|
| `core/`, `ui/`, `tests/`, `tools/`, the five styles and their themes, `styled_background.gdshader`, `hit_flash.gdshader`, the switch and slider artwork (SVG drawn in `tools/build_theme.gd`), the placeholder app icon (`icon.png`, `assets/template_icon/`) | Original work for this template; reuse freely in your games |

## Fonts (all SIL Open Font License 1.1, from Google Fonts)
The licence text for each is next to it in `core/ui/fonts/OFL_<name>.txt`. OFL fonts may be
bundled in commercial games if each copy carries the licence: both export presets pack the
`OFL_*.txt` files (and the icons' Apache licence) into the app, and the credits list the fonts.

| Font | Used by style | Copyright |
|---|---|---|
| Outfit | Sleek Dark | The Outfit Project Authors (github.com/Outfitio/Outfit-Fonts) |
| Fredoka | Candy Casual | The Fredoka Project Authors (github.com/hafontia/Fredoka-One) |
| Orbitron (Reserved Font Name "Orbitron") | Neon Arcade titles | The Orbitron Project Authors (github.com/theleagueof/orbitron) |
| Exo 2 | Neon Arcade text | The Exo 2 Project Authors (github.com/googlefonts/Exo-2.0) |
| Nunito | Cozy Paper | The Nunito Project Authors (github.com/googlefonts/nunito) |
| Pixelify Sans | Pixel Retro titles | The Pixelify Sans Project Authors (github.com/eifetx/Pixelify-Sans) |
| VT323 | Pixel Retro text and numbers | The VT323 Project Authors (peter.hull@oikoi.com) |
| Anonymous Pro, Courier Prime, Lobster Two | GUT only (not shipped) | See `addons/gut/fonts/` |

## Icons
| Item | Licence | Source |
|---|---|---|
| 38 icons in `core/ui/icons/` (Material Symbols Rounded, filled; recoloured white and resized to 48 px) | Apache 2.0 (`core/ui/icons/LICENSE_material_symbols.txt`) | Google, github.com/google/material-design-icons |

## Game assets
Add one row per asset as you add them: file, author, licence, source URL.
| File | Author | Licence | Source |
|---|---|---|---|
| `game/halves/icons/shuffle.svg` (Material Symbols Rounded "shuffle", filled; recoloured white, 48 px) | Google | Apache 2.0 (`core/ui/icons/LICENSE_material_symbols.txt`) | github.com/google/material-design-icons, `symbols/web/shuffle/materialsymbolsrounded/shuffle_fill1_24px.svg` |
| Halves tiles, half shapes, snap card and shards | Drawn in code (`game/halves/halves_shapes.gd`, `halves_tile_view.gd`, `halves_snap_fx.gd`) from the concept's palette | Original work | - |
| `data/levels/halves_v2.json`, `halves_daily_v2.json`, `halves_zen_v2.json`, `halves_rush_v2.json` | Generated offline from the masks and plans in `tools/levelgen/` | Original work | - |
| Particle shapes (petal, rain streak, leaf, snowflake, glow), the Halves mark, feature overlays (mist, key, padlock, frost, gold) | Drawn in code (`game/halves/chapter_background.gd`, `halves_logo.gd`, `halves_tile_view.gd`) | Original work | - |

### Chapter prints (`assets/chapters/`, baked by `tools/art/process_prints.gd` from the sources in `tools/art/prints.json`)
All by Utagawa Hiroshige (1797-1858), from *One Hundred Famous Views of Edo* (1856-58): public domain
worldwide (the artist died over 160 years ago); the scans were released by their collections without restrictions.
| File | Print | Collection (scan) | Licence of the scan | Source |
|---|---|---|---|---|
| `spring_bg.webp`, `spring_print.webp` | Plum Garden at Kameido (1857) | Rijksmuseum, Amsterdam, RP-P-1956-743 | Public domain | commons.wikimedia.org/wiki/File:De_pruimenboomgaard_te_Kameido-Rijksmuseum_RP-P-1956-743.jpeg |
| `summer_bg.webp`, `summer_print.webp` | Sudden Shower over Shin-Ohashi Bridge and Atake (1857) | The Metropolitan Museum of Art, DP123602 | CC0 (Met Open Access) | Wikimedia Commons, "MET DP123602" |
| `autumn_bg.webp`, `autumn_print.webp` | Maple Trees at Mama, Tekona Shrine and Tsugi Bridge (1857) | The Metropolitan Museum of Art, DP121529 | CC0 (Met Open Access) | Wikimedia Commons, "MET DP121529" |
| `winter_bg.webp`, `winter_print.webp` | Kinryuzan Temple at Asakusa (1856) | The Metropolitan Museum of Art, DP122116 | CC0 (Met Open Access) | Wikimedia Commons, "MET DP122116" |
| `moon_bg.webp`, `moon_print.webp` | Night View of Saruwaka-machi (1856) | Library of Congress, LCCN 2008660961 | Public domain (no known restrictions) | commons.wikimedia.org/wiki/File:Saruwaka-machi_yoru_no_kei_LCCN2008660961.jpg |

### Sounds (`assets/audio/sfx/`, made by `tools/audio/build_audio.sh`: trimmed, levelled, some layered)
| Files | Source pack | Author | Licence | Source |
|---|---|---|---|---|
| select, deselect, snap, snap_big, shuffle, undo, reveal, gold, coin (chip and card sounds) | Casino Audio | Kenney (kenney.nl) | CC0 | kenney.nl/assets/casino-audio |
| blocked, mistake, unlock, thaw, chapter (wood, soft, metal, glass and bell impacts) | Impact Sounds | Kenney | CC0 | kenney.nl/assets/impact-sounds |
| snap, snap_big, hint, unlock, gold, star, click, open, close, tick, swift (glass, pluck and interface tones) | Interface Sounds | Kenney | CC0 | kenney.nl/assets/interface-sounds |
| best, win_spring, win_summer, win_autumn, win_winter, win_moon, chapter (pizzicato jingles) | Music Jingles | Kenney | CC0 | kenney.nl/assets/music-jingles |

### Music (`assets/audio/music/`, at most 180 s, faded for looping and levelled by `tools/audio/build_audio.sh`)
| File | Track | Author | Licence | Source |
|---|---|---|---|---|
| `menu.ogg` | Oriental Somber (koto, shamisen, shakuhachi) | Tozan | CC0 | opengameart.org/content/oriental-somber |
| `spring.ogg` | Hot Springs Town | Kistol | CC0 | opengameart.org/content/hot-springs-town |
| `summer.ogg` | Another August | The Cynic Project (cynicmusic) | CC0 | opengameart.org/content/another-august |
| `autumn.ogg` | Vaporware (Calm Piano 1) | The Cynic Project | CC0 | opengameart.org/content/calm-piano-1-vaporware |
| `winter.ogg` | November Snow | The Cynic Project | CC0 | opengameart.org/content/november-snow |
| `moon.ogg` | Lifewave 2k (Calm Ambient 3) | The Cynic Project | CC0 | opengameart.org/content/calm-ambient-3-lifewave-2k |
