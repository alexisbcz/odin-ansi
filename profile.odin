package ansi

import "core:os"
import "core:strings"
import "core:terminal"

/*
Profile says how much styling an output can show. The members are ordered, so
`profile >= .ANSI_256` reads as "at least 256 colors".
*/
Profile :: enum u8 {
	// No escape sequences at all, for pipes, files and dumb terminals.
	Plain,
	// Attributes such as bold and underline, but no colors. `NO_COLOR` selects it.
	No_Color,
	// The 16 basic colors.
	ANSI_16,
	// The xterm 256-color palette.
	ANSI_256,
	// 24-bit RGB colors.
	True_Color,
}

/*
Environment holds the inputs that profile_from_environment looks at. Fill it
by hand in tests, or let detect_profile read the real process environment.
The strings are borrowed and never freed by this package.
*/
Environment :: struct {
	// Whether the output is attached to a terminal.
	is_tty:      bool,
	// The value of `TERM`, such as `xterm-256color`.
	term:        string,
	// The value of `COLORTERM`, such as `truecolor`.
	colorterm:   string,
	// The value of `NO_COLOR`. Any non-empty value disables colors.
	no_color:    string,
	// The value of `FORCE_COLOR`, or `CLICOLOR_FORCE` when the former is unset.
	force_color: string,
}

/*
profile_from_environment picks a Profile from `env` without touching the
process. The rules, in order:

1. `force_color` set to anything but empty, `0` or `false` forces styling on,
   even when the output isn't a terminal. The values `2` and `3` also ask for
   at least 256 colors and for true color.
2. Otherwise, output that isn't a terminal, or `TERM=dumb`, gets `.Plain`.
3. `COLORTERM=truecolor` or `24bit`, or a `TERM` containing `truecolor`,
   `24bit` or `direct`, gives `.True_Color`. A `TERM` containing `256color`
   gives `.ANSI_256`. Any other non-empty `TERM` gives `.ANSI_16`, and an
   empty one `.No_Color`.
4. A non-empty `no_color` caps the result at `.No_Color`, following
   https://no-color.org.
*/
profile_from_environment :: proc(env: Environment) -> Profile {
	forced := env.force_color != "" && env.force_color != "0" && env.force_color != "false"
	if !forced && (!env.is_tty || env.term == "dumb") {
		return .Plain
	}

	p := term_profile(env.term, env.colorterm)
	if forced {
		p = max(p, Profile.ANSI_16)
		switch env.force_color {
		case "2":
			p = max(p, Profile.ANSI_256)
		case "3":
			p = .True_Color
		}
	}
	if env.no_color != "" {
		p = min(p, Profile.No_Color)
	}
	return p
}

@(private)
term_profile :: proc(term, colorterm: string) -> Profile {
	switch colorterm {
	case "truecolor", "24bit":
		return .True_Color
	}
	switch {
	case term == "" || term == "dumb":
		return .No_Color
	case strings.contains(term, "truecolor"), strings.contains(term, "24bit"), strings.contains(term, "direct"):
		return .True_Color
	case strings.contains(term, "256color"):
		return .ANSI_256
	}
	return .ANSI_16
}

/*
detect_profile reads `NO_COLOR`, `FORCE_COLOR`, `CLICOLOR_FORCE`, `TERM` and
`COLORTERM` from the process environment, checks whether `f` is a terminal,
and applies profile_from_environment. A `nil` file counts as not a terminal.

On Windows, where `TERM` is usually unset, a console counts as `.ANSI_256`,
or `.True_Color` inside Windows Terminal. Importing this package also lets
`core:terminal` turn on escape sequence processing for the Windows console.

It does not allocate.
*/
detect_profile :: proc(f: ^os.File) -> Profile {
	bufs: [5][256]byte
	lookup :: proc(buf: []byte, key: string) -> (value: string, found: bool) {
		v, err := os.lookup_env(buf, key)
		return v, err == nil
	}

	env: Environment
	env.is_tty = f != nil && terminal.is_terminal(f)
	env.term, _ = lookup(bufs[0][:], "TERM")
	env.colorterm, _ = lookup(bufs[1][:], "COLORTERM")
	env.no_color, _ = lookup(bufs[2][:], "NO_COLOR")
	found: bool
	env.force_color, found = lookup(bufs[3][:], "FORCE_COLOR")
	if !found {
		env.force_color, _ = lookup(bufs[4][:], "CLICOLOR_FORCE")
	}

	when ODIN_OS == .Windows {
		if env.term == "" && env.is_tty {
			env.term = "xterm-256color"
			wt_buf: [64]byte
			if _, in_wt := lookup(wt_buf[:], "WT_SESSION"); in_wt {
				env.colorterm = "truecolor"
			}
		}
	}
	return profile_from_environment(env)
}
