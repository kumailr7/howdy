# Show the most recent scan results recorded by the PAM module

# Import required modules
import builtins
import json
import os
import sys
import paths
import scanlog

from i18n import _

path = os.path.join(str(paths.log_path), "scans.log")

# How many entries to show, from the optional argument
count = 20
if builtins.howdy_args.arguments:
	try:
		count = max(1, int(builtins.howdy_args.arguments[0]))
	except ValueError:
		print(_("The number of entries must be a number"))
		sys.exit(1)

entries = scanlog.read(paths.log_path)
if not entries and not os.path.exists(path):
	print(_("No scans recorded yet ({})").format(path))
	sys.exit(0)

entries = entries[-count:]

if builtins.howdy_args.plain:
	for entry in entries:
		print(json.dumps(entry))
	sys.exit(0)

print(_("Time                       User       Service    Secs  Frames  Certainty  Result"))
for entry in entries:
	ok = entry.get("code") == 0
	colour = "\033[32m" if ok else "\033[31m"
	certainty = entry.get("best_certainty")
	print("{time:<26} {user:<10} {service:<10} {seconds:>4}  {frames:>6}  {cert:>9}  {colour}{result}\033[0m".format(
		time=str(entry.get("time", ""))[:25],
		user=str(entry.get("user", ""))[:10],
		service=str(entry.get("service", ""))[:10],
		seconds=entry.get("seconds", ""),
		frames=entry.get("frames", ""),
		cert="-" if certainty is None else certainty,
		colour=colour,
		result=str(entry.get("result", entry.get("code"))) + (" [stranger]" if entry.get("stranger") else "")))
