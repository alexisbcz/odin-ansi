package ansi

import "base:runtime"
import "core:strconv"

// Writer accumulates output bytes and remembers the first allocation failure,
// so the rendering code can write freely and check for errors once at the end.
@(private)
Writer :: struct {
	buf: [dynamic]byte,
	err: runtime.Allocator_Error,
}

@(private)
writer_make :: proc(capacity: int, allocator: runtime.Allocator) -> (w: Writer, err: runtime.Allocator_Error) {
	w.buf = make([dynamic]byte, 0, max(capacity, 0), allocator) or_return
	return
}

@(private)
write_str :: proc(w: ^Writer, s: string) {
	if w.err != nil || len(s) == 0 {
		return
	}
	_, w.err = append(&w.buf, s)
}

@(private)
write_byte :: proc(w: ^Writer, b: byte) {
	if w.err != nil {
		return
	}
	_, w.err = append(&w.buf, b)
}

@(private)
write_spaces :: proc(w: ^Writer, n: int) {
	for _ in 0 ..< n {
		write_byte(w, ' ')
	}
}

@(private)
write_int :: proc(w: ^Writer, n: int) {
	buf: [32]byte
	write_str(w, strconv.write_int(buf[:], i64(n), 10))
}

// write_repeat fills `cells` terminal columns with copies of `s`. When `s` is
// wider than one cell and does not divide `cells`, spaces fill the remainder.
@(private)
write_repeat :: proc(w: ^Writer, s: string, cells: int) {
	if cells <= 0 {
		return
	}
	cell_w := display_width(s)
	if cell_w <= 0 {
		write_spaces(w, cells)
		return
	}
	for _ in 0 ..< cells / cell_w {
		write_str(w, s)
	}
	write_spaces(w, cells % cell_w)
}

// writer_finish hands the buffer to the caller as a string, or frees it and
// reports the first allocation failure.
@(private)
writer_finish :: proc(w: ^Writer) -> (out: string, err: Error) {
	if w.err != nil {
		failure := w.err
		delete(w.buf)
		w^ = {}
		return "", failure
	}
	return string(w.buf[:]), nil
}
