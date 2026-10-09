# How Vantagraph Custom works underneath

[Back to the README](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Install](../INSTALL.md) · [Colour editor](../COLORS.md) · [Settings](../SETTINGS.md) · [Extensions](../EXTENSIONS.md)

This page is for people editing the theme, forking it, or trying to work out why a colour is not doing what they told it to. If you only want to use Vantagraph Custom, the [README](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) and the guides above cover everything.

---

## How a colour reaches the screen

```
Colors tab                      vantagraph-custom-settings.js, UI only
    |
    |  setColor(key, value)
    v
colour engine                   theme.js: COLOR_KEYS, links, storage
    |
    |  root.style.setProperty on :root
    v
--spice-<key>, --spice-rgb-<key>, Spicetify names, --vg-<key>
    |
    |  read by user.css, and by Spotify's own stylesheet,
    |  whose hex colours Spicetify replaced with --spice-* at apply time
    v
Encore tokens                   --background-base, --text-subdued, and the rest
    |
    v
the DOM
```

**Every colour is defined once, in `COLOR_KEYS` in `theme.js`.** Each entry has a key, a group for the editor, a label, a description, and either a `value` (its VantagraphBlack default) or a `link` to another key it follows until the user sets it.

**What the user picks is one JSON object** under `vantagraph-custom:colors` in Spicetify's localStorage, holding only the colours that differ from the default. The engine validates every stored value on load and drops anything it cannot parse.

**`color.ini` only covers the first frame.** Spicetify turns it into `--spice-*` variables at apply time, which is what Spotify shows before `theme.js` has run. It holds the same VantagraphBlack defaults as `COLOR_KEYS`, and the two have to be kept in step by hand. Colours with opacity and linked colours live only in `COLOR_KEYS`, because Spicetify's `color.ini` parser reads six-digit hex and nothing else.

### What each key writes

A key is written as `--spice-<key>` together with `--spice-rgb-<key>` (`r,g,b`, which Spotify's own stylesheet uses for its translucent tints), plus the Spicetify names in its `spice` list:

| Key | Also writes |
|---|---|
| `window` | `sidebar` |
| `panel` | `main` |
| `panel-hover` | `main-elevated`, `highlight-elevated` |
| `menu` | `card` |
| `player` | `playbar` |
| `stroke` | `highlight` |
| `btn-active` | `button-active` |
| `play-btn` | `play-button` |
| `play-btn-hover` | `play-button-active` |
| `bar-fill` | `progress-fg` |
| `bar-bg` | `progress-bg` |

Keys marked `vg: true` are colours only this theme uses (`menu-text`, `icon`, `icon-hover`, `play-icon`, `row-hover`, `divider`, `shine`, the six `glass-*` tints). They are written as `--vg-<key>` and read by `user.css`.

Three values are derived rather than set:

- `--spice-progress-bg-alpha` is Bar Track at 35% of its opacity, for the playback bar background.
- `--vg-ui-panel`, `--vg-ui-text` and a few more are solid copies the settings window draws with, so a transparent Panel never makes the editor unreadable.
- While a background image is on, `--spice-main` stays `transparent` whatever Panel is set to, and the Panel colour comes back when the image is switched off.

Where `user.css` needs a colour at a strength other than the user's, it mixes instead of hardcoding: `color-mix(in srgb, var(--spice-shadow) 30%, transparent)` is Shadow at 30%, whatever Shadow is.

### Adding a colour

1. `theme.js`: add an entry to `COLOR_KEYS` with a `value` or a `link`. The editor picks it up from there, with search, undo and sharing included.
2. `user.css` or the injected CSS in `theme.js`: use the variable.
3. If it is a plain hex colour on a Spicetify name, add it to `color.ini` too.
4. `docs/COLORS.md`: add the row to its group's table.

### Where it breaks

Some Encore tokens are **hardcoded in Spotify's own stylesheet** and never read a `--spice-*` variable at all. `--essential-subdued`, `--decorative-subdued` and `--background-elevated-press` are the ones that come up most. No colour in the editor moves them; they have to be overridden in `user.css`.

That is the single most common source of "I changed the colour and one button stayed grey".

### Finding out which layer won

The **target** icon in the editor blinks every place a colour paints, which answers most questions without DevTools.

For the rest there is `Extensions/vantagraph-custom-debug.js`. Paste it into DevTools or load it as an extension, and it prints four blocks: the Encore defaults, the Spicetify values against the editor's inline values, every inline variable on `:root`, and anything anomalous. Re-run it with `_vgDebug()`.

Reaching DevTools inside Spotify is `Ctrl + Shift + I` once Spicetify has enabled it.

---

## File map

| File | What it is |
|---|---|
| `theme.js` | The engine. Class mapping, the colour model and engine, every setting, the background system, the wave animation. |
| `user.css` | The stylesheet. Numbered sections following Spotify's DOM from the top bar down. |
| `color.ini` | The VantagraphBlack defaults for the first frame. The comment block at the top documents every key. |
| `manifest.json` | Marketplace metadata: name, description, preview image, readme path, the scripts to load. |
| `Extensions/` | The six extensions. |
| `src/assets/icons/` | Sources of the three icons the extensions embed. |
| `src/utils/debug-tools/` | Development scripts, not shipped to users. |

### Inside `theme.js`

Section headings rather than line numbers, because line numbers go stale the moment anyone edits the file. Search for these:

| Section | What lives there |
|---|---|
| `VG_CLASS_MAP` | Spotify's generated class names mapped to stable `vg-*` names |
| `applyDynamicClasses` | Applies that map, with a `MutationObserver` and a `requestAnimationFrame` debounce |
| `COLORS` | `COLOR_GROUPS` and `COLOR_KEYS`: every colour, its default or link |
| `COLOR MATH` | `parseColor`, `formatColor` and the HEX, RGB, HSL and HSV conversions |
| `COLOR ENGINE` | Storage, link resolution, `writeColorVars`, `setColor`, `resetColor`, `flashColor` |
| `FONT_PRESETS` | Spotify Default, Inter and JetBrains Mono |
| `applyFont`, `applyHeartColor` | The appliers |
| `applySetting` | One switch, every other setting passes through it |
| `window.VantagraphCustomData` | What the extensions are allowed to use |

### Inside `user.css`

Sections are numbered and follow the DOM hierarchy: root, top, topbar, left sidebar, main, right sidebar, player, lyrics, context menu, misc, layout, colorist, focus, hover.

Within a section you will find two subheadings repeatedly:

- **normal** is the plain state
- **bg-active** is what applies when a background image is on, which turns the surfaces to glass

There is no separate light-theme rule set. Every colour a light palette needs has its own key.

---

## Adding a snippet

Four places, and missing the fourth is a silent bug.

1. `theme.js`, `applySetting`: add a `case` for the key, in the hide-snippet group.
2. `theme.js`, the `btnCss` object: add the CSS line.
3. `theme.js`, `defaultOffSnippets`: add the key. Being in that array means "off by default", so the element stays visible until someone turns the snippet on.
4. `vantagraph-custom-settings.js`: add the toggle row to the right accordion, **and** add `vantagraph-<key>` to the `injectedIds` array used by the reset routine.

Skip step 4's second half and Reset to Defaults will not clear your snippet. Nothing will look broken; the setting will simply survive a reset that claims to remove everything.

---

## Problems already solved

Worth knowing about before you rediscover them.

**Flicker from `backdrop-filter` next to a rotating element.** A Chromium bug: a spinning element such as the vinyl causes black tearing on a neighbouring element carrying `backdrop-filter`. Moving the filter off the element and onto a `::before` pseudo-element isolates the blur from the parent's repaint cycle and fixes it. GPU hints such as `translateZ` and `backface-visibility` did nothing and were removed.

**The heart icon was always red.** Spotify stopped changing `aria-label` between liked and unliked. Anything keyed on the label coloured the icon whether or not the track was saved. The check is `aria-checked === "true"` now, in both `theme.js` and the CSS selectors.

**The progress bar fill kept fading.** `opacity` on the parent cascades to every child, and the fill is a child. Replaced with an `rgba` variable, `--spice-progress-bg-alpha`, so only the background is transparent.

**Encore's internal colour classes ignore overrides.** `.encore-internal-color-text-subdued` computes its colour internally and skips the `--text-subdued` override, so `color` is forced to the Icons colour on the player and topbar buttons carrying that class.

**Spotify writes `fill: transparent` inline.** React applies inline styles to the like and save SVGs, and CSS alone cannot win against that. The observer inside `applyHeartColor()` overwrites it, debounced at 100ms to avoid a mutation loop.

**In-app colour changes left Spotify's translucent tints behind.** Spotify's stylesheet draws hover and selection tints as `rgba(var(--spice-rgb-text), …)` and friends. Writing only `--spice-text` changed the text but not those tints. The engine writes the `--spice-rgb-*` twin of every colour it sets.

---

## Testing a change

Edit, then `spicetify apply`, then Spotify restarts. Verify in DevTools.

Browser preview tooling is no help here, because this is an Electron application rather than a page you can load. If you need to confirm DOM behaviour, write a console snippet and run it inside Spotify.
