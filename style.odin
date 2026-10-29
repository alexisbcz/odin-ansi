package ansistyle

// Attribute is a text effect that terminals turn on with an SGR code.
Attribute :: enum u8 {
	Bold,
	Faint,
	Italic,
	Underline,
	Blink,
	Reverse,
	Strikethrough,
}

// Attributes is a set of text effects, written as a literal such as `{.Bold, .Underline}`.
Attributes :: bit_set[Attribute;u8]

@(private)
ATTRIBUTE_CODES :: [Attribute]int {
	.Bold          = 1,
	.Faint         = 2,
	.Italic        = 3,
	.Underline     = 4,
	.Blink         = 5,
	.Reverse       = 7,
	.Strikethrough = 9,
}

// Vertical_Align places a shorter block inside a taller row in join_horizontal.
Vertical_Align :: enum u8 {
	Top,
	Middle,
	Bottom,
}

// Spacing holds a size for each side of a block, in columns for left and right and in lines for top and bottom.
Spacing :: struct {
	top, right, bottom, left: int,
}

// spacing_all returns the same spacing on every side.
spacing_all :: proc "contextless" (n: int) -> Spacing {
	return {n, n, n, n}
}

// spacing_vh returns `vertical` lines above and below and `horizontal` columns left and right.
spacing_vh :: proc "contextless" (vertical, horizontal: int) -> Spacing {
	return {vertical, horizontal, vertical, horizontal}
}

// spacing_trbl returns a spacing in CSS order: top, right, bottom, left.
spacing_trbl :: proc "contextless" (top, right, bottom, left: int) -> Spacing {
	return {top, right, bottom, left}
}

// spacing builds a Spacing from one, two or four values, like CSS shorthand.
spacing :: proc {
	spacing_all,
	spacing_vh,
	spacing_trbl,
}

/*
Style describes how render draws a block of text. It is a plain value: build
it with a struct literal, copy it and change fields freely. The zero value
draws text unchanged.

Layout, from the inside out:

1. Each line of text is aligned inside the content width, which is the widest
   line, raised by `width` and capped by `max_width`. Lines that don't fit get
   cut with `…`.
2. `padding` surrounds the content and takes the background color.
3. `border` surrounds the padding, drawn in `border_fg` and `border_bg`.
4. `margin` surrounds everything with unstyled spaces.

A value is safe to use from several threads at once; it holds no pointers
except the strings in `border`.
*/
Style :: struct {
	// Foreground color of the text, or `nil` for the terminal default.
	fg:        Color,
	// Background color of the text and padding, or `nil` for the terminal default.
	bg:        Color,
	// Text effects such as `.Bold`.
	attrs:     Attributes,
	// Horizontal alignment of each line inside the content width.
	align:     Align,
	// Minimum width inside the border, padding included. 0 means "fit the text".
	width:     int,
	// Maximum width inside the border, padding included. 0 means no limit.
	max_width: int,
	// Space between the text and the border.
	padding:   Spacing,
	// Space outside the border.
	margin:    Spacing,
	// Box pieces; the zero value draws no border.
	border:    Border,
	// Color of the border lines.
	border_fg: Color,
	// Background color behind the border lines.
	border_bg: Color,
}

@(private)
validate_spacing :: proc(s: Spacing, err: Layout_Error) -> Error {
	if s.top < 0 || s.right < 0 || s.bottom < 0 || s.left < 0 {
		return err
	}
	return nil
}

// write_sgr opens an SGR sequence for the given colors and attributes, as far
// as `profile` allows. It returns whether it wrote anything, so the caller
// knows to write RESET afterwards.
@(private)
write_sgr :: proc(w: ^Writer, fg, bg: Color, attrs: Attributes, profile: Profile) -> (opened: bool) {
	if profile == .Plain {
		return false
	}
	fg_out, bg_out := color_convert(fg, profile), color_convert(bg, profile)
	if attrs == {} && fg_out == nil && bg_out == nil {
		return false
	}
	codes := ATTRIBUTE_CODES
	write_str(w, "\x1b[")
	first := true
	for a in attrs {
		if !first {
			write_byte(w, ';')
		}
		first = false
		write_int(w, codes[a])
	}
	if fg_out != nil {
		if !first {
			write_byte(w, ';')
		}
		first = false
		write_color_params(w, fg_out, false)
	}
	if bg_out != nil {
		if !first {
			write_byte(w, ';')
		}
		write_color_params(w, bg_out, true)
	}
	write_byte(w, 'm')
	return true
}

@(private)
write_color_params :: proc(w: ^Writer, c: Color, background: bool) {
	switch v in c {
	case Basic_Color:
		n := int(v)
		base := 40 if background else 30
		if n >= 8 {
			base += 60
			n -= 8
		}
		write_int(w, base + n)
	case Indexed_Color:
		write_str(w, "48;5;" if background else "38;5;")
		write_int(w, int(v))
	case RGB:
		write_str(w, "48;2;" if background else "38;2;")
		write_int(w, int(v.r))
		write_byte(w, ';')
		write_int(w, int(v.g))
		write_byte(w, ';')
		write_int(w, int(v.b))
	}
}

/*
sgr returns the escape sequence that turns on `fg`, `bg` and `attrs` under
`profile`, or an empty string when there is nothing to turn on. Write RESET
after the styled text when the result is not empty.

Returns:
- out: a new string owned by the caller; free it with `delete(out, allocator)`.
- err: an allocator error.
*/
sgr :: proc(fg, bg: Color, attrs: Attributes, profile: Profile, allocator := context.allocator) -> (out: string, err: Error) {
	w := writer_make(32, allocator) or_return
	write_sgr(&w, fg, bg, attrs, profile)
	return writer_finish(&w)
}

// write_piece writes `s` in the given colors and closes the sequence again.
@(private)
write_piece :: proc(w: ^Writer, s: string, fg, bg: Color, profile: Profile) {
	if s == "" {
		return
	}
	opened := write_sgr(w, fg, bg, {}, profile)
	write_str(w, s)
	if opened {
		write_str(w, RESET)
	}
}

// write_blank writes `n` spaces on the background color `bg`.
@(private)
write_blank :: proc(w: ^Writer, n: int, bg: Color, profile: Profile) {
	if n <= 0 {
		return
	}
	opened := write_sgr(w, nil, bg, {}, profile)
	write_spaces(w, n)
	if opened {
		write_str(w, RESET)
	}
}

/*
write_cell writes one line of a styled field: left padding, the aligned text
and right padding, `pad_left + width + pad_right` columns in total. Text wider
than `width` is cut with `…`. Padding and alignment gaps get only the
background color, so underlines and strikethroughs stop at the text.
*/
@(private)
write_cell :: proc(w: ^Writer, text: string, width, pad_left, pad_right: int, align: Align, fg, bg: Color, attrs: Attributes, profile: Profile) {
	text_w := display_width(text)
	if text_w > width {
		write_blank(w, pad_left, bg, profile)
		opened := write_sgr(w, fg, bg, attrs, profile)
		used := write_truncated(w, text, width, "…")
		if opened {
			write_str(w, RESET)
		}
		write_blank(w, width - used + pad_right, bg, profile)
		return
	}
	if text == "" {
		write_blank(w, pad_left + width + pad_right, bg, profile)
		return
	}
	left, right := gaps(text_w, width, align)
	write_blank(w, pad_left + left, bg, profile)
	opened := write_sgr(w, fg, bg, attrs, profile)
	write_str(w, text)
	if opened {
		write_str(w, RESET)
	}
	write_blank(w, right + pad_right, bg, profile)
}

/*
render draws `text` with `style` for a terminal with `profile`. Lines are
separated by `\n` in the input and the output, and the output has no trailing
newline. Every line of the result has the same display width, so blocks can be
joined with join_horizontal and join_vertical.

Escape sequences already in `text` pass through, but a RESET inside them also
ends this style's colors for the rest of that line.

Inputs:
- style: the colors, attributes and layout to apply.
- text: the text to draw; it may contain several lines.
- profile: what the terminal supports; colors are downsampled to fit, and
  `.Plain` gives layout without any escape sequences.
- allocator: allocates the result.

Returns:
- out: a new string owned by the caller; free it with `delete(out, allocator)`.
- err: `.Negative_Width`, `.Negative_Padding`, `.Negative_Margin` or an allocator error.
*/
render :: proc(style: Style, text: string, profile: Profile, allocator := context.allocator) -> (out: string, err: Error) {
	if style.width < 0 || style.max_width < 0 {
		return "", .Negative_Width
	}
	validate_spacing(style.padding, .Negative_Padding) or_return
	validate_spacing(style.margin, .Negative_Margin) or_return

	p, m, b := style.padding, style.margin, style.border
	content_w := max(display_width(text), style.width - p.left - p.right)
	if style.max_width > 0 {
		content_w = min(content_w, max(style.max_width - p.left - p.right, 0))
	}
	inner_w := p.left + content_w + p.right

	has_top, has_bottom := b.top != "", b.bottom != ""
	has_left, has_right := b.left != "", b.right != ""
	left_w := display_width(b.left) if has_left else 0
	right_w := display_width(b.right) if has_right else 0
	outer_w := m.left + left_w + inner_w + right_w + m.right

	lines := m.top + int(has_top) + p.top + height(text) + p.bottom + int(has_bottom) + m.bottom
	w := writer_make(lines * (outer_w + 32) + len(text), allocator) or_return

	row := 0
	next_row :: proc(w: ^Writer, row: ^int) {
		if row^ > 0 {
			write_byte(w, '\n')
		}
		row^ += 1
	}
	edge :: proc(w: ^Writer, style: Style, profile: Profile, left, fill, right: string, has_left, has_right: bool, inner_w: int) {
		write_spaces(w, style.margin.left)
		opened := write_sgr(w, style.border_fg, style.border_bg, {}, profile)
		if has_left {
			write_str(w, pick(left, fill))
		}
		write_repeat(w, fill, inner_w)
		if has_right {
			write_str(w, pick(right, fill))
		}
		if opened {
			write_str(w, RESET)
		}
		write_spaces(w, style.margin.right)
	}
	content_row :: proc(w: ^Writer, style: Style, profile: Profile, line: string, content_w: int) {
		b := style.border
		write_spaces(w, style.margin.left)
		write_piece(w, b.left, style.border_fg, style.border_bg, profile)
		write_cell(w, line, content_w, style.padding.left, style.padding.right, style.align, style.fg, style.bg, style.attrs, profile)
		write_piece(w, b.right, style.border_fg, style.border_bg, profile)
		write_spaces(w, style.margin.right)
	}

	for _ in 0 ..< m.top {
		next_row(&w, &row)
		write_spaces(&w, outer_w)
	}
	if has_top {
		next_row(&w, &row)
		edge(&w, style, profile, b.top_left, b.top, b.top_right, has_left, has_right, inner_w)
	}
	for _ in 0 ..< p.top {
		next_row(&w, &row)
		content_row(&w, style, profile, "", content_w)
	}
	rest, done := text, false
	for line in next_line(&rest, &done) {
		next_row(&w, &row)
		content_row(&w, style, profile, line, content_w)
	}
	for _ in 0 ..< p.bottom {
		next_row(&w, &row)
		content_row(&w, style, profile, "", content_w)
	}
	if has_bottom {
		next_row(&w, &row)
		edge(&w, style, profile, b.bottom_left, b.bottom, b.bottom_right, has_left, has_right, inner_w)
	}
	for _ in 0 ..< m.bottom {
		next_row(&w, &row)
		write_spaces(&w, outer_w)
	}
	return writer_finish(&w)
}
