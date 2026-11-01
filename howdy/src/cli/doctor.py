# Check that the howdy installation is complete and usable

# Import required modules
import builtins
import configparser
import glob
import importlib.util
import os
import sys
import paths_factory

from i18n import _

user = builtins.howdy_user

problems = 0


def report(ok, text, hint=""):
	"""Print one check result, counting failures"""
	global problems
	print(("\033[32m[ ok ]\033[0m " if ok else "\033[31m[FAIL]\033[0m ") + text)
	if not ok:
		problems += 1
		if hint:
			print("       " + hint)


# The config file, nothing else works without it
config_path = paths_factory.config_file_path()
config = configparser.ConfigParser()
config_ok = os.path.isfile(config_path)
report(config_ok, _("Config file {}").format(config_path),
	_("Missing. Restore it from {}.pacsave if one exists").format(config_path))

if config_ok:
	try:
		config.read(config_path)
	except configparser.Error as err:
		config_ok = False
		report(False, _("Config file is readable"), str(err))

# The camera, first existing entry of a comma-separated device_path
if config_ok:
	device_path = config.get("video", "device_path", fallback="")
	candidates = [p.strip() for p in device_path.split(",") if p.strip()]
	found = [p for p in candidates if os.path.exists(p)]
	report(bool(found), _("Camera {}").format(found[0] if found else device_path or "(unset)"),
		_("None of the configured device_path entries exist, check video.device_path"))

# The enrolled face model of this user
model_path = paths_factory.user_model_path(user)
report(os.path.isfile(model_path), _("Face model for {}").format(user),
	_("None enrolled, run: sudo howdy -U {} add").format(user))

# The dlib data files
for path in (
	paths_factory.shape_predictor_5_face_landmarks_path(),
	paths_factory.mmod_human_face_detector_path(),
	paths_factory.dlib_face_recognition_resnet_model_v1_path(),
):
	report(os.path.isfile(path), _("Data file {}").format(path),
		_("Missing, see the Readme in {}").format(paths_factory.dlib_data_dir_path()))

# Optional liveness check
if config_ok and config.getboolean("liveness", "enabled", fallback=False):
	has_ort = importlib.util.find_spec("onnxruntime") is not None
	report(has_ort, _("Liveness: onnxruntime installed"),
		_("Liveness is enabled, so face login is refused without it: pacman -S python-onnxruntime"))
	for name in ("MiniFASNetV2.onnx", "MiniFASNetV1SE.onnx"):
		path = paths_factory.liveness_model_path(name)
		report(os.path.isfile(path), _("Liveness model {}").format(path),
			_("Liveness is enabled, so face login is refused without it"))

# PAM module and services that use it
module = None
for directory in ("/usr/lib/security", "/lib/security", "/usr/lib64/security", "/lib/x86_64-linux-gnu/security"):
	if os.path.isfile(os.path.join(directory, "pam_howdy.so")):
		module = directory
		break
report(module is not None, _("PAM module pam_howdy.so"), _("Not found in the usual PAM directories"))

services = []
for path in sorted(glob.glob("/etc/pam.d/*")):
	try:
		with open(path) as handle:
			if any("pam_howdy" in line and not line.lstrip().startswith("#") for line in handle):
				services.append(os.path.basename(path))
	except OSError:
		pass
report(bool(services), _("PAM services using howdy: {}").format(", ".join(services) or "-"),
	_("No /etc/pam.d file loads pam_howdy.so, so nothing will ask for your face"))

# Lock screens (quickshell shells, etc.) with their own PAM config live in the user's home
import pwd
try:
	home = pwd.getpwnam(user).pw_dir
except KeyError:
	home = ""
extra = []
for path in sorted(glob.glob(os.path.join(home, ".config", "quickshell", "*", "pam", "*"))) if home else []:
	try:
		with open(path) as handle:
			if any("pam_howdy" in line and not line.lstrip().startswith("#") for line in handle):
				extra.append(path)
	except OSError:
		pass
if extra:
	report(True, _("Lock screen PAM configs using howdy: {}").format(", ".join(extra)))
else:
	print(_("[ -- ] No quickshell lock screen PAM config uses howdy (ignore if you use another locker)"))

# Summary of recent scans from the scan log
try:
	import json
	import paths
	with open(os.path.join(str(paths.log_path), "scans.log")) as handle:
		recent = [json.loads(line) for line in handle.readlines()[-20:] if line.strip()]
	if recent:
		failed = [e for e in recent if e.get("code") != 0]
		reasons = {}
		for entry in failed:
			reasons[entry.get("result", "?")] = reasons.get(entry.get("result", "?"), 0) + 1
		text = _("Last {} scans: {} failed").format(len(recent), len(failed))
		if reasons:
			text += " (" + ", ".join("{} x {}".format(n, r) for r, n in sorted(reasons.items(), key=lambda i: -i[1])) + ")"
		print(text + _(", see: sudo howdy log"))
except (OSError, ValueError):
	pass

print()
if problems:
	print(_("{} problem(s) found").format(problems))
	sys.exit(1)
print(_("All checks passed"))
