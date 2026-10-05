#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
source="$root/Inspo/Circuit Breakers (USA)/Circuit Breakers (USA).cue"
addon="$root/Inspo/Circuit Breakers (Europe) (EnFrDeEsIt) (Demo-Add-On Disc)/Circuit Breakers (Europe) (En,Fr,De,Es,It) (Demo-Add-On Disc).cue"
out=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--addon)
			addon="${2:?--addon needs a path}"
			shift 2
			;;
		--out)
			out="${2:?--out needs a path}"
			shift 2
			;;
		*)
			source="$1"
			shift
			;;
	esac
done
args=("$source")
if [[ -n "$addon" ]]; then
	args+=(--addon "$addon")
fi
if [[ -n "$out" ]]; then
	args+=(--out "$out")
fi
exec "$root/Godot/Godot_v4.7.2-stable_linux.x86_64" --headless --path "$root/Project" -s res://scripts/export_cli.gd -- "${args[@]}"
