# Changelog

Every released version of Vantagraph Custom, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[README](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Releases](https://github.com/Miabeyefendi/Vantagraph-Custom/releases)

---

## [1.0.0](https://github.com/Miabeyefendi/Vantagraph-Custom/releases/tag/1.0.0) - 2026-09-24

First release. Vantagraph Custom is a lite edition of
[Vantagraph](https://github.com/Miabeyefendi/Vantagraph) 5.0.2: the preset
palettes and the custom icon set are gone, and every colour the theme paints
is set by the user from inside Spotify.

### Added

- **Colour editor.** The first tab of the settings window. Thirty-six colours
  in seven groups, each with a colour field, hue and opacity strips, an
  eyedropper where Spotify supports it, R G B A fields, and a value box that
  takes HEX (3, 4, 6 or 8 digits), `rgb()`, `rgba()`, `hsl()` and `hsla()`.
  Values can be shown as HEX, RGB or HSL.
- **Colours that follow others.** Menu Text, Icons, Icon Hover and Play Icon
  follow Text, Subtext, Accent and Panel until given a value of their own.
- **Find.** Blinks a colour, and everything following it, inside Spotify.
- **Undo and redo** for colours, 100 steps, with `Ctrl+Z` and `Ctrl+Y`.
- **Palette sharing.** Copy the whole palette as text; load one back from that
  text or from `color.ini` lines. The panel opens with a ready example palette
  that can be copied or tried in one click, and every colour row shows its key.
- **Palette and recent swatches**, and a search box across all colours.
- **Movable settings window.** Drag the title bar, double-click to centre it,
  hold the eye button to look through it.
- New colours that were fixed values before: menu text, icons, icon hover,
  play icon, row hover, divider, shine, the six glass tints used over a
  background image, and Spotify's own selected-row, button, disabled button,
  notification, error and misc colours.

### Changed

- The engine writes the `--spice-rgb-*` twin of every colour, so Spotify's own
  translucent hover and selection tints follow the palette.
- A background image keeps the user's colours instead of switching to a preset
  palette. The glass look is tinted by the new glass colours.
- The settings window draws with solid copies of the palette, so a
  transparent Panel or Text never makes it unreadable.
- Theme folder `vantagraph-custom`, extensions `vantagraph-custom-*.js`,
  stored settings `vantagraph-custom:*`, so it can sit next to Vantagraph
  without the two overwriting each other's files or settings.

### Removed

- The eleven preset palettes. `color.ini` holds one, VantagraphBlack, as the
  starting point.
- The separate light-theme rule set. Light palettes are made from the same
  colours as dark ones.
- The custom icon set and its extension. Spotify's own icons stay as they
  are. The buttons that open the theme's own windows keep their icons,
  embedded in their extensions.
- The Custom Accent snippet, covered by the editor.
- Font presets cut from eight to two, Inter and JetBrains Mono, next to
  Spotify's own font. Any other font still works as a custom font.
