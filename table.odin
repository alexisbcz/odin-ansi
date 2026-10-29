package ansistyle

/*
Table describes a grid of text cells for table_render. It borrows every slice
and string; nothing in it is freed by this package.

Rows may have different lengths: the table has as many columns as its longest
row or its header, and missing cells are empty. A cell may span several lines.

The border's `left` string separates columns as well as drawing the left
edge, and its `top` string draws every horizontal rule. The zero Border draws
the table without any lines.
*/
Table :: struct {
	// Header cells, drawn above the body and followed by a rule. May be empty.
	headers:        []string,
	// Body rows.
	rows:           [][]string,
	// Alignment for each column; columns past the end of the slice align left.
	align:          []Align,
	// Box pieces for the outer edge, the column separators and the rules.
	border:         Border,
	// Color of every border line.
	border_fg:      Color,
	// Colors and attributes of the header cells. Layout fields are ignored.
	header_style:   Style,
	// Colors and attributes of the body cells. Layout fields are ignored.
	cell_style:     Style,
	// Spaces on each side of every cell's text.
	padding:        int,
	// Draw a rule between body rows, not only below the header.
	row_separators: bool,
}

/*
table_render draws `t` for a terminal with `profile`. Each column is as wide as
its widest cell. The output has no trailing newline, and an empty table gives
an empty string.

Returns:
- out: a new string owned by the caller; free it with `delete(out, allocator)`.
- err: `.Negative_Padding` when `t.padding < 0`, or an allocator error.
*/
table_render :: proc(t: Table, profile: Profile, allocator := context.allocator) -> (out: string, err: Error) {
	if t.padding < 0 {
		return "", .Negative_Padding
	}
	columns := len(t.headers)
	for row in t.rows {
		columns = max(columns, len(row))
	}
	if columns == 0 {
		return "", nil
	}

	widths := make([]int, columns, allocator) or_return
	defer delete(widths, allocator)
	for cell, i in t.headers {
		widths[i] = max(widths[i], display_width(cell))
	}
	total_len := 0
	for row in t.rows {
		for cell, i in row {
			widths[i] = max(widths[i], display_width(cell))
			total_len += len(cell)
		}
	}
	line_w := 0
	for width in widths {
		line_w += width + 2 * t.padding + 1
	}

	w := writer_make(total_len + (len(t.rows) * 2 + 4) * (line_w * 4 + 16), allocator) or_return
	b := t.border
	first := true
	if b.top != "" {
		table_rule(&w, t, widths, profile, b.top_left, b.middle_top, b.top_right, b.top, &first)
	}
	if len(t.headers) > 0 {
		table_row(&w, t, t.headers, t.header_style, widths, profile, &first)
		if b.top != "" && len(t.rows) > 0 {
			table_rule(&w, t, widths, profile, b.middle_left, b.middle, b.middle_right, b.top, &first)
		}
	}
	for row, i in t.rows {
		if i > 0 && t.row_separators && b.top != "" {
			table_rule(&w, t, widths, profile, b.middle_left, b.middle, b.middle_right, b.top, &first)
		}
		table_row(&w, t, row, t.cell_style, widths, profile, &first)
	}
	if b.bottom != "" {
		table_rule(&w, t, widths, profile, b.bottom_left, b.middle_bottom, b.bottom_right, b.bottom, &first)
	}
	return writer_finish(&w)
}

@(private)
table_rule :: proc(w: ^Writer, t: Table, widths: []int, profile: Profile, left, middle, right, fill: string, first: ^bool) {
	if !first^ {
		write_byte(w, '\n')
	}
	first^ = false
	b := t.border
	opened := write_sgr(w, t.border_fg, nil, {}, profile)
	if b.left != "" {
		write_str(w, pick(left, fill))
	}
	for width, i in widths {
		if i > 0 && b.left != "" {
			write_str(w, pick(middle, fill))
		}
		write_repeat(w, fill, width + 2 * t.padding)
	}
	if b.right != "" {
		write_str(w, pick(right, fill))
	}
	if opened {
		write_str(w, RESET)
	}
}

@(private)
table_row :: proc(w: ^Writer, t: Table, cells: []string, style: Style, widths: []int, profile: Profile, first: ^bool) {
	row_h := 1
	for cell in cells {
		row_h = max(row_h, height(cell))
	}

	// Each cell keeps its own cursor so multi-line cells are read in one pass.
	MAX_STACK_COLUMNS :: 64
	Cursor :: struct {
		rest: string,
		done: bool,
	}
	stack: [MAX_STACK_COLUMNS]Cursor
	for line_index in 0 ..< row_h {
		if !first^ {
			write_byte(w, '\n')
		}
		first^ = false
		write_piece(w, t.border.left, t.border_fg, nil, profile)
		for width, col in widths {
			if col > 0 {
				write_piece(w, t.border.left, t.border_fg, nil, profile)
			}
			line := ""
			if col < len(cells) {
				if col < MAX_STACK_COLUMNS {
					c := &stack[col]
					if line_index == 0 {
						c^ = Cursor{cells[col], false}
					}
					line, _ = next_line(&c.rest, &c.done)
				} else {
					line = nth_line(cells[col], line_index)
				}
			}
			align := t.align[col] if col < len(t.align) else Align.Left
			write_cell(w, line, width, t.padding, t.padding, align, style.fg, style.bg, style.attrs, profile)
		}
		write_piece(w, t.border.right, t.border_fg, nil, profile)
	}
}

// nth_line returns line `n` of `s`, or an empty string past the last line.
@(private)
nth_line :: proc(s: string, n: int) -> string {
	rest, done := s, false
	i := 0
	for line in next_line(&rest, &done) {
		if i == n {
			return line
		}
		i += 1
	}
	return ""
}
