# Extensions

[Back to the README](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Install](./INSTALL.md) · [Colour editor](./COLORS.md) · [Settings](./SETTINGS.md)

Six files ship with the theme. One is required, four are features you take or leave, and one is for people editing the theme. How to enable them is in the [installation guide](./INSTALL.md#2-choose-what-to-enable).

This edition has no icon extension. Spotify's own icons stay as they are, and the extensions draw their controls with standard icons. Only the buttons that open the theme's own windows (settings, lyric miniplayer, volume presets) carry Vantagraph icons, embedded in their own files.

---

## Taskbar Player

A borderless, always-on-top bar built on `documentPictureInPicture`. It keeps working while another application is fullscreen, which is the entire reason it exists: alt-tabbing out of a game to skip a track is the problem it removes.

Spotify is a single-page app and wipes the DOM on navigation, which normally kills anything injected into it. This one survives that through a `MutationObserver` on the picture-in-picture document plus a `requestAnimationFrame` sentinel that rebuilds the bar if it goes missing. It carries live lyrics, seek, volume, shuffle, repeat and like, takes its colours from your palette, and narrows itself when lyrics are switched off.

It is bundled but deliberately excluded from the default install block, because opening a second always-on-top window is not a decision to make on someone's behalf.

---

## The rest

| Extension | What it does |
|---|---|
| `vantagraph-custom-settings.js` | The settings window, the colour editor and the topbar button. **Required** for any of the configuration to be reachable. |
| `vantagraph-custom-volume-plus.js` | Scroll wheel volume on the bar, middle-click mute, a percentage tooltip, quick presets at 25/50/75/100% with an accent-coloured active ring, and a wider 250px bar. Public API only, no private `_volume` access. |
| `vantagraph-custom-lyric-miniplayer.js` | Picture-in-picture lyrics with word-synced karaoke on a `requestAnimationFrame` loop, eight animation presets, translations, a vinyl display, alignment and font size controls, and its own settings popup. Its colours follow your palette live. |
| `vantagraph-custom-loopyloop.js` | Right-click the progress bar to set loop start and end. Loops persist per track URI in localStorage, and scrolling near a marker nudges it for fine adjustment. |
| `vantagraph-custom-taskbarplayer.js` | The floating player above. |
| `vantagraph-custom-debug.js` | Prints the colour override chain for any CSS variable: Encore default, Spicetify `--spice-*`, then the colour editor's inline value. Paste it into DevTools or load it as an extension. Not for normal use. |

---

## Credits

Three of these are full rewrites built on top of earlier work. The original idea in each case belongs to someone else, and it is worth being specific about where the line falls.

### Volume+

**[Aspecky](https://github.com/Aspecky)** · [original](https://github.com/Aspecky/spicetify-extensions/tree/main/volume-plus)

The idea taken: scroll-wheel volume with a tooltip.

Rewritten from scratch here with middle-click mute, a quick-preset overlay with an active indicator and double-click restore to a preferred volume, an enforced 250px bar width, a Tippy fallback label, modern `data-testid` selectors, volume restore on startup, a first-run hint for the middle-click gesture, and public API access only.

### LoopyLoop

**khanhas** and the **[Spicetify](https://github.com/spicetify)** maintainers · [original](https://github.com/spicetify/cli/tree/main/Extensions)

The idea taken: right-click the progress bar to set loop points.

Rewritten here with selectors drawn from the Vantagraph class-mapping system, native `createElement` in place of the deprecated `_HTMLContextMenuItem` API, theme-aware colours through `--spice-accent`, `--spice-player` and `--spice-highlight`, per-track persistence keyed by URI, and proximity-based scroll-to-nudge.

### Lyric Miniplayer

**[FO-SS](https://github.com/FO-SS)** · [original](https://github.com/FO-SS/Spictify-Lyric-Miniplayer)

The idea taken: a floating picture-in-picture lyrics window.

Rewritten here with live `--spice-*` theming, a `requestAnimationFrame` render loop, `VantagraphCustomData` integration, a Spotify-like layout, a separate settings popup window, eight animation presets, translations, a vinyl display, an alignment picker, font size control, karaoke glow, and inline repeat, like and volume.

---

## Elsewhere

The visual direction of the documentation owes something to the showcase styles of [Catppuccin](https://github.com/catppuccin), [Tokyo Night](https://github.com/folke/tokyonight.nvim), [Dracula](https://draculatheme.com/), [Nord](https://www.nordtheme.com/) and [Gruvbox](https://github.com/morhetz/gruvbox).

Spotify, the Spotify logo and Spicetify belong to their respective owners. Their use here is nominative and implies no affiliation or endorsement.
