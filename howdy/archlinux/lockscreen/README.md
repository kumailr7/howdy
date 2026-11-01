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

## Face scan pill (dynamic island)

- `glyph/glyph/FaceIsland.qml`: a pill at the top of the screen while howdy is
  scanning (sudo, polkit, ...): a spinning dot ring, then a check mark and
  "unlocked", or a cross with the reason ("too dark", "not recognised", ...).
  It reads `/run/howdy/status.json`, which `compare.py` writes (config option
  `scan_status` in `[core]`). The lock screen has its own indicator, so scans for
  the `lock`, `lockface` and `sddm` services are ignored.
- Add it to `glyph/Glyph.qml` below the `LiveIsland` line, so it sits under the
  live island when both are visible:

      FaceIsland { offset: live.occupied }
