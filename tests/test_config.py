import configparser
import os
import unittest

CONFIG = os.path.join(os.path.dirname(__file__), "..", "howdy", "src", "config.ini")


class ConfigTest(unittest.TestCase):
	def setUp(self):
		self.config = configparser.ConfigParser()
		self.config.read(CONFIG)

	def test_sections_exist(self):
		for section in ("core", "video", "snapshots", "service_certainty", "camera_controls", "intruder", "liveness", "debug"):
			self.assertTrue(self.config.has_section(section), section)

	def test_risky_features_default_off(self):
		self.assertFalse(self.config.getboolean("intruder", "enabled"))
		self.assertFalse(self.config.getboolean("liveness", "enabled"))
		self.assertEqual(self.config.getfloat("video", "dark_giveup"), 0)

	def test_camera_controls_default_empty(self):
		self.assertEqual(self.config.get("video", "v4l2_controls"), "")
		self.assertEqual(self.config.items("camera_controls"), [])

	def test_scan_log_default_on(self):
		self.assertTrue(self.config.getboolean("core", "scan_log"))

	def test_service_certainty_has_no_active_overrides(self):
		self.assertEqual(self.config.items("service_certainty"), [])

	def test_intruder_numbers_parse(self):
		self.assertGreater(self.config.getint("intruder", "alert_after"), 0)
		self.assertGreater(self.config.getint("intruder", "window"), 0)


if __name__ == "__main__":
	unittest.main()
