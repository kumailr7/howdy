import os
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "howdy", "src"))
import scanlog  # noqa: E402


def stamp(seconds_ago):
	return (datetime.now(timezone.utc) - timedelta(seconds=seconds_ago)).isoformat(timespec="seconds")


class ScanLogTest(unittest.TestCase):
	def setUp(self):
		self.tmp = tempfile.TemporaryDirectory()
		self.dir = os.path.join(self.tmp.name, "log")

	def tearDown(self):
		self.tmp.cleanup()

	def test_append_creates_private_files(self):
		scanlog.append(self.dir, {"code": 0})
		self.assertEqual(os.stat(self.dir).st_mode & 0o777, 0o700)
		self.assertEqual(os.stat(scanlog.log_file(self.dir)).st_mode & 0o777, 0o600)

	def test_read_roundtrip_and_limit(self):
		for i in range(5):
			scanlog.append(self.dir, {"code": i})
		self.assertEqual([e["code"] for e in scanlog.read(self.dir)], [0, 1, 2, 3, 4])
		self.assertEqual([e["code"] for e in scanlog.read(self.dir, 2)], [3, 4])

	def test_read_missing_log(self):
		self.assertEqual(scanlog.read(self.dir), [])

	def test_read_skips_corrupt_lines(self):
		scanlog.append(self.dir, {"code": 1})
		with open(scanlog.log_file(self.dir), "a") as handle:
			handle.write("not json\n")
		scanlog.append(self.dir, {"code": 2})
		self.assertEqual([e["code"] for e in scanlog.read(self.dir)], [1, 2])

	def test_oversized_log_is_trimmed(self):
		scanlog.append(self.dir, {"code": 0})
		with open(scanlog.log_file(self.dir), "a") as handle:
			handle.write(('{"code": 9, "pad": "' + "x" * 900 + '"}\n') * 400)
		self.assertGreater(os.path.getsize(scanlog.log_file(self.dir)), scanlog.MAX_BYTES)
		scanlog.append(self.dir, {"code": 5})
		entries = scanlog.read(self.dir)
		self.assertLessEqual(len(entries), scanlog.KEEP_LINES + 1)
		self.assertEqual(entries[-1]["code"], 5)

	def test_count_strangers_respects_window(self):
		scanlog.append(self.dir, {"time": stamp(10), "stranger": True})
		scanlog.append(self.dir, {"time": stamp(100), "stranger": True})
		scanlog.append(self.dir, {"time": stamp(5000), "stranger": True})
		scanlog.append(self.dir, {"time": stamp(10)})
		self.assertEqual(scanlog.count_strangers(self.dir, 300), 2)
		self.assertEqual(scanlog.count_strangers(self.dir, 50), 1)

	def test_count_strangers_ignores_bad_times(self):
		scanlog.append(self.dir, {"time": "garbage", "stranger": True})
		self.assertEqual(scanlog.count_strangers(self.dir, 300), 0)


if __name__ == "__main__":
	unittest.main()
