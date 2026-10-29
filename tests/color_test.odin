package ansistyle_tests

import ansistyle ".."
import "core:testing"

@(test)
test_parse_hex_six_digits :: proc(t: ^testing.T) {
	c, err := ansistyle.parse_hex("#FF8800")
	testing.expect_value(t, err, nil)
	testing.expect_value(t, c, ansistyle.RGB{0xff, 0x88, 0x00})
}

@(test)
test_parse_hex_three_digits_expand :: proc(t: ^testing.T) {
	c, err := ansistyle.parse_hex("#f80")
	testing.expect_value(t, err, nil)
	testing.expect_value(t, c, ansistyle.RGB{0xff, 0x88, 0x00})
}

@(test)
test_parse_hex_accepts_missing_hash :: proc(t: ^testing.T) {
	c, err := ansistyle.parse_hex("0a0b0c")
	testing.expect_value(t, err, nil)
	testing.expect_value(t, c, ansistyle.RGB{0x0a, 0x0b, 0x0c})
}

@(test)
test_parse_hex_rejects_bad_length :: proc(t: ^testing.T) {
	for input in ([]string{"#", "#ff", "#ffff", "#fffffff", "12345"}) {
		_, err := ansistyle.parse_hex(input)
		testing.expectf(t, err == ansistyle.Color_Error.Invalid_Hex_Length, "%q gave %v", input, err)
	}
}

@(test)
test_parse_hex_rejects_bad_digit :: proc(t: ^testing.T) {
	for input in ([]string{"#ggg", "#12345z", "# 12345", "#ff00ä"}) {
		_, err := ansistyle.parse_hex(input)
		testing.expectf(t, err != nil, "%q should fail", input)
	}
	_, err := ansistyle.parse_hex("#12345z")
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Color_Error.Invalid_Hex_Digit))
}

@(test)
test_parse_hex_rejects_empty :: proc(t: ^testing.T) {
	_, err := ansistyle.parse_hex("")
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Color_Error.Empty))
}

@(test)
test_parse_color_names_ignore_case_and_separators :: proc(t: ^testing.T) {
	for input in ([]string{"bright_blue", "Bright-Blue", "BRIGHTBLUE", "bright blue"}) {
		c, err := ansistyle.parse_color(input)
		testing.expectf(t, err == nil, "%q gave %v", input, err)
		testing.expect_value(t, c, ansistyle.Color(ansistyle.Basic_Color.Bright_Blue))
	}
	c, err := ansistyle.parse_color("red")
	testing.expect_value(t, err, nil)
	testing.expect_value(t, c, ansistyle.Color(ansistyle.Basic_Color.Red))
}

@(test)
test_parse_color_gray_aliases :: proc(t: ^testing.T) {
	for input in ([]string{"gray", "grey", "bright_black"}) {
		c, err := ansistyle.parse_color(input)
		testing.expect_value(t, err, nil)
		testing.expect_value(t, c, ansistyle.Color(ansistyle.Basic_Color.Bright_Black))
	}
}

@(test)
test_parse_color_index :: proc(t: ^testing.T) {
	c, err := ansistyle.parse_color("208")
	testing.expect_value(t, err, nil)
	testing.expect_value(t, c, ansistyle.Color(ansistyle.Indexed_Color(208)))

	c, err = ansistyle.parse_color("0")
	testing.expect_value(t, err, nil)
	testing.expect_value(t, c, ansistyle.Color(ansistyle.Indexed_Color(0)))
}

@(test)
test_parse_color_index_out_of_range :: proc(t: ^testing.T) {
	for input in ([]string{"256", "1000", "99999999999999999999999"}) {
		_, err := ansistyle.parse_color(input)
		testing.expectf(t, err == ansistyle.Color_Error.Index_Out_Of_Range, "%q gave %v", input, err)
	}
}

@(test)
test_parse_color_hex_needs_hash :: proc(t: ^testing.T) {
	c, err := ansistyle.parse_color("#00ff00")
	testing.expect_value(t, err, nil)
	testing.expect_value(t, c, ansistyle.Color(ansistyle.RGB{0, 255, 0}))

	_, err = ansistyle.parse_color("bad")
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Color_Error.Unknown_Name))

	_, err = ansistyle.parse_color("#zz")
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Color_Error.Invalid_Hex_Length))
}

@(test)
test_parse_color_rejects_unknown_and_empty :: proc(t: ^testing.T) {
	_, err := ansistyle.parse_color("purple")
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Color_Error.Unknown_Name))

	_, err = ansistyle.parse_color("bright_bright_bright_bright_bright_blue")
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Color_Error.Unknown_Name))

	_, err = ansistyle.parse_color("12a")
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Color_Error.Unknown_Name))

	_, err = ansistyle.parse_color("")
	testing.expect_value(t, err, ansistyle.Error(ansistyle.Color_Error.Empty))
}

@(test)
test_color_rgb_resolves_palette :: proc(t: ^testing.T) {
	cases := []struct {
		color: ansistyle.Color,
		want:  ansistyle.RGB,
	} {
		{ansistyle.Basic_Color.Bright_White, {255, 255, 255}},
		{ansistyle.Indexed_Color(1), {0x80, 0, 0}},
		{ansistyle.Indexed_Color(196), {0xff, 0, 0}},
		{ansistyle.Indexed_Color(16), {0, 0, 0}},
		{ansistyle.Indexed_Color(231), {0xff, 0xff, 0xff}},
		{ansistyle.Indexed_Color(232), {8, 8, 8}},
		{ansistyle.Indexed_Color(255), {238, 238, 238}},
		{ansistyle.rgb(1, 2, 3), {1, 2, 3}},
	}
	for c in cases {
		got, ok := ansistyle.color_rgb(c.color)
		testing.expect(t, ok)
		testing.expectf(t, got == c.want, "%v gave %v, want %v", c.color, got, c.want)
	}
	_, ok := ansistyle.color_rgb(nil)
	testing.expect(t, !ok)
}

@(test)
test_rgb_to_256_hits_exact_cube_entries :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.rgb_to_256({0xff, 0, 0}), ansistyle.Indexed_Color(196))
	testing.expect_value(t, ansistyle.rgb_to_256({0, 0, 0}), ansistyle.Indexed_Color(16))
	testing.expect_value(t, ansistyle.rgb_to_256({0xff, 0xff, 0xff}), ansistyle.Indexed_Color(231))
	testing.expect_value(t, ansistyle.rgb_to_256({0x5f, 0x87, 0xaf}), ansistyle.Indexed_Color(67))
}

@(test)
test_rgb_to_256_prefers_gray_ramp_for_grays :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.rgb_to_256({128, 128, 128}), ansistyle.Indexed_Color(244))
	testing.expect_value(t, ansistyle.rgb_to_256({8, 8, 8}), ansistyle.Indexed_Color(232))
}

@(test)
test_rgb_to_basic_picks_nearest :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.rgb_to_basic({250, 10, 10}), ansistyle.Basic_Color.Bright_Red)
	testing.expect_value(t, ansistyle.rgb_to_basic({10, 10, 10}), ansistyle.Basic_Color.Black)
	testing.expect_value(t, ansistyle.rgb_to_basic({0, 0, 120}), ansistyle.Basic_Color.Blue)
	testing.expect_value(t, ansistyle.rgb_to_basic({250, 250, 250}), ansistyle.Basic_Color.Bright_White)
}

@(test)
test_color_convert_keeps_rgb_for_true_color :: proc(t: ^testing.T) {
	c := ansistyle.rgb(12, 34, 56)
	testing.expect_value(t, ansistyle.color_convert(c, .True_Color), c)
}

@(test)
test_color_convert_downsamples_for_256 :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.color_convert(ansistyle.rgb(255, 0, 0), .ANSI_256), ansistyle.Color(ansistyle.Indexed_Color(196)))
	testing.expect_value(t, ansistyle.color_convert(ansistyle.indexed(42), .ANSI_256), ansistyle.indexed(42))
}

@(test)
test_color_convert_downsamples_for_16 :: proc(t: ^testing.T) {
	testing.expect_value(t, ansistyle.color_convert(ansistyle.indexed(9), .ANSI_16), ansistyle.Color(ansistyle.Basic_Color.Bright_Red))
	testing.expect_value(t, ansistyle.color_convert(ansistyle.indexed(196), .ANSI_16), ansistyle.Color(ansistyle.Basic_Color.Bright_Red))
	testing.expect_value(t, ansistyle.color_convert(ansistyle.rgb(0, 0, 120), .ANSI_16), ansistyle.Color(ansistyle.Basic_Color.Blue))
}

@(test)
test_color_convert_drops_colors_without_color_support :: proc(t: ^testing.T) {
	for profile in ([]ansistyle.Profile{.No_Color, .Plain}) {
		testing.expect_value(t, ansistyle.color_convert(ansistyle.rgb(1, 2, 3), profile), nil)
		testing.expect_value(t, ansistyle.color_convert(ansistyle.Basic_Color.Red, profile), nil)
	}
	testing.expect_value(t, ansistyle.color_convert(nil, .True_Color), nil)
}

@(test)
test_color_convert_never_upsamples_basic :: proc(t: ^testing.T) {
	for profile in ([]ansistyle.Profile{.ANSI_16, .ANSI_256, .True_Color}) {
		testing.expect_value(t, ansistyle.color_convert(ansistyle.Basic_Color.Cyan, profile), ansistyle.Color(ansistyle.Basic_Color.Cyan))
	}
}

@(test)
test_parse_color_returns_nil_on_hex_error :: proc(t: ^testing.T) {
	for input in ([]string{"#", "#12", "#12345z"}) {
		c, err := ansistyle.parse_color(input)
		testing.expectf(t, err != nil, "%q gave no error", input)
		testing.expectf(t, c == nil, "%q gave %v instead of nil", input, c)
	}
}
