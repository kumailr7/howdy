# Howdy — Repo Context

Linux face-authentication ("Windows Hello for Linux"). A C++ PAM module spawns a Python script that matches a webcam frame against stored dlib face encodings. Version string: `Howdy 3.0.0 BETA`. Branch: `master`.

## Layout

| Path | What |
|---|---|
| `meson.build`, `meson.options` (= `meson_options.txt`) | Top-level build; builds `howdy-gtk` before `howdy` (order matters) |
| `howdy/src/` | Core: Python CLI + recognition, C++ PAM module in `pam/` |
| `howdy-gtk/src/` | GTK3 UI (settings window, onboarding, auth-sticky window) |
| `howdy/debian`, `howdy-gtk/debian`, `howdy/archlinux` | Legacy packaging (not meson-based) |
| `.github/workflows/check.yml` | Only CI: meson build + clang-tidy; no tests |

## Authentication flow

1. PAM calls `pam_howdy.so` (`howdy/src/pam/main.cc`, `identify()` :198-425).
2. `check_enabled()` skips Howdy (`PAM_AUTHINFO_UNAVAIL`) if: `core.disabled`; `abort_if_ssh` and an SSH env var is set; `abort_if_lid_closed` and lid closed; or no `<user_models_dir>/<user>.dat`.
3. Spawns `python compare.py <user>` via `posix_spawnp` with an **empty environment**.
4. Two threads (`optional_task.hh`) race: `waitpid` on the child vs `pam_get_authtok` (password prompt). Whichever finishes first wins; if the face match wins, the password prompt is cancelled using `core.workaround`:
   - `input` (default): fake Enter via `/dev/uinput` (`enter_device.cc`), up to 5 retries.
   - `native`: `pthread_cancel` (marked UNSAFE in code).
   - `off`: no password race.
5. Exit code → PAM result: 0 success; 10 no model; 11 timeout; 12 abort; 13 too dark; 14 invalid device; 15 rubberstamp failed (declared, falls to default case); anything else `PAM_AUTH_ERR`. Timeout falls through to the normal password prompt.

## compare.py (`howdy/src/compare.py`)

- Loads `<models>/<user>.dat` (JSON despite extension), concatenates all `model["data"]` encodings (:126-129).
- Models load in a background thread: HOG detector (or CNN `mmod_human_face_detector.dat` if `core.use_cnn`), `shape_predictor_5_face_landmarks.dat`, `dlib_face_recognition_resnet_model_v1.dat`. Missing files → exit 1 with a hint to run `dlib-data/install.sh`.
- Frame loop: CLAHE, skip black/dark frames (`dark_threshold`), downscale to `max_height`, optional `rotate`, detect → landmarks → descriptor. Match = min Euclidean distance; success when `0 < match < certainty/10` (:324).
- Timeout (`video.timeout`, default 4s) → exit 11, or 13 if every valid frame was dark.
- Starts `howdy-gtk --start-auth-ui` (:157) and feeds it status lines over stdin; works without it.
- After a match, if `rubberstamps.enabled`, runs `rubberstamps.execute` (:362-376).
- Exit codes from compare.py: 0, 1 (missing data/module), 10, 11, 12 (no username arg), 13, 14 (bad device), 15.

## CLI (`howdy/src/cli.py`, `cli/*.py`)

Installed as `howdy` (sh wrapper `bin/howdy.in`). Needs root; refuses user `root`. User resolved from `SUDO_USER` / `DOAS_USER` / `PKEXEC_UID` / `getuser`. Flags: `-U/--user`, `-y`, `--plain`.

`add`, `clear`, `config` (opens `$EDITOR`, else nano, else vi), `disable 0|1` (1 = disable), `list`, `remove [id]`, `set key value` (line rewrite in config.ini), `snapshot`, `test` (live preview; opencv recorder only), `version`.

## Video recorders (`howdy/src/recorders/`)

`VideoCapture(config)` picks a backend by `video.recording_plugin` and exposes a cv2-like `.internal` (`read/grab/release/set/get`). `read_frame()` returns `(frame, gray)`.

- `opencv` (default/fallback): `cv2.VideoCapture(path, CAP_V4L)`.
- `ffmpeg`: `ffmpeg_reader.py`, needs `ffmpeg-python` (exit 12 if missing); records N frames into a buffer, skips frame 0.
- `pyv4l2`: `pyv4l2_reader.py`, needs `pyv4l2` (exit 13 if missing). **Bug:** hardcoded 352x352 grayscale reshape (:94).
- `v4l2.py` is a generated ctypes binding (~1900 lines); don't edit.

## Rubberstamps (`howdy/src/rubberstamps/`)

Post-match plugins. Config: `[rubberstamps] stamp_rules`, one per line: `name timeout (failsafe|faildeadly) [key=value ...]` (default `nod 5s failsafe min_distance=12`). Any `.py` file in the directory (except `__init__`) is a stamp; class name must equal file name and subclass `RubberStamp`. Return False → process exits 15. Shipped: `nod` (head nod = pass, shake = fail, via landmark nose/eye geometry) and `hotkey` (needs `keyboard` pip module; abort=esc, confirm=enter). `set_ui_text` writes to the GTK process stdin.

## GTK app (`howdy-gtk/src/`)

- `init.py` dispatches: `--start-auth-ui` → `authsticky.py`, else `window.py`.
- `window.py` (`main.glade`): tabs Models / Video / About; calls `elevate.elevate()` (Python `elevate` package); shows `onboarding.py` wizard (7 slides) on first run or `--force-onboarding`.
- Talks to core by shelling out to `howdy` CLI (`add`, `remove`, `list --plain -U`, `set`), reading `config.ini` directly, and stdin for the auth UI.
- Polkit policy installed only with `-Dwith_polkit=true`.

## Storage and paths

Generated `paths.py` from `paths.py.in` via meson; read through `paths_factory.py`.

- Config: `<sysconfdir>/howdy/config.ini` (installed only if absent)
- User models: `<config_dir>/models/<user>.dat`
- dlib models: `<prefix>/share/dlib-data/` (fetched by `install.sh`)
- Snapshots: `/var/log/howdy/snapshots`
- i18n: gettext domain `core`; PAM module has its own `po/`

## config.ini sections

- `[core]`: detection_notice, timeout_notice, no_confirmation, suppress_unknown, abort_if_ssh (true), abort_if_lid_closed (true), disabled, use_cnn (false), workaround (off|input|native)
- `[video]`: certainty 3.5, timeout 4, device_path, warn_no_device, max_height 320, frame_width/height -1, dark_threshold 60, recording_plugin, device_format v4l2, force_mjpeg, exposure -1, device_fps -1, rotate 0
- `[snapshots]`: save_failed, save_successful
- `[rubberstamps]`: enabled false, stamp_rules
- `[debug]`: end_report, verbose_stamps, gtk_stdout

## Build and packaging

- Meson >= 0.64. `meson setup build && meson compile -C build && meson install -C build` (README:82-114).
- Options: `pam_dir`, `config_dir`, `dlib_data_dir`, `user_models_dir`, `log_path` (/var/log/howdy), `install_in_site_packages`, `py_sources_dir`, `install_pam_config`, `python_path` (/usr/bin/python), `with_polkit`.
- PAM deps: libpam, threads, libevdev, INIReader (falls back to `inih` r53 wrap).
- Install: core Python → `$libdir/howdy`; gtk → `$libdir/howdy-gtk`, assets → `share/howdy-gtk`; PAM config → `share/pam-configs/howdy` (if `install_pam_config`); bash completion; man page.
- **Debian** (legacy, non-meson): builds only `src/pam`; `postinst` downloads and builds dlib v19.16 and symlinks `/usr/local/bin/howdy` to `cli.py`. `howdy-gtk` control depends on `python-gtk2` (stale).
- **Arch** `PKGBUILD`: stale (pkgver 2.6.1, no meson, no gtk, depends on `pam-python`).

## Known issues / gotchas

- `main.cc:80`: `S("Unknown error: ") + status` is pointer arithmetic on `const char*`, producing garbage text.
- `main.cc:166`: lid-state parsing passes `file.eof()` as the delimiter (odd); the glob failure path reads a possibly stale `errno`.
- `main.hh:46-58`: `checkenv()` uses prefix `strncmp` (matches variables merely starting with the name) and is non-`inline` in a header.
- Exit code 15 is declared in `main.hh` but not handled in `howdy_error`.
- `pyv4l2_reader.py:94` hardcoded 352x352 grayscale.
- `rubberstamps/__init__.py`: a `key=value` option with no `=` raises an uncaught ValueError.
- `compare.py`: `dark_threshold` fallback is 60 but an earlier read at line 144 uses 50.
- `autocomplete/howdy.in:15` lists "clear" twice and omits "set".
- `meson.options` and `meson_options.txt` are duplicates.
- `input` workaround needs R/W on `/dev/uinput` and a focused password field; `native` uses unsafe `pthread_cancel`.
- Child process runs with an empty environment.
- No tests; CI only does a meson build and clang-tidy.
