<div align="center">

<img width="2046" height="769" alt="a30256b3-6dd4-4082-8b64-22c9f0894bb5" src="https://github.com/user-attachments/assets/ed73f41e-73ec-44ce-8a80-50751ccb66a6" />


# ♡ angelOS ♡

**`~ welcome back, internet angel ~ ● LIVE`**

A **CachyOS + [Niri](https://github.com/YaLTeR/niri)** rice with its own desktop shell, **angelOS**, built on
[Quickshell](https://quickshell.org) in the spirit of *NEEDY GIRL OVERDOSE*. Two looks, one desktop:
**Pixel** — Win98 windows, pixel hearts and a bar that sings along — and **macOS** (*Golden Gate*) —
a Dock, a menu bar, Liquid Glass and ⌘ keys for people coming from a Mac.

![niri](https://img.shields.io/badge/niri-26.04-ff5cad?style=flat-square&labelColor=241432)
![quickshell](https://img.shields.io/badge/quickshell-0.3-4fe3ff?style=flat-square&labelColor=241432)
![cachyos](https://img.shields.io/badge/CachyOS%20%2F%20Arch-♡-b36bff?style=flat-square&labelColor=241432)
![themes](https://img.shields.io/badge/themes-pixel%20%2B%20macOS-ffb3d9?style=flat-square&labelColor=241432)
![stress](https://img.shields.io/badge/stress-0%25-57e3a2?style=flat-square&labelColor=241432)
![love](https://img.shields.io/badge/love-100%25-ff5cad?style=flat-square&labelColor=241432)

<img src="docs/screenshots/pixel-dark.png" width="49%" alt="The Pixel theme: Win98 taskbar with pixel hearts, clock.exe, sysmon.exe, music.exe and cava.exe widgets"> <img src="docs/screenshots/macos-light.png" width="49%" alt="The macOS theme (Golden Gate): menu bar on top, Liquid Glass Dock at the bottom, glass widgets">

*`pixel.exe` ✧ `goldengate.app` — one click apart (Settings → Appearance).*

**English** · [Русский](README.ru.md)

</div>

> [!NOTE]
> Every screenshot and GIF is a clean install in a nested niri session with a throw-away home: a generated
> wallpaper, a placeholder user, no notifications or chats of anyone's. In a nested session niri uses `Alt`
> as `Mod`; on real hardware `Mod` is the **Super / Windows** key (⌘ in the macOS theme), and that is what
> the tables use.

**Jump to:** [Two looks](#-two_looksexe) · [Pixel](#-pixelexe) · [macOS](#-goldengateapp) · [Game](#-gameexe) ·
[Plugins](#-pluginsexe) · [Tiling](#-tilingexe) · [Keys](#-keybindings) · [Terminal](#-terminalexe) ·
[Install](#-installerexe) · [Updates](#-updating) · [Login screen](#-login-screen-sddm) · [Layout](#-repository-layout) ·
[License](#-license)

---

## ✧ two_looks.exe

angelOS is the whole desktop: bar or menu bar, Dock, wallpaper, widgets, launcher, notifications, OSD, lock screen,
polkit dialogs, clipboard history and a settings app. It lives in [`.config/quickshell/angelos`](.config/quickshell/angelos)
and is plain QML, so everything is hackable. It wears one of two looks — the installer asks, and
**Settings → Appearance** switches at any time; everything a look changed outside the shell (GTK, Qt, the cursor,
niri's keys) comes back when you leave it.

| | **Pixel** (angelOS) | **macOS** (Golden Gate) |
| --- | --- | --- |
| Panel | Win98 taskbar: pixel-heart workspaces, window buttons, the current **lyric line** in the middle | Menu bar: the app's own menus, Control Center, Spotlight, date |
| Apps | Start menu + launcher | **Dock** with magnification, minimized windows, Downloads and Trash |
| Windows | pixel frames, 4 px corners, a thin accent outline | 16 px corners, shadows, traffic lights, **minimize to the Dock** |
| Glass | — | **Liquid Glass**: niri's blur under the shell, a lens edge drawn by a shader |
| Sounds | Y2K pack | Mac-like system sounds (our own, CC0) |
| Keys | angelOS's (`Mod`+`Space`, `Mod`+`Q`…) | optional **⌘ keys**: ⌘Q ⌘W ⌘M ⌘Space ⌘Tab, tiling on `Super`+`Alt` |
| Font, cursor | pixel fonts, pixel cursors | Inter, the `macOS` cursor |

<img src="docs/screenshots/pixel-light.png" width="49%" alt="Pixel theme, light palette"> <img src="docs/screenshots/macos-dark.png" width="49%" alt="macOS theme, dark: menu bar, Dock and glass widgets at dusk">

---

## ✧ pixel.exe

### ♡ desktop.exe

The taskbar is a Win98 one with pixel hearts for workspaces (or the icons of the apps on them), window buttons, a tray
recoloured to the theme, and the **current lyric line of the song in the middle** (synced lyrics from
[lrclib.net](https://lrclib.net)). Widgets sit on the wallpaper. Palettes include `bubblegum`, `overdose`,
`cyber angel`, Gruvbox, Rosé Pine, Catppuccin and colours generated from your wallpaper.

![The Pixel desktop: workspaces, windows, light and dark, flavours](docs/demo/pixel-desktop.gif)

| Keys | Action |
| --- | --- |
| `Mod`+`Alt`+`T` | Light ⇄ dark theme |
| `Mod`+`Alt`+`Y` | Lyrics line on / off |
| `Mod`+`Mouse wheel` on the hearts | Switch workspace |
| Right-click a window button | Close that window |

### ♡ wallpaper.exe

Changing the wallpaper plays a pixel transition (mosaic + ordered Bayer dither) — only when the picture changes, so
switching workspaces stays instant, even with a wallpaper per workspace. `Mod`+`Shift`+`Return` opens the picker: one
picture for every screen, one per monitor or one per workspace.

![Pixel mosaic transition between wallpapers](docs/demo/wallpaper.gif)

### ♡ menu.exe

Right-click the wallpaper for a **Windows 11-style** menu: quick actions on top, then **View ▸** (widgets, edit mode,
snap to grid), **New ▸** (note, screenshot, recording), **Open ▸** (your folders), display settings, personalisation,
*Open in Terminal* and **Show more options ▸** for plugin items. Widgets (`clock.exe`, `sysmon.exe`, `cava.exe`,
`music.exe` and the plugins' ones) are dragged by their title bar; double-click a title for edit mode.

![Windows 11-style right-click menu adding a widget](docs/demo/menu.gif)

### ♡ launcher.exe

`Mod`+`Space`: fuzzy app search that learns what you launch, `web …` for the web and your favourite sites,
`plugins …` for the plugin catalog, `claude …` for Claude Code and `> command` for anything in `sh`.

![Launcher: apps, web search, a shell command](docs/demo/launcher.gif)

### ♡ settings.exe

A real window laid out like Windows 11's Settings — or a macOS sidebar, a Win98 Control Panel, Properties tabs or big
tiles (`angelos settingsView …`). Theme, Wallpaper, **Widgets**, Taskbar (drag-and-drop layout), Start, **Display**
(drag the screens around; the exact refresh rates niri lists, saved so they survive a reboot), Keyboard, Mouse,
**Windows** (width presets, a width per app, Alt+Tab), Sound, **Default apps**, Notifications, Plugins, Updates.
Every change to niri's config is backed up, checked with `niri validate` and rolled back if niri says no.
Browsers follow the theme too: Helium and Chromium live through GTK, Firefox through `userChrome.css`.

![Settings: appearance, bar layout, widgets, window widths, default apps](docs/demo/settings.gif)

### ♡ tips.exe

The first login opens a setup wizard, one question at a time (language, the game, the main screen, layouts, light or
dark, how much moves), then the **interface tips** circle every part of the screen in pixels. *Set up later*
(or `angelos setup skip`, even from a text console) lets the desktop go at once; replay both from Settings → Account.

![Interface tips circling the start button, workspaces and the clock](docs/demo/tips.gif)

---

## ✧ goldengate.app

The whole desktop like macOS 27 *Golden Gate*, for people coming from a Mac — drawn from screenshots and Apple's HIG,
not from memory, and without a single file of Apple's (see [what is not Apple](#what-is-not-apple)). Pick it in the
installer, in the first-run wizard (*“Coming from a Mac?”*), in Settings → Appearance, or with
`angelos settingsSkin goldengate`. Details: [`docs/GOLDEN-GATE.md`](.config/quickshell/angelos/docs/GOLDEN-GATE.md).

### ♡ menubar.app

24 pt on top of every screen, the wallpaper showing through. On the left the angelOS emblem (About This Computer,
System Settings, Force Quit, Sleep, Restart, Shut Down, Lock, Log Out), the app's name in bold and **its own menus** —
Qt apps over dbusmenu, GTK 3 through `appmenu-gtk-module`, GtkApplication actions, and a standard set built from the
app's own shortcuts for the rest (nothing dead in the menus: what cannot be done is not there). On the right: sound,
layout, Wi-Fi and Bluetooth when there are any, the tray, Spotlight, **Control Center** and the date.
`Ctrl`+`F2` walks the menus from the keyboard.

![The menu bar: an app's menus, Control Center, Notification Center](docs/demo/macos-menubar.gif)

### ♡ dock.app

A Liquid Glass slab at the bottom: the pinned apps, *Applications*, the recent ones after a divider, **minimized
windows**, Downloads and the Trash. A dot under running apps, a tooltip over the icons, a right-click menu (the app's
windows, the actions from its `.desktop` file, *Keep in Dock*, *Open*, *Quit*; *Empty* on the Trash),
**magnification** like on a Mac (the icon under the pointer grows, its neighbours follow a cosine curve, and the Dock
widens both ways so the icon stays under your pointer) and auto-hide. Icons come from
[MacTahoe](https://github.com/vinceliuice/MacTahoe-icon-theme) (GPL-3.0, downloaded at a pinned release and checked
with sha256; only the Dock reads it).

![The Dock: magnification, a right-click menu, minimizing a window and bringing it back](docs/demo/macos-dock.gif)

### ♡ minimize.app

niri has no minimizing — it throws the request away — so angelOS does it: the window goes to a hidden workspace on
the same monitor and a **snapshot of it lands on the right of the Dock** with the app's icon in the corner. Minimize
with the yellow light (in title bars angelOS draws and, through `extras/minimize-hook`, in GTK/Qt apps' own), *Window →
Minimize*, `⌘M`, or `angelos macMinimize`; bring it back with a click on the snapshot, on the app's icon, in Alt+Tab or
in niri's overview. Leaving the theme brings every minimized window back to the desktop.

### ♡ spotlight.app ✧ controlcenter.app

`⌘Space` opens **Spotlight**: a dark glass capsule for apps, files, actions and the clipboard, the best hit
highlighted. **Control Center** has the macOS layout — Wi-Fi and Bluetooth next to *Now Playing*, Screen Recording,
Mission Control, Lock, Dark Mode, Screenshot, Do Not Disturb, the Display and Sound sliders (what the machine lacks is
not shown). A click on the date opens the **Notification Center**; banners arrive in the top right.

![Spotlight and Control Center](docs/demo/macos-spotlight.gif)

### ♡ liquidglass.app

The glass of the menus, the Dock, Control Center, notifications, Spotlight, ⌘Tab and the desktop widgets is three
layers: **blur and saturation from niri 26.04** (`background-effect`, only under the glass, windows included),
a **tint** from clear to tinted (*Settings → Appearance → Liquid Glass*), and a **lens edge** — a dark rim, a highlight
stronger towards the light and a thin band of “gathered” light with a touch of colour split — drawn by
[`shaders/liquid_glass.frag`](.config/quickshell/angelos/shaders/liquid_glass.frag). *Reduce transparency* makes it
solid; `niri-game-mode` does the same while a game covers the screen.

### ♡ sounds.app

Notification, error, the volume “pop”, the screenshot shutter, emptying the Trash, USB in/out, charger in, lock and
log-in — **our own sounds**, synthesised by `scripts/mac-sounds.py` (CC0), quiet enough to sit under music. A file with
the same name in `~/.local/share/angelos/sounds/macos/` plays instead, so you can bring the sounds of your own Mac.
Settings → Sound → *Sound effects*: on/off, volume, the volume-change sound, a preview of each.

### What is not Apple

The repository is public and holds no file of Apple's: an angelOS emblem instead of the apple, **Inter** (SIL OFL)
instead of SF Pro (downloaded at a pinned commit; SF Pro is never shipped), Lucide icons, **MacTahoe** Dock icons
(GPL-3.0), the **`macOS` cursor** of [ful1e5/apple_cursor](https://github.com/ful1e5/apple_cursor) (GPL-3.0, redrawn in
SVG), synthesised sounds and generated wallpapers.

---

## ✧ game.exe

angelOS is also a game played over your real desktop: an angel lives in the corner and what happens next depends on
your choices. It may scare you, but it never harms: it doesn't touch your files, sends nothing anywhere and never reads
your windows, browser or chats. The lock screen, power menu, volume, notifications and polkit always work. Both looks
play it — in hell, the Dock and the menu bar turn to obsidian glass and blood.

- **Out at once, any time:** `angelos game off` or **`Mod`+`Ctrl`+`Shift`+`Esc`** — angelOS stays as plain dotfiles;
  `angelos game on` brings it back. The installer asks (`ANGELOS_GAME=0|1`).
- **Motion:** `angelos motion full|calm|off` — *calm*: no flashes, shaking or sudden loud sounds; *off*: no animations.
- Progress lives in `~/.config/angelos/save.json` (updates never touch it). How it works inside, **with spoilers**:
  [`docs/STORY.md`](.config/quickshell/angelos/docs/STORY.md).

<img src="docs/screenshots/angelos-hell.png" width="80%" alt="The desktop after the angel was thrown down">

---

## ✧ plugins.exe

A plugin is a folder with a `manifest.json` that can add right-click items, bar and desktop widgets, launcher
providers, a settings page and a background service. Guide:
[`docs/PLUGINS.md`](.config/quickshell/angelos/docs/PLUGINS.md).

- **Community Plugins** — one catalog in **Settings → Plugins** (and `plugins …` in the launcher): the approved entries
  of the [angelOS community registry](https://github.com/futureUnd1ground/angelos-community-registry) next to what you
  have, with install, update and **roll back**. Updates are checked once a day; before each one the installed copy
  becomes a snapshot, and a plugin that does not load goes back to it by itself.
- **Plugin Studio** — with *Developer mode* on, describe a plugin, answer its questions, and Studio writes themed QML
  with your own OpenAI or Anthropic key, shows the files and checks them before you install
  ([guide](.config/quickshell/angelos/docs/PLUGIN_STUDIO.md)).

| Built in | What it does |
| --- | --- |
| `cat` | A pixel cat on the bar: asleep, walking or running with the CPU load |
| `speedtest` | Internet speed test with a pixel speedometer and history |
| `web-search` | `web …` in the launcher: search engines and favourite sites |
| `claude-companion` | What is left of your Claude plan, live Claude Code sessions, `claude …` in the launcher |
| `codex-companion` | The same for OpenAI Codex: 5-hour and weekly windows, today's tokens, live sessions, `codex …` in the launcher |
| `osu-mini` | An osu!-style mini game: pixel hearts on the beat, combos, ranks (Start → Mini game, `osu` in the launcher) |
| `nightlight` | A warm screen in the evening through `wlsunset` |
| `stream-stats` | NGO-style `stats.exe`: stress = CPU, darkness = RAM, love = uptime |
| `quick-actions` | Extra right-click items |

![Community Plugins: the catalog, installing a plugin, its widget on the desktop](docs/demo/plugins.gif)

---

## ✧ tiling.exe

Windows live in columns on an infinite horizontal strip: new ones open to the right, focus scrolls the view, columns
can be resized, centred, stacked, turned into tabs or popped out as floating windows. `Mod`+`Tab` (pixel) or
`Ctrl`+`↑` / `F3` (macOS) zooms out to every workspace at once. In the macOS theme new windows float like on a Mac, and
the tiling keys move to `Super`+`Alt`.

![Scrollable tiling](docs/demo/tiling.gif)

![Overview of every workspace](docs/demo/overview.gif)

Forgot a key? `Mod`+`Shift`+`Esc` opens niri's hotkey overlay — every bind has a readable title.

![Hotkey overlay](docs/demo/hotkeys.gif)

---

## ✧ Keybindings

Each look has its own key profile: [`keybinds.kdl`](.config/niri/cfg/keybinds.kdl) only picks one —
[`keybinds-common.kdl`](.config/niri/cfg/keybinds-common.kdl) (both looks) plus
[`keybinds-pixel.kdl`](.config/niri/cfg/keybinds-pixel.kdl) or [`keybinds-macos.kdl`](.config/niri/cfg/keybinds-macos.kdl),
switched with the look in one validated step. Settings → Keyboard edits the profile in front.

### Both looks

| Keys | Action |
| --- | --- |
| `Mod`+`T` | Terminal (kitty) |
| `Mod`+`B` | Default browser |
| `Mod`+`E` | Files (Nautilus) |
| `Mod`+`V` | Clipboard history |
| `Mod`+`S` / `Mod`+`Alt`+`S` | Settings |
| `Mod`+`Shift`+`Return` | Wallpaper picker |
| `Mod`+`Shift`+`Q` | Power menu |
| `Mod`+`Alt`+`T` / `Mod`+`Alt`+`Y` | Light ⇄ dark / lyrics on-off |
| `Mod`+`Shift`+`S` | Screenshot a region (“gravity ropes”) |
| `Mod`+`Shift`+`R` | Record a region (toggle) |
| `Mod`+`Shift`+`V` | Voice dictation (toggle) |
| `Mod`+`Shift`+`X` | Screencast privacy: chats and password managers go black on the stream |
| `Ctrl`+`Shift`+`2` / `3` | Screenshot the screen / the window |
| `Mod`+`Shift`+`←→↑↓` | Focus another monitor (`+Ctrl`: move the column there) |
| `Mod`+`Shift`+`P` | Monitors off |
| `Alt`+`Tab` | angelOS's window switcher |
| `Mod`+`Alt`+`=` / `-` / `0` | Lens: zoom in / out / close |
| `Mod`+`Esc` | Release a fullscreen app's keyboard grab |
| `Mod`+`Ctrl`+`Shift`+`Esc` | Out of the game at once |
| `Ctrl`+`Alt`+`Delete` | Quit niri |

Media and volume keys go to `angelos …` (a small OSD shows the level) and keep working on the lock screen.

### Pixel

| Keys | Action |
| --- | --- |
| `Mod`+`Space` | Launcher |
| `Mod`+`Q` | Close window |
| `Mod`+`Alt`+`L` | Lock screen |
| `Mod`+`H` / `Mod`+`L` (or arrows) | Focus column left / right (`+Ctrl`: move it) |
| `Mod`+`J` / `Mod`+`K` | Focus window down / up |
| `Mod`+`1`…`9` / `Mod`+`Ctrl`+`1`…`9` | Go to workspace / move the column there |
| `Mod`+`O` | Previous workspace |
| `Mod`+`Tab` | Overview |
| `Mod`+`R` / `Mod`+`Alt`+`R` | Next / previous column width |
| `Mod`+`C` | Centre column |
| `Mod`+`[` / `Mod`+`]` | Pull a window into the neighbouring column, or push it out |
| `Mod`+`W` | Tabbed column |
| `Mod`+`Shift`+`Space` | Floating ⇄ tiled |
| `Mod`+`F` / `Mod`+`Shift`+`F` / `Mod`+`M` | Fullscreen / maximise column / maximise to the edges |
| `Mod`+`-` / `Mod`+`=` | Column narrower / wider |
| `Mod`+`Shift`+`T` | OCR a region to the clipboard |

### macOS (⌘ = `Super`)

The ⌘ keys are offered, never imposed: the installer asks (`MAC_KEYS=1|0`), and *Settings → Appearance → Golden Gate*
turns them on or off. Without them the macOS look keeps the pixel keys.

| Keys | Action |
| --- | --- |
| `⌘Space` | Spotlight |
| `⌘Q` | Quit the app in front (its own *Quit*, else all its windows) |
| `⌘W` | Close window |
| `⌘M` | Minimize to the Dock |
| `⌘H` | Hide the app |
| `⌘Tab` / `⌘⇧Tab` | Switch apps |
| `` ⌘` `` | Next window of the same app |
| `⌘,` | System Settings |
| `⌘⇧3` / `⌘⇧4` / `⌘⇧5` | Screenshot: screen / area / the screenshot menu |
| `⌃⌘F` | Fullscreen |
| `⌃⌘Q` | Lock screen |
| `⌥⌘Esc` | Force Quit |
| `⌃←` / `⌃→` | Workspace left / right |
| `⌃↑`, `F3` | Mission Control (overview) |
| `⌃F2` | The menu bar from the keyboard |
| `⌘⌥Space` | angelOS's launcher |
| `⌘⌥` + `H J K L` / arrows, `1`…`9`, `R`, `C`, `F`, `W` | Tiling: the pixel keys, one `Alt` further |

Inside apps, their own shortcuts stay theirs (`Ctrl`+`C`, `Ctrl`+`V`), and the menus label them that way.

---

## ✧ terminal.exe

- **fish** is the login shell (the installer asks; `FISH_DEFAULT=0` keeps yours) with the look from the screenshots:
  the **pure** prompt, **fastfetch** with angelOS's logo as the greeting, **eza** for `ls`, **fzf**, *done* and
  *autopair*. On CachyOS this is `cachyos-fish-config`; on Arch the same comes from `packages/fish.txt` and fisher.
- **kitty**, **foot** and **Alacritty** wear the angelOS palette (heaven and hell), **btop** and **fastfetch** too.
- **Neovim** with [LazyVim](https://lazyvim.github.io): the plugins install themselves on the first start, the colours
  follow the terminal. It goes in only where `~/.config/nvim` is not there yet — your own config is never mixed with it.
- `n` opens Neovim; `angelos …` is on the `PATH`.

---

## ✧ Helper tools

Installed to `~/.local/bin`, plain Bash/Python on `grim`, `slurp`, `wf-recorder`, `tesseract` and `wl-clipboard`.

| Command | What it does |
| --- | --- |
| `niri-screenshot-region` | Region screenshot with a pixel “gravity ropes” overlay, saved to `~/Pictures/Screenshots` |
| `niri-record-region` | Toggle a region recording to `~/Videos` (`NIRI_RECORD_FPS`, `NIRI_RECORD_CODEC`, `NIRI_RECORD_CRF`) |
| `niri-ocr` / `niri-ocr-region` | A region's text to the clipboard (every installed Tesseract language; `-region` in a stone-block frame) |
| `niri-cast-privacy` | `block-out-from "screencast"` for Telegram, Bitwarden, Helium and Discord: your screen stays, the stream sees black |
| `niri-game-mode` | A user service: no animations, blur or glass while a window covers an output |
| `polkit-agent-guard` | Keeps a polkit agent registered: the shell's, else `hyprpolkitagent` — a password dialog always comes |
| `voxtype-indicator` | The classic dictation indicator for [Voxtype](https://github.com/peteonrails/voxtype) |

---

## ✧ installer.exe

```bash
git clone https://github.com/MixaDoDs/AngelOS-Dotfiles.git
cd AngelOS-Dotfiles
./install.sh
```

One command. On a terminal it goes live: a pastel **stream** in the terminal drawn with
[gum](https://github.com/charmbracelet/gum) — pixel frames, menus you tick with the space bar, a
**progress bar of hearts** and a chat that comments on your install. gum comes from the official repositories and is
installed before the first question (or say no, and you get plain numbered prompts).

![The installer: profile, theme, apps, layouts and the hearts progress bar](docs/demo/installer.gif)

What it asks (English, or Russian when your locale is `ru_*`):

1. **Profile** — `full` (the whole look) or `tech` (niri config and helper tools only).
2. **Shell** — **angelOS** (default), Noctalia, or none.
3. **Theme** — **Pixel** or **macOS**, and with macOS whether you want the **⌘ keys**.
4. **The game** — angelOS as a game, or plain dotfiles.
5. **Wallpapers** — packs from [PixelStreetArt_Wallpapers](https://github.com/MixaDoDs/PixelStreetArt_Wallpapers),
   only the ticked folders are fetched.
6. **fish** — when it is not installed: install it with its look and make it the login shell (`/etc/shells`, `chsh`).
7. **The apps from the screenshots** — Helium, Telegram, Spotify, Obsidian, qView, mpv, LocalSend, Discord (Flathub);
   all ticked, untick what you don't want.
8. **Voice input** (Voxtype + a ~1.6 GB Whisper model), the **SDDM login screen**, the **everyday tools**.
9. **Keyboard** — tick your layouts, pick the one active after login and the switch shortcut.

Then it installs, with a backup of everything it replaces (`name.bak.YYYYMMDD-HHMMSS`), validates niri's config and
says what is next. Re-running is safe: unchanged files stay, files you (or angelOS's settings) changed are kept and
their new versions are parked in `~/.local/state/angelos/kept-updates/`. On the first login angelOS opens its setup
wizard — without the questions the installer already asked.

### Unattended

Every question has a variable, so it also runs with no terminal at all (`./install.sh --help` lists everything):

```bash
DOTFILES_MODE=full DESKTOP_SHELL=angelos ANGELOS_THEME=macos MAC_KEYS=1 \
KB_LAYOUTS="us ru" KB_TOGGLE=alt_shift WALLPAPER_PACKS=Pixel \
FISH_DEFAULT=1 INSTALL_APPS=1 APPS=helium,telegram,discord \
INSTALL_VOXTYPE=0 INSTALL_SDDM=1 ./install.sh
```

| Variable | Values | |
| --- | --- | --- |
| `DOTFILES_MODE` | `full` \| `tech` | the profile |
| `DESKTOP_SHELL` | `angelos` \| `noctalia` \| `none` | the shell |
| `ANGELOS_THEME` | `pixel` \| `macos` | the look (unattended: left as it is unless given) |
| `MAC_KEYS` | `1` \| `0` | the ⌘ keys with the macOS look |
| `ANGELOS_GAME` | `1` \| `0` | the game |
| `FISH_DEFAULT` | `1` \| `0` | fish as the login shell (an installed fish is left alone unless `1` is given) |
| `INSTALL_APPS`, `APPS` | `0`/`1`, `all` \| `helium,telegram,…` | the apps from the screenshots (unattended default: none) |
| `WALLPAPER_PACKS` | `all` \| `none` \| `Lain,Pixel,…` | wallpaper packs |
| `KB_LAYOUTS`, `KB_TOGGLE` | `us,ru`, `alt_shift` \| `ctrl_shift` \| `caps` \| `ralt` \| `lalt` \| `grp:…` | keyboard |
| `INSTALL_VOXTYPE`, `DOWNLOAD_VOXTYPE_MODEL` | `1` \| `0` | voice input |
| `INSTALL_SDDM` | `1` \| `0` | the login screen |
| `INSTALL_TOOLS`, `INSTALL_FLATPAK` | `1` \| `0` | everyday tools, Flathub extras |
| `CACHYOS_REPOS` | `1` \| `0` | Arch Linux: add the author's repositories first — CachyOS's (for your CPU, above Arch's) and `[multilib]`, so Helium, qView, LocalSend and Steam install with pacman |
| `SKIP_PACKAGES` | `0` \| `1` | configs only: no pacman, no sudo |
| `OVERWRITE_CONFIGS` | `0` \| `1` | also replace configs you changed (with a backup) |
| `ENABLE_SERVICES`, `VALIDATE_NIRI` | `1` \| `0` | user services, `niri validate` |
| `NO_TUI`, `NO_ANIM` | `1` | plain prompts, no boot animation |

### Requirements

- **Arch Linux or CachyOS** (refused elsewhere before a file changes; `DOTFILES_FORCE_DISTRO=1` at your own risk).
  The packages of the rice come from Arch's official repositories ([`scripts/check-packages.sh`](scripts/check-packages.sh)
  asks archlinux.org); a few looks and apps live only in CachyOS's repositories (`cachyos-fish-config`, Helium, qView,
  LocalSend) — on Arch the installer skips them and says so. No AUR.
- A Wayland session, `sudo`, `git`, `curl`.

`./scripts/check.sh` checks the repository and runs the installer end to end against throw-away home directories —
it never touches your real configuration. `./scripts/ci-local.sh` runs the GitHub check in the same `archlinux`
container.

---

## ✧ Updating

**Settings → Updates** checks the repository you installed from, shows what is new and, on a click, runs `git pull`
and the installer without packages. Before anything changes, every file the installer may write is copied to
`~/.local/state/angelos/backups/<date>-update/`; an update counts only when the installer, the niri wiring and
`niri validate` all pass, and otherwise the page offers **Restore the state before the update**. A running angelOS
asks whether to restart the shell now or later (windows stay open). From a terminal: `git pull && ./install.sh`.

## ✧ Login screen (SDDM)

The installer sets up [SDDM](https://github.com/sddm/sddm) with **pixel-cyberpunk**, an animated pixel-art theme from
[Qylock](https://github.com/Darkkal44/qylock) by Darkkal44: a looping video background, a pixel font, clock, user and
session switchers.

![SDDM login screen with the pixel-cyberpunk theme](docs/screenshots/sddm-login.png)

`INSTALL_SDDM=1` installs `sddm` and exactly the Qt modules the theme imports, copies the theme, selects it in
`/etc/sddm.conf.d/zz-pixelstreetart.conf` (a `Current=` in `/etc/sddm.conf` is commented out with a backup), enables
`sddm.service` (asking first when another login manager is on) and boots into `graphical.target`. Preview it:
`sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/pixel-cyberpunk`.

| Symptom | Fix |
| --- | --- |
| Boots to a text console | `sudo systemctl enable --force sddm && sudo systemctl set-default graphical.target` |
| `display-manager.service already exists` | disable the other one (`gdm`, `lightdm`, `ly@tty2`, `greetd`), then enable SDDM |
| Plain SDDM instead of the pixel theme | `grep -r Current= /etc/sddm.conf /etc/sddm.conf.d/`; install `qt6-5compat` |
| Black background | `sudo pacman -S qt6-multimedia qt6-multimedia-ffmpeg` |

## ✧ Keyboard, mouse and monitors

- **Layouts** go into [`~/.config/niri/cfg/input.kdl`](.config/niri/cfg/input.kdl); they also pick the Voxtype language
  and the OCR language packs. Change them later in Settings → Keyboard & mouse; `niri msg keyboard-layouts` shows what
  is active. Win+Space is never offered: `Mod`+`Space` opens the launcher (Spotlight on macOS).
- **Mouse**: libinput defaults, because every mouse is different; tune it in Settings → Keyboard & mouse.
- **Monitors**: `~/.config/niri/monitor.kdl` starts empty, so niri auto-detects your outputs. Settings → Display writes
  it — resolution, the exact refresh rate niri lists, scale, rotation, position — names the monitors by
  “Make Model Serial” (a renamed connector still matches) and makes sure niri reads it first, so 144 Hz stays 144 Hz
  after a reboot. The installer never overwrites it.

## ✧ Repository layout

```text
.config/quickshell/angelos/  angelOS: the shell, both looks, plugins, templates, docs
.config/niri/                niri: config, key profiles (common / pixel / macos), rules, animations
.config/                     fish, kitty, foot, Alacritty, GTK, btop, fastfetch, Neovim, Noctalia, Voxtype
.local/bin/                  helper tools
.local/share/                the pixora icon theme and pixel fonts
Pictures/                    the default wallpapers (the packs live in PixelStreetArt_Wallpapers)
packages/                    pacman.txt, angelos.txt, sddm.txt, tools.txt, fish.txt, nvim.txt, apps*.txt, flatpak-apps.txt
installer/tui.sh             the installer's face: gum menus, pixel frames, hearts, the stream chat
install.sh                   the installer: asks everything, backs up, Arch Linux / CachyOS only
scripts/check.sh             repository check, with end-to-end installer tests
sddm/                        the pixel-cyberpunk SDDM theme and its drop-in
docs/                        screenshots and the GIFs of this README
```

## ✧ Notes

- No credentials, API keys, tokens, browser profiles, cookies, history, caches, keyrings or runtime state are in the
  repository, and `scripts/check.sh` fails if one ever slips in. Your angelOS settings (`~/.config/angelos`) are yours.
- Wallpaper packs are a separate repository and optional.
- niri's config syntax changes between releases; check the niri documentation if an option is rejected.

## ✧ License

The dotfiles and angelOS are released under the **MIT license** — see [`LICENSE`](LICENSE), © 2026 MixaDoDs.

Parts made by others keep their own licenses, listed in [`THIRD-PARTY.md`](THIRD-PARTY.md): the SDDM theme from
[Qylock](https://github.com/Darkkal44/qylock) (GPL v3, unmodified), the fonts (SIL OFL 1.1 —
[`LICENSES/OFL-1.1.txt`](LICENSES/OFL-1.1.txt); Cozette: MIT), the `pixora` icons and HackerNoon's pixel icons
(CC BY 4.0), pixelarticons (MIT), Lucide (ISC), and the Claude Companion plugin, a port of
[lowcache/noctalia-claude-plugin](https://github.com/lowcache/noctalia-claude-plugin) (MIT). MacTahoe, Inter and the
`macOS` cursor are downloaded when the macOS look is first turned on, under their own licenses — never shipped here.

<div align="center">

`♡ thank you for watching the stream ♡`

</div>
