<div align="center">

<img src="docs/readme/footage/header.svg" width="100%" alt="A VHS playback screen: PLAY, a blinking REC dot, the date 31.12.2002 and a running timecode; the word angelOS jumps in a red and blue glitch; RECOVERED MEDIA · 12 TAPES · CASE #0031-12">

**English** · [Русский](README.ru.md)

![tape](https://img.shields.io/badge/tape-03%20·%20Uriel%20(Beta)-ff5cad?style=flat-square&labelColor=241432)
![niri](https://img.shields.io/badge/niri-26.04-4fe3ff?style=flat-square&labelColor=241432)
![quickshell](https://img.shields.io/badge/quickshell-0.3-b36bff?style=flat-square&labelColor=241432)
![cachyos](https://img.shields.io/badge/CachyOS%20%2F%20Arch-♡-ffb3d9?style=flat-square&labelColor=241432)
![license](https://img.shields.io/badge/license-MIT-57e3a2?style=flat-square&labelColor=241432)
![signal](https://img.shields.io/badge/signal-lost-ff5cad?style=flat-square&labelColor=241432)

</div>

```text
CASE ............. #0031-12
RECOVERED ........ 01.01.2003, 04:12, from a flat on the fourth floor
ITEMS ............ 1 × desktop tower, smoke damage to the case, drive intact
                   1 × camcorder, tape still inside
                   1 × CD-R, marker on the label: "SAVE YOURSELF"
                   1 × scrap of lined paper, three lines on it
                   12 × VHS-C tapes, numbered by hand
CONDITION ........ the drive still boots
```

<img src="docs/readme/footage/stamp-evidence.svg" width="260" align="right" alt="A red rubber stamp: EVIDENCE · DO NOT ERASE">

> **ARCHIVIST'S NOTE.** What follows is the tapes in the order they were numbered, transcribed by us, with stills
> pulled from the drive. The camcorder's clock was never set, so every timecode says December 2002; ignore it. We
> left the transcripts as they are. Where the tape is damaged it says so. Where something was blacked out, it was
> blacked out before it reached us.
>
> The drive boots into a desktop for **CachyOS / Arch** on [**niri**](https://github.com/YaLTeR/niri), with a shell
> written on [**Quickshell**](https://quickshell.org). We copied it here, all of it, so you can run it yourself.
> We did. It is fine. Mostly.

<img src="docs/screenshots/pixel-dark.png" width="100%" alt="Still from the drive, at night: the Win98-style taskbar with pixel hearts, the clock, system monitor and music widgets, a terminal with fastfetch, and the release wallpaper with a ring in the sky over the water">

<sub>▶ <b>STILL 00</b> · the drive, first boot after recovery · nobody had touched the settings</sub>

> [!NOTE]
> Every still and clip on this page was re-shot by us on a clean install, in a nested niri session with a throw-away
> home: user `angel`, nobody's notifications, nobody's chats. In a nested session niri uses `Alt` as `Mod`; on real
> hardware `Mod` is **Super / Windows** (⌘ in the macOS look), and that is what the key tables say.

<div align="center">

**TAPE INDEX**

| | label on the sticker | | | label on the sticker |
| :-: | --- | --- | :-: | --- |
| [01](#tape-01) | *the note* · install | | [07](#tape-07) | *goldengate.app* · the macOS look |
| [02](#tape-02) | *two faces* · Pixel or macOS | | [08](#tape-08) | *someone in the corner* · the game |
| [03](#tape-03) | *the wallpaper breathes* | | [09](#tape-09) | *other people's things* · plugins |
| [04](#tape-04) | *i right-clicked* · menus, widgets | | [10](#tape-10) | *it looks after itself* · updates, reports |
| [05](#tape-05) | *everything is a setting* | | [11](#tape-11) | *what it runs on* · hardware |
| [06](#tape-06) | *windows on a strip* · niri, terminal | | [12](#tape-12) | *it is all here* · the repository |
| | | | [▤](#tape-keys) | *taped under the keyboard* · keys |

</div>

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-01"></a>
<img src="docs/readme/footage/tape-01.svg" width="100%" alt="TAPE 01 of 12. Label: the note. 20.12.2002, 23:41">

`[00:00:00]` *Black. The lens cap comes off. A desk lamp, a keyboard, a scrap of lined paper being flattened with the
side of a hand.*

`[00:00:06]` **VOICE (behind the camera):** "Three lines. Somebody on the forum said three lines and it asks the rest."

<div align="center">
<img src="docs/readme/install-note.png" width="640" alt="EVIDENCE: a torn scrap of lined paper: git clone the repository, cd into it, run install.sh. One command, it asks the rest.">

<sub>▶ <b>EVIDENCE 01-A</b> · the scrap of paper, as found under the keyboard</sub>
</div>

`[00:00:14]` *The camera tilts down to the terminal. He types it in.*

```bash
git clone https://github.com/MixaDoDs/AngelOS-Dotfiles.git
cd AngelOS-Dotfiles
./install.sh
```

`[00:00:31]` *The terminal turns pastel. A stream starts in it: pixel frames, menus ticked with the space bar, a
progress bar made of hearts, a little chat in the corner that comments on what is going on.*
([gum](https://github.com/charmbracelet/gum) draws it.)

![The installer: profile, look, apps, layouts and the hearts progress bar](docs/demo/installer.gif)

<sub>▶ <b>01 · 00:00:31 – 00:02:50</b> · the installer, recorded off the monitor</sub>

`[00:01:02]` **VOICE:** "It's asking me things." *He reads them out one by one. We wrote down what he answered.*

| `[01:02]` it asked | what was on the screen |
| --- | --- |
| Profile | `full` (the whole look) or `tech` (niri config and the helper tools only) |
| Shell | angelOS (default) or none |
| Look | **Pixel** or **macOS**, and with macOS whether to take the ⌘ keys |
| The game | angelOS as a game, or plain dotfiles (`ANGELOS_GAME=0\|1`) |
| Wallpapers | packs from [PixelStreetArt_Wallpapers](https://github.com/MixaDoDs/PixelStreetArt_Wallpapers), only the ticked folders |
| fish | install it with its look and make it the login shell (`FISH_DEFAULT=0` keeps yours) |
| Apps | the ones in the stills: Helium, Telegram, Spotify, Obsidian, qView, mpv, LocalSend, Discord |
| Extras | voice input (Voxtype + a Whisper model), the SDDM login screen, the everyday tools |
| Keyboard | layouts, which one is on after login, the switch shortcut |

`[00:02:50]` *The chat in the terminal says it backed everything up first* (`name.bak.YYYYMMDD-HHMMSS`), *ran*
`niri validate`, *and tells him what to do next.* **VOICE:** "Can I run it again?" *It says yes, that is safe.*

> **ARCHIVIST.** There is a second way in that does not ask anything: `INTERACTIVE=0` with the answers as environment
> variables (`PROFILE`, `ANGELOS_THEME`, `MAC_KEYS`, `KB_LAYOUTS`, `INSTALL_APPS` and the rest, listed at the top of
> `install.sh`). We used it for the re-shoots.

`[00:03:15]` *He logs in. The screen says it is finishing the install.*

`[00:03:19]` ░░░░░░░░ **TAPE DAMAGED** ░░░░░░░░ *about a minute is unreadable.* *On the frames we could recover:
something comes up from under the bottom edge of the screen. Then a cute little tune.* █████████████████

`[00:04:22]` *A setup wizard, as if nothing had happened. Language. Where he is coming from: Windows, a Mac, another
Linux, nothing. The game or just a desktop. Which screen is the main one, layouts, mouse, light or dark, a
wallpaper, how much should move. Then pixel circles walk him around the screen and say what each thing is.*

![The interface tips circling the start button, the workspaces and the clock](docs/demo/tips.gif)

<sub>▶ <b>01 · 00:04:22</b> · the tips. Settings → Account replays them, and the wizard</sub>

> **ARCHIVIST.** If the wizard ever hangs, `angelos setup skip` from a text console lets the desktop go at once.

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-02"></a>
<img src="docs/readme/footage/tape-02.svg" width="100%" alt="TAPE 02 of 12. Label: two faces. 21.12.2002, 14:05">

`[00:00:00]` *Daylight through the blinds. Same desk.* **VOICE:** "Yesterday it asked Pixel or macOS. I said pixel.
Let's see the other one."

`[00:00:08]` *Settings → Appearance. One click. The whole desktop changes face. Another click and it comes back,
and so does everything the look changed outside the shell: GTK, Qt, the cursor, niri's keys.*

| `[00:00:08]` | **Pixel** (angelOS) | **macOS** (Golden Gate) |
| --- | --- | --- |
| Panel | a Win98 taskbar: pixel-heart workspaces, window buttons, the **current lyric line** in the middle | a menu bar: the app's own menus, Control Center, Spotlight, the date |
| Apps | Start menu + launcher | a **Dock** with magnification, minimized windows, Downloads and Trash |
| Windows | pixel frames, 4 px corners, a thin accent outline | 16 px corners, shadows, traffic lights, **minimize to the Dock** |
| Glass | — | **Liquid Glass**: niri's blur under the shell, a lens edge drawn by a shader |
| Sounds | the Y2K pack | Mac-like system sounds (its own, CC0) |
| Keys | angelOS's (`Mod`+`Space`, `Mod`+`Q`…) | optional **⌘ keys**: ⌘Q ⌘W ⌘M ⌘Space ⌘Tab, tiling on `Super`+`Alt` |
| Font, cursor | pixel fonts, pixel cursors | Inter, the `macOS` cursor |

<img src="docs/screenshots/pixel-light.png" width="49%" alt="Still: the Pixel look by day, bubblegum palette, the Start menu open, the ophanim wallpaper from the first release"> <img src="docs/screenshots/macos-light.png" width="49%" alt="Still: the macOS look by day, the menu bar, the Dock, the Lake wallpaper">

<sub>▶ <b>STILLS 02-A, 02-B</b> · pixel.exe ✧ goldengate.app, one click apart</sub>

`[00:01:40]` *Music starts somewhere off-camera. The pixel bar types out the line that is being sung, like a stream
caption, and the old line slides up.* **VOICE:** "It knows the words."

> **ARCHIVIST.** Synced lyrics from [lrclib.net](https://lrclib.net) over MPRIS. Palettes on the tape: `bubblegum`,
> `overdose`, `cyber angel`, Gruvbox, Rosé Pine, Catppuccin, or colours pulled out of the wallpaper.

![The Pixel desktop: workspaces, windows, light and dark, the flavours](docs/demo/pixel-desktop.gif)

<sub>▶ <b>02 · 00:02:05</b> · the flavours, one after another</sub>

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-03"></a>
<img src="docs/readme/footage/tape-03.svg" width="100%" alt="TAPE 03 of 12. Label: the wallpaper breathes. 22.12.2002, 02:17">

`[00:00:00]` *The room is dark. Only the monitor. The camera is very close to the screen, you can see the pixels.*

`[00:00:11]` **VOICE (whispering):** "Watch the water."

`[00:00:15]` *The picture stays a picture, but parts of it move. Stars twinkle, one falls. The water ripples and
reflects them. A glint runs along the ring in the sky. A pebble drops off the cliff and rings spread on the water.*

![The wallpaper at night: stars, ripples on the water, a glint running over the ring, rings on the water](docs/demo/live-wall.gif)

<sub>▶ <b>03 · 00:00:15</b> · nothing was edited. it does this by itself</sub>

`[00:01:10]` *He opens a window over it, full screen. Closes it. The water had stopped while it was covered.*
**VOICE:** "It holds its breath when you're not looking."

> **ARCHIVIST.** The shell looks at the picture and finds the sky, the water, the clouds, the thing in the sky, and
> moves only those; it goes still under a full-screen window and costs almost nothing. *Settings → Wallpaper →
> Alive* switches the layers one by one. A picture can carry a hint next to it (`picture.scene.json`: which part is
> sky, which is water, where the ring is); pictures without one get the automatic look.

`[00:02:30]` *He scrolls through a folder: `~/Pictures/AngelOS/`. Every release came with its own wallpapers, drawn
for it, each in a day and a night version. The shell picks day or night by the theme and the shape by the monitor:
16:9, 21:9, or 9:16 when the screen is turned on its side.*

<div align="center">
<img src="docs/readme/release-01-angel.png" width="100%" alt="Release 01 Angel: Feathers, Lake, Ophanim, Wires; day over night">
<img src="docs/readme/release-02-archangel.png" width="75%" alt="Release 02 Archangel: Dead, Life, Numb; day over night">
<img src="docs/readme/release-03-uriel-beta.png" width="66%" alt="Release 03 Uriel (Beta): the edge of the world, in 16:9, 9:16 and 21:9; day over night">

<sub>▶ <b>EVIDENCE 03-A</b> · contents of <code>~/Pictures/AngelOS/</code>, releases 01 Angel · 02 Archangel · 03 Uriel (Beta), day over night</sub>
</div>

`[00:03:02]` `Mod`+`Shift`+`Return`. *A picker: one picture for every screen, one per monitor, one per workspace.
Changing it plays a pixel mosaic with a dither. Only when the picture changes; switching workspaces stays instant.*

![The pixel mosaic transition between the wallpapers of the three releases](docs/demo/wallpaper.gif)

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-04"></a>
<img src="docs/readme/footage/tape-04.svg" width="100%" alt="TAPE 04 of 12. Label: i right-clicked. 22.12.2002, 19:30">

`[00:00:00]` **VOICE:** "Okay. Right-click on the desktop."

`[00:00:03]` *A menu. He closes it, changes something in the settings, right-clicks again. A different menu. He does
it again. And again.*

![The right-click menu in its six looks: list, radial, Y2K bubble, tiles, wings, harp](docs/demo/menu-styles.gif)

<sub>▶ <b>04 · 00:00:03 – 00:01:20</b> · list · ring · Y2K bubble · Control Center tiles · wings · harp</sub>

`[00:01:21]` **VOICE (counting on fingers):** "Six." *Pause.* "The settings page says six. The file has seven."

`[00:01:25]` ░░░░ *the seventh one is on the tape for eleven frames. We are not printing them.* ░░░░

> **ARCHIVIST.** Whatever it looks like, the menu holds the same things: quick actions on top, **View ▸** (widgets,
> edit mode, snap to grid), **New ▸** (note, screenshot, recording), **Open ▸** (folders), display settings,
> personalisation, *Open in Terminal*, and **Show more options ▸** for what the plugins add. What is in it, in what
> order, your own items: *Settings → Right-click menu*.

![The Windows 11-style menu adding a widget to the desktop](docs/demo/menu.gif)

<sub>▶ <b>04 · 00:02:40</b> · he puts a widget on the wallpaper</sub>

`[00:02:40]` *Little windows on the wallpaper: `clock.exe`, `sysmon.exe` (CPU, GPU, RAM, VRAM, net), `cava.exe`,
`music.exe`. He drags one by its title bar. Double-clicks the title: edit mode. Around each one a pixel window, a
plate, or nothing.*

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-05"></a>
<img src="docs/readme/footage/tape-05.svg" width="100%" alt="TAPE 05 of 12. Label: everything is a setting. 23.12.2002, 11:52">

`[00:00:00]` *Most of this tape is the screen, filmed slowly, page after page. He talks over it like he is making a
list so he stops being surprised.* We kept the list.

![Settings: appearance, the bar layout, widgets, window widths, default apps](docs/demo/settings.gif)

<sub>▶ <b>05 · 00:00:00 – 00:14:51</b> · Settings, every page</sub>

<details>
<summary><b>▶ TRANSCRIPT 05 · 00:00:20 – 00:14:51</b> <sub>(his list, word for word)</sub></summary>

<br>

- `[00:00:20]` "**The bar.** Six shapes: a taskbar, a top bar, an island, a dock, capsules, *windose*. Any edge of
  the screen. You drag things around on it."
- `[00:02:11]` "**Settings itself** has four faces. Windows 11, a macOS sidebar, a Win98 Control Panel, Properties
  tabs." *(`angelos settingsView …`)* "It has search. It understands synonyms. It remembers what I searched."
- `[00:03:40]` "**Alt+Tab**, three styles: angelOS, NGO, Y2K. Or niri's own with live previews."
- `[00:04:02]` "**Switching workspaces**, thirteen animations." *He reads them:* soft, dash, spring, snap, zoom,
  card, wipe, fade, dissolve, glitch, CRT, realm, instant. "And a popup that says `workspace_N.exe`. And hearts."
- `[00:05:30]` "**The login screen**, five looks, a live preview, the same wallpaper as the desktop. **The lock
  screen**, two: a stream with a chat, or a gate in the sky."
- `[00:06:48]` "**fastfetch**, seven styles." *compact, angel, helper, receipt, stream, window, mini.* "Each one
  has its own sigil."
- `[00:07:30]` "**Fonts** by preset, pixel or not. **Cursors** pixel or `macOS`. **Sounds** in packs, Y2K,
  Overdose, macOS; on every click or never; quieter under music."
- `[00:09:12]` "**Windows:** width presets, a width per app, where new ones open." *Pause.* "And a cobweb grows on
  a window you haven't touched for hours. I didn't believe that one. Look." *He doesn't show it. The tape cuts.*
- `[00:11:05]` "**Display:** drag the screens around. The exact refresh rates niri lists, rotation, scale. Saved,
  so they're still there after a reboot."
- `[00:13:40]` "Every time it changes niri's config it makes a backup, runs `niri validate`, and puts it back if
  niri says no. The browsers follow the theme too." *(Helium and Chromium through GTK, Firefox through
  `userChrome.css`.)*

</details>

<img src="docs/screenshots/sddm-login.png" width="100%" alt="Still: the login screen in the pixel look, with the desktop's wallpaper">

<sub>▶ <b>STILL 05-A</b> · the login screen, as he left it</sub>

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-06"></a>
<img src="docs/readme/footage/tape-06.svg" width="100%" alt="TAPE 06 of 12. Label: windows on a strip. 24.12.2002, 21:08">

`[00:00:00]` **VOICE:** "The windows don't overlap. They stand in columns. On a strip. It goes on forever to the
right."

`[00:00:09]` *He opens one window after another; each new one opens to the right and the view scrolls after the
focus. He resizes a column, centres it, stacks two, turns them into tabs, pops one out floating.*
**VOICE:** "I thought I'd hate this." *Long pause.* "I don't."

![Scrollable tiling](docs/demo/tiling.gif)

`[00:01:30]` `Mod`+`Tab`. *The camera pulls back and so does the screen: every workspace at once.*

![The overview of every workspace](docs/demo/overview.gif)

`[00:02:15]` `Mod`+`Space`. *A launcher. Fuzzy search that learns what he opens. He types `web` and a search,
`plugins` and the catalog, `claude` and Claude Code, `>` and a shell command.*

![The launcher: apps, a web search, a shell command](docs/demo/launcher.gif)

`[00:03:01]` **VOICE:** "I forgot the key." `Mod`+`Shift`+`Esc`. *niri's overlay; every bind with a readable name.*

![The hotkey overlay](docs/demo/hotkeys.gif)

`[00:03:40]` *The terminal. It came dressed.*

> **ARCHIVIST.** **fish** with the pure prompt, fastfetch with the angelOS logo as the greeting, eza, fzf, done,
> autopair (on CachyOS this is `cachyos-fish-config`; on Arch the same comes from `packages/fish.txt` and fisher).
> **kitty**, **foot** and **Alacritty** wear the palette, so do **btop** and **fastfetch**. **Neovim** with
> [LazyVim](https://lazyvim.github.io) goes in only where `~/.config/nvim` is empty; an existing config is never
> touched. `n` opens it; `angelos …` is on the `PATH`.

<details>
<summary><b>▶ EVIDENCE 06-A</b> · <code>ls ~/.local/bin</code>, as found</summary>

<br>

| tool | what it does |
| --- | --- |
| `niri-screenshot-region` | a region, with pixel "gravity ropes" |
| `niri-record-region` | toggle a recording to `~/Videos` |
| `niri-ocr` | a region's text to the clipboard, every installed Tesseract language |
| `niri-cast-privacy` | chats and password managers go black on a stream |
| `niri-game-mode` | no animations, blur or glass while a game covers a screen |
| `polkit-agent-guard` | a password dialog always comes |
| `voxtype-indicator` | dictation |

Plain Bash and Python, all of them.

</details>

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-07"></a>
<img src="docs/readme/footage/tape-07.svg" width="100%" alt="TAPE 07 of 12. Label: goldengate.app. 25.12.2002, 16:44">

`[00:00:00]` *Christmas. Somebody else's voice in the next room, a TV. He has switched to the other face and is
showing it to the camera like a product.* **VOICE (mock announcer):** "macOS twenty-seven. *Golden Gate.*"

<img src="docs/screenshots/macos-dark.png" width="100%" alt="Still: the macOS look at night, the menu bar, Control Center open, the Dock, the Numb wallpaper with an eclipse">

<sub>▶ <b>STILL 07-A</b> · drawn from screenshots and Apple's guidelines, not from memory, and without a single file of Apple's</sub>

`[00:00:40]` *He points at things with a pen. We transcribed what he points at.*

- **`[00:00:40]` The menu bar.** 24 pt on top of every screen. On the left the angelOS emblem (About, Settings,
  Force Quit, Sleep, Restart, Shut Down, Lock, Log Out), the app's name in bold and **its own menus**: Qt apps over
  dbusmenu, GTK 3 through `appmenu-gtk-module`, GtkApplication actions, and a standard set built from the app's own
  shortcuts for the rest. "Nothing in the menus is dead. I checked." On the right: sound, layout, Wi-Fi and
  Bluetooth when there are any, the tray, Spotlight, **Control Center**, the date. `Ctrl`+`F2` walks the menus.
- **`[00:02:12]` The Dock.** A Liquid Glass slab: pinned apps, *Applications*, recent ones after a divider,
  **minimized windows**, Downloads, Trash. A dot under running apps, a right-click menu with windows and `.desktop`
  actions, **magnification** like on a Mac (the icon under the pointer grows, its neighbours follow a cosine, the Dock
  widens both ways so the icon stays under the pointer), auto-hide. Icons from
  [MacTahoe](https://github.com/vinceliuice/MacTahoe-icon-theme) (GPL-3.0, pinned release, sha256-checked).
- **`[00:03:30]` Minimize.** **VOICE:** "niri can't minimize. It throws the request away." *He clicks the yellow
  light. The window shrinks into the Dock as a snapshot.* "This one can." *(A hidden workspace. The yellow light,
  Window → Minimize, `⌘M`, or `angelos macMinimize`; back with a click on the snapshot, the icon, Alt+Tab or the
  overview.)*
- **`[00:04:15]` Spotlight** (`⌘Space`): a dark glass capsule for apps, files, actions, the clipboard. **Control
  Center** in the macOS layout: Wi-Fi, Bluetooth, *Now Playing*, Screen Recording, Mission Control, Lock, Dark Mode,
  Screenshot, Do Not Disturb, Display and Sound. The date opens the **Notification Center**.
- **`[00:05:02]` Liquid Glass.** *The camera goes right up to the edge of the Dock.* Three layers: niri 26.04's
  blur and saturation under the glass, a tint from clear to tinted, and a lens edge (a dark rim, a highlight
  stronger towards the light, a thin band of gathered light with a touch of colour split) drawn by
  [`shaders/liquid_glass.frag`](.config/quickshell/angelos/shaders/liquid_glass.frag). *Reduce transparency*
  makes it solid.
- **`[00:05:50]` Sounds.** *He plugs a USB stick in and out, three times, for the sound.* Notification, error, the
  volume pop, the shutter, emptying the Trash, USB in and out, charger, lock, log-in; synthesised by
  `scripts/mac-sounds.py`, CC0. Files with the same names in `~/.local/share/angelos/sounds/macos/` replace them.

![The menu bar: an app's menus, Control Center, the Notification Center](docs/demo/macos-menubar.gif)

![The Dock: a right-click menu, minimizing a window and bringing it back](docs/demo/macos-dock.gif)

![Spotlight and Control Center](docs/demo/macos-spotlight.gif)

> **ARCHIVIST.** We went through the drive for anything of Apple's. There is nothing. An angelOS emblem instead of the
> apple, **Inter** (SIL OFL) instead of SF Pro, Lucide icons, MacTahoe Dock icons (GPL-3.0), the `macOS` cursor
> from [ful1e5/apple_cursor](https://github.com/ful1e5/apple_cursor) (GPL-3.0), synthesised sounds, drawn
> wallpapers. MacTahoe, Inter and the cursor are downloaded the first time the look is turned on, under their own
> licenses. Pick it in the installer, in the wizard (*"Coming from a Mac?"*), in Settings → Appearance, or with
> `angelos settingsSkin goldengate`.

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-08"></a>
<img src="docs/readme/footage/tape-08.svg" width="100%" alt="TAPE 08 of 12. Label: someone in the corner. 26.12.2002, 03:33">

`[00:00:00]` *Night. The camera is on a pile of books, pointed at the bottom right corner of the screen. He is not
in the shot. He is whispering.*

`[00:00:05]` **VOICE:** "She's been there since the first login. Sitting on the bar."

`[00:00:12]` *A small pixel figure sits on the edge of the taskbar, legs over the side.*

`[00:00:40]` **VOICE:** "She talks. Not often. Not about nothing. She noticed when I opened six windows in a row.
She noticed I'd been at the screen four hours." *Pause.* "There are achievements. Chests. She has a diary. It has
a key, and I had to earn the key, and she minds" *[inaudible]* "...if I read it while she's around."

<img src="docs/screenshots/intro.png" width="100%" alt="Still from the damaged minute of tape 01: the screen split red and blue at the edges, something rising from below">

<sub>▶ <b>STILL 01-X</b> · the one frame we could recover from the damaged minute on tape 01</sub>

`[00:02:10]` *A disc spins up somewhere in the tower. A chime. Her lines come out in a little Undertale-style voice.*

`[00:02:30]` **VOICE:** "The lock screen can be a stream. With a chat that answers you. There's a mode for
streaming where she sits in the frame and reads the chat."

`[00:03:33]` █████████████████████████████████████████████████████████████
`[00:03:41]` ██████ **VOICE:** "...there's a floor under this one." ███████████████████████
`[00:04:02]` █████████████████████████████████████████████████████████████

> [!IMPORTANT]
> **ARCHIVIST.** Before we let anyone run the drive, we read the code. This is what we can say for sure:
> **it may scare you, but it never harms.** It does not touch your files, sends nothing anywhere, and never reads
> your windows, browser or chats. The lock screen, the power menu, volume, notifications and polkit always work,
> whatever is going on. Everything that flashes, shakes or gets loud has a *calm* switch.
>
> - **Out at once, any time:** `angelos game off`, or **`Mod`+`Ctrl`+`Shift`+`Esc`**. What stays is plain dotfiles:
>   she is gone, and the right-click menu loses its seventh look. `angelos game on` brings it back. The installer and
>   the wizard ask first.
> - **Motion:** `angelos motion full|calm|off`. *Calm*: no flashes, no shaking, no sudden loud sounds. *Off*: no
>   animations at all.
> - **Progress** lives in `~/.config/angelos/save.json`. Updates never touch it.
>
> About the lower floor we will only say that the Dock and the menu bar know about it too.

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-09"></a>
<img src="docs/readme/footage/tape-09.svg" width="100%" alt="TAPE 09 of 12. Label: other people's things. 27.12.2002, 20:20">

`[00:00:00]` **VOICE:** "Other people write things for it."

`[00:00:04]` *Settings → Plugins. A catalog: the approved entries of the
[angelOS community registry](https://github.com/futureUnd1ground/angelos-community-registry) next to what is already
installed. Install, update, **roll back**. He installs one. A widget appears on the desktop.*

![Community Plugins: the catalog, installing a plugin, its widget on the desktop](docs/demo/plugins.gif)

<sub>▶ <b>09 · 00:00:04</b> · the catalog. <code>plugins …</code> in the launcher opens the same</sub>

> **ARCHIVIST.** A plugin is a folder with a `manifest.json`. It can add right-click items, bar and desktop widgets,
> launcher providers, a settings page and a background service; the guide is
> [`docs/PLUGINS.md`](.config/quickshell/angelos/docs/PLUGINS.md). Updates are checked once a day; before each one
> the installed copy becomes a snapshot, and a plugin that does not load goes back to it by itself.
> With *Developer mode* on, **Plugin Studio** asks what the plugin should do, asks its questions back, writes themed
> QML with your own OpenAI or Anthropic key, shows the files and checks them before you install
> ([guide](.config/quickshell/angelos/docs/PLUGIN_STUDIO.md)).

| `[00:01:50]` already on the drive | what he said about it |
| --- | --- |
| `cat` | "A cat on the bar. It's asleep. Now it's walking. Now it runs, because the CPU is busy." |
| `speedtest` | an internet speed test with a pixel speedometer and a history |
| `web-search` | `web …` in the launcher: search engines and favourite sites |
| `claude-companion` | what is left of your Claude plan, live Claude Code sessions, `claude …` in the launcher |
| `codex-companion` | the same for OpenAI Codex: 5-hour and weekly windows, today's tokens, live sessions |
| `osu-mini` | "There's osu in it." On the beat: pixel hearts, combos, ranks (`osu` in the launcher) |
| `nightlight` | a warm screen in the evening through `wlsunset` |
| `stream-stats` | `stats.exe`: stress = CPU, darkness = RAM, love = uptime |
| `quick-actions` | extra right-click items |

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-10"></a>
<img src="docs/readme/footage/tape-10.svg" width="100%" alt="TAPE 10 of 12. Label: it looks after itself. 28.12.2002, 09:15">

`[00:00:00]` *Morning. Coffee on the desk.* **VOICE:** "It updated overnight. Well. It asked first."

`[00:00:07]` *Settings → Updates. What is new, the last run, a button.*

<img src="docs/screenshots/updates.png" width="100%" alt="Still: Settings → Updates, what is new, the last run, the restore button">

<sub>▶ <b>STILL 10-A</b> · if something goes wrong, the button at the bottom says <i>Restore the state before the update</i></sub>

> **ARCHIVIST.** It checks the repository it was installed from and, on a click, runs `git pull` and the installer
> without packages. Before anything changes, every file the installer may write is copied to
> `~/.local/state/angelos/backups/<date>-update/`. An update counts only when the installer, the niri wiring and
> `niri validate` all pass; otherwise the page offers the restore. A running angelOS asks whether to restart now or
> later; windows stay open. From a terminal: `git pull && ./install.sh`.

`[00:01:20]` **VOICE:** "I changed some things. It didn't overwrite them." *He reads off the screen:*

- a config he never changed follows the author on every update;
- one he changed gets the author's changes merged in, and where both changed the same lines, his stay (the old file
  next to it as `*.bak.<date>`); shortcuts merge key by key;
- files angelOS generates stay his, the new versions parked in `~/.local/state/angelos/kept-updates/`;
- his own lines go in `~/.config/fish/user.fish` and `~/.config/niri/cfg/user.kdl`, read last, never touched;
- after an update it *offers* the apps the author added to the groups he took. It never installs or removes
  anything by itself.

`[00:02:45]` *Settings → About → Report a problem.* **VOICE:** "If it breaks, this packs one archive."

<img src="docs/screenshots/report.png" width="100%" alt="Still: Settings → About, this computer, the angelOS version, report a problem">

> **ARCHIVIST.** `angelos report` does the same from a terminal: versions (angelOS, Quickshell, Qt, niri, kernel,
> GPU), the service state and restarts, what it costs, the log, the last crash reports, the niri config check,
> plugins and settings, with the personal bits taken out (the home path and user name become `~` and `<user>`;
> launcher history, workspace names and free texts are left out). **Nothing is sent anywhere.** The archive lands in
> `~/` with a link to a new issue, and you decide what to attach. A watchdog restarts the shell if it stops answering
> for fifteen seconds and keeps the crash report. The login screen keeps a backup of the previous theme. The
> installer never overwrites `monitor.kdl`.

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-11"></a>
<img src="docs/readme/footage/tape-11.svg" width="100%" alt="TAPE 11 of 12. Label: what it runs on. 30.12.2002, 22:47">

`[00:00:00]` *There is no tape for the 29th. This one is short and hurried. He films the back of the tower, the
cables, a laptop on the bed, a second monitor turned on its side, a gamepad.* **VOICE:** "Will it run on yours?
Probably. Listen."

| `[00:00:20]` | |
| --- | --- |
| **System** | CachyOS or Arch Linux. The installer appends only the `[cachyos]` repository where it is missing; Arch's own packages win. Steam's driver prompt no longer drags in anything exotic. |
| **GPU** | NVIDIA and AMD. The system monitor reads both; the Qt fixes for NVIDIA are in. |
| **Laptop** | battery and charge limit, eco mode, brightness and keyboard-light keys, touchpad direction and acceleration; in the wizard and in Settings, and only shown on a laptop. |
| **Monitors** | any number, any refresh rate (the exact one niri lists, so 144 Hz stays 144 Hz after a reboot), scale, rotation, portrait screens with 9:16 wallpapers, ultrawides with 21:9. Named by *Make Model Serial*, so a renamed connector still matches. |
| **Keyboards** | any layouts and the switch shortcut you choose; they also pick the dictation language and the OCR packs. ⌘ keys for people from a Mac, GTK window buttons for people from Windows. |
| **Languages** | English and Russian: the installer, the wizard, the shell, and her. |
| **Browsers** | Helium, Firefox, Chromium, Brave, Zen, LibreWolf, Vivaldi or Chrome; the wizard asks, `Mod`+`B` opens the default. |
| **Access** | UI size, motion, contrast, a lens (`Mod`+`Alt`+`=`), voice dictation, shake-to-find-the-cursor. Screen time, breaks, water: she does the reminding. |
| **Gamepads** | the shell knows yours, its buttons and axes. |
| **Streaming** | an OBS-aware stream mode, `niri-cast-privacy` for chats and password managers, a game mode that drops effects while a game covers the screen. |

`[00:02:58]` **VOICE:** "Tomorrow's the last one. I'll film all of it. Every file."

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-12"></a>
<img src="docs/readme/footage/tape-12.svg" width="100%" alt="TAPE 12 of 12, damaged. Label: it is all here. 31.12.2002, 23:58. The counter reaches 23:59:59 and the picture cuts to NO SIGNAL">

`[00:00:00]` *New Year's Eve. Fireworks somewhere far away, through the window. The camera pans slowly over a file
manager, folder by folder. He sounds happy.*

`[00:00:10]` **VOICE:** "It's all here. All of it. MIT. The dotfiles, the shell, the wallpapers."

```text
.config/quickshell/angelos/  angelOS: the shell, both looks, plugins, templates, docs
.config/niri/                niri: config, key profiles (common / pixel / macos), rules, animations
.config/                     fish, kitty, foot, Alacritty, GTK, btop, fastfetch, Neovim, Voxtype
.local/bin/                  helper tools
.local/share/                the pixora icon theme and pixel fonts
Pictures/AngelOS/            every release's wallpapers, with their scene hints
packages/                    pacman.txt, angelos.txt, sddm.txt, tools.txt, fish.txt, nvim.txt (the apps: data/apps-catalog.json)
installer/tui.sh             the installer's face: gum menus, pixel frames, hearts, the stream chat
install.sh                   the installer: asks everything, backs up, Arch Linux / CachyOS only
scripts/check.sh             the repository check, with end-to-end installer tests
scripts/demo/                the stand the stills and clips on this page were shot in
docs/                        the stills and clips of this page
```

`[00:00:58]` **VOICE:** "No passwords in it. No keys, no tokens, no browser stuff, no cookies, no history. There's a
check that fails if one ever gets in." *(`scripts/check.sh`, the same one GitHub runs; `scripts/ci-local.sh` runs it
in an `archlinux` container.)* "My settings stay mine." *(`~/.config/angelos`.)*

`[00:01:20]` **VOICE:** "If something's wrong, open an issue. Attach the report. Pull requests too."

`[00:01:31]` *The smell is mentioned for the first time.* **VOICE (away from the mic):** "...is that the
computer?" *[laughs]* "It's fine. It's always warm."

`[00:01:40]` ░░░░░░░░░░░░░░░░ *He saves something.* ░░░░░░░░░░░░░░░░

`[00:01:41]` **NO SIGNAL**

> **ARCHIVIST.** License: MIT, all of it, see [`LICENSE`](LICENSE), © 2026 MixaDoDs. Parts made by others keep their
> own licenses, listed in [`THIRD-PARTY.md`](THIRD-PARTY.md).

<img src="docs/readme/footage/divider.svg" width="100%" alt="">

<a id="tape-keys"></a>
<img src="docs/readme/footage/tape-keys.svg" width="100%" alt="APPENDIX. Label: taped under the keyboard">

> **ARCHIVIST.** Found when we turned the keyboard over: a folded sheet, taped down, in the same handwriting as the
> scrap of paper. Each look has its own key profile: [`keybinds.kdl`](.config/niri/cfg/keybinds.kdl) only picks one,
> [`keybinds-common.kdl`](.config/niri/cfg/keybinds-common.kdl) (both looks) plus
> [`keybinds-pixel.kdl`](.config/niri/cfg/keybinds-pixel.kdl) or [`keybinds-macos.kdl`](.config/niri/cfg/keybinds-macos.kdl).
> Settings → Keyboard edits the one in front.

<details>
<summary><b>▤ SHEET 1</b> · both looks</summary>

| Keys | Action |
| --- | --- |
| <kbd>Mod</kbd>+<kbd>T</kbd> | Terminal (kitty) |
| <kbd>Mod</kbd>+<kbd>B</kbd> | Default browser |
| <kbd>Mod</kbd>+<kbd>E</kbd> | Files (Nautilus) |
| <kbd>Mod</kbd>+<kbd>V</kbd> | Clipboard history |
| <kbd>Mod</kbd>+<kbd>S</kbd> / <kbd>Mod</kbd>+<kbd>Alt</kbd>+<kbd>S</kbd> | Settings |
| <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>Return</kbd> | Wallpaper picker |
| <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>Q</kbd> | Power menu |
| <kbd>Mod</kbd>+<kbd>Alt</kbd>+<kbd>T</kbd> / <kbd>Mod</kbd>+<kbd>Alt</kbd>+<kbd>Y</kbd> | Light ⇄ dark / lyrics on-off |
| <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> | Screenshot a region ("gravity ropes") |
| <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> | Record a region (toggle) |
| <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>V</kbd> | Voice dictation (toggle) |
| <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>X</kbd> | Screencast privacy: chats and password managers go black on the stream |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>2</kbd> / <kbd>3</kbd> | Screenshot the screen / the window |
| <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>←→↑↓</kbd> | Focus another monitor (+<kbd>Ctrl</kbd>: move the column there) |
| <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> | Monitors off |
| <kbd>Alt</kbd>+<kbd>Tab</kbd> | angelOS's window switcher |
| <kbd>Mod</kbd>+<kbd>Alt</kbd>+<kbd>=</kbd> / <kbd>-</kbd> / <kbd>0</kbd> | Lens: zoom in / out / close |
| <kbd>Mod</kbd>+<kbd>Esc</kbd> | Release a fullscreen app's keyboard grab |
| <kbd>Mod</kbd>+<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Esc</kbd> | **Out of the game at once** |
| <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>Delete</kbd> | Quit niri |

Media and volume keys go to `angelos …` (a small OSD shows the level) and keep working on the lock screen.

</details>

<details>
<summary><b>▤ SHEET 2</b> · Pixel</summary>

| Keys | Action |
| --- | --- |
| <kbd>Mod</kbd>+<kbd>Space</kbd> | Launcher |
| <kbd>Mod</kbd>+<kbd>Q</kbd> | Close window |
| <kbd>Mod</kbd>+<kbd>Alt</kbd>+<kbd>L</kbd> | Lock screen |
| <kbd>Mod</kbd>+<kbd>H</kbd> / <kbd>Mod</kbd>+<kbd>L</kbd> (or arrows) | Focus column left / right (+<kbd>Ctrl</kbd>: move it) |
| <kbd>Mod</kbd>+<kbd>J</kbd> / <kbd>Mod</kbd>+<kbd>K</kbd> | Focus window down / up |
| <kbd>Mod</kbd>+<kbd>1</kbd>…<kbd>9</kbd> / <kbd>Mod</kbd>+<kbd>Ctrl</kbd>+<kbd>1</kbd>…<kbd>9</kbd> | Go to workspace / move the column there |
| <kbd>Mod</kbd>+<kbd>O</kbd> | Previous workspace |
| <kbd>Mod</kbd>+<kbd>Tab</kbd> | Overview |
| <kbd>Mod</kbd>+<kbd>R</kbd> / <kbd>Mod</kbd>+<kbd>Alt</kbd>+<kbd>R</kbd> | Next / previous column width |
| <kbd>Mod</kbd>+<kbd>C</kbd> | Centre column |
| <kbd>Mod</kbd>+<kbd>[</kbd> / <kbd>Mod</kbd>+<kbd>]</kbd> | Pull a window into the neighbouring column, or push it out |
| <kbd>Mod</kbd>+<kbd>W</kbd> | Tabbed column |
| <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd> | Floating ⇄ tiled |
| <kbd>Mod</kbd>+<kbd>F</kbd> / <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>F</kbd> / <kbd>Mod</kbd>+<kbd>M</kbd> | Fullscreen / maximise column / maximise to the edges |
| <kbd>Mod</kbd>+<kbd>-</kbd> / <kbd>Mod</kbd>+<kbd>=</kbd> | Column narrower / wider |
| <kbd>Mod</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd> | OCR a region to the clipboard |

</details>

<details>
<summary><b>▤ SHEET 3</b> · macOS (⌘ = Super)</summary>

The ⌘ keys are optional: the installer asks (`MAC_KEYS=1|0`), and *Settings → Appearance → Golden Gate*
turns them on or off. Without them the macOS look keeps the pixel keys.

| Keys | Action |
| --- | --- |
| <kbd>⌘</kbd><kbd>Space</kbd> | Spotlight |
| <kbd>⌘</kbd><kbd>Q</kbd> | Quit the app in front (its own *Quit*, else all its windows) |
| <kbd>⌘</kbd><kbd>W</kbd> | Close window |
| <kbd>⌘</kbd><kbd>M</kbd> | Minimize to the Dock |
| <kbd>⌘</kbd><kbd>H</kbd> | Hide the app |
| <kbd>⌘</kbd><kbd>Tab</kbd> / <kbd>⌘</kbd><kbd>⇧</kbd><kbd>Tab</kbd> | Switch apps |
| <kbd>⌘</kbd><kbd>`</kbd> | Next window of the same app |
| <kbd>⌘</kbd><kbd>,</kbd> | System Settings |
| <kbd>⌘</kbd><kbd>⇧</kbd><kbd>3</kbd> / <kbd>4</kbd> / <kbd>5</kbd> | Screenshot: screen / area / the screenshot menu |
| <kbd>⌃</kbd><kbd>⌘</kbd><kbd>F</kbd> | Fullscreen |
| <kbd>⌃</kbd><kbd>⌘</kbd><kbd>Q</kbd> | Lock screen |
| <kbd>⌥</kbd><kbd>⌘</kbd><kbd>Esc</kbd> | Force Quit |
| <kbd>⌃</kbd><kbd>←</kbd> / <kbd>⌃</kbd><kbd>→</kbd> | Workspace left / right |
| <kbd>⌃</kbd><kbd>↑</kbd>, <kbd>F3</kbd> | Mission Control (overview) |
| <kbd>⌃</kbd><kbd>F2</kbd> | The menu bar from the keyboard |
| <kbd>⌘</kbd><kbd>⌥</kbd><kbd>Space</kbd> | angelOS's launcher |
| <kbd>⌘</kbd><kbd>⌥</kbd> + <kbd>H</kbd> <kbd>J</kbd> <kbd>K</kbd> <kbd>L</kbd> / arrows, <kbd>1</kbd>…<kbd>9</kbd>, <kbd>R</kbd>, <kbd>C</kbd>, <kbd>F</kbd>, <kbd>W</kbd> | Tiling: the pixel keys, one <kbd>Alt</kbd> further |

Inside apps, their own shortcuts stay theirs (<kbd>Ctrl</kbd>+<kbd>C</kbd>, <kbd>Ctrl</kbd>+<kbd>V</kbd>), and the menus label them that way.

</details>

<details>
<summary><b>▤ SHEET 4</b> · the login screen (SDDM), when it misbehaves</summary>

| Symptom | Fix |
| --- | --- |
| Boots to a text console | `sudo systemctl enable --force sddm && sudo systemctl set-default graphical.target` |
| `display-manager.service already exists` | disable the other one (`gdm`, `lightdm`, `ly@tty2`, `greetd`), then enable SDDM |
| Plain SDDM instead of the angelOS theme | `grep -r Current= /etc/sddm.conf /etc/sddm.conf.d/`; install `qt6-declarative` |
| Missing wallpaper | set a wallpaper in angelOS and check `/usr/share/sddm/themes/angelos/walls/` |

Preview the theme without logging out: `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/angelos`.

</details>

<img src="docs/readme/footage/end.svg" width="100%" alt="A blue VHS NO SIGNAL screen; for a moment it flickers back to a frame with the words: she says hi. Then: STOP · END OF TAPE">

<div align="center">
<sub><code>♡ thank you for watching the stream ♡</code></sub>
</div>
