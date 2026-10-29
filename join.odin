package ansistyle

/*
join_horizontal places blocks side by side, left to right. Each block is padded
with spaces to its own widest line, and shorter blocks are placed vertically
according to `align`.

Returns:
- out: a new string owned by the caller; free it with `delete(out, allocator)`.
- err: an allocator error.
*/
join_horizontal :: proc(blocks: []string, align: Vertical_Align, allocator := context.allocator) -> (out: string, err: Error) {
	if len(blocks) == 0 {
		return "", nil
	}
	Cursor :: struct {
		rest:   string,
		done:   bool,
		width:  int,
		height: int,
	}
	cursors := make([]Cursor, len(blocks), allocator) or_return
	defer delete(cursors, allocator)

	total_h, total_w, total_len := 0, 0, 0
	for block, i in blocks {
		cursors[i] = Cursor{block, false, display_width(block), height(block)}
		total_h = max(total_h, cursors[i].height)
		total_w += cursors[i].width
		total_len += len(block)
	}

	w := writer_make(total_len + total_h * (total_w + 1), allocator) or_return
	for row in 0 ..< total_h {
		if row > 0 {
			write_byte(&w, '\n')
		}
		for &c in cursors {
			offset := 0
			switch align {
			case .Top:
			case .Middle:
				offset = (total_h - c.height) / 2
			case .Bottom:
				offset = total_h - c.height
			}
			if row < offset || row >= offset + c.height {
				write_spaces(&w, c.width)
				continue
			}
			line, _ := next_line(&c.rest, &c.done)
			write_str(&w, line)
			write_spaces(&w, c.width - display_width(line))
		}
	}
	return writer_finish(&w)
}

/*
join_vertical stacks blocks top to bottom. Every line is padded with spaces to
the widest line of all blocks and placed according to `align`.

Returns:
- out: a new string owned by the caller; free it with `delete(out, allocator)`.
- err: an allocator error.
*/
join_vertical :: proc(blocks: []string, align: Align, allocator := context.allocator) -> (out: string, err: Error) {
	if len(blocks) == 0 {
		return "", nil
	}
	width, total_len, total_h := 0, 0, 0
	for block in blocks {
		width = max(width, display_width(block))
		total_len += len(block)
		total_h += height(block)
	}

	w := writer_make(total_len + total_h * (width + 1), allocator) or_return
	first := true
	for block in blocks {
		rest, done := block, false
		for line in next_line(&rest, &done) {
			if !first {
				write_byte(&w, '\n')
			}
			first = false
			left, right := gaps(display_width(line), width, align)
			write_spaces(&w, left)
			write_str(&w, line)
			write_spaces(&w, right)
		}
	}
	return writer_finish(&w)
}
