# Lock screen integration (quickshell "glyph" shell)

Copies of the files changed in `~/.config/quickshell/glyph/` to use howdy:

- `lock.qml`: scans your face right after the screen locks and again after
  DPMS/suspend wake. Typing a password cancels the scan; Enter on an empty
  field also scans.
- `pam/lock`: password login, with `pam_howdy.so` tried first.
- `pam/lockface`: howdy only, used by the automatic scan so a missed scan does
  not count as a failed password in `pam_faillock`.

Install by copying them back into `~/.config/quickshell/glyph/` (the real
location is `~/.local/share/glyph/config/quickshell/glyph`). Run
`sudo howdy doctor` to check the PAM side.
