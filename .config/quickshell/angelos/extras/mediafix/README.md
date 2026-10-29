# mediafix (bundled)

Copy of [MixaDoDs/mediafix](https://github.com/MixaDoDs/mediafix) (commit 52ad472):
prepares videos for DaVinci Resolve — the video stream is copied as is, every audio
track becomes PCM 24-bit / 48 kHz, results go to `~/Videos/MediaFix` (in angelOS: Settings → Screenshots and recording → Folder for DaVinci videos, passed as `MEDIAFIX_DIR`), originals are
never changed. Needs `ffmpeg` (`sudo pacman -S ffmpeg`).

angelOS runs it from:

- Nautilus: right-click videos → «Подготовить для DaVinci Resolve (mediafix)»
  (extension installed by Settings → Default apps → Files · Nautilus);
- the desktop right-click menu → Open ▸ mediafix, the launcher (`mediafix`) and
  `python3 ~/.config/quickshell/angelos/scripts/nautilus-setup.py mediafix [files…]`.

To update: copy `mediafix.py` from the upstream repository over this file.
