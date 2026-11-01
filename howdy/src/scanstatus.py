# Publish the state of the running face scan so desktop shells can show it
# (for example a Face ID style pill in a dynamic island).
#
# One small JSON file, rewritten in place at the start and end of every scan:
#   {"state": "scanning" | "success" | "failed", "user": ..., "service": ...,
#    "reason": ..., "time": <unix seconds>}
# It only holds the user name, PAM service and a result label, so it is world
# readable. Failures to write are ignored: a status file must never block login.

import json
import os
import time

STATUS_DIR = "/run/howdy"
STATUS_NAME = "status.json"


def write(state, user="", service="", reason="", directory=STATUS_DIR):
	try:
		os.makedirs(directory, mode=0o755, exist_ok=True)
		path = os.path.join(directory, STATUS_NAME)
		payload = json.dumps({
			"state": state,
			"user": user,
			"service": service,
			"reason": reason,
			"time": time.time(),
		})
		# In place, not renamed over: file watchers keep following the same inode
		with open(path, "w") as handle:
			handle.write(payload)
		os.chmod(path, 0o644)
		return True
	except Exception:
		return False
