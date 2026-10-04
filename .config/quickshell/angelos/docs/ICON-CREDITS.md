# Icon credits

angelOS's own pixel icons (`widgets/Icons.js`) are part of angelOS. The two other icon styles
(Settings → Appearance → Icons) are converted from these sets by `scripts/icon-sets.py` into
`widgets/IconSets.js`.

## pixelarticons

Source: <https://github.com/halfmage/pixelarticons> (npm `pixelarticons@2.4.1`).
Used as the "pixelarticons" style: rendered to bitmaps on their 24-unit grid, cropped to their
ink, coloured by the angelOS theme.

Icons used (angelOS name): arrowDown, arrowLeft, arrowRight, arrowUp, bell, bellOff, calc, calendar, camera, cd, chat, check, chip, close, cursor, document, download, fire, folder, gamepad, gauge, gear, grid, image, info, keyboard, lock, logout, maximize, mic, micMute, minimize, minus, monitor, moon, mouse, music, package, palette, pin, plug, plus, power, refresh, search, skull, sparkle, sparkleStar, speaker, speakerMute, star, sun, terminal, trash, warn, window.

```
MIT License

Copyright (c) 2019 Gerrit Halfmann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Pixel Icon Library by HackerNoon

Source: <https://github.com/hackernoon/pixel-icon-library> (npm `@hackernoon/pixel-icon-library@1.1.0`),
<https://pixeliconlibrary.com>. Icons © HackerNoon, licensed under
[Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).

**Changes made:** the SVG icons were rendered to bitmaps on their 24-unit grid, cropped to their
ink and are recoloured by the angelOS theme at runtime; only the icons listed below are included.

Icons used (angelOS name): arrowDown, arrowLeft, arrowRight, arrowUp, bell, bellOff, calendar, camera, cd, chat, check, close, document, download, fire, folder, gear, grid, image, info, lock, logout, maximize, minimize, minus, monitor, moon, music, package, palette, pin, plus, refresh, search, sparkle, sparkleStar, speaker, speakerMute, star, sun, terminal, trash, warn, window.

## MacTahoe (the Golden Gate Dock)

Source: <https://github.com/vinceliuice/MacTahoe-icon-theme>, release `2026-09-10`, © Vince Liuice,
GPL-3.0. Not in this repository: `scripts/mac-icons.py` downloads the pinned release (SHA-256
checked) when the Golden Gate skin is on and puts its default variant together in
`~/.local/share/angelos/icons/MacTahoe`, its `COPYING` and `AUTHORS` included. Only the Dock reads
it (`services/DockIcons.qml`), unchanged.
