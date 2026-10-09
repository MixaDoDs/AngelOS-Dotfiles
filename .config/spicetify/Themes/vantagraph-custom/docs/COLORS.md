# The colour editor

[Back to the README](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Install](./INSTALL.md) · [Settings](./SETTINGS.md) · [Extensions](./EXTENSIONS.md)

Vantagraph Custom ships one palette, **VantagraphBlack**, and hands you the rest. Open the settings button at the top right of the topbar; the first tab, **🎨 Colors**, is the editor.

Every change paints Spotify while you make it. Nothing needs a file edit and nothing needs a restart. Your colours are stored under the `vantagraph-custom:colors` key in Spicetify's localStorage, so they survive Spotify updates.

---

## The window

The settings window can be moved, so it never sits on top of the thing you are colouring.

| | |
|---|---|
| Drag the title bar | Moves the window anywhere on screen |
| Double-click the title bar | Puts it back in the centre |
| Hold the **eye** button | The window turns almost invisible while you hold it, so you can see the full screen behind it |

---

## Editing a colour

Click a colour's swatch or its name and the picker opens underneath. Click again to close it.

| Part | What it does |
|---|---|
| Colour field | Left to right is saturation, bottom to top is brightness |
| Hue strip | The colour itself |
| Opacity strip | From fully transparent on the left to solid on the right. The checkerboard shows through whatever is see-through |
| Preview | Old colour on the left, new on the right. Click the old half to go back to what you started with |
| Value box | Type or paste a colour in any format below, then press Enter or click away |
| HEX / RGB / HSL | How values are shown, in the box and on every row |
| Copy icon | Copies the value |
| Eyedropper | Pick any colour from the screen. Shown only where Spotify's browser engine supports it |
| R G B A | Exact channels. R, G and B run 0 to 255, A is the opacity in percent |
| PALETTE | Every colour already in use, one click to reuse |
| RECENT | Your last twelve picks |

With the colour field or a strip focused, the arrow keys nudge by 1%, and by 10% with Shift held.

### Formats the value box accepts

| Format | Example |
|---|---|
| Hex, 3 or 6 digits | `#0af`, `#00AAFF` |
| Hex with opacity, 4 or 8 digits | `#0af8`, `#00AAFF80` |
| Hex without `#` | `00AAFF` |
| `rgb()` | `rgb(0, 170, 255)` |
| `rgba()` | `rgba(0, 170, 255, 0.5)` |
| Space syntax | `rgb(0 170 255 / 50%)` |
| `hsl()` and `hsla()` | `hsl(200, 100%, 50%)`, `hsla(200, 100%, 50%, 0.5)` |

Anything else turns the box red and changes nothing.

---

## Colours that follow other colours

Four colours start out tied to another one, so a palette looks consistent after changing only the basics.

| Colour | Follows |
|---|---|
| Menu Text | Text |
| Icons | Subtext |
| Icon Hover | Accent |
| Play Icon | Panel |

A tied row shows a link icon and the name it follows. Pick a colour for it and the tie is cut; the row then keeps its own value whatever happens to the parent. The **reset arrow** on that row ties it back.

---

## Finding where a colour paints

The **target** icon on any row makes that colour blink magenta and cyan for about a second, together with every colour that follows it. It is the quickest answer to "what does Stroke actually colour".

---

## Undo, redo and reset

| | |
|---|---|
| **Undo** / **Redo** | Also `Ctrl+Z` and `Ctrl+Y` (or `Ctrl+Shift+Z`) while the Colors tab is open. One drag counts as one step. The last 100 steps are kept until Spotify restarts |
| The **reset arrow** on a row | That colour goes back to its default, or a tied colour follows its parent again |
| **Reset colours** | Every colour back to VantagraphBlack. It asks first, and Undo brings your palette back |

**Reset to Defaults** at the bottom of the window resets every setting of the theme, colours included.

---

## Sharing a palette

**Share** opens the sharing panel. It starts with a ready example, so the format never has to be guessed:

```ini
; Plum Night: one colour per line, key = value
; any format works, colours left out go back to default
window         = #0F0B16
panel          = #171120
panel-hover    = #221A2E
menu           = #261D33
player         = #0C0912
stroke         = #2E2340
text           = #EDE6F5
subtext        = #9C8FB0
accent         = #C79BFF
btn-active     = #C79BFF
play-btn       = #C79BFF
play-btn-hover = #DDBFFF
play-icon      = #171120
bar-fill       = #C79BFF
bar-bg         = rgba(199, 155, 255, 0.2)
heart          = #FF5C8A
row-hover      = rgba(199, 155, 255, 0.08)
```

- **Copy example** puts it on the clipboard, **Try it** loads it straight away. Undo brings your own palette back.
- The small grey word next to each colour's name in the editor is its **key**, the name used on the left of these lines.
- **Copy palette** writes your whole palette into the box and onto the clipboard.
- **Load pasted palette** reads the box. It takes lines like the example, the text Copy palette produces, or `color.ini` lines taken from any Spicetify theme: section headers and `;` comments are skipped, as are keys this theme does not have.

Loading replaces every colour, so a shared palette looks the same for everyone. Colours missing from the text go back to their defaults. Undo brings the previous palette back.

What Copy palette produces looks like this:

```json
{
  "theme": "Vantagraph Custom",
  "colors": {
    "window": "#040404",
    "panel": "rgba(8, 8, 8, 0.85)",
    "accent": "#7AA2F7"
  }
}
```

---

## Every colour

The search box at the top of the tab filters these by name, key or description.

### Surfaces

| Colour | Key | Default | Paints |
|---|---|---|---|
| Window | `window` | `#040404` | Backmost app background, seen between the panels |
| Panel | `panel` | `#080808` | Left, main and right panel background |
| Panel Hover | `panel-hover` | `#111111` | Hovered rows and buttons, right panel cards |
| Menu & Cards | `menu` | `#171717` | Right-click menu and card background |
| Player Bar | `player` | `#010101` | Bottom player bar and the Next Track card |
| Stroke | `stroke` | `#0D0D0D` | Borders and the player bar top edge |
| Active Tab | `tab-active` | `#171717` | Selected tab and filter chip background |

### Text & Icons

| Colour | Key | Default | Paints |
|---|---|---|---|
| Text | `text` | `#F0F5F2` | Titles, song names, links and body text |
| Subtext | `subtext` | `#525752` | Artists, descriptions, captions, timestamps |
| Menu Text | `menu-text` | follows Text | Right-click menu items and their icons |
| Icons | `icon` | follows Subtext | Player, topbar and volume area icons |
| Icon Hover | `icon-hover` | follows Accent | Icon colour and glow on hover |

### Buttons & Accent

| Colour | Key | Default | Paints |
|---|---|---|---|
| Accent | `accent` | `#B0B5B0` | Wave, Next Track card, playing track, focus rings |
| Active Button | `btn-active` | `#9EA39E` | Shuffle, repeat and other switched-on buttons |
| Play Button | `play-btn` | `#F0F5F2` | Fill of every play button |
| Play Button Hover | `play-btn-hover` | `#B0B5B0` | Play button fill on hover |
| Play Icon | `play-icon` | follows Panel | Play and pause symbol drawn on play buttons |
| Heart | `heart` | `#FF1040` | Liked-song heart |

### Progress Bars

| Colour | Key | Default | Paints |
|---|---|---|---|
| Bar Fill | `bar-fill` | `#B0B5B0` | Filled part of the playback and volume bars |
| Bar Track | `bar-bg` | `#010101` | Empty part of the playback and volume bars |

### Lines, Hover & Shadow

| Colour | Key | Default | Paints |
|---|---|---|---|
| Row Hover | `row-hover` | `rgba(255, 255, 255, 0.06)` | Track row and menu item hover tint |
| Divider | `divider` | `rgba(255, 255, 255, 0.06)` | Track list header line, menu border, progress bar line |
| Shine | `shine` | `rgba(255, 255, 255, 0.25)` | Light line along the top of the player bar |
| Shadow | `shadow` | `#000000` | Every shadow, the theme's and Spotify's own |

### Background Image Glass

These only show while a background image is on (the **BG** tab).

| Colour | Key | Default | Paints |
|---|---|---|---|
| Topbar Glass | `glass-topbar` | `rgba(0, 0, 0, 0.35)` | Topbar tint over a background image |
| Left Panel Glass | `glass-sidebar` | `rgba(0, 0, 0, 0.35)` | Left panel tint over a background image |
| Main View Glass | `glass-main` | `rgba(0, 0, 0, 0.25)` | Main view tint over a background image |
| Right Panel Glass | `glass-right` | `rgba(0, 0, 0, 0.3)` | Right panel tint over a background image |
| Player Bar Glass | `glass-player` | `rgba(0, 0, 0, 0.4)` | Player bar and Next Track tint over a background image |
| Glass Edge | `glass-edge` | `rgba(255, 255, 255, 0.08)` | Edge light and inner glow of the glass panels |

### Spotify Extras

Colours Spotify's own stylesheet uses, reached through Spicetify.

| Colour | Key | Default | Paints |
|---|---|---|---|
| Selected Row | `selected-row` | `#FFFFFF` | Spotify's own hover and selection tint, drawn faintly |
| Button | `button` | `#1DB954` | Spotify's primary buttons |
| Disabled Button | `button-disabled` | `#535353` | Buttons that cannot be clicked |
| Notification | `notification` | `#4687D6` | Info toasts and banners |
| Error | `notification-error` | `#E22134` | Error toasts and warnings |
| Misc | `misc` | `#7F7F7F` | Leftover greys Spotify draws in a few places |

---

## Good to know

**Light palettes are yours to balance.** There is no separate light mode. Text, icons, the menu and the play symbol all have their own colours, so a light palette works as soon as those are set to something that reads on it.

**See-through surfaces show what is behind them.** Under a panel sits the Window colour; with a background image on, the image. Transparent panels look best together with a background.

**The settings window stays readable.** It is drawn with solid copies of Panel, Text and a few others, so making Panel transparent does not make the editor disappear.

**A few greys cannot be reached.** Spotify hardcodes some of its design tokens, `--essential-subdued` among them, and no theme colour moves them. `vantagraph-custom-debug.js` shows which layer is winning for any variable; the [tutorial](./guides/TUTORIAL.md) explains the layers.

**`color.ini` is optional.** It holds VantagraphBlack for the split second before the theme's script runs. You never need to edit it.
