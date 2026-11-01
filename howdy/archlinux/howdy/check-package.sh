#!/bin/sh
# Check that a built howdy-git package contains the files it must ship.
# Usage: check-package.sh [package.pkg.tar.zst]   (default: newest in this directory)
set -eu

dir=$(cd "$(dirname "$0")" && pwd)
pkg=${1:-$(ls -t "$dir"/howdy-git-*.pkg.tar.zst 2>/dev/null | head -1)}
[ -n "$pkg" ] && [ -f "$pkg" ] || { echo "no package found" >&2; exit 2; }

files=$(pacman -Qlp "$pkg" | awk '{print $2}')
status=0

for want in \
	/etc/howdy/config.ini \
	/usr/share/libalpm/hooks/howdy-config.hook \
	/usr/lib/security/pam_howdy.so \
	/usr/lib/howdy/compare.py \
	/usr/lib/howdy/scanlog.py \
	/usr/lib/howdy/scanstatus.py \
	/usr/lib/howdy/camera_controls.py \
	/usr/lib/howdy/cli/doctor.py \
	/usr/lib/howdy/cli/log.py \
	/usr/share/howdy/liveness/MiniFASNetV2.onnx \
	/usr/share/howdy/liveness/MiniFASNetV1SE.onnx \
	/usr/share/dlib-data/dlib_face_recognition_resnet_model_v1.dat
do
	if printf '%s\n' "$files" | grep -qx "$want"; then
		echo "ok       $want"
	else
		echo "MISSING  $want"
		status=1
	fi
done

# The config must stay a pacman backup file so upgrades never overwrite edits
if pacman -Qip "$pkg" >/dev/null 2>&1 && bsdtar -xOf "$pkg" .PKGINFO | grep -qx 'backup = etc/howdy/config.ini'; then
	echo "ok       backup=(etc/howdy/config.ini)"
else
	echo "MISSING  backup=(etc/howdy/config.ini)"
	status=1
fi

exit $status
