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

- `glyph/components/FacePill.qml`: the pill itself, shared by the desktop island
  and the lock screen. `glyph/lock/LockSurface.qml` shows it on the lock screen
  and `lock.qml` drives it (scanning, success, failed with a reason).
- `glyph/glyph/FaceIsland.qml`: a pill at the top of the screen while howdy is
  scanning (sudo, polkit, ...): a spinning dot ring, then a check mark and
  "unlocked", or a cross with the reason ("too dark", "not recognised", ...).
  It reads `/run/howdy/status.json`, which `compare.py` writes (config option
  `scan_status` in `[core]`). Scans for the `lock`, `lockface` and `sddm`
  services are ignored there, because the lock screen shows its own pill.
- Add it to `glyph/Glyph.qml` below the `LiveIsland` line, so it sits under the
  live island when both are visible:

      FaceIsland { offset: live.occupied }

## Headphones pill

- `glyph/glyph/HeadsetIsland.qml`: when a Bluetooth headset connects, a pill with
  the headphones icon, the device name and a battery ring (red at 20% or less)
  drops from the top for a few seconds. It skips Nothing/CMF/Ear devices, which
  already have their own card (`buds/Buds.qml`). Add it to `glyph/Glyph.qml`
  below the `FaceIsland` line:

      HeadsetIsland { offset: live.occupied }

## Event pill (charging, sound, mic, DND, Wi-Fi, VPN)

- `glyph/glyph/EventIsland.qml`: one pill with a queue for short events: charger
  plugged or unplugged, low battery (20/10/5%), silent or sound on, volume,
  mic mute, mic in use by an app, Do Not Disturb, Wi-Fi network joined, VPN on or off,
  USB device connected or removed (udev), downloads in `~/Downloads` (`.crdownload`
  and `.part` files), and a Wi-Fi hotspot starting or stopping (NetworkManager). Add it to
  `glyph/Glyph.qml` below the `HeadsetIsland` line:

      EventIsland { offset: live.occupied }
