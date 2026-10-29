/*
Package ansistyle styles and lays out text for terminals, in the spirit of Go's lipgloss.

The package lives in the `odin-ansi` repository. It isn't called `ansi`
because `core:terminal/ansi` already uses that name, and Odin requires package
names to be unique within a program that imports `core:log` or `core:testing`.

It covers four jobs:

- Colors: the 16 basic colors, the 256-color palette and 24-bit RGB, with
  automatic downsampling to whatever the terminal supports.
- Detection: a Profile picked from `NO_COLOR`, `FORCE_COLOR`, `TERM`,
  `COLORTERM` and whether the output is a terminal.
- Measurement: display widths that skip escape sequences and count grapheme
  clusters, so wide CJK text and emoji line up.
- Layout: a Style with padding, margins, alignment and borders, plus tables and
  helpers that join blocks side by side or on top of each other.

Every procedure that builds a string takes an allocator and returns a string
that the caller owns. The package keeps no global mutable state.

Example:
	import "core:fmt"
	import "core:os"
	import "shared:ansistyle"

	main :: proc() {
		ansistyle.enable_virtual_terminal(os.stdout)
		profile := ansistyle.detect_profile(os.stdout)
		style := ansistyle.Style{
			fg      = ansistyle.Basic_Color.Bright_Cyan,
			attrs   = {.Bold},
			padding = ansistyle.spacing(0, 1),
			border  = ansistyle.ROUNDED_BORDER,
		}
		box, err := ansistyle.render(style, "hello, terminal", profile)
		if err != nil {
			return
		}
		defer delete(box)
		fmt.println(box)
	}
*/
package ansistyle

import "base:runtime"

// ESC is the escape byte that starts every ANSI control sequence.
ESC :: "\x1b"

// RESET is the SGR sequence that clears every color and attribute.
RESET :: "\x1b[0m"

// Color_Error lists the ways parsing a color can fail.
Color_Error :: enum {
	None,
	// The input string was empty.
	Empty,
	// A hex color did not have 3 or 6 digits after the optional `#`.
	Invalid_Hex_Length,
	// A hex color contained a character outside `0-9`, `a-f` and `A-F`.
	Invalid_Hex_Digit,
	// A palette index was greater than 255.
	Index_Out_Of_Range,
	// The input was neither a known color name, an index nor a hex color.
	Unknown_Name,
}

// Layout_Error lists the layout parameters that the package rejects.
Layout_Error :: enum {
	None,
	// A width, such as `Style.width` or the width passed to truncate, was negative.
	Negative_Width,
	// A padding value, in a Style or a Table, was negative.
	Negative_Padding,
	// A margin value was negative.
	Negative_Margin,
	// A tab width passed to expand_tabs was zero or negative.
	Invalid_Tab_Width,
}

/*
Error is the compound error type returned by every fallible procedure in this
package. `nil` means success. Compare it against a specific variant, for
example `ansistyle.Error(ansistyle.Color_Error.Invalid_Hex_Digit)`, or use a type switch.
*/
Error :: union #shared_nil {
	Color_Error,
	Layout_Error,
	runtime.Allocator_Error,
}
