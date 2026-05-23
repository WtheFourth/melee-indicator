# Melee Indicator

A lightweight World of Warcraft addon that displays a configurable shape on
your screen. The shape changes color depending on whether your current target
is within range of a chosen melee spell.

Note: I made this at midnight using Claude on my iPad, and have not tested anything
yet. I saw a YouTube video that had something similar and wanted to see what I could
spin up, and this is the result. 

## Features

- Four shapes: square (default), circle, diamond, triangle
- Configurable size and on-screen position (drag the indicator or type X/Y)
- Border with selectable texture, thickness (0 px to 8 px), and color
  &mdash; defaults to a 1 px solid black outline
- Independent in-range and out-of-range colors, each with full alpha control
- Per-specialization range spell, picked from your spellbook or typed manually
  by name or spell ID
- Falls back to Auto Attack when no spell is configured
- Only visible when targeting an attackable, living enemy
- Shows while unlocked so you can position the indicator before locking it

## Slash commands

| Command | What it does |
| --- | --- |
| `/melee` or `/mi` | Open / close the options window |
| `/mi lock` | Lock the indicator (only shows when targeting an enemy) |
| `/mi unlock` | Unlock the indicator so it can be dragged |
| `/mi reset` | Restore all settings to defaults |

## Installation

1. Download the latest release zip from CurseForge (or this repository).
2. Extract the `MeleeIndicator` folder into
   `World of Warcraft/_retail_/Interface/AddOns/`.
3. Restart the client (or `/reload`) and target an enemy to see the
   indicator.

## Compatibility

Built for retail Midnight. The TOC lists all Midnight sub-patches
(12.0.0, 12.0.1, 12.0.5) so the addon does not show as out of date for
players on an earlier Midnight build. LibSharedMedia-3.0 is detected at
runtime &mdash; if another addon loads it, additional border textures
appear in the dropdown automatically. LibSharedMedia is **not** required.

## Reporting issues

Open an issue on this repository. Please include the WoW version
(`/dump select(4, GetBuildInfo())`), a description of what you expected,
and what actually happened.

## License

[MIT](LICENSE).
