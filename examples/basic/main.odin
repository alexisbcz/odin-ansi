// Example basic styles text, draws two boxes and joins them. Run it with `odin run examples/basic`.
package main

import ansi "../.."
import "core:fmt"
import "core:os"

main :: proc() {
	// Pick colors for the real terminal. Piped output gets plain text.
	ansi.enable_virtual_terminal(os.stdout)
	profile := ansi.detect_profile(os.stdout)

	title_style := ansi.Style {
		fg    = ansi.rgb(0xff, 0x87, 0x00),
		attrs = {.Bold, .Underline},
	}
	title, err := ansi.render(title_style, "odin-ansi", profile)
	if err != nil {
		fmt.eprintln("render failed:", err)
		os.exit(1)
	}
	defer delete(title)
	fmt.println(title)

	card := ansi.Style {
		fg        = ansi.Basic_Color.Bright_White,
		bg        = ansi.indexed(24),
		padding   = ansi.spacing(1, 2),
		width     = 24,
		align     = .Center,
		border    = ansi.ROUNDED_BORDER,
		border_fg = ansi.Basic_Color.Bright_Cyan,
	}
	left, left_err := ansi.render(card, "Hello, 世界\nwide text lines up", profile)
	if left_err != nil {
		fmt.eprintln("render failed:", left_err)
		os.exit(1)
	}
	defer delete(left)

	note := ansi.Style {
		fg      = ansi.Basic_Color.Bright_Black,
		attrs   = {.Italic},
		padding = ansi.spacing(0, 1),
		margin  = ansi.spacing(0, 0, 0, 2),
		border  = ansi.NORMAL_BORDER,
	}
	label := fmt.aprintf("profile:\n%v", profile)
	defer delete(label)
	right, right_err := ansi.render(note, label, profile)
	if right_err != nil {
		fmt.eprintln("render failed:", right_err)
		os.exit(1)
	}
	defer delete(right)

	row, join_err := ansi.join_horizontal({left, right}, .Middle)
	if join_err != nil {
		fmt.eprintln("join failed:", join_err)
		os.exit(1)
	}
	defer delete(row)
	fmt.println(row)
}
