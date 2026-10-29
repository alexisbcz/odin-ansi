# Changelog

This file records all notable changes to this project.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-29

### Added

- `Color` as a union of the 16 basic colors, the 256-color palette and 24-bit `RGB`.
- `parse_color` and `parse_hex` for colors written as names, palette indexes or hex.
- `color_convert`, `rgb_to_256` and `rgb_to_basic` to downsample colors.
- `Profile`, `detect_profile` and `profile_from_environment`, which honor `NO_COLOR`, `FORCE_COLOR`, `CLICOLOR_FORCE`, `TERM`, `COLORTERM` and TTY state.
- `enable_virtual_terminal` for Windows consoles.
- `display_width`, `height`, `size`, `strip`, `truncate`, `align_text` and `expand_tabs`, all aware of escape sequences and grapheme clusters.
- `Style` and `render` with colors, attributes, alignment, `width`, `max_width`, padding, margins and borders.
- Border presets: normal, rounded, thick, double, ASCII and hidden.
- `Table` and `table_render` with per-column alignment, multi-line cells, ragged rows and header and row rules.
- `join_horizontal` and `join_vertical` to combine rendered blocks.
- `sgr` to build an opening escape sequence by hand.

[Unreleased]: https://github.com/alexisbcz/odin-ansi/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/alexisbcz/odin-ansi/releases/tag/v0.1.0
