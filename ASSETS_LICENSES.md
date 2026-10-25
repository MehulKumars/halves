# Assets and code licences

Every third-party file in a shipped game must be listed here with its author, licence and source.
Allowed: CC0 and public domain, MIT, Apache 2.0, CC BY (with credit in the Credits screen), SIL OFL for
fonts, Unsplash and Pexels licence photos (credited anyway; never Unsplash+), and our own work drawn or
synthesised in code.
Never: CC BY-NC, CC BY-ND, CC BY-SA (Halves is closed source), GPL, Pixabay (its "standalone" clause
covers edited wallpapers), AI-generated assets. No feature may let players save or export a photo.
Halves v3 ships no CC BY-SA assets; do not add any.

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
| 39 icons in `core/ui/icons/` (Material Symbols Rounded, filled, and Material Icons "local_fire_department"; recoloured white and resized to 48 px) | Apache 2.0 (`core/ui/icons/LICENSE_material_symbols.txt`) | Google, github.com/google/material-design-icons |

## Game assets
Add one row per asset as you add them: file, author, licence, source URL.
| File | Author | Licence | Source |
|---|---|---|---|
| `game/halves/icons/shuffle.svg` (Material Symbols Rounded "shuffle", filled; recoloured white, 48 px) | Google | Apache 2.0 (`core/ui/icons/LICENSE_material_symbols.txt`) | github.com/google/material-design-icons, `symbols/web/shuffle/materialsymbolsrounded/shuffle_fill1_24px.svg` |
| Halves tiles, half shapes, snap card and shards | Drawn in code (`game/halves/halves_shapes.gd`, `halves_tile_view.gd`, `halves_snap_fx.gd`) from the concept's palette | Original work | - |
| `data/levels/halves_v3.json`, `halves_daily_v3.json`, `halves_zen_v3.json`, `halves_rush_v3.json` (and the v2 files) | Generated offline from the masks and plans in `tools/levelgen/` | Original work | - |
| Particle shapes (petal, rain streak, leaf, snowflake, glow), the Halves mark, feature overlays (mist, key, padlock, frost, gold) | Drawn in code (`game/halves/chapter_background.gd`, `halves_logo.gd`, `halves_tile_view.gd`) | Original work | - |
| "Drawn" backgrounds (the eleven places as layered silhouettes) | Drawn in code (`game/halves/halves_scenery.gd`) | Original work | - |
| `assets/audio/music/focus_tones.ogg` (binaural beat, soft chord, brown noise) | Synthesised by `tools/audio/build_music.sh` (ffmpeg) | Original work | - |

### Background photos (`assets/backgrounds/`, baked by `tools/art/process_photos.gd` from `tools/art/photos.json`)
All from Wikimedia Commons (a few first shared on Unsplash under CC0). Changes made: cropped to portrait
and resized (and dimmed on screen during play). Each place shows <place>_a for its levels 1-10 and
<place>_b for 11-20 (HalvesChapters); Floating Gate, Golden Pavilion and Thousand Gates have one photo.
| File | Photo | Author | Licence | Source |
|---|---|---|---|---|
| `fuji_lake_a.webp` (also the home screen) | Kawaguchiko, Part II - Kawaguchiko6805 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Kawaguchiko,_Part_II_-_Kawaguchiko6805.jpg |
| `fuji_lake_b.webp` | Kawaguchiko, Part I - Kawaguchiko6814 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Kawaguchiko,_Part_I_-_Kawaguchiko6814.jpg |
| `sakura_a.webp` | Blossom-ueno-park (Unsplash) | Don Kawahigashi | CC0 1.0 | commons.wikimedia.org/wiki/File:Blossom-ueno-park_(Unsplash).jpg |
| `sakura_b.webp` | Cherry blossom in Fukuokazeki sakura park | On-chan | CC0 1.0 | commons.wikimedia.org/wiki/File:Cherry_blossom_in_Fukuokazeki_sakura_park.JPG |
| `bamboo_a.webp` | Hokokuji Bamboo Forest Kamakura | Urashimataro | Public domain | commons.wikimedia.org/wiki/File:Hokokuji_Bamboo_Forest_Kamakura.jpg |
| `bamboo_b.webp` | Impressive bamboo canopy (Unsplash) | Jason Ortego | CC0 1.0 | commons.wikimedia.org/wiki/File:Impressive_bamboo_canopy_(Unsplash).jpg |
| `kyoto_a.webp` | HigashiyamaStreets7228 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:HigashiyamaStreets7228.jpg |
| `kyoto_b.webp` | Streets of Gion, Kyoto - Gion7709 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Streets_of_Gion,_Kyoto_-_Gion7709.jpg |
| `nara_a.webp` | Nara - Nara7619 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Nara_-_Nara7619.jpg |
| `nara_b.webp` | Nara - Nara7598 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Nara_-_Nara7598.jpg |
| `tokyo_a.webp` | Tokyo Tower at night - DSC00818 | Daderot | CC0 1.0 | commons.wikimedia.org/wiki/File:Tokyo_Tower_at_night_-_DSC00818.JPG |
| `tokyo_b.webp` | Azabudai Hills and Tokyo Tower at night | Syced | CC0 1.0 | commons.wikimedia.org/wiki/File:Azabudai_Hills_and_Tokyo_Tower_at_night.jpg |
| `autumn_a.webp` | Eikando, Kyoto - Eikando7376 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Eikando,_Kyoto_-_Eikando7376.jpg |
| `autumn_b.webp` | Nanzen-ji, Kyoto - Nanzenji7336 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Nanzen-ji,_Kyoto_-_Nanzenji7336.jpg |
| `moon_a.webp` | Matsumoto-castle-2026-PM | Hiroaki Kikuchi | CC0 1.0 | commons.wikimedia.org/wiki/File:Matsumoto-castle-2026-PM.jpg |
| `moon_b.webp` | Tokyo Tower and moon seen from Shibuya Stream | Syced | CC0 1.0 | commons.wikimedia.org/wiki/File:Tokyo_Tower_and_moon_seen_from_Shibuya_Stream.jpg |
| `ginzan_a.webp` | Otaru Canal Cruise (20240223) | Fumikas Sagisavas | CC0 1.0 | commons.wikimedia.org/wiki/File:Otaru_Canal_Cruise_(20240223).jpg |
| `ginzan_b.webp` | Ginzan Onsen, the other side | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Ginzan_Onsen,_the_other_side.jpg |
| `himeji_a.webp` | Himeji - Himeji357 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Himeji_-_Himeji357.jpg |
| `himeji_b.webp` | Himeji Castle 20260403120700 | Loggieloggie | CC0 1.0 | commons.wikimedia.org/wiki/File:Himeji_Castle_20260403120700.jpg |
| `shirakawa_a.webp` | Shirakawa-go - Shirakawa170 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Shirakawa-go_-_Shirakawa170.jpg |
| `shirakawa_b.webp` | View of Shirakawa-go from Ogimachi Joseki Observatory - Jason Ortego 2015 (Unsplash) | Jason Ortego | CC0 1.0 | commons.wikimedia.org/wiki/File:View_of_Shirakawa-go_from_Ogimachi_Joseki_Observatory_-_Jason_Ortego_2015_(Unsplash).jpg |
| `hokkaido_a.webp` | Field of flowers in Hokkaido, Japan | TheOneMattMan | CC0 1.0 | commons.wikimedia.org/wiki/File:Field_of_flowers_in_Hokkaido,_Japan.jpg |
| `hokkaido_b.webp` | Historical Village of Hokkaido & Moerenuma Park - HistoricalVillageHokkaido7148 | lumoplank | CC0 1.0 | commons.wikimedia.org/wiki/File:Historical_Village_of_Hokkaido_&_Moerenuma_Park_-_HistoricalVillageHokkaido7148.jpg |
| `torii.webp` | Itsukushima-jinja torii at sunset, Miyajima | Jakub Hałun | CC BY 4.0 | commons.wikimedia.org/wiki/File:Itsukushima-jinja_torii_at_sunset,_Miyajima,_Japan,_20240816_1835_4171.jpg |
| `kinkaku.webp` | Kinkakuji temple in snow | Takeshi Kuboki | CC BY 2.0 | commons.wikimedia.org/wiki/File:%E9%9B%AA%E3%81%AE%E9%87%91%E9%96%A3%E5%AF%BA_Kinkakuji_temple_in_snow_(5360759256).jpg |
| `inari.webp` | Fushimi Inari, Kyoto | Jakub Hałun | CC BY 4.0 | commons.wikimedia.org/wiki/File:Fushimi_Inari,_Kyoto,_20240818_1400_4476.jpg |
Each `<id>_thumb.webp` is a 320 px square from the same photo.

### Sounds (`assets/audio/sfx/`, made by `tools/audio/build_audio.sh`: trimmed, levelled, some layered)
| Files | Source pack | Author | Licence | Source |
|---|---|---|---|---|
| select, deselect, snap, snap_big, shuffle, undo, reveal, gold, coin (chip and card sounds) | Casino Audio | Kenney (kenney.nl) | CC0 | kenney.nl/assets/casino-audio |
| blocked, mistake, unlock, thaw, chapter (wood, soft, metal, glass and bell impacts) | Impact Sounds | Kenney | CC0 | kenney.nl/assets/impact-sounds |
| snap, snap_big, hint, unlock, gold, star, click, open, close, tick, swift (glass, pluck and interface tones) | Interface Sounds | Kenney | CC0 | kenney.nl/assets/interface-sounds |
| best, win_spring, win_summer, win_autumn, win_winter, win_moon, chapter (pizzicato jingles) | Music Jingles | Kenney | CC0 | kenney.nl/assets/music-jingles |

### Music and soundscapes (`assets/audio/music/`, from `tools/audio/music.tsv` by `tools/audio/build_music.sh`)
Songs are levelled to -18 LUFS and play whole, one after another; soundscapes are cut to seamless loops
(at most 120 s) at -24 LUFS. Changes made: levelled, faded in, looped, re-encoded. None is AI-generated
(Free Music Archive pages say "AI generated? No").
| File | Track | Author | Licence | Source |
|---|---|---|---|---|
| `roof_tops.ogg` (Lo-fi) | Roof Tops | HoliznaCC0 | CC0 1.0 | freemusicarchive.org/music/holiznacc0/summer-air-lo-fi/roof-tops/ |
| `ocean_breeze.ogg` (Lo-fi) | Ocean Breeze | HoliznaCC0 | CC0 1.0 | freemusicarchive.org/music/holiznacc0/public-domain-lofi/ocean-breeze-lofi-ukulele-peaceful-mp3/ |
| `bubbles.ogg` (Lo-fi) | Bubbles | HoliznaCC0 | CC0 1.0 | freemusicarchive.org/music/holiznacc0/public-domain-lofi/bubbles-lofi-bright-relaxed/ |
| `cafe_weather.ogg` (Lo-fi) | it's perfect weather for a trip to the café, don't you think? | AvapXia | CC BY 4.0 | freemusicarchive.org/music/avapxia/summer-lofi/its-perfect-weather-for-a-trip-to-the-cafe-dont-you-think/ |
| `evening_glow.ogg` (Lo-fi) | Evening Glow | Lee Rosevere | CC BY 4.0 | freemusicarchive.org/music/lee-rosevere/music-for-podcasts-beats/evening-glow/ |
| `up_in_the_sky.ogg` (Calm) | Up in the Sky | Memoraphile | CC0 1.0 | opengameart.org/content/up-in-the-sky |
| `early_morning.ogg` (Calm) | Early Morning Song (Finch Duet) | Lee Rosevere | CC BY 4.0 | freemusicarchive.org/music/lee-rosevere/music-for-podcasts-ambient/early-morning-song-finch-duet/ |
| `autumn_sunshine.ogg` (Calm) | Autumn Sunshine | Matthew C. Wright | CC BY 4.0 | freemusicarchive.org/music/matthew-c-wright/slow-royalty-free-piano-away-for-autumn/gentle-royalty-free-piano-autumn-sunshine/ |
| `rain_leaves.ogg` (Rain) | Rain on leaves | Gravity Sound | CC BY 4.0 | commons.wikimedia.org/wiki/File:Rain_on_leaves_(Gravity_Sound).wav |
| `waves.ogg` (Nature) | Sea of the Beach of Dellec #2 | Joseph Sardin (BigSoundBank) | CC0 1.0 | bigsoundbank.com/sea-of-the-beach-of-dellec-2-s2565.html |
| `forest_stream.ogg` (Nature) | Forest and Stream #3 | Pierre Sibanarco (BigSoundBank) | CC0 1.0 | bigsoundbank.com/sound-2716-forest-and-stream-3.html |
| `night_crickets.ogg` (Nature) | Campaign at Night #4 | Joseph Sardin (BigSoundBank) | CC0 1.0 | bigsoundbank.com/campaign-at-night-4-s1880.html |
