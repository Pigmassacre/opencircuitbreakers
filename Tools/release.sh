#!/bin/bash
# Package Linux and Windows builds and, when asked, publish them.
# Usage: Tools/release.sh
#        Tools/release.sh publish
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -gt 1 ]] || [[ $# -eq 1 && "$1" != publish ]]; then
	echo "usage: Tools/release.sh [publish]" >&2
	exit 1
fi
version="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$root/Project/project.godot")"
for key in file_version product_version; do
	preset_version="$(sed -n "s/^application\/$key=\"\(.*\)\"$/\1/p" "$root/Project/export_presets.cfg")"
	if [[ "$preset_version" != "$version.0" ]]; then
		echo "export_presets.cfg $key $preset_version does not match project.godot version $version" >&2
		exit 1
	fi
done
tag="v$version"
if [[ $# -eq 1 ]]; then
	changes="$(awk -v heading="## $version " '
		index($0, heading) == 1 { found = 1; next }
		found && /^## / { exit }
		found { print }
	' "$root/CHANGELOG.md")"
	if [[ -z "${changes//[[:space:]]/}" ]]; then
		echo "CHANGELOG.md has no entry for $version" >&2
		exit 1
	fi
fi
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
gh release create "$tag" "$linux_zip" "$windows_zip" \
	--title "$tag" \
	--verify-tag \
	--notes "$(cat <<EOF
$changes

Linux and Windows builds of OpenCircuitBreakers.

The download does not include any Circuit Breakers data. On first launch, point the setup screen at your own copy of the game (select the .cue file so the music is extracted too). An optional demo add-on disc adds Castle and Rooftop.

OpenCircuitBreakers is MIT licensed. The included Kenney Racing Kit, City Kit and Game Icons are CC0.
EOF
)"
echo "published $tag"
