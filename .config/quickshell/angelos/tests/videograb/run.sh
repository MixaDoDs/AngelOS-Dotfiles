#!/usr/bin/env bash
# Video for Discord and from a link, offline: scripts/videograb.py (its self-test), real squeezes
# of made-up videos (ffmpeg's lavfi: under the limit, the cut exact to a frame, +faststart), then
# offscreen services/VideoGrab with stand-ins for yt-dlp, notify-send and wl-copy — the Halo's
# capsule, the shelf, a yt-dlp failure reaching the notification, a squeeze held through a game.
# No site is asked anything.
#
#   tests/videograb/run.sh [angelOS dir]      exit 0 = all good, 77 = no quickshell/ffmpeg
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/shell.qml" ]] || { echo "no angelOS in $DIR"; exit 2; }
command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null || { echo "no ffmpeg"; exit 77; }
VG="$DIR/scripts/videograb.py"
fail=0
ok() { printf '  ✓ %s\n' "$1"; }
bad() { printf '  ✕ %s\n' "$1"; fail=1; }

if out=$(python3 "$VG" --self-test 2>&1); then ok "videograb.py: the bitrate plan, yt-dlp's progress over two parts, free names"
else bad "videograb.py self-test: $(tail -3 <<<"$out" | tr '\n' ' ')"; fi

T="$(mktemp -d /tmp/aos-videograb.XXXXXX)"
trap 'pkill -P $$ 2>/dev/null; rm -rf "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/angelos" "$H/Downloads" "$H/Videos" "$T/rt" "$T/root" "$T/bin" && chmod 700 "$T/rt"

# ---- the squeeze itself ----
# each frame's brightness is twice its number: the cut's first frame tells where it starts
ffmpeg -v error -y -f lavfi -i "nullsrc=s=320x240:r=30:d=6,geq=lum='2*N':cb=128:cr=128" -f lavfi -i "sine=f=440:d=6" \
  -c:v libx264 -crf 10 -c:a aac -shortest "$H/Videos/clip.mp4"
last() { tail -1 | python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("path",""))' 2>/dev/null; }
frames() { ffprobe -v error -count_frames -select_streams v -show_entries stream=nb_read_frames -of csv=p=0 "$1"; }
first() { ffprobe -v error -f lavfi -i "movie='${1//\'/\\\'}',signalstats" -show_entries frame_tags=lavfi.signalstats.YAVG -read_intervals %+#1 -of csv=p=0 | head -1 | tr -d ','; }
faststart() { python3 - "$1" <<'PY'
import struct, sys
f = open(sys.argv[1], "rb"); order = []
while True:
    h = f.read(8)
    if len(h) < 8: break
    size, kind = struct.unpack(">I4s", h)
    if size == 1: size = struct.unpack(">Q", f.read(8))[0]; f.seek(size - 16, 1)
    else: f.seek(size - 8, 1)
    order.append(kind.decode())
sys.exit(0 if "moov" in order and "mdat" in order and order.index("moov") < order.index("mdat") else 1)
PY
}
for enc in auto 0; do
  name=$([[ $enc == 0 ]] && echo libx264 || echo "auto (NVENC if it opens)")
  p=$(VIDEOGRAB_NVENC=$enc python3 "$VG" shrink "$H/Videos/clip.mp4" --start 1.5 --end 4.5 --mb 20 | last)
  if [[ ! -f "$p" ]]; then bad "$name: no file"; continue; fi
  n=$(frames "$p") y=$(first "$p") size=$(stat -c %s "$p")
  a=$(ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "$p")
  v=$(ffprobe -v error -select_streams v -show_entries stream=codec_name -of csv=p=0 "$p")
  idx=$(python3 -c "print(round(float('${y:-0}') / 2))")
  if [[ "$p" == *"clip (Discord"*").mp4" ]] && (( size <= 20000000 )) && (( n >= 89 && n <= 91 )) && (( idx >= 44 && idx <= 46 )) && [[ $a == aac && $v == h264 ]] && faststart "$p"; then
    ok "$name: 1.5–4.5 s → $n frames from frame $idx, h264+aac, +faststart, $((size / 1024)) KB"
  else bad "$name: $p — $n frames (90), first frame $idx (45), $v+$a, $size bytes, faststart $(faststart "$p" && echo yes || echo no)"; fi
  rm -f "$p"
done
# a heavy one under a small limit: the size holds, the length stays, it gets smaller
ffmpeg -v error -y -f lavfi -i "testsrc2=s=1280x720:r=30:d=8,noise=alls=40:allf=t" -f lavfi -i "sine=d=8" \
  -c:v libx264 -preset ultrafast -crf 20 -c:a aac -shortest "$T/heavy.mp4"
p=$(python3 "$VG" shrink "$T/heavy.mp4" --mb 0.6 | last)
if [[ -f "$p" ]]; then
  size=$(stat -c %s "$p") dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$p") h=$(ffprobe -v error -select_streams v -show_entries stream=height -of csv=p=0 "$p")
  if (( size <= 600000 )) && python3 -c "import sys; sys.exit(abs($dur - 8) > 0.1)" && (( h < 720 )); then ok "heavy 8 s under 0.6 MB: $((size / 1024)) KB, ${dur} s, ${h}p"
  else bad "heavy under 0.6 MB: $size bytes, $dur s, ${h}p"; fi
else bad "heavy under 0.6 MB: no file"; fi
out=$(python3 "$VG" shrink "$T/heavy.mp4" --mb 0.01 | tail -1)
[[ "$out" == *'"error"'* ]] && ok "too long for the limit: said so, nothing made" || bad "too long for the limit: $out"

# the estimate before squeezing, the sound alone, the copy for editing (extras/mediafix)
est=$(python3 "$VG" estimate "$H/Videos/clip.mp4" --start 1 --end 4 --mb 20)
too=$(python3 "$VG" estimate "$T/heavy.mp4" --mb 0.05)
if [[ "$est" == *'"fits": true'*'"height": 240'* && "$too" == *'"fits": false'*'"max": '* ]]; then ok "estimate: the size and height before it runs, the longest cut when it can't fit"
else bad "estimate: $est / $too"; fi
p=$(python3 "$VG" wav "$H/Videos/clip.mp4" --start 1 --end 3 | last)
w=$([[ -f "$p" ]] && ffprobe -v error -show_entries stream=codec_name,sample_rate:format=duration -of csv=p=0 "$p" | tr '\n' ' ')
[[ "$p" == */clip.wav && "$w" == "pcm_s24le,48000 2.0"* ]] && ok "WAV: the cut's sound, PCM 24 bit / 48 kHz" || bad "WAV: $p — $w"
rm -f "$p"
p=$(HOME="$H" python3 "$VG" edit "$H/Videos/clip.mp4" --start 1.5 --end 4.5 | last)
e=$([[ -f "$p" ]] && ffprobe -v error -show_entries stream=codec_name,sample_rate -of csv=p=0 "$p" | tr '\n' ' ')
d=$([[ -f "$p" ]] && ffprobe -v error -show_entries format=duration -of csv=p=0 "$p")
if [[ "$p" == "$H/Videos/MediaFix/clip_DR.mov" && "$e" == "h264 pcm_s24le,48000 " ]] && python3 -c "import sys; sys.exit(not 3 <= float('${d:-0}') < 4.6)"; then ok "for editing: mediafix's copy, the video as it is, PCM sound, the cut from a key frame (${d} s)"
else bad "for editing: $p — $e, $d s"; fi
rm -rf "$H/Videos/MediaFix"

# every format of the conversion ring (services/Convert), into «Сконвертировано» beside
mkdir -p "$T/cv" && cd "$T/cv" || exit 1
magick -size 64x48 xc:red -fill blue -draw "rectangle 10,10 40,30" -alpha set a.png 2>/dev/null
cp "$H/Videos/clip.mp4" v.mp4 && ffmpeg -v error -f lavfi -i sine=d=2 s.wav
# sources of another format for the ones a.png / v.mp4 / s.wav already are
magick a.png b.webp && ffmpeg -v error -i v.mp4 -c copy v.mov
cv=() cvbad=()
for f in png jpg webp avif gif ico mp4 webm mkv gifv mp3 wav flac ogg m4a; do
  case $f in png) in=b.webp ;; jpg|webp|avif|gif|ico) in=a.png ;; mp3|wav|flac|ogg|m4a) in="v.mp4 s.wav" ;; mp4) in=v.mov ;; *) in=v.mp4 ;; esac
  # shellcheck disable=SC2086
  out=$(ANGELOS_LANG=ru VIDEOGRAB_NVENC=0 python3 "$VG" convert $f $in 2>&1)
  ext=$([[ $f == gifv ]] && echo gif || echo $f)
  first=${in%% *}
  if [[ "$out" == *'"done"'* && "$out" != *'"error"'* && -s "Сконвертировано/${first%.*}.$ext" ]]; then cv+=("$f"); else cvbad+=("$f: $(tail -1 <<<"$out" | cut -c1-120)"); fi
done
[[ ${#cvbad[@]} -eq 0 ]] && ok "convert: ${cv[*]} (pictures, video, video and sound into sound)" || bad "convert: ${cvbad[*]}"
sz=$(python3 "$VG" sizes video v.mp4) szi=$(python3 "$VG" sizes image a.png)
[[ "$sz" == *'"same": ["mp4"]'* && "$sz" == *'"webm": '* && "$szi" == *'"same": ["png"]'* && "$szi" == *'"avif": '* ]] && ok "sizes: an estimate per format, the one they already are named" || bad "sizes: $sz / $szi"
out=$(python3 "$VG" convert mp4 v.mp4 | tail -1)
[[ "$out" == *'"error"'* ]] && ok "convert: an MP4 into MP4 is refused (nothing to do)" || bad "convert mp4 v.mp4: $out"
out=$(python3 "$VG" convert mp3 a.png | tail -1)
[[ "$out" == *'"error"'* ]] && ok "convert: a picture into a sound format is refused" || bad "convert mp3 a.png: $out"
[[ -f a.png && -f b.webp && -f v.mp4 && -f v.mov && -f s.wav ]] && ok "convert: the originals are where they were" || bad "convert touched the originals"
cd - >/dev/null || exit 1
mkdir -p "$H/Pictures" "$H/Music" && cp "$T/cv/a.png" "$H/Pictures/p.png" && cp "$T/cv/s.wav" "$H/Music/s.wav" && echo hi >"$H/Music/notes.txt"

# ---- the service, with stand-ins ----
cat >"$T/bin/yt-dlp" <<'PY'
#!/usr/bin/env python3
# a stand-in yt-dlp: the progress lines the real one prints for videograb.py's template
import os, sys, time
args = sys.argv[1:]
open(os.environ["VG_LOG"] + "/ytdlp.log", "a").write(" ".join(args) + "\n")
url = args[-1]
if "fail" in url:
    print("WARNING: [youtube] fail: nsig extraction failed", file=sys.stderr)
    print("ERROR: [youtube] fail: Sign in to confirm you’re not a bot. Use --cookies-from-browser or --cookies for the authentication.", file=sys.stderr)
    sys.exit(1)
out = args[args.index("-P") + 1]
for part, total in (("f137", 3_000_000), ("f140", 500_000)):
    for i in range(1, 9):
        print(f"[vg] {total * i // 8} {total if part == 'f137' else 'NA'} {total if part == 'f140' else 'NA'} Тестовое видео", flush=True)
        time.sleep(0.25)
path = os.path.join(out, "Тестовое видео [ok].mp4")
open(path, "wb").write(b"\0" * 3_500_000)
print("[vg-file] " + path, flush=True)
PY
cat >"$T/bin/notify-send" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$VG_LOG/notify.log"
SH
cat >"$T/bin/wl-copy" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$VG_LOG/wlcopy.log"
SH
chmod +x "$T/bin/"*

QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; ((fail)) && exit 1; exit 77; }

for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
cat >"$T/root/shell.qml" <<'QML'
//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.tests.videograb
ShellRoot {
    VideoGrabDriver {}
}
QML
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "appearance": {"language": "ru"}}
JSON
log="${ANGELOS_TEST_LOG:-$T/qs.log}"
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 NIRI_SOCKET="$T/no-niri" \
  VG_LOG="$T" VG_SRC="$H/Videos/clip.mp4" VIDEOGRAB_NVENC=0 \
  timeout 120 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

n=0 qfail=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; qfail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the VideoGrab test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; qfail=1; }
errs=$(grep -E 'VideoGrab|Downloads\.qml|Shelf\.qml' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|not a function' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -8)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; qfail=1; }
# what went out of the shell: one link, no playlist, no cookies; the failure with yt-dlp's words
# and the offer of a newer one; the squeezed file into the clipboard as a file
grep -q -- '--no-playlist' "$T/ytdlp.log" 2>/dev/null && ! grep -q -- 'cookies' "$T/ytdlp.log" || { echo "  ✕ yt-dlp's arguments: $(head -1 "$T/ytdlp.log" 2>/dev/null)"; qfail=1; }
grep -q 'Sign in to confirm' "$T/notify.log" 2>/dev/null && grep -q 'update=' "$T/notify.log" || { echo "  ✕ the failure's notification: $(cat "$T/notify.log" 2>/dev/null | tr '\n' ' ')"; qfail=1; }
grep -q 'Сожму после игры' "$T/notify.log" 2>/dev/null || { echo "  ✕ no word of the squeeze held for the game"; qfail=1; }
shrunk=$(sed -n 's/.*TEST-SHRUNK //p' "$log" | head -1)
grep -qF -- "--type text/uri-list file://" "$T/wlcopy.log" 2>/dev/null || { echo "  ✕ the squeezed file was not copied as a file: $(cat "$T/wlcopy.log" 2>/dev/null)"; qfail=1; }
[[ -f "$shrunk" && $(frames "$shrunk") -ge 89 && $(frames "$shrunk") -le 91 ]] || { echo "  ✕ the squeezed file from the shelf: '$shrunk'"; qfail=1; }
ls -A "$H/Downloads" | grep -q '^\.angelos-grab' && { echo "  ✕ a grab's hidden folder was left in ~/Downloads"; qfail=1; }
((qfail)) || echo "  ✓ VideoGrab: $n checks (the capsule's percent, the shelf, a yt-dlp failure in a notification with «update», a squeeze held through a game, the clipboard)"
((qfail)) && fail=1
exit $fail
