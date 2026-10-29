// Package ansistyle_tests holds the unit tests for ansistyle. Run them with `odin test tests`.
package ansistyle_tests

import ansistyle ".."
import "base:runtime"
import "core:log"
import "core:mem"
import "core:testing"

/*
track_begin wraps the current allocator in a tracking allocator. Pair it with
a deferred track_end, which fails the test on leaks or bad frees:

	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)
*/
track_begin :: proc(tr: ^mem.Tracking_Allocator) -> runtime.Allocator {
	mem.tracking_allocator_init(tr, context.allocator)
	return mem.tracking_allocator(tr)
}

// track_end asserts that every allocation was freed exactly once.
track_end :: proc(t: ^testing.T, tr: ^mem.Tracking_Allocator, loc := #caller_location) {
	testing.expectf(t, len(tr.allocation_map) == 0, "%d allocation(s) leaked", len(tr.allocation_map), loc = loc)
	for _, entry in tr.allocation_map {
		log.errorf("leak: %d bytes at %v", entry.size, entry.location)
	}
	testing.expectf(t, len(tr.bad_free_array) == 0, "%d bad free(s)", len(tr.bad_free_array), loc = loc)
	mem.tracking_allocator_destroy(tr)
}

// Limited passes the first `remaining` allocations and resizes to `backing`,
// then fails every later one with `.Out_Of_Memory`. Frees always succeed.
Limited :: struct {
	backing:   runtime.Allocator,
	remaining: int,
}

limited_allocator :: proc(l: ^Limited) -> runtime.Allocator {
	return runtime.Allocator{procedure = limited_proc, data = l}
}

limited_proc :: proc(
	data: rawptr,
	mode: runtime.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	loc := #caller_location,
) -> (
	[]byte,
	runtime.Allocator_Error,
) {
	l := (^Limited)(data)
	switch mode {
	case .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed:
		if l.remaining <= 0 {
			return nil, .Out_Of_Memory
		}
		l.remaining -= 1
	case .Free, .Free_All, .Query_Features, .Query_Info:
	}
	return l.backing.procedure(l.backing.data, mode, size, alignment, old_memory, old_size, loc)
}

OUT_OF_MEMORY :: ansistyle.Error(runtime.Allocator_Error.Out_Of_Memory)

// expect_render renders `text` and compares the result with `want`.
expect_render :: proc(t: ^testing.T, style: ansistyle.Style, text: string, profile: ansistyle.Profile, want: string, loc := #caller_location) {
	got, err := ansistyle.render(style, text, profile)
	defer delete(got)
	testing.expect_value(t, err, nil, loc = loc)
	testing.expect_value(t, got, want, loc = loc)
}

// expect_table renders `table` and compares the result with `want`.
expect_table :: proc(t: ^testing.T, table: ansistyle.Table, profile: ansistyle.Profile, want: string, loc := #caller_location) {
	got, err := ansistyle.table_render(table, profile)
	defer delete(got)
	testing.expect_value(t, err, nil, loc = loc)
	testing.expect_value(t, got, want, loc = loc)
}
