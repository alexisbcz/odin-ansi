package ansistyle

/*
Border is the set of strings that draw a box. Each string should be one
terminal column wide. An empty edge, such as `top = ""`, leaves that side
undrawn; copy a preset and blank a field to draw only some sides.

The `middle_*` pieces join inner lines in tables: `middle_left` and
`middle_right` end a horizontal rule, `middle_top` and `middle_bottom` end a
column separator, and `middle` crosses both.
*/
Border :: struct {
	top, bottom, left, right:                                   string,
	top_left, top_right, bottom_left, bottom_right:             string,
	middle_left, middle_right, middle, middle_top, middle_bottom: string,
}

// NORMAL_BORDER draws a box with thin lines and square corners.
NORMAL_BORDER :: Border {
	top           = "─",
	bottom        = "─",
	left          = "│",
	right         = "│",
	top_left      = "┌",
	top_right     = "┐",
	bottom_left   = "└",
	bottom_right  = "┘",
	middle_left   = "├",
	middle_right  = "┤",
	middle        = "┼",
	middle_top    = "┬",
	middle_bottom = "┴",
}

// ROUNDED_BORDER draws a box with thin lines and rounded corners.
ROUNDED_BORDER :: Border {
	top           = "─",
	bottom        = "─",
	left          = "│",
	right         = "│",
	top_left      = "╭",
	top_right     = "╮",
	bottom_left   = "╰",
	bottom_right  = "╯",
	middle_left   = "├",
	middle_right  = "┤",
	middle        = "┼",
	middle_top    = "┬",
	middle_bottom = "┴",
}

// THICK_BORDER draws a box with heavy lines.
THICK_BORDER :: Border {
	top           = "━",
	bottom        = "━",
	left          = "┃",
	right         = "┃",
	top_left      = "┏",
	top_right     = "┓",
	bottom_left   = "┗",
	bottom_right  = "┛",
	middle_left   = "┣",
	middle_right  = "┫",
	middle        = "╋",
	middle_top    = "┳",
	middle_bottom = "┻",
}

// DOUBLE_BORDER draws a box with double lines.
DOUBLE_BORDER :: Border {
	top           = "═",
	bottom        = "═",
	left          = "║",
	right         = "║",
	top_left      = "╔",
	top_right     = "╗",
	bottom_left   = "╚",
	bottom_right  = "╝",
	middle_left   = "╠",
	middle_right  = "╣",
	middle        = "╬",
	middle_top    = "╦",
	middle_bottom = "╩",
}

// ASCII_BORDER draws a box with `-`, `|` and `+`, for terminals without box-drawing glyphs.
ASCII_BORDER :: Border {
	top           = "-",
	bottom        = "-",
	left          = "|",
	right         = "|",
	top_left      = "+",
	top_right     = "+",
	bottom_left   = "+",
	bottom_right  = "+",
	middle_left   = "+",
	middle_right  = "+",
	middle        = "+",
	middle_top    = "+",
	middle_bottom = "+",
}

// HIDDEN_BORDER takes the same space as a border but draws spaces, which keeps
// bordered and borderless blocks the same size.
HIDDEN_BORDER :: Border {
	top           = " ",
	bottom        = " ",
	left          = " ",
	right         = " ",
	top_left      = " ",
	top_right     = " ",
	bottom_left   = " ",
	bottom_right  = " ",
	middle_left   = " ",
	middle_right  = " ",
	middle        = " ",
	middle_top    = " ",
	middle_bottom = " ",
}

// pick returns `piece`, or `fallback` when the border leaves `piece` empty.
@(private)
pick :: proc(piece, fallback: string) -> string {
	return piece if piece != "" else fallback
}
