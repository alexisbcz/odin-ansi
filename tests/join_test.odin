package ansistyle_tests

import ansistyle ".."
import "core:mem"
import "core:testing"

@(test)
test_join_horizontal_vertical_alignment :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	cases := []struct {
		align: ansistyle.Vertical_Align,
		want:  string,
	}{{.Top, "ax\nb \nc "}, {.Middle, "a \nbx\nc "}, {.Bottom, "a \nb \ncx"}}
	for c in cases {
		got, err := ansistyle.join_horizontal({"a\nb\nc", "x"}, c.align)
		testing.expect_value(t, err, nil)
		testing.expect_value(t, got, c.want)
		delete(got)
	}
}

@(test)
test_join_horizontal_pads_each_block :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	got, err := ansistyle.join_horizontal({"ab\nc", "日\n本語", "z"}, .Top)
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, got, "ab日  z\nc 本語 ")
}

@(test)
test_join_vertical_alignment :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	center, err := ansistyle.join_vertical({"a", "bcd"}, .Center)
	defer delete(center)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, center, " a \nbcd")

	right, right_err := ansistyle.join_vertical({"a\nbb", "cccc"}, .Right)
	defer delete(right)
	testing.expect_value(t, right_err, nil)
	testing.expect_value(t, right, "   a\n  bb\ncccc")
}

@(test)
test_join_empty_input :: proc(t: ^testing.T) {
	h, err := ansistyle.join_horizontal({}, .Top)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, h, "")

	v, v_err := ansistyle.join_vertical({}, .Left)
	testing.expect_value(t, v_err, nil)
	testing.expect_value(t, v, "")
}

@(test)
test_join_reports_allocator_error :: proc(t: ^testing.T) {
	l := Limited{context.allocator, 0}
	_, err := ansistyle.join_horizontal({"a", "b"}, .Top, limited_allocator(&l))
	testing.expect_value(t, err, OUT_OF_MEMORY)
	_, err = ansistyle.join_vertical({"a", "b"}, .Left, limited_allocator(&l))
	testing.expect_value(t, err, OUT_OF_MEMORY)
}

@(test)
test_join_rendered_boxes_side_by_side :: proc(t: ^testing.T) {
	tr: mem.Tracking_Allocator
	context.allocator = track_begin(&tr)
	defer track_end(t, &tr)

	left, left_err := ansistyle.render({border = ansistyle.ASCII_BORDER}, "a\nb", .Plain)
	defer delete(left)
	testing.expect_value(t, left_err, nil)
	right, right_err := ansistyle.render({border = ansistyle.ASCII_BORDER}, "x", .Plain)
	defer delete(right)
	testing.expect_value(t, right_err, nil)

	got, err := ansistyle.join_horizontal({left, right}, .Bottom)
	defer delete(got)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, got, "+-+   \n|a|+-+\n|b||x|\n+-++-+")
}
