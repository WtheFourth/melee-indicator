# Changelog

All notable changes to Melee Indicator will be documented in this file.

## [1.0.0] - 2026-05-23

### Added
- Initial release.
- Four selectable shapes: square, circle, diamond, triangle.
- Configurable size (16 px to 128 px) and on-screen position.
- Drag-to-move with lock toggle, plus typed X/Y coordinate inputs.
- Border with texture dropdown, thickness slider (0 px to 8 px), and color
  picker. Defaults to a 1 px solid black border.
- LibSharedMedia-3.0 border textures appear in the dropdown automatically
  when LSM is present.
- Independent in-range and out-of-range colors with full alpha control.
- Range spell stored per specialization, populated from the player's
  spellbook with a manual name / spell-ID override.
- Indicator only renders when targeting an attackable, living enemy.
- Slash commands `/melee` and `/mi`, with `lock`, `unlock`, and `reset`
  subcommands.
- Saved-variable position is validated on load; corrupted positions reset to
  the default instead of throwing an error.
