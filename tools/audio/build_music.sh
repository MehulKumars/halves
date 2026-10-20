#!/usr/bin/env bash
# Bakes assets/audio/music/<id>.ogg from tools/audio/music.tsv and the sources fetch_music.sh
# downloaded: songs are levelled whole (a playlist plays them in turn); ambience is cut to a
# seamless loop (its tail crossfaded into its head). "Focus" tones are synthesised here, no source.
# Usage: tools/audio/build_music.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/tools/audio/src/music"
OUT="$ROOT/assets/audio/music"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
# Longest ambience loop in seconds, and the crossfade that hides its seam.
LOOP_MAX=120
SEAM=4

# Integrated loudness (LUFS) of a file.
lufs() { ffmpeg -nostdin -hide_banner -nostats -i "$1" -af ebur128 -f null - 2>&1 | sed -n 's/^ *I: *\(-\?[0-9.]*\) LUFS.*/\1/p' | tail -1; }

# Static gain to `target` LUFS with a soft limiter (no pumping, so loop seams stay seamless).
level() {
	local in="$1" out="$2" target="$3" quality="$4"
	local now gain
	now=$(lufs "$in")
	gain=$(awk -v t="$target" -v n="$now" 'BEGIN { printf "%.2f", t - n }')
	ffmpeg -nostdin -loglevel error -y -i "$in" -map 0:a -af "volume=${gain}dB,alimiter=limit=0.9:level=disabled" \
		-ar 44100 -ac 2 -c:a libvorbis -q:a "$quality" "$out"
	echo "  $(basename "$out") (${now} LUFS -> ${target}, $(du -k "$out" | cut -f1) KB)"
}

# A seamless loop: the first `len` s, with the next SEAM s faded over the start.
seamless() {
	local in="$1" out="$2" len="$3"
	ffmpeg -nostdin -loglevel error -y -i "$in" -filter_complex \
		"[0:a]aformat=sample_rates=44100:channel_layouts=stereo,atrim=0:$(($len + $SEAM)),asplit=3[h][b][t];
		[h]atrim=0:$SEAM,asetpts=PTS-STARTPTS,afade=t=in:d=$SEAM:curve=qsin[hf];
		[t]atrim=$len:$(($len + $SEAM)),asetpts=PTS-STARTPTS,afade=t=out:d=$SEAM:curve=qsin[tf];
		[hf][tf]amix=inputs=2:normalize=0[x];
		[b]atrim=$SEAM:$len,asetpts=PTS-STARTPTS[body];
		[x][body]concat=n=2:v=0:a=1" -c:a pcm_s16le "$out"
}

echo "== songs and ambience"
grep -v '^#' "$ROOT/tools/audio/music.tsv" | while IFS=$'\t' read -r style id mode file title artist licence page url; do
	[ -z "$id" ] && continue
	in="$SRC/$file"
	[ -s "$in" ] || { echo "missing $in (run tools/audio/fetch_music.sh)"; exit 1; }
	if [ "$mode" = "loop" ]; then
		length=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
		len=$(awk -v l="$length" -v m="$LOOP_MAX" -v s="$SEAM" 'BEGIN { x = int(l - s - 1); print (x < m ? x : m) }')
		seamless "$in" "$TMP/loop.wav" "$len"
		level "$TMP/loop.wav" "$OUT/$id.ogg" -24 1
	else
		ffmpeg -nostdin -loglevel error -y -i "$in" -map 0:a -af "afade=t=in:d=1.5" -c:a pcm_s16le "$TMP/song.wav"
		level "$TMP/song.wav" "$OUT/$id.ogg" -18 3
	fi
done

echo "== focus tones (synthesised)"
# 120 s, exactly periodic: a 6 Hz binaural beat (200 Hz left, 206 Hz right), a soft A-major pad in
# just intonation (110, 165, 220, 275 Hz) breathing every 20 s, over low brown noise.
ffmpeg -nostdin -loglevel error -y -f lavfi -i "anoisesrc=color=brown:amplitude=0.5:duration=130:seed=7" \
	-af "lowpass=f=420,highpass=f=40" -ac 2 -c:a pcm_s16le "$TMP/noise_raw.wav"
seamless "$TMP/noise_raw.wav" "$TMP/noise.wav" 120
ffmpeg -nostdin -loglevel error -y -f lavfi -i \
	"aevalsrc=0.05*sin(2*PI*200*t)+0.022*(sin(2*PI*110*t)+0.7*sin(2*PI*165*t)+0.5*sin(2*PI*220*t)+0.35*sin(2*PI*275*t))*(0.7+0.3*sin(2*PI*t/20))|0.05*sin(2*PI*206*t)+0.022*(sin(2*PI*110*t)+0.7*sin(2*PI*165*t)+0.5*sin(2*PI*220*t)+0.35*sin(2*PI*275*t))*(0.7+0.3*sin(2*PI*t/20)):s=44100:d=120" \
	-i "$TMP/noise.wav" -filter_complex "[0][1]amix=inputs=2:normalize=0:weights=1 0.35" -c:a pcm_s16le "$TMP/focus.wav"
level "$TMP/focus.wav" "$OUT/focus_tones.ogg" -24 2
