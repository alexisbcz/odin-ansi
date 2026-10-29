package ansistyle_tests

import ansistyle ".."
import "core:mem"
import "core:testing"

@(test)
test_display_width_ascii :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.display_width("hello"), 5)
	testing.expect_value(t, ansistyle.display_width(""), 0)
}

@(test)
test_display_width_counts_wide_chars_twice :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.display_width("日本語"), 6)
	testing.expect_value(t, ansistyle.display_width("한국"), 4)
	testing.expect_value(t, ansistyle.display_width("a日b"), 4)
}

@(test)
test_display_width_counts_emoji_clusters_once :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.display_width("👍🏽"), 2)
	testing.expect_value(t, ansistyle.display_width("👨‍👩‍👧"), 2)
	testing.expect_value(t, ansistyle.display_width("🇫🇷"), 2)
}

@(test)
test_display_width_ignores_combining_marks :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.display_width("été"), 3)
	testing.expect_value(t, ansistyle.display_width("a​b"), 2)
}

@(test)
test_display_width_skips_escape_sequences :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.display_width("\x1b[1;38;2;255;0;0mred\x1b[0m"), 3)
	link := "\x1b]8;;https://odin-lang.org\x1b\\Odin\x1b]8;;\x1b\\"
	testing.expect_value(t, ansistyle.display_width(link), 4)
	testing.expect_value(t, ansistyle.display_width("\x1b]0;title\x07ok"), 2)
	testing.expect_value(t, ansistyle.display_width("\x1b7saved\x1b8"), 5)
}

@(test)
test_display_width_survives_malformed_escapes :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.display_width("\x1b[31"), 0)
	testing.expect_value(t, ansistyle.display_width("abc\x1b"), 3)
	testing.expect_value(t, ansistyle.display_width("\x1b]8;;unterminated"), 0)
	testing.expect_value(t, ansistyle.display_width("\x1b[3\nab"), 2)
	testing.expect_value(t, ansistyle.display_width("\xff\xfe"), 2)
}

@(test)
test_display_width_of_lines_is_widest :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.display_width("ab\nabcd\nabc"), 4)
	testing.expect_value(t, ansistyle.display_width("ab\r\n日本"), 4)
}

@(test)
test_height_and_size :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.height(""), 1)
	testing.expect_value(t, ansistyle.height("a\nb\n"), 3)
	w, h := ansistyle.size("日本\nabc")
	testing.expect_value(t, w, 4)
	testing.expect_value(t, h, 2)
}

@(test)
test_strip_removes_sequences :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	got, err := ansistyle.strip("\x1b[1;31mred\x1b[0m \x1b]8;;http://x\x07link\x1b]8;;\x07")
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, got, "red link")
}

@(test)
test_strip_reports_allocator_error :: proc(t: ^testing.T) {
	l := Limited{context.allocator, 0}
	_, err := ansistyle.strip("abc", limited_allocator(&l))
	testing.expect_value(t, err, OUT_OF_MEMORY)
}

@(test)
test_truncate_cuts_with_tail :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	got, err := ansistyle.truncate("hello world", 5, "…")
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, got, "hell…")
}

@(test)
test_truncate_never_splits_wide_chars :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	got, err := ansistyle.truncate("日本語", 3)
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, got, "日")

	emoji, emoji_err := ansistyle.truncate("👨‍👩‍👧👍🏽", 3)
	defer delete(emoji)
	testing.expect_value(t, emoji_err, nil)
	testing.expect_value(t, emoji, "👨‍👩‍👧")
}

@(test)
test_truncate_keeps_escape_sequences :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	got, err := ansistyle.truncate("\x1b[31mhello\x1b[0m", 3, "…")
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, got, "\x1b[31mhe…\x1b[0m")
}

@(test)
test_truncate_leaves_short_lines_alone :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	got, err := ansistyle.truncate("abcdef\nxy", 3, ".")
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, got, "ab.\nxy")

	same, same_err := ansistyle.truncate("abc", 3, "…")
	defer delete(same)
	testing.expect_value(t, same_err, nil)
	testing.expect_value(t, same, "abc")
}

@(test)
test_truncate_drops_tail_wider_than_width :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	got, err := ansistyle.truncate("hello", 1, "...")
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, got, "h")

	empty, empty_err := ansistyle.truncate("hello", 0, "…")
	defer delete(empty)
	testing.expect_value(t, empty_err, nil)
	testing.expect_value(t, empty, "")
}

@(test)
test_truncate_rejects_negative_width :: proc(t: ^testing.T) {
	_, err := ansistyle.truncate("hello", -1)
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Layout_Error.Negative_Width))
}

@(test)
test_align_text_left_center_right :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	cases := []struct {
		align: ansistyle.Align,
		want:  string,
	}{{.Left, "ab   "}, {.Center, " ab  "}, {.Right, "   ab"}}
	for c in cases {
		got, err := ansistyle.align_text("ab", 5, c.align)
		testing.expect_value(t, err, nil)
		testing.expect_value(t, got, c.want)
		delete(got)
	}
}

@(test)
test_align_text_handles_lines_and_wide_text :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	got, err := ansistyle.align_text("a\r\n日本\nlonger", 3, .Right)
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, got, "  a\n日本\nlonger")
}

@(test)
test_align_text_rejects_negative_width :: proc(t: ^testing.T) {
	_, err := ansistyle.align_text("ab", -3, .Left)
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Layout_Error.Negative_Width))
}

@(test)
test_expand_tabs_aligns_to_stops :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	got, err := ansistyle.expand_tabs("a\tb\n\tx\nab\tc\x1b[1m\ty", 4)
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, got, "a   b\n    x\nab  c\x1b[1m   y")
}

@(test)
test_expand_tabs_rejects_bad_width :: proc(t: ^testing.T) {
	_, err := ansistyle.expand_tabs("\t", 0)
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Layout_Error.Invalid_Tab_Width))
}

@(test)
test_expand_tabs_frees_buffer_when_growth_fails :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	// The first allocation succeeds; growing the buffer for the spaces fails.
	l := Limited{context.allocator, 1}
	_, err := ansistyle.expand_tabs("\t\t\t\t", 8, limited_allocator(&l))
	testing.expect_value(t, err, OUT_OF_MEMORY)
}

@(test)
test_display_width_skips_nf_escape_sequences :: proc(t: ^testing.T) {
	// `tput sgr0` on xterm prints ESC ( B before the SGR reset.
	testing.expect_value(t, ansistyle.display_width("\x1b(Bab\x1b[m"), 2)
	testing.expect_value(t, ansistyle.display_width("\x1b#8ab"), 2)
	testing.expect_value(t, ansistyle.display_width("\x1b)0\x1b(0ab"), 2)
}

@(test)
test_lone_escape_keeps_the_next_line_break :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.display_width("ab\x1b\ncd"), 2)
	testing.expect_value(t, ansistyle.display_width("\x1b(\nab"), 2)
}

@(test)
test_strip_removes_nf_escape_sequences :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	out, err := ansistyle.strip("\x1b(Bab\x1b[m\x1b#8c")
	defer delete(out)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, out, "abc")
}
