#!/usr/bin/env bash
# Downloads the music and ambience listed in tools/audio/music.tsv (CC0 / CC BY / CC BY-SA, see
# ASSETS_LICENSES.md) into tools/audio/src/music/, which git ignores. Run before build_music.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIR="$ROOT/tools/audio/src/music"
mkdir -p "$DIR"
touch "$ROOT/tools/audio/src/.gdignore"
grep -v '^#' "$ROOT/tools/audio/music.tsv" | while IFS=$'\t' read -r style id mode file title artist licence page url; do
	[ -z "$id" ] && continue
	if [ -s "$DIR/$file" ]; then echo "  have $file"; continue; fi
	curl -sSfL -A "HalvesGame/1.0 (https://github.com/MehulKumars/halves)" -o "$DIR/$file" "$url"
	echo "  got $file: $title ($artist, $licence)"
	sleep 1
done
