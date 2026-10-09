# Settings

[Back to the README](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Install](./INSTALL.md) · [Colour editor](./COLORS.md) · [Extensions](./EXTENSIONS.md)

Everything is configured from inside Spotify. Click the **settings button** at the top right of the topbar and a five-tab window opens. Nothing here needs a file edit, and nothing needs a restart: every control takes effect as you use it.

The window can be dragged by its title bar and put back in the centre with a double-click. Holding the **eye** button makes it see-through for a moment.

Settings are stored under `vantagraph-custom:*` keys in Spicetify's localStorage. They survive a Spotify update; they do not survive **Reset to Defaults**, which is the point of that button.

---

## 🎨 Colors

The colour editor: thirty-six colours in seven groups, each with a full picker, opacity, eyedropper, undo, search and palette sharing. It has its own page: [the colour editor](./COLORS.md).

---

## ✏️ Font

| Control | What it does |
|---|---|
| Preset | Spotify's own font, **Inter** (a plain sans that reads everywhere and covers most alphabets) and **JetBrains Mono** (a monospace that looks nothing like either). Kept to three on purpose: fewer fonts to fetch, fewer things to break |
| Custom family | Type any Google Fonts name and the stylesheet URL is built for you. A locally installed font works too, just type its family name |
| Size | 10 to 20px, applied to every Encore type element rather than to a handful of selectors |

---

## 📐 Layout

| Control | Range | What it does |
|---|---|---|
| Icon Size | 12 to 34px | Every icon, not just the player controls |
| Density | compact / default / comfortable | Row heights and padding throughout |
| Corners | 0 to 24px | Border radius on cards, covers and panels |

Each slider has a **DEF** button that restores the value Spotify ships with, so you can compare against stock without resetting everything else.

---

## 🖼️ Background

| Control | What it does |
|---|---|
| Image URL | Any image address |
| Album Cover as BG | Uses the artwork of whatever is playing, changing with the track |
| Blur, Brightness, Contrast, Saturation | Live filters over whichever image is in use |

With an image on, the panels turn to glass: a blurred copy of the image tinted by the colours in the **Background Image Glass** group of the Colors tab. Your other colours stay as they are, so you can switch the background on and off at any time.

---

## ✂️ Snippets

Thirty-plus toggles, grouped into accordions.

| Group | What is in it |
|---|---|
| Visual | Rounded images, modern scrollbar, stop the vinyl animation, reduced motion |
| Hide buttons | Friend Activity, What's New, Fullscreen, Lyrics, Mini Player, Queue, Shuffle, Repeat, Connect, Volume bar, Now Playing widget, Next Track widget |
| Hide elements | Made for You, Top Mixes, Jump Back In, New Releases, Recommended Stations, Recents, Best of Artists, Favorite Artists, Recommended for Today, Home shortcuts, mood recommendations, promo card, ads banner, podcasts filter |
| Layout | Thin library rows, auto-hide sidebar below 1200px |
| Dev tools | Panel labels, layout grid, element highlighter, spacing visualiser, CSS variable monitor, DOM mutation logger, Encore audit |

The developer tools are there because building a theme against Spotify means guessing which class does what. They are safe to leave off and useful when a selector stops matching.

---

## Reset to Defaults

The red button at the bottom of the window. It wipes every `vantagraph-custom:*` localStorage key, removes the injected `<style>` and `<link>` tags, clears the inline `--spice-*` and `--vg-*` variables from `:root`, drops the body classes and puts the VantagraphBlack colours back.

It is a full reset rather than a settings reset, which is what you want when something looks wrong and you cannot tell which of thirty toggles caused it. The colours it clears can still be brought back with **Undo** in the Colors tab until Spotify restarts.
