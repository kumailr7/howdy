import json
import os
import sys
import tempfile
import time
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "howdy", "src"))
import scanstatus  # noqa: E402


class ScanStatusTest(unittest.TestCase):
	def setUp(self):
		self.tmp = tempfile.TemporaryDirectory()
		self.dir = os.path.join(self.tmp.name, "run")
		self.path = os.path.join(self.dir, scanstatus.STATUS_NAME)

	def tearDown(self):
		self.tmp.cleanup()

	def read(self):
		with open(self.path) as handle:
			return json.load(handle)

	def test_write_creates_readable_file(self):
		self.assertTrue(scanstatus.write("scanning", "kumail", "sudo", directory=self.dir))
		data = self.read()
		self.assertEqual((data["state"], data["user"], data["service"], data["reason"]), ("scanning", "kumail", "sudo", ""))
		self.assertLess(abs(data["time"] - time.time()), 5)
		self.assertEqual(os.stat(self.path).st_mode & 0o777, 0o644)

	def test_rewrites_in_place(self):
		scanstatus.write("scanning", "kumail", "sudo", directory=self.dir)
		inode = os.stat(self.path).st_ino
		scanstatus.write("failed", "kumail", "sudo", "no match before timeout", directory=self.dir)
		self.assertEqual(os.stat(self.path).st_ino, inode)
		self.assertEqual(self.read()["reason"], "no match before timeout")

	def test_unwritable_location_is_harmless(self):
		blocker = os.path.join(self.tmp.name, "file")
		open(blocker, "w").close()
		self.assertFalse(scanstatus.write("success", directory=os.path.join(blocker, "sub")))


if __name__ == "__main__":
	unittest.main()
