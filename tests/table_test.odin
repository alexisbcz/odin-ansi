package ansistyle_tests

import ansistyle ".."
import "core:mem"
import "core:testing"

@(test)
test_table_normal_border :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	table := ansistyle.Table {
		headers = {"A", "BB"},
		rows    = {{"1", "2"}},
		border  = ansistyle.NORMAL_BORDER,
	}
	expect_table(t, table, .Plain, "┌─┬──┐\n│A│BB│\n├─┼──┤\n│1│2 │\n└─┴──┘")

	table.padding = 1
	expect_table(t, table, .Plain, "┌───┬────┐\n│ A │ BB │\n├───┼────┤\n│ 1 │ 2  │\n└───┴────┘")
}

@(test)
test_table_without_border :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	table := ansistyle.Table {
		headers = {"A", "BB"},
		rows    = {{"1", "2"}},
		padding = 1,
	}
	expect_table(t, table, .Plain, " A  BB \n 1  2  ")
}

@(test)
test_table_column_alignment :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	table := ansistyle.Table {
		rows  = {{"a", "b", "c"}, {"ccc", "ddd", "eee"}},
		align = {.Right, .Center},
	}
	expect_table(t, table, .Plain, "  a b c  \ncccdddeee")
}

@(test)
test_table_ragged_rows_and_multiline_cells :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	table := ansistyle.Table {
		rows = {{"x"}, {"y", "1\n2"}},
	}
	expect_table(t, table, .Plain, "x \ny1\n 2")

	boxed := ansistyle.Table {
		headers = {"h"},
		rows    = {{"a", "b\r\nc"}},
		border  = ansistyle.ASCII_BORDER,
	}
	expect_table(t, boxed, .Plain, "+-+-+\n|h| |\n+-+-+\n|a|b|\n| |c|\n+-+-+")
}

@(test)
test_table_row_separators :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	table := ansistyle.Table {
		rows           = {{"a"}, {"b"}},
		border         = ansistyle.ASCII_BORDER,
		row_separators = true,
	}
	expect_table(t, table, .Plain, "+-+\n|a|\n+-+\n|b|\n+-+")
}

@(test)
test_table_header_without_rows :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	expect_table(t, {headers = {"h"}, border = ansistyle.ASCII_BORDER}, .Plain, "+-+\n|h|\n+-+")
}

@(test)
test_table_empty_is_empty_string :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	expect_table(t, {}, .True_Color, "")
	expect_table(t, {rows = {{}, {}}, border = ansistyle.NORMAL_BORDER}, .True_Color, "")
}

@(test)
test_table_rejects_negative_padding :: proc(t: ^testing.T) {
	_, err := ansistyle.table_render({rows = {{"a"}}, padding = -1}, .Plain)
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Layout_Error.Negative_Padding))
}

@(test)
test_table_reports_allocator_error :: proc(t: ^testing.T) {
	l := Limited{context.allocator, 0}
	_, err := ansistyle.table_render({rows = {{"a"}}}, .Plain, limited_allocator(&l))
	testing.expect_value(t, err, OUT_OF_MEMORY)

	// The scratch column widths succeed, the output buffer fails.
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)
	once := Limited{context.allocator, 1}
	_, err = ansistyle.table_render({rows = {{"a"}}}, .Plain, limited_allocator(&once))
	testing.expect_value(t, err, OUT_OF_MEMORY)
}

@(test)
test_table_styles_header_and_cells :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	table := ansistyle.Table {
		headers      = {"h"},
		rows         = {{"c"}},
		header_style = {attrs = {.Bold}},
		cell_style   = {fg = ansistyle.Basic_Color.Green},
	}
	expect_table(t, table, .ANSI_16, "\x1b[1mh\x1b[0m\n\x1b[32mc\x1b[0m")
	expect_table(t, table, .Plain, "h\nc")
}

@(test)
test_table_colors_border :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	table := ansistyle.Table {
		rows      = {{"a"}},
		border    = ansistyle.ASCII_BORDER,
		border_fg = ansistyle.Basic_Color.Red,
	}
	want := "\x1b[31m+-+\x1b[0m\n\x1b[31m|\x1b[0ma\x1b[31m|\x1b[0m\n\x1b[31m+-+\x1b[0m"
	expect_table(t, table, .ANSI_16, want)
}

@(test)
test_table_measures_wide_cells :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	table := ansistyle.Table {
		rows = {{"日本", "x"}, {"a", "👍🏽"}},
	}
	expect_table(t, table, .Plain, "日本x \na   👍🏽")
}

@(test)
test_table_supports_many_columns :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	// More columns than the renderer keeps on the stack.
	row: [70]string
	for &cell in row {
		cell = "a\nb"
	}
	rows := [][]string{row[:]}
	got, err := ansistyle.table_render({rows = rows}, .Plain)
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, len(got), 70 * 2 + 1)
	testing.expect_value(t, ansistyle.display_width(got), 70)
	testing.expect_value(t, ansistyle.height(got), 2)
}
