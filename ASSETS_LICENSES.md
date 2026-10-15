# Assets and code licences

Every third-party file in a shipped game must be listed here with its author, licence and source.
Allowed: CC0, MIT, CC-BY (with credit in the Credits screen), SIL OFL for fonts.
Never: CC-BY-NC (bars ad-supported games), CC-BY-ND, GPL or CC-BY-SA in closed-source games, AI-generated assets.

## Code (addons)
| Item | Version | Author | Licence | Ships in release? |
|---|---|---|---|---|
| Maaack's Game Template, Scene Loader, Music Controller, UI Sound Controller, Plugin Updater, Clean Copy Examples | 1.7.0 | Marek Belski and contributors | MIT (`LICENSE.txt`) | Yes |
| GUT (Godot Unit Test) | 9.7.1 | Butch Wesley and contributors | MIT (`addons/gut/LICENSE.md`) | No (excluded from the release preset) |
| LimboConsole | 0.8.0 | Serhii Snitsaruk | MIT (`addons/limbo_console/LICENSE.md`) | Yes, but disabled in release builds |

## Written for this template
| Item | Notes |
|---|---|
| `core/`, `tests/`, `tools/`, `core/ui/mobile_theme.tres`, `core/feel/hit_flash.gdshader` | Original work for this template; reuse freely in your games |

## Fonts
| Font | Used by | Licence |
|---|---|---|
| Monaspace Argon | LimboConsole | SIL OFL 1.1 (`addons/limbo_console/res/fonts/LICENSE.md`) |
| Anonymous Pro, Courier Prime, Lobster Two | GUT only (not shipped) | See `addons/gut/fonts/` |

## Images from Maaack's template
| Asset | Licence | Action before shipping a game |
|---|---|---|
| Godot Engine logo (`assets/godot_engine_logo/`) | CC BY 4.0 (Andrea Calabró) | Keep with credit, or remove from the opening scene |
| Git logo (`assets/git_logo/`) | CC BY 3.0 (Jason Long) | Remove from the opening scene |
| Maaack plugin logo (`assets/plugin_logo/`) | MIT | Remove from the opening scene |

## Game assets
Add one row per asset as you add them: file, author, licence, source URL.
| File | Author | Licence | Source |
|---|---|---|---|
