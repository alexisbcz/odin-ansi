# odin-ansi

[![CI](https://github.com/alexisbcz/odin-ansi/actions/workflows/ci.yml/badge.svg)](https://github.com/alexisbcz/odin-ansi/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Odin](https://img.shields.io/badge/Odin-dev--2026--09-1e5a99.svg)](https://odin-lang.org)

Terminal styling and layout for Odin, in the spirit of Go's lipgloss: colors that downsample to what the terminal supports, text attributes, padding, borders, tables and side-by-side blocks that stay aligned even with CJK text and emoji.

```text
╭───────────┬──────────┬───────┬──────────────────────────╮
│ Package   │ Language │ Stars │ Notes                    │
├───────────┼──────────┼───────┼──────────────────────────┤
│ lipgloss  │    Go    │ 9,800 │ the inspiration          │
│ odin-ansi │   Odin   │     1 │ grapheme-aware           │
│           │          │       │ widths                   │
│ 日本語    │   CJK    │     - │ two columns per glyph    │
│ emoji     │    👍🏽    │     - │ one cluster, two columns │
╰───────────┴──────────┴───────┴──────────────────────────╯
```

The repository is `odin-ansi`, but the package name is `ansistyle`. Odin needs every package name in a program to be unique, and `core:log` and `core:testing` already pull in a package named `ansi` from `core:terminal/ansi`.

## Install

The repository root is the package, so you can vendor it in two ways.

As a Git submodule inside your project:

```sh
git submodule add https://github.com/alexisbcz/odin-ansi libs/ansistyle
```

```odin
import "libs/ansistyle"
```

As a copy in a shared collection that all your projects use:

```sh
git clone https://github.com/alexisbcz/odin-ansi ~/odin-shared/ansistyle
odin build . -collection:shared=$HOME/odin-shared
```

```odin
import "shared:ansistyle"
```

The directory name becomes the import name, so clone into a directory called `ansistyle` as shown. If you keep the name `odin-ansi`, give the import a name: `import ansistyle "libs/odin-ansi"`.

## Quick start

```odin
package main

import "core:fmt"
import "core:os"
import "shared:ansistyle"

main :: proc() {
	// Turn on escape sequences on Windows, then ask what stdout supports.
	ansistyle.enable_virtual_terminal(os.stdout)
	profile := ansistyle.detect_profile(os.stdout)

	style := ansistyle.Style {
		fg        = ansistyle.rgb(0xff, 0x87, 0x00),
		attrs     = {.Bold},
		padding   = ansistyle.spacing(0, 2),
		border    = ansistyle.ROUNDED_BORDER,
		border_fg = ansistyle.Basic_Color.Bright_Black,
	}
	box, err := ansistyle.render(style, "Hello, 世界", profile)
	if err != nil {
		fmt.eprintln("render failed:", err)
		return
	}
	defer delete(box)
	fmt.println(box)
}
```

The output, with the colors left out:

```text
╭───────────────╮
│  Hello, 世界  │
╰───────────────╯
```

## Colors and profiles

A `Color` is a union of `Basic_Color` (the 16 terminal colors), `Indexed_Color` (the 256-color palette) and `RGB`. The `nil` color keeps the terminal default.

A `Profile` says what an output can show: `.Plain`, `.No_Color`, `.ANSI_16`, `.ANSI_256` or `.True_Color`. Every procedure that writes escape sequences takes one and downsamples colors to fit, so the RGB orange `#ff8700` becomes palette entry 208 on a 256-color terminal and yellow on a 16-color one.

`detect_profile` follows these rules:

- Output that isn't a terminal, or `TERM=dumb`, gets `.Plain`: layout but no escape sequences.
- `COLORTERM=truecolor` or `24bit` gives true color, and a `TERM` that contains `256color` gives 256 colors.
- A non-empty `NO_COLOR` keeps attributes such as bold but drops every color, as [no-color.org](https://no-color.org) asks.
- `FORCE_COLOR` or `CLICOLOR_FORCE` turns styling on for pipes. The values `2` and `3` ask for 256 colors and true color.

To test your own code against each case, build an `Environment` by hand and pass it to `profile_from_environment`, which never reads the process environment.

`parse_color` reads colors from configuration files and flags. It accepts names such as `bright_blue`, palette indexes such as `208` and hex colors such as `#ff8700`.

## API overview

| Declaration | Purpose | Allocates | Free with |
| --- | --- | --- | --- |
| `Style` | Colors, attributes, alignment, width limits, padding, margins and border | No | Not needed |
| `render(style, text, profile, allocator)` | Draw text with a style | Yes | `delete` |
| `Table` | Headers, rows, column alignment, border and cell styles | No | Not needed |
| `table_render(table, profile, allocator)` | Draw a table | Yes | `delete` |
| `join_horizontal(blocks, align, allocator)` | Put blocks side by side | Yes | `delete` |
| `join_vertical(blocks, align, allocator)` | Stack blocks | Yes | `delete` |
| `display_width(s)`, `height(s)`, `size(s)` | Measure text in terminal columns and lines | No | Not needed |
| `strip(s, allocator)` | Remove escape sequences | Yes | `delete` |
| `truncate(s, width, tail, allocator)` | Cut lines to a width without splitting graphemes | Yes | `delete` |
| `align_text(s, width, align, allocator)` | Pad lines to a width | Yes | `delete` |
| `expand_tabs(s, tab_width, allocator)` | Replace tabs with spaces | Yes | `delete` |
| `sgr(fg, bg, attrs, profile, allocator)` | Build one opening escape sequence | Yes | `delete` |
| `detect_profile(f)`, `profile_from_environment(env)` | Pick a `Profile` | No | Not needed |
| `enable_virtual_terminal(f)` | Turn on escape processing in a Windows console | No | Not needed |
| `parse_color(s)`, `parse_hex(s)` | Read a color from text | No | Not needed |
| `color_convert(c, profile)`, `rgb_to_256(c)`, `rgb_to_basic(c)` | Downsample colors | No | Not needed |
| `NORMAL_BORDER`, `ROUNDED_BORDER`, `THICK_BORDER`, `DOUBLE_BORDER`, `ASCII_BORDER`, `HIDDEN_BORDER` | Border presets | No | Not needed |
| `Error` | Union of `Color_Error`, `Layout_Error` and `runtime.Allocator_Error` | No | Not needed |

## Layout rules

- `render` aligns each line inside the content width, which is the widest line, raised by `width` and capped by `max_width`. Both limits count padding but not the border. Lines that don't fit end in `…`.
- Padding takes the background color. Underlines and strikethroughs stop at the text, so padding never looks underlined.
- An empty edge in a `Border` leaves that side out. Copy a preset and set `top = ""` to draw only the sides you want.
- Every line of a rendered block has the same display width, so `join_horizontal` and `join_vertical` line blocks up without measuring again.
- Display widths count grapheme clusters with `core:unicode/utf8`: East Asian wide characters and emoji take two columns, combining marks and control characters take none. Run `expand_tabs` on text with tabs before you lay it out.

## Examples

Each directory under `examples/` is a runnable program:

```sh
odin run examples/basic
odin run examples/table
FORCE_COLOR=3 odin run examples/table | cat -v   # see the escape sequences
```

## Design notes

- Every allocating procedure takes `allocator := context.allocator` and returns a string that the caller owns. Empty results are `""` and own no memory.
- Fallible procedures return `(T, Error)`. The library never panics on bad input, and malformed escape sequences only end early.
- `Style` and `Table` are plain values that borrow their strings. Build them with struct literals and copy them freely.
- The package keeps no global mutable state, so it's safe to use from several threads.

## Testing

```sh
odin check . -vet -strict-style -disallow-do -no-entry-point
odin test tests -vet -strict-style -disallow-do
vale sync && vale *.md
```

The tests wrap every allocating call in a tracking allocator and fail on any leak.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). Commits follow Conventional Commits, and every change that users can see gets a line in [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).
