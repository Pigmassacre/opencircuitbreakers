#!/bin/bash
# Package release builds into Builds/. Without an argument, packages both platforms.
# Usage: Tools/package.sh
#        Tools/package.sh linux
#        Tools/package.sh windows
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -eq 0 ]]; then
	set -- linux windows
fi
for platform in "$@"; do
	python3 "$root/Tools/package.py" "$platform"
done
