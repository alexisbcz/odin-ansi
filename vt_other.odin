#+build !windows
#+private
package ansistyle

import "core:os"

_enable_virtual_terminal :: proc(f: ^os.File) -> bool {
	return true
}
