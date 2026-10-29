package ansistyle_tests

import ansistyle ".."
import "core:mem"
import "core:testing"

@(test)
test_render_zero_style_is_identity :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	expect_render(t, {}, "hello", .True_Color, "hello")
	expect_render(t, {}, "", .True_Color, "")
}

@(test)
test_render_pads_lines_to_one_width :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	expect_render(t, {}, "hi\r\nthere", .Plain, "hi   \nthere")
	expect_render(t, {align = .Right}, "hi\nthere", .Plain, "   hi\nthere")
}

@(test)
test_render_basic_colors_and_attributes :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	expect_render(t, {fg = ansistyle.Basic_Color.Red, attrs = {.Bold}}, "hi", .ANSI_16, "\x1b[1;31mhi\x1b[0m")
	expect_render(t, {fg = ansistyle.Basic_Color.Bright_Blue, bg = ansistyle.Basic_Color.Bright_Red}, "hi", .ANSI_16, "\x1b[94;101mhi\x1b[0m")
	expect_render(t, {bg = ansistyle.Basic_Color.Green}, "hi", .ANSI_16, "\x1b[42mhi\x1b[0m")
}

@(test)
test_render_all_attribute_codes :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	style := ansistyle.Style {
		attrs = {.Bold, .Faint, .Italic, .Underline, .Blink, .Reverse, .Strikethrough},
	}
	expect_render(t, style, "x", .No_Color, "\x1b[1;2;3;4;5;7;9mx\x1b[0m")
}

@(test)
test_render_true_color_and_palette_sequences :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	expect_render(t, {fg = ansistyle.rgb(1, 2, 3), bg = ansistyle.indexed(200)}, "hi", .True_Color, "\x1b[38;2;1;2;3;48;5;200mhi\x1b[0m")
	expect_render(t, {bg = ansistyle.rgb(255, 255, 255)}, "hi", .True_Color, "\x1b[48;2;255;255;255mhi\x1b[0m")
}

@(test)
test_render_downsamples_to_profile :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	style := ansistyle.Style {
		fg = ansistyle.rgb(255, 0, 0),
	}
	expect_render(t, style, "hi", .ANSI_256, "\x1b[38;5;196mhi\x1b[0m")
	expect_render(t, style, "hi", .ANSI_16, "\x1b[91mhi\x1b[0m")
}

@(test)
test_render_no_color_keeps_attributes :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	style := ansistyle.Style {
		fg    = ansistyle.rgb(255, 0, 0),
		attrs = {.Bold},
	}
	expect_render(t, style, "hi", .No_Color, "\x1b[1mhi\x1b[0m")
	expect_render(t, {fg = ansistyle.Basic_Color.Red}, "hi", .No_Color, "hi")
}

@(test)
test_render_plain_emits_no_escapes :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	style := ansistyle.Style {
		fg        = ansistyle.Basic_Color.Red,
		bg        = ansistyle.rgb(0, 0, 0),
		attrs     = {.Bold, .Underline},
		border    = ansistyle.ASCII_BORDER,
		border_fg = ansistyle.Basic_Color.Blue,
	}
	expect_render(t, style, "hi", .Plain, "+--+\n|hi|\n+--+")
}

@(test)
test_render_rounded_border :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	expect_render(t, {border = ansistyle.ROUNDED_BORDER}, "hi\nyou", .Plain, "╭───╮\n│hi │\n│you│\n╰───╯")
}

@(test)
test_render_colored_border :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	style := ansistyle.Style {
		border    = ansistyle.ASCII_BORDER,
		border_fg = ansistyle.Basic_Color.Blue,
	}
	want := "\x1b[34m+-+\x1b[0m\n\x1b[34m|\x1b[0mx\x1b[34m|\x1b[0m\n\x1b[34m+-+\x1b[0m"
	expect_render(t, style, "x", .ANSI_16, want)
}

@(test)
test_render_partial_border :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	b := ansistyle.NORMAL_BORDER
	b.left, b.right = "", ""
	expect_render(t, {border = b}, "ab", .Plain, "──\nab\n──")

	sides := ansistyle.NORMAL_BORDER
	sides.top, sides.bottom = "", ""
	expect_render(t, {border = sides}, "ab", .Plain, "│ab│")
}

@(test)
test_render_border_with_wide_text :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	expect_render(t, {border = ansistyle.NORMAL_BORDER}, "日本\nab", .Plain, "┌────┐\n│日本│\n│ab  │\n└────┘")
}

@(test)
test_render_padding_and_margin :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	style := ansistyle.Style {
		padding = ansistyle.spacing(1, 2),
		margin  = ansistyle.spacing(0, 0, 0, 1),
	}
	expect_render(t, style, "ab", .Plain, "       \n   ab  \n       ")

	boxed := ansistyle.Style {
		padding = ansistyle.spacing(0, 1),
		margin  = ansistyle.spacing(1),
		border  = ansistyle.ASCII_BORDER,
	}
	expect_render(t, boxed, "x", .Plain, "       \n +---+ \n | x | \n +---+ \n       ")
}

@(test)
test_render_background_covers_padding :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	style := ansistyle.Style {
		bg      = ansistyle.Basic_Color.Blue,
		attrs   = {.Underline},
		padding = ansistyle.spacing(0, 1),
	}
	// Padding gets only the background, so the underline stops at the text.
	want := "\x1b[44m \x1b[0m\x1b[4;44mx\x1b[0m\x1b[44m \x1b[0m"
	expect_render(t, style, "x", .ANSI_16, want)
}

@(test)
test_render_width_and_alignment :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	expect_render(t, {width = 8, align = .Center}, "ab", .Plain, "   ab   ")
	expect_render(t, {width = 8, align = .Right}, "ab", .Plain, "      ab")
	expect_render(t, {width = 6, padding = ansistyle.spacing(0, 1)}, "ab", .Plain, " ab   ")
	// width is a minimum: longer text keeps its size.
	expect_render(t, {width = 2}, "abcd", .Plain, "abcd")
}

@(test)
test_render_max_width_truncates :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	expect_render(t, {max_width = 4}, "abcdefgh\nab", .Plain, "abc…\nab  ")
	expect_render(t, {max_width = 6, padding = ansistyle.spacing(0, 1)}, "abcdefgh", .Plain, " abc… ")
	// A wide character that doesn't fit leaves a gap instead of overflowing.
	expect_render(t, {max_width = 4}, "日本語", .Plain, "日… ")
	// max_width wins over width.
	expect_render(t, {width = 10, max_width = 3}, "ab", .Plain, "ab ")
}

@(test)
test_render_rejects_negative_layout :: proc(t: ^testing.T) {
	_, err := ansistyle.render({width = -1}, "x", .Plain)
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Layout_Error.Negative_Width))
	_, err = ansistyle.render({max_width = -1}, "x", .Plain)
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Layout_Error.Negative_Width))
	_, err = ansistyle.render({padding = {left = -1}}, "x", .Plain)
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Layout_Error.Negative_Padding))
	_, err = ansistyle.render({margin = {bottom = -2}}, "x", .Plain)
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Layout_Error.Negative_Margin))
}

@(test)
test_render_reports_allocator_error :: proc(t: ^testing.T) {
	l := Limited{context.allocator, 0}
	out, err := ansistyle.render({border = ansistyle.NORMAL_BORDER}, "x", .True_Color, limited_allocator(&l))
	testing.expect_value(t, err, OUT_OF_MEMORY)
	testing.expect_value(t, out, "")
}

@(test)
test_render_passes_nested_styles_through :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	inner, err := ansistyle.render({attrs = {.Bold}}, "hi", .ANSI_16)
	defer delete(inner)
	testing.expect_value(t, err, nil)
	expect_render(t, {width = 4}, inner, .ANSI_16, "\x1b[1mhi\x1b[0m  ")
}

@(test)
test_sgr_builds_opening_sequence :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	seq, err := ansistyle.sgr(ansistyle.Basic_Color.Green, nil, {.Underline}, .ANSI_256)
	defer delete(seq)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, seq, "\x1b[4;32m")

	empty, empty_err := ansistyle.sgr(nil, nil, {}, .True_Color)
	defer delete(empty)
	testing.expect_value(t, empty_err, nil)
	testing.expect_value(t, empty, "")
}

@(test)
test_spacing_shorthands :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.spacing(2), ansistyle.Spacing{2, 2, 2, 2})
	testing.expect_value(t, ansistyle.spacing(1, 3), ansistyle.Spacing{1, 3, 1, 3})
	testing.expect_value(t, ansistyle.spacing(1, 2, 3, 4), ansistyle.Spacing{top = 1, right = 2, bottom = 3, left = 4})
}

@(test)
test_render_max_width_caps_padding :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	// Padding wider than max_width shrinks, right side first, so the block
	// never grows past the limit.
	expect_render(t, {max_width = 4, padding = ansistyle.spacing(0, 3)}, "hello", .Plain, "    ")
	expect_render(t, {max_width = 5, padding = ansistyle.spacing(0, 3)}, "hello", .Plain, "     ")
	expect_render(t, {max_width = 2, padding = {left = 1, right = 3}}, "x", .Plain, "  ")
	box, err := ansistyle.render({max_width = 4, padding = ansistyle.spacing(0, 3), border = ansistyle.NORMAL_BORDER}, "hello", .Plain)
	defer delete(box)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, ansistyle.display_width(box), 6)
}
