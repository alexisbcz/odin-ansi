package ansistyle_tests

import ansistyle ".."
import "core:os"
import "core:testing"

@(test)
test_profile_pipe_is_plain :: proc(t: ^testing.T) {
	env := ansistyle.Environment{is_tty = false, term = "xterm-256color", colorterm = "truecolor"}
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.Plain)
}

@(test)
test_profile_dumb_terminal_is_plain :: proc(t: ^testing.T) {
	env := ansistyle.Environment{is_tty = true, term = "dumb"}
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.Plain)
}

@(test)
test_profile_colorterm_gives_true_color :: proc(t: ^testing.T) {
	for colorterm in ([]string{"truecolor", "24bit"}) {
		env := ansistyle.Environment{is_tty = true, term = "xterm", colorterm = colorterm}
		testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.True_Color)
	}
	env := ansistyle.Environment{is_tty = true, term = "xterm-direct"}
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.True_Color)
}

@(test)
test_profile_term_256color :: proc(t: ^testing.T) {
	env := ansistyle.Environment{is_tty = true, term = "screen-256color"}
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.ANSI_256)
}

@(test)
test_profile_other_terms_get_16_colors :: proc(t: ^testing.T) {
	for term in ([]string{"xterm", "vt100", "linux"}) {
		env := ansistyle.Environment{is_tty = true, term = term}
		testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.ANSI_16)
	}
}

@(test)
test_profile_empty_term_has_no_color :: proc(t: ^testing.T) {
	env := ansistyle.Environment{is_tty = true}
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.No_Color)
}

@(test)
test_profile_no_color_keeps_attributes_only :: proc(t: ^testing.T) {
	env := ansistyle.Environment{is_tty = true, term = "xterm-256color", colorterm = "truecolor", no_color = "1"}
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.No_Color)

	// An empty NO_COLOR doesn't count, per no-color.org.
	env.no_color = ""
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.True_Color)
}

@(test)
test_profile_force_color_overrides_pipe :: proc(t: ^testing.T) {
	env := ansistyle.Environment{is_tty = false, force_color = "1"}
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.ANSI_16)

	env.force_color = "2"
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.ANSI_256)

	env.force_color = "3"
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.True_Color)

	env = {is_tty = false, term = "dumb", force_color = "true"}
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.ANSI_16)

	env = {is_tty = false, term = "xterm-256color", force_color = "1"}
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.ANSI_256)
}

@(test)
test_profile_force_color_zero_is_ignored :: proc(t: ^testing.T) {
	for value in ([]string{"0", "false", ""}) {
		env := ansistyle.Environment{is_tty = false, term = "xterm", force_color = value}
		testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.Plain)
	}
}

@(test)
test_profile_no_color_beats_force_color :: proc(t: ^testing.T) {
	env := ansistyle.Environment{is_tty = false, force_color = "3", no_color = "yes"}
	testing.expect_value(t, ansistyle.profile_from_environment(env), ansistyle.Profile.No_Color)
}

@(test)
test_profile_order_reads_as_capability :: proc(t: ^testing.T) {
	testing.expect(t, ansistyle.Profile.True_Color > ansistyle.Profile.ANSI_256)
	testing.expect(t, ansistyle.Profile.ANSI_256 > ansistyle.Profile.ANSI_16)
	testing.expect(t, ansistyle.Profile.ANSI_16 > ansistyle.Profile.No_Color)
	testing.expect(t, ansistyle.Profile.No_Color > ansistyle.Profile.Plain)
}

// This is the only test that touches the process environment, so it doesn't
// race with the others.
@(test)
test_detect_profile_reads_process_environment :: proc(t: ^testing.T) {
	_ = os.unset_env("FORCE_COLOR")
	_ = os.unset_env("CLICOLOR_FORCE")
	_ = os.unset_env("NO_COLOR")
	testing.expect_value(t, ansistyle.detect_profile(nil), ansistyle.Profile.Plain)

	testing.expect_value(t, os.set_env("FORCE_COLOR", "3"), nil)
	testing.expect_value(t, ansistyle.detect_profile(nil), ansistyle.Profile.True_Color)

	testing.expect_value(t, os.set_env("NO_COLOR", "1"), nil)
	testing.expect_value(t, ansistyle.detect_profile(nil), ansistyle.Profile.No_Color)

	_ = os.unset_env("FORCE_COLOR")
	_ = os.unset_env("NO_COLOR")
	testing.expect_value(t, os.set_env("CLICOLOR_FORCE", "1"), nil)
	testing.expect(t, ansistyle.detect_profile(nil) >= .ANSI_16)
	_ = os.unset_env("CLICOLOR_FORCE")
}
