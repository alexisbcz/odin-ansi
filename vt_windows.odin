#+private
package ansistyle

import "core:os"
import win "core:sys/windows"

_enable_virtual_terminal :: proc(f: ^os.File) -> bool {
	handle := win.HANDLE(os.fd(f))
	mode: win.DWORD
	if !win.GetConsoleMode(handle, &mode) {
		return false
	}
	if mode & win.ENABLE_VIRTUAL_TERMINAL_PROCESSING != 0 {
		return true
	}
	return bool(win.SetConsoleMode(handle, mode | win.ENABLE_PROCESSED_OUTPUT | win.ENABLE_VIRTUAL_TERMINAL_PROCESSING))
}
