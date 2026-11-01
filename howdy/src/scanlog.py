# Reading and writing of the scan log (one JSON object per line)

import json
import os
from datetime import datetime, timezone

LOG_NAME = "scans.log"
# Past this size only the newest KEEP_LINES lines survive
MAX_BYTES = 256 * 1024
KEEP_LINES = 200


def log_file(directory):
	return os.path.join(str(directory), LOG_NAME)


def append(directory, entry):
	"""Append one entry, creating the directory and file root-only and trimming an oversized log"""
	os.makedirs(str(directory), mode=0o700, exist_ok=True)
	path = log_file(directory)

	if os.path.exists(path) and os.path.getsize(path) > MAX_BYTES:
		with open(path) as handle:
			tail = handle.readlines()[-KEEP_LINES:]
		with open(path, "w") as handle:
			handle.writelines(tail)

	fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
	with os.fdopen(fd, "a") as handle:
		handle.write(json.dumps(entry) + "\n")


def read(directory, count=None):
	"""Return the parsed entries (newest last), skipping unreadable lines"""
	try:
		with open(log_file(directory)) as handle:
			lines = handle.readlines()
	except FileNotFoundError:
		return []

	entries = []
	for line in lines:
		try:
			entries.append(json.loads(line))
		except ValueError:
			continue
	return entries[-count:] if count else entries


def count_strangers(directory, window, now=None):
	"""Count logged unknown-face attempts that happened within the last `window` seconds"""
	now = now or datetime.now(timezone.utc)
	total = 0
	for entry in read(directory, KEEP_LINES):
		if not entry.get("stranger"):
			continue
		try:
			when = datetime.fromisoformat(entry.get("time", ""))
		except ValueError:
			continue
		if (now - when).total_seconds() <= window:
			total += 1
	return total
