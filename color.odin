package ansistyle

/*
Basic_Color is one of the 16 colors that every color terminal supports. The
first eight are the normal colors and the last eight their bright variants.
The terminal's theme decides the exact shades.
*/
Basic_Color :: enum u8 {
	Black,
	Red,
	Green,
	Yellow,
	Blue,
	Magenta,
	Cyan,
	White,
	Bright_Black,
	Bright_Red,
	Bright_Green,
	Bright_Yellow,
	Bright_Blue,
	Bright_Magenta,
	Bright_Cyan,
	Bright_White,
}

/*
Indexed_Color is an entry in the xterm 256-color palette: 0-15 are the basic
colors, 16-231 a 6x6x6 color cube and 232-255 a ramp of grays.
*/
Indexed_Color :: distinct u8

// RGB is a 24-bit true color.
RGB :: struct {
	r, g, b: u8,
}

/*
Color is any color the package can emit. The `nil` value means "no color",
which leaves the terminal's default in place.
*/
Color :: union {
	Basic_Color,
	Indexed_Color,
	RGB,
}

// ANSI_PALETTE holds the xterm default shades of the 16 basic colors. The
// package uses them to measure distances when it downsamples a color.
ANSI_PALETTE :: [16]RGB {
	{0x00, 0x00, 0x00},
	{0x80, 0x00, 0x00},
	{0x00, 0x80, 0x00},
	{0x80, 0x80, 0x00},
	{0x00, 0x00, 0x80},
	{0x80, 0x00, 0x80},
	{0x00, 0x80, 0x80},
	{0xc0, 0xc0, 0xc0},
	{0x80, 0x80, 0x80},
	{0xff, 0x00, 0x00},
	{0x00, 0xff, 0x00},
	{0xff, 0xff, 0x00},
	{0x00, 0x00, 0xff},
	{0xff, 0x00, 0xff},
	{0x00, 0xff, 0xff},
	{0xff, 0xff, 0xff},
}

@(private)
CUBE_LEVELS :: [6]u8{0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff}

// rgb returns the true color with the given channels.
rgb :: proc "contextless" (r, g, b: u8) -> Color {
	return RGB{r, g, b}
}

// indexed returns the 256-color palette entry `n`.
indexed :: proc "contextless" (n: u8) -> Color {
	return Indexed_Color(n)
}

/*
parse_hex parses a CSS-style hex color such as `#ff8800`, `ff8800` or `#f80`.

Returns:
- c: the parsed color.
- err: `.Empty`, `.Invalid_Hex_Length` or `.Invalid_Hex_Digit`.
*/
parse_hex :: proc "contextless" (s: string) -> (c: RGB, err: Error) {
	digits := s
	if len(digits) > 0 && digits[0] == '#' {
		digits = digits[1:]
	}
	if len(s) == 0 {
		return {}, .Empty
	}
	nibbles: [6]u8
	switch len(digits) {
	case 3, 6:
	case:
		return {}, .Invalid_Hex_Length
	}
	for i in 0 ..< len(digits) {
		v, ok := hex_digit(digits[i])
		if !ok {
			return {}, .Invalid_Hex_Digit
		}
		nibbles[i] = v
	}
	if len(digits) == 3 {
		return RGB{nibbles[0] * 17, nibbles[1] * 17, nibbles[2] * 17}, nil
	}
	return RGB{nibbles[0] << 4 | nibbles[1], nibbles[2] << 4 | nibbles[3], nibbles[4] << 4 | nibbles[5]}, nil
}

@(private)
hex_digit :: proc "contextless" (b: byte) -> (v: u8, ok: bool) {
	switch b {
	case '0' ..= '9':
		return b - '0', true
	case 'a' ..= 'f':
		return b - 'a' + 10, true
	case 'A' ..= 'F':
		return b - 'A' + 10, true
	}
	return 0, false
}

@(private)
Color_Name :: struct {
	name:  string,
	color: Basic_Color,
}

@(private)
COLOR_NAMES :: [?]Color_Name{
	{"black", .Black},
	{"red", .Red},
	{"green", .Green},
	{"yellow", .Yellow},
	{"blue", .Blue},
	{"magenta", .Magenta},
	{"cyan", .Cyan},
	{"white", .White},
	{"gray", .Bright_Black},
	{"grey", .Bright_Black},
	{"brightblack", .Bright_Black},
	{"brightred", .Bright_Red},
	{"brightgreen", .Bright_Green},
	{"brightyellow", .Bright_Yellow},
	{"brightblue", .Bright_Blue},
	{"brightmagenta", .Bright_Magenta},
	{"brightcyan", .Bright_Cyan},
	{"brightwhite", .Bright_White},
}

/*
parse_color reads a color from user input, such as a configuration file or a
command-line flag. It accepts three forms:

- a basic color name such as `red`, `bright_blue`, `Bright-Blue` or `gray`;
  case, `-`, `_` and spaces are ignored;
- a decimal palette index from `0` to `255`;
- a hex color that starts with `#`, as accepted by parse_hex.

Returns:
- c: the parsed color; never `nil` on success and always `nil` on failure.
- err: `.Empty`, `.Index_Out_Of_Range`, `.Unknown_Name` or a parse_hex error.
*/
parse_color :: proc "contextless" (s: string) -> (c: Color, err: Error) {
	if len(s) == 0 {
		return nil, .Empty
	}
	if s[0] == '#' {
		value := parse_hex(s) or_return
		return value, nil
	}

	all_digits := true
	for i in 0 ..< len(s) {
		if s[i] < '0' || s[i] > '9' {
			all_digits = false
			break
		}
	}
	if all_digits {
		n := 0
		for i in 0 ..< len(s) {
			n = n * 10 + int(s[i] - '0')
			if n > 255 {
				return nil, .Index_Out_Of_Range
			}
		}
		return Indexed_Color(n), nil
	}

	// Normalize the name into a small stack buffer: lowercase, no separators.
	buf: [32]byte
	n := 0
	for i in 0 ..< len(s) {
		b := s[i]
		switch b {
		case '-', '_', ' ':
			continue
		case 'A' ..= 'Z':
			b += 'a' - 'A'
		}
		if n == len(buf) {
			return nil, .Unknown_Name
		}
		buf[n] = b
		n += 1
	}
	name := string(buf[:n])
	names := COLOR_NAMES
	for entry in names {
		if entry.name == name {
			return entry.color, nil
		}
	}
	return nil, .Unknown_Name
}

/*
color_rgb returns the RGB value of `c`. Basic and indexed colors use the xterm
default palette.

Returns:
- value: the color's channels.
- ok: false when `c` is `nil`.
*/
color_rgb :: proc "contextless" (c: Color) -> (value: RGB, ok: bool) {
	palette := ANSI_PALETTE
	switch v in c {
	case Basic_Color:
		return palette[u8(v) & 15], true
	case Indexed_Color:
		return indexed_rgb(u8(v)), true
	case RGB:
		return v, true
	}
	return {}, false
}

@(private)
indexed_rgb :: proc "contextless" (i: u8) -> RGB {
	palette := ANSI_PALETTE
	cube := CUBE_LEVELS
	switch {
	case i < 16:
		return palette[i]
	case i < 232:
		j := i - 16
		return RGB{cube[j / 36], cube[(j / 6) % 6], cube[j % 6]}
	case:
		v := 8 + 10 * (i - 232)
		return RGB{v, v, v}
	}
}

// distance is the "redmean" approximation of perceptual color distance. It
// returns a squared value, which is fine for comparisons.
@(private)
distance :: proc "contextless" (a, b: RGB) -> int {
	rmean := (int(a.r) + int(b.r)) / 2
	dr := int(a.r) - int(b.r)
	dg := int(a.g) - int(b.g)
	db := int(a.b) - int(b.b)
	return ((512 + rmean) * dr * dr >> 8) + 4 * dg * dg + ((767 - rmean) * db * db >> 8)
}

/*
rgb_to_256 returns the 256-color palette entry closest to `c`. It picks the
nearer of the closest color-cube entry and the closest gray, the same way
xterm-compatible tools such as tmux do.
*/
rgb_to_256 :: proc "contextless" (c: RGB) -> Indexed_Color {
	level :: proc "contextless" (v: u8) -> int {
		switch {
		case v < 48:
			return 0
		case v < 115:
			return 1
		case:
			return (int(v) - 35) / 40
		}
	}
	cube := CUBE_LEVELS
	r, g, b := level(c.r), level(c.g), level(c.b)
	cube_rgb := RGB{cube[r], cube[g], cube[b]}
	cube_index := 16 + 36 * r + 6 * g + b

	average := (int(c.r) + int(c.g) + int(c.b)) / 3
	gray_index := 23 if average > 238 else max(average - 3, 0) / 10
	gray_value := u8(8 + 10 * gray_index)
	gray_rgb := RGB{gray_value, gray_value, gray_value}

	if distance(c, gray_rgb) < distance(c, cube_rgb) {
		return Indexed_Color(232 + gray_index)
	}
	return Indexed_Color(cube_index)
}

// rgb_to_basic returns the basic color whose xterm default shade is closest to `c`.
rgb_to_basic :: proc "contextless" (c: RGB) -> Basic_Color {
	palette := ANSI_PALETTE
	best := 0
	best_distance := max(int)
	for shade, i in palette {
		d := distance(c, shade)
		if d < best_distance {
			best, best_distance = i, d
		}
	}
	return Basic_Color(best)
}

/*
color_convert downsamples `c` so that a terminal with `profile` can show it.

- `.True_Color` keeps every color.
- `.ANSI_256` turns RGB into the nearest palette entry.
- `.ANSI_16` turns RGB and palette entries into the nearest basic color.
- `.No_Color` and `.Plain` return `nil`.

Colors never upsample: a Basic_Color stays basic under every color profile.
*/
color_convert :: proc "contextless" (c: Color, profile: Profile) -> Color {
	if profile < .ANSI_16 {
		return nil
	}
	switch v in c {
	case Basic_Color:
		return v
	case Indexed_Color:
		if profile == .ANSI_16 {
			if v < 16 {
				return Basic_Color(v)
			}
			return rgb_to_basic(indexed_rgb(u8(v)))
		}
		return v
	case RGB:
		switch profile {
		case .True_Color:
			return v
		case .ANSI_256:
			return rgb_to_256(v)
		case .ANSI_16, .No_Color, .Plain:
			return rgb_to_basic(v)
		}
	}
	return nil
}
