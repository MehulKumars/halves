#!/usr/bin/env bash
# Builds the game's sounds (assets/audio/sfx/*.wav) from the CC0 Kenney packs listed in
# ASSETS_LICENSES.md, with ffmpeg: trim, level, mono WAV, layering. Music: build_music.sh.
# Usage: tools/audio/build_audio.sh <dir with the unzipped Kenney packs>
set -euo pipefail

KENNEY="${1:?Kenney packs dir (kenney_casino-audio/, kenney_impact-sounds/, ...)}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SFX_OUT="$ROOT/assets/audio/sfx"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$SFX_OUT"

src() { find "$KENNEY" -type f -name "$1" | head -1; }

# Trims leading silence, mono 44.1 kHz, then sets the peak to $3 dBFS.
level() {
	local in="$1" out="$2" peak="$3"
	ffmpeg -loglevel error -y -i "$in" -af "silenceremove=start_periods=1:start_threshold=-55dB,aformat=sample_rates=44100:channel_layouts=mono" "$TMP/trim.wav"
	local max
	max=$(ffmpeg -hide_banner -i "$TMP/trim.wav" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-\?[0-9.]*\) dB.*/\1/p')
	local gain
	gain=$(awk -v p="$peak" -v m="$max" 'BEGIN { printf "%.2f", p - m }')
	ffmpeg -loglevel error -y -i "$TMP/trim.wav" -af "volume=${gain}dB" -c:a pcm_s16le "$out"
}

# One sound: name, source file, peak dBFS.
one() { level "$(src "$2")" "$SFX_OUT/$1.wav" "$3"; echo "  sfx $1 <- $2"; }

# Two layers: the body, then a quieter sparkle `$4` dB under it, `$5` ms later.
two() {
	ffmpeg -loglevel error -y -i "$(src "$2")" -i "$(src "$3")" -filter_complex \
		"[1]adelay=$5|$5,volume=$4dB[b];[0][b]amix=inputs=2:duration=longest:normalize=0" "$TMP/mix.wav"
	level "$TMP/mix.wav" "$SFX_OUT/$1.wav" "$6"
	echo "  sfx $1 <- $2 + $3"
}

echo "== sounds"
one select    chip-lay-1.ogg            -6
one deselect  chip-lay-3.ogg            -12
one blocked   impactWood_light_002.ogg  -14
two snap      chips-collide-2.ogg glass_002.ogg -7 15 -4
two snap_big  chips-collide-4.ogg glass_005.ogg -4 10 -3
one mistake   impactSoft_medium_001.ogg -9
one shuffle   card-shuffle.ogg          -8
one hint      pluck_001.ogg             -8
one undo      card-slide-3.ogg          -9
one reveal    card-place-2.ogg          -9
two unlock    impactMetal_light_001.ogg glass_004.ogg -6 60 -6
one thaw      impactGlass_light_002.ogg -8
two gold      glass_006.ogg chips-stack-1.ogg -4 40 -6
one coin      chips-stack-3.ogg         -10
one star      glass_001.ogg             -5
one click     click_002.ogg             -12
one open      open_002.ogg              -12
one close     close_002.ogg             -12
one tick      tick_002.ogg              -10
one swift     maximize_004.ogg          -6
one best      jingles_PIZZI02.ogg       -5
one win_spring jingles_PIZZI01.ogg      -5
one win_summer jingles_PIZZI03.ogg      -5
one win_autumn jingles_PIZZI07.ogg      -5
one win_winter jingles_PIZZI12.ogg      -5
one win_moon   jingles_PIZZI14.ogg      -5
two chapter   impactBell_heavy_001.ogg jingles_PIZZI10.ogg 0 350 -4

