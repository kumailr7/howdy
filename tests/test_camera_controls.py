import configparser
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "howdy", "src"))
import camera_controls  # noqa: E402


def make_config(text):
	config = configparser.ConfigParser()
	config.read_string(text)
	return config


class ParseTest(unittest.TestCase):
	def test_valid_and_rejected(self):
		valid, rejected = camera_controls.parse("brightness=190, backlight_compensation = 2,bad,x=1.5,; rm -rf /")
		self.assertEqual(valid, ["brightness=190", "backlight_compensation=2"])
		self.assertEqual(rejected, ["bad", "x=1.5", ";rm-rf/"])

	def test_negative_and_empty(self):
		self.assertEqual(camera_controls.parse("exposure=-1")[0], ["exposure=-1"])
		self.assertEqual(camera_controls.parse("")[0], [])
		self.assertEqual(camera_controls.parse(None)[0], [])


class ControlsForTest(unittest.TestCase):
	CONFIG = """
[video]
v4l2_controls = gain=10
[camera_controls]
Azurewave = brightness=190
ugreen = brightness=120
"""

	def test_matches_device_by_name(self):
		config = make_config(self.CONFIG)
		valid, _ = camera_controls.controls_for(config, "/dev/v4l/by-id/usb-Azurewave_Integrated_Camera-video-index0")
		self.assertEqual(valid, ["gain=10", "brightness=190"])
		valid, _ = camera_controls.controls_for(config, "/dev/v4l/by-id/usb-UGREEN_cam-video-index0")
		self.assertEqual(valid, ["gain=10", "brightness=120"])

	def test_no_match(self):
		config = make_config("[video]\nv4l2_controls =\n[camera_controls]\nfoo = brightness=1\n")
		self.assertEqual(camera_controls.controls_for(config, "/dev/video0")[0], [])


class ApplyTest(unittest.TestCase):
	CONFIG = "[video]\nv4l2_controls = brightness=190,backlight_compensation=2\n"

	def test_runs_v4l2_ctl_without_a_shell(self):
		with mock.patch("shutil.which", return_value="/usr/bin/v4l2-ctl"), \
			mock.patch("subprocess.run", return_value=mock.Mock(returncode=0)) as run:
			applied = camera_controls.apply(make_config(self.CONFIG), "/dev/video0")
		self.assertEqual(applied, ["brightness=190", "backlight_compensation=2"])
		self.assertEqual(run.call_args[0][0], ["v4l2-ctl", "-d", "/dev/video0", "--set-ctrl=brightness=190,backlight_compensation=2"])
		self.assertNotIn("shell", run.call_args[1])

	def test_missing_tool_or_failure_is_harmless(self):
		with mock.patch("shutil.which", return_value=None):
			self.assertEqual(camera_controls.apply(make_config(self.CONFIG), "/dev/video0"), [])
		with mock.patch("shutil.which", return_value="/usr/bin/v4l2-ctl"), \
			mock.patch("subprocess.run", return_value=mock.Mock(returncode=1)):
			self.assertEqual(camera_controls.apply(make_config(self.CONFIG), "/dev/video0"), [])
		with mock.patch("shutil.which", return_value="/usr/bin/v4l2-ctl"), \
			mock.patch("subprocess.run", side_effect=OSError):
			self.assertEqual(camera_controls.apply(make_config(self.CONFIG), "/dev/video0"), [])

	def test_nothing_configured_runs_nothing(self):
		with mock.patch("subprocess.run") as run:
			self.assertEqual(camera_controls.apply(make_config("[video]\nv4l2_controls =\n"), "/dev/video0"), [])
		run.assert_not_called()


if __name__ == "__main__":
	unittest.main()
