#!/bin/bash
# Package Linux and Windows builds and, when given a tag, publish them.
# Usage: Tools/release.sh
#        Tools/release.sh v0.1.0
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/Tools/package.sh"
linux_zip="$root/Builds/OpenCircuitBreakers-linux-x86_64.zip"
windows_zip="$root/Builds/OpenCircuitBreakers-windows-x86_64.zip"
rm -f "$linux_zip" "$windows_zip"
(
	cd "$root/Builds/Linux"
	zip -r "$linux_zip" .
)
(
	cd "$root/Builds/Windows"
	zip -r "$windows_zip" .
)
if [[ $# -eq 0 ]]; then
	echo "wrote $linux_zip"
	echo "wrote $windows_zip"
	exit 0
fi
tag="$1"
gh release create "$tag" "$linux_zip" "$windows_zip" \
	--title "$tag" \
	--generate-notes \
	--notes "$(cat <<EOF
Linux and Windows builds of OpenCircuitBreakers.

The download does not include any Circuit Breakers data. On first launch, point the setup screen at your own copy of the game (select the .cue file so the music is extracted too). An optional demo add-on disc adds Castle and Rooftop.

OpenCircuitBreakers is MIT licensed. The included Kenney Racing Kit, City Kit and Game Icons are CC0.
EOF
)"
echo "published $tag"
