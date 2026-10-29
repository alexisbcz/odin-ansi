// Example table prints a colored table of packages. Run it with `odin run examples/table`.
package main

import ansi "../.."
import "core:fmt"
import "core:os"

main :: proc() {
	ansi.enable_virtual_terminal(os.stdout)
	profile := ansi.detect_profile(os.stdout)

	table := ansi.Table {
		headers      = {"Package", "Language", "Stars", "Notes"},
		rows         = {
			{"lipgloss", "Go", "9,800", "the inspiration"},
			{"odin-ansi", "Odin", "1", "grapheme-aware\nwidths"},
			{"日本語", "CJK", "-", "two columns per glyph"},
			{"emoji", "👍🏽", "-", "one cluster, two columns"},
		},
		align        = {.Left, .Center, .Right, .Left},
		border       = ansi.ROUNDED_BORDER,
		border_fg    = ansi.Basic_Color.Bright_Black,
		header_style = {fg = ansi.Basic_Color.Bright_Magenta, attrs = {.Bold}},
		padding      = 1,
	}
	out, err := ansi.table_render(table, profile)
	if err != nil {
		fmt.eprintln("table failed:", err)
		os.exit(1)
	}
	defer delete(out)
	fmt.println(out)
}
