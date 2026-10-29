package ansi

import "core:strings"
import "core:unicode/utf8"

// Align places text horizontally inside a wider field.
Align :: enum u8 {
	Left,
	Center,
	Right,
}

// escape_len returns the byte length of the escape sequence at the start of
// `s`, which must begin with ESC. Unterminated sequences run to the end of `s`.
@(private)
escape_len :: proc(s: string) -> int {
	if len(s) < 2 {
		return len(s)
	}
	switch s[1] {
	case '[':
		// CSI: parameter and intermediate bytes, then one final byte.
		for j in 2 ..< len(s) {
			b := s[j]
			switch b {
			case 0x40 ..= 0x7e:
				return j + 1
			case 0x20 ..= 0x3f:
			case:
				// Malformed: stop before the byte that can't belong here.
				return j
			}
		}
		return len(s)
	case ']', 'P', '_', '^', 'X':
		// OSC, DCS, APC, PM and SOS: a string ended by BEL or ESC `\`.
		for j in 2 ..< len(s) {
			if s[j] == 0x07 {
				return j + 1
			}
			if s[j] == 0x1b && j + 1 < len(s) && s[j + 1] == '\\' {
				return j + 2
			}
		}
		return len(s)
	case:
		if s[1] < 0x80 {
			return 2
		}
		return 1
	}
}

// next_segment splits `s` into runs of visible text and whole escape sequences.
@(private)
next_segment :: proc(s: string, i: ^int) -> (seg: string, is_escape: bool, ok: bool) {
	if i^ >= len(s) {
		return "", false, false
	}
	rest := s[i^:]
	if rest[0] == 0x1b {
		n := escape_len(rest)
		i^ += n
		return rest[:n], true, true
	}
	n := strings.index_byte(rest, 0x1b)
	if n < 0 {
		n = len(rest)
	}
	i^ += n
	return rest[:n], false, true
}

@(private)
text_width :: proc(s: string) -> int {
	_, _, width := utf8.grapheme_count(s)
	return width
}

/*
display_width returns how many terminal columns `s` occupies. It skips ANSI
escape sequences, counts each grapheme cluster once, gives East Asian wide
characters and emoji two columns, and gives control characters, such as tabs,
zero columns. For text with several lines it returns the widest line.
*/
display_width :: proc(s: string) -> int {
	best, cur := 0, 0
	i := 0
	for seg, is_escape in next_segment(s, &i) {
		if is_escape {
			continue
		}
		rest := seg
		for {
			nl := strings.index_byte(rest, '\n')
			if nl < 0 {
				cur += text_width(rest)
				break
			}
			cur += text_width(rest[:nl])
			best = max(best, cur)
			cur = 0
			rest = rest[nl + 1:]
		}
	}
	return max(best, cur)
}

// height returns the number of lines in `s`. An empty string is one empty line.
height :: proc(s: string) -> int {
	return strings.count(s, "\n") + 1
}

// size returns the display width and the height of `s` as one block.
size :: proc(s: string) -> (width, lines: int) {
	return display_width(s), height(s)
}

// next_line yields the lines of `s` without their `\n` or `\r\n` endings. A
// trailing newline yields a final empty line, matching height.
@(private)
next_line :: proc(s: ^string, done: ^bool) -> (line: string, ok: bool) {
	if done^ {
		return "", false
	}
	nl := strings.index_byte(s^, '\n')
	if nl < 0 {
		line = s^
		s^ = ""
		done^ = true
	} else {
		line = s[:nl]
		s^ = s[nl + 1:]
	}
	if len(line) > 0 && line[len(line) - 1] == '\r' {
		line = line[:len(line) - 1]
	}
	return line, true
}

/*
strip removes every ANSI escape sequence from `s`, leaving the visible text.

Returns:
- out: a new string owned by the caller; free it with `delete(out, allocator)`.
- err: an allocator error.
*/
strip :: proc(s: string, allocator := context.allocator) -> (out: string, err: Error) {
	w := writer_make(len(s), allocator) or_return
	i := 0
	for seg, is_escape in next_segment(s, &i) {
		if !is_escape {
			write_str(&w, seg)
		}
	}
	return writer_finish(&w)
}

/*
truncate shortens each line of `s` to at most `width` columns, ending cut lines
with `tail`, such as `"…"`. It never splits a grapheme cluster and keeps every
escape sequence, so styles still close. When `tail` is wider than `width`, the
lines are cut without it.

Returns:
- out: a new string owned by the caller; free it with `delete(out, allocator)`.
- err: `.Negative_Width` when `width < 0`, or an allocator error.
*/
truncate :: proc(s: string, width: int, tail := "", allocator := context.allocator) -> (out: string, err: Error) {
	if width < 0 {
		return "", .Negative_Width
	}
	w := writer_make(len(s) + len(tail), allocator) or_return
	rest, done := s, false
	first := true
	for line in next_line(&rest, &done) {
		if !first {
			write_byte(&w, '\n')
		}
		first = false
		write_truncated(&w, line, width, tail)
	}
	return writer_finish(&w)
}

// write_truncated writes `line` cut to `width` columns and returns the number
// of columns written.
@(private)
write_truncated :: proc(w: ^Writer, line: string, width: int, tail: string) -> int {
	line_w := display_width(line)
	if line_w <= width {
		write_str(w, line)
		return line_w
	}
	tail, tail_w := tail, display_width(tail)
	if tail_w > width {
		tail, tail_w = "", 0
	}
	budget := width - tail_w
	used := 0
	cut := false
	i := 0
	for seg, is_escape in next_segment(line, &i) {
		if is_escape {
			write_str(w, seg)
			continue
		}
		if cut {
			continue
		}
		it := utf8.decode_grapheme_iterator_make(seg)
		for text, g in utf8.decode_grapheme_iterate(&it) {
			if used + g.width > budget {
				cut = true
				write_str(w, tail)
				break
			}
			write_str(w, text)
			used += g.width
		}
	}
	if !cut {
		write_str(w, tail)
	}
	return used + tail_w
}

/*
align_text pads every line of `s` with spaces to `width` columns, placing the
text according to `align`. Lines that are already wider stay as they are.

Returns:
- out: a new string owned by the caller; free it with `delete(out, allocator)`.
- err: `.Negative_Width` when `width < 0`, or an allocator error.
*/
align_text :: proc(s: string, width: int, align: Align, allocator := context.allocator) -> (out: string, err: Error) {
	if width < 0 {
		return "", .Negative_Width
	}
	w := writer_make(len(s) + width, allocator) or_return
	rest, done := s, false
	first := true
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
	return writer_finish(&w)
}

// gaps splits the free space around text of width `used` in a `width` column field.
@(private)
gaps :: proc(used, width: int, align: Align) -> (left, right: int) {
	free := max(width - used, 0)
	switch align {
	case .Left:
		return 0, free
	case .Center:
		return free / 2, free - free / 2
	case .Right:
		return free, 0
	}
	return 0, free
}

/*
expand_tabs replaces each tab in `s` with spaces up to the next multiple of
`tab_width` columns. Display widths count tabs as zero columns, so expand tabs
before you measure or lay out text that contains them.

Returns:
- out: a new string owned by the caller; free it with `delete(out, allocator)`.
- err: `.Invalid_Tab_Width` when `tab_width <= 0`, or an allocator error.
*/
expand_tabs :: proc(s: string, tab_width := 4, allocator := context.allocator) -> (out: string, err: Error) {
	if tab_width <= 0 {
		return "", .Invalid_Tab_Width
	}
	w := writer_make(len(s), allocator) or_return
	column := 0
	i := 0
	for seg, is_escape in next_segment(s, &i) {
		if is_escape {
			write_str(&w, seg)
			continue
		}
		it := utf8.decode_grapheme_iterator_make(seg)
		for text, g in utf8.decode_grapheme_iterate(&it) {
			switch text {
			case "\t":
				n := tab_width - column % tab_width
				write_spaces(&w, n)
				column += n
			case "\n", "\r\n":
				write_str(&w, text)
				column = 0
			case:
				write_str(&w, text)
				column += g.width
			}
		}
	}
	return writer_finish(&w)
}
