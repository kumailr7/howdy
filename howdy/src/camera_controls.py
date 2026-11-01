# Apply V4L2 camera controls (brightness, exposure, ...) from the config file

import re
import shutil
import subprocess

# A control is "name=value": a lowercase V4L2 control name and an integer
CONTROL = re.compile(r"^[a-z][a-z0-9_]*=-?[0-9]+$")


def parse(text):
	"""Split a comma separated control string, return (valid controls, rejected parts)"""
	valid, rejected = [], []
	for part in (text or "").split(","):
		part = part.strip().replace(" ", "")
		if not part:
			continue
		(valid if CONTROL.match(part) else rejected).append(part)
	return valid, rejected


def controls_for(config, device_path):
	"""Collect the controls for a camera: [video] v4l2_controls, then every
	[camera_controls] entry whose key is part of the device path (later wins)"""
	valid, rejected = parse(config.get("video", "v4l2_controls", fallback=""))
	if config.has_section("camera_controls"):
		for key, value in config.items("camera_controls"):
			if key and key.lower() in str(device_path).lower():
				more, bad = parse(value)
				valid += more
				rejected += bad
	return valid, rejected


def apply(config, device_path):
	"""Set the configured controls with v4l2-ctl, returns the controls applied.
	Never raises: a camera that rejects a control must not stop face login."""
	valid, _rejected = controls_for(config, device_path)
	if not valid or shutil.which("v4l2-ctl") is None:
		return []
	try:
		result = subprocess.run(
			["v4l2-ctl", "-d", str(device_path), "--set-ctrl=" + ",".join(valid)],
			stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
	except (OSError, subprocess.SubprocessError):
		return []
	return valid if result.returncode == 0 else []
