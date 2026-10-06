# Third-party parts

Everything in this repository not listed here is © 2026 MixaDoDs under the MIT license
([`LICENSE`](LICENSE)). The parts below were made by others and keep their own licenses.

| What | Where | License | Source |
|---|---|---|---|
| SDDM theme *pixel-cyberpunk* (incl. its `bg.mp4`) | `sddm/themes/pixel-cyberpunk/` | GNU GPL v3 ([`LICENSE`](sddm/themes/pixel-cyberpunk/LICENSE)) | [Qylock](https://github.com/Darkkal44/qylock) by Darkkal44, unmodified |
| Pixelify Sans (the SDDM theme's font) | `sddm/themes/pixel-cyberpunk/font/` | SIL OFL 1.1 | [Pixelify Sans](https://github.com/eifetx/Pixelify-Sans) |
| Pixeloid Sans, Pixeloid Mono | `.local/share/fonts/pixel/` | SIL OFL 1.1 | GGBotNet |
| Cozette, CozetteVector | `.local/share/fonts/pixel/` | MIT (below) | [Cozette](https://github.com/slavfox/Cozette) by Ines |
| Caveat | `.config/quickshell/angelos/data/fonts/` | SIL OFL 1.1 | [googlefonts/caveat](https://github.com/googlefonts/caveat) |
| Jacquard 12, Jacquard 24 | `.config/quickshell/angelos/data/fonts/` | SIL OFL 1.1 | [Soft Type Jacquard](https://github.com/scfried/soft-type-jacquard) |
| Jacquard 12 Hell (Jacquard 12 + Cyrillic) | `.config/quickshell/angelos/data/fonts/` | SIL OFL 1.1 (a modified version) | ours on top of Jacquard 12 |
| Departure Mono | `.config/quickshell/angelos/data/fonts/` | SIL OFL 1.1 | [Departure Mono](https://departuremono.com) by Helena Zhang |
| Pixora icon theme (`pixora`, `pixora-dark`) | `.local/share/icons/` | CC BY 4.0 | [tsora1603/pixora-icons](https://github.com/tsora1603/pixora-icons) by tsora1603 (based on Tux on Pixels by maxtron95, CC0; inspired by DeltaPixel). Included as obtained; no changes recorded in this repository. [License](https://creativecommons.org/licenses/by/4.0/) |
| pixelarticons (one of the shell's icon styles, converted) | `.config/quickshell/angelos/widgets/IconSets.js` | MIT | [halfmage/pixelarticons](https://github.com/halfmage/pixelarticons) — see [`ICON-CREDITS.md`](.config/quickshell/angelos/docs/ICON-CREDITS.md) |
| Pixel Icon Library by HackerNoon (an icon style, converted) | `.config/quickshell/angelos/widgets/IconSets.js` | CC BY 4.0 | [hackernoon/pixel-icon-library](https://github.com/hackernoon/pixel-icon-library) — changes listed in [`ICON-CREDITS.md`](.config/quickshell/angelos/docs/ICON-CREDITS.md) |
| LazyVim starter (the Neovim config's skeleton: `init.lua`, `lua/config/lazy.lua`, `stylua.toml`, the example spec) | `.config/nvim/` | Apache License 2.0 ([`LICENSE`](.config/nvim/LICENSE)) | [LazyVim/starter](https://github.com/LazyVim/starter); our changes: the terminal-palette options and autocmds, `lua/plugins/{terminal-theme,langs,web,clangd}.lua`, `lazyvim.json` extras |
| Lucide icons (a subset: the Golden Gate skin's line icons, as SVG path data) | `.config/quickshell/angelos/widgets/MacIcons.js` | ISC (the ones derived from Feather: MIT) — notices below | [lucide.dev](https://lucide.dev), lucide-static 1.52.0, unmodified paths |
| Claude Companion plugin (a port) | `.config/quickshell/angelos/plugins/claude-companion/` | MIT (below) | [lowcache/noctalia-claude-plugin](https://github.com/lowcache/noctalia-claude-plugin) |

The SIL OFL 1.1 text with every font's copyright line: [`LICENSES/OFL-1.1.txt`](LICENSES/OFL-1.1.txt).

## Ideas, no code taken

The manifests credit these Noctalia plugins as the idea behind angelOS's own versions; their
code was not copied. Their licenses could not be checked (the repositories were not found):

- `cat` — idea: DotNetRob/cat (credited as MIT)
- `speedtest` — idea: nilsonlinux/speedtest-meter (credited as MIT)
- `web-search` — after notfinaldev/web-search (credited as MIT)

## Unclear — source unknown

These are in the repository, but where they come from and under what terms is not known.
Replace or remove them before relying on the repository being free to redistribute:

- `Pictures/Pixel/wallhaven-p9qj59.png` (Noctalia's default wallpaper), `Pictures/wallpapers/wallhaven-1q2zd1.jpg`,
  `Pictures/wallpapers/wallhaven-vg8mo8.jpg` — downloaded from wallhaven.cc; the artists and licenses are not recorded.
- `.config/quickshell/angelos/plugins/osu-mini/sfx/{hit,miss,perfect,break}.wav` — no source or generator recorded.

Not third-party: the angel's and the demon's sprites (`modules/y2k/sprites/`) are the author's;
all other sounds of angelOS are synthesised by `scripts/y2k-sounds.py`; the GIFs and screenshots in
`docs/` are recordings of angelOS in a clean demo stand (`scripts/demo/`), on a wallpaper drawn by
`scripts/demo/wallpaper.py`. NEEDY GIRL OVERDOSE and Undertale are only referenced
(names, a voice style made by the synthesiser) — none of their art or sound is included.

## Notices

### Cozette — MIT

```
MIT License

Copyright (c) 2020, Ines <ines@moonwit.ch>

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

### noctalia-claude-plugin (the Claude Companion port) — MIT

```
MIT License

Copyright (c) 2026 lowcache

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

pixelarticons' MIT notice and the HackerNoon credit are in
[`ICON-CREDITS.md`](.config/quickshell/angelos/docs/ICON-CREDITS.md).

### Lucide — ISC (and Feather — MIT, for the icons derived from it)

```
ISC License

Copyright (c) 2026 Lucide Icons and Contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

```
The MIT License (MIT) (for the Lucide icons derived from Feather: airplay, calendar, check,
chevron-*, clock, command, download, info, lock, log-out, maximize, minimize, minimize-2, minus,
monitor, moon, music, plus, power, search, terminal, trash-2, type, x and others)

Copyright (c) 2013-present Cole Bemis

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
