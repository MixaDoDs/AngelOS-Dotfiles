# Installing Vantagraph Custom

[Back to the README](https://github.com/Miabeyefendi/Vantagraph-Custom#readme) · [Colour editor](./COLORS.md) · [Settings](./SETTINGS.md) · [Extensions](./EXTENSIONS.md)

---

## Before you start

| | |
|---|---|
| [Spotify Desktop](https://www.spotify.com/download/) | tested on `1.2.86` and newer |
| [Spicetify CLI](https://spicetify.app/docs/getting-started) | tested on `2.43` and newer |
| Platform | Windows, macOS or Linux |

Vantagraph Custom and [Vantagraph](https://github.com/Miabeyefendi/Vantagraph) are separate themes with separate extension files and separate stored settings. Pick one. If both sets of extensions are enabled at the same time, you get two settings buttons and two volume wheels.

---

## Marketplace, or by hand?

**Spicetify Marketplace** is the short path. Search for Vantagraph Custom, press install, done. The theme and every extension are pulled straight from this repository and start at once, so there is nothing to copy and nothing to enable. Skip the rest of this page and go to the [colour editor](./COLORS.md).

Two things work differently there. Extensions are not individually switchable, because the Marketplace installs a theme as one unit; turn a feature off inside the settings window instead. And updates arrive through a CDN that caches for a few hours, so a fresh release can take a moment to reach you.

**By hand** gives you file-level control and instant updates. That is the rest of this page.

---

## 1. Copy the files

Spicetify keeps themes and extensions in two **separate** folders. Run `spicetify config-dir` to open the right place.

| What | Where it goes |
|---|---|
| This repository, with `color.ini`, `user.css` and `theme.js` at its root | `…/spicetify/Themes/vantagraph-custom/` |
| Every `.js` file inside `Extensions/` | `…/spicetify/Extensions/` |

Name the theme folder exactly `vantagraph-custom`. Spicetify finds a theme by its folder name, and on Linux the match is case-sensitive.

The result should look like this:

```
spicetify/
├─ Themes/
│  └─ vantagraph-custom/
│     ├─ color.ini
│     ├─ user.css
│     └─ theme.js
└─ Extensions/
   ├─ vantagraph-custom-settings.js          required
   ├─ vantagraph-custom-lyric-miniplayer.js  optional
   ├─ vantagraph-custom-loopyloop.js         optional
   ├─ vantagraph-custom-taskbarplayer.js     optional
   ├─ vantagraph-custom-volume-plus.js       optional
   └─ vantagraph-custom-debug.js             developers only
```

Extensions do **not** go inside the theme folder. That is the single most common installation mistake, and it fails silently: the theme loads, the settings button never appears.

---

## 2. Choose what to enable

Everything is opt-in except the settings window.

| Tier | Extension | Why |
|---|---|---|
| **Required** | `vantagraph-custom-settings.js` | The settings button and the colour editor. Without it the theme runs in VantagraphBlack, or in the colours you saved earlier, and nothing can be changed. |
| **Optional** | `vantagraph-custom-lyric-miniplayer.js`<br>`vantagraph-custom-loopyloop.js`<br>`vantagraph-custom-taskbarplayer.js`<br>`vantagraph-custom-volume-plus.js` | Feature add-ons. Enable as many as you want, none is required. |
| **Developers** | `vantagraph-custom-debug.js` | Prints the colour override chain in the console. Not for normal use. |

What each one actually does is in the [extensions guide](./EXTENSIONS.md).

---

## 3. Apply

### Minimal: theme and settings window

```bash
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js 1
spicetify config current_theme vantagraph-custom
spicetify config extensions vantagraph-custom-settings.js
spicetify apply
```

### Full: theme and the optional extensions

```bash
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js 1
spicetify config current_theme vantagraph-custom
spicetify config extensions vantagraph-custom-settings.js
spicetify config extensions vantagraph-custom-volume-plus.js
spicetify config extensions vantagraph-custom-lyric-miniplayer.js
spicetify config extensions vantagraph-custom-loopyloop.js
spicetify apply
```

`vantagraph-custom-taskbarplayer.js` is bundled but deliberately left out of that block, because it opens a separate always-on-top window and that is a strong opinion to force on everyone. Add it on purpose:

```bash
spicetify config extensions vantagraph-custom-taskbarplayer.js
spicetify apply
```

### Coming from Vantagraph

Switch the extensions over before applying, otherwise both sets run:

```bash
spicetify config extensions vantagraph-settings.js-
spicetify config extensions vantagraph-icons.js-
spicetify config extensions vantagraph-volume-plus.js-
spicetify config extensions vantagraph-lyric-miniplayer.js-
spicetify config extensions vantagraph-loopyloop.js-
spicetify config extensions vantagraph-taskbarplayer.js-
```

Your Vantagraph settings stay where they were. Vantagraph Custom keeps its own under `vantagraph-custom:*`, so switching back later loses nothing.

---

## Verifying it worked

Spotify restarts in the VantagraphBlack palette and a **settings button** appears at the top right of the topbar. Click it and the settings window opens on the **Colors** tab.

If the colours changed but there is no button, `vantagraph-custom-settings.js` is not enabled or is in the wrong folder. Check with:

```bash
spicetify config extensions
```

---

## Going back to stock Spotify

```bash
spicetify config inject_css 0 replace_colors 0 overwrite_assets 0 inject_theme_js 0
spicetify config current_theme marketplace
spicetify config extensions vantagraph-custom-settings.js-
spicetify config extensions vantagraph-custom-volume-plus.js-
spicetify config extensions vantagraph-custom-lyric-miniplayer.js-
spicetify config extensions vantagraph-custom-loopyloop.js-
spicetify config extensions vantagraph-custom-taskbarplayer.js-
spicetify apply
```

The trailing `-` on each extension name is Spicetify's uninstall syntax.

To clear the stored settings as well, open the window first and press **Reset to Defaults**. That wipes every `vantagraph-custom:*` key from localStorage, your colours included, removes the injected styles and clears the inline variables. Uninstalling without it leaves those keys behind, harmlessly but pointlessly. If you want to keep your colours for later, copy them out first with **Share**.

---

## When something breaks

**After a Spotify update everything is gone.** Spotify replaces the patched client files on update. Run `spicetify backup apply` to re-apply on top of the new version. Your colours are stored separately and come back with it.

**The settings button disappeared after an update.** Same cause. If it persists after re-applying, Spotify may have changed the topbar markup; open an [issue](https://github.com/Miabeyefendi/Vantagraph-Custom/issues/new?template=bug_report.yml) with your Spotify and Spicetify versions.

**I made the palette unreadable.** Press **Reset colours** in the Colors tab, or **Reset to Defaults** at the bottom of the window. The window itself stays readable whatever the Panel and Text colours are.

**A colour looks wrong in one place only.** Press the **target** icon next to the colour you suspect; it blinks everything it paints. If the spot does not blink for any colour, Spotify hardcodes it. `vantagraph-custom-debug.js` prints the full override chain for any variable, and the [tutorial](./guides/TUTORIAL.md) explains the layers.
