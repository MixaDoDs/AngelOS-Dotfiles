# The global menu of the Golden Gate skin

The Golden Gate skin (macOS 27 for people coming from a Mac) puts the focused app's menus —
File, Edit, View… — into the menu bar at the top of the screen, and they have to work, not just
look like menus. Wayland has no common way for that and niri ties no menu to a window, so this
is what apps actually offer and how angelOS gets at it. Checked on CachyOS on 2026-10-04: niri
26.04, Qt 6.11.2 with qt6ct, GTK 3.24.52, GTK 4.22.5, appmenu-gtk-module 25.04, Quickshell 0.3.1.

## What apps offer

| Toolkit | What it exports | How angelOS finds it |
|---|---|---|
| Qt 5/6 (qt6ct, the generic Unix theme) | Its `QMenuBar` as `com.canonical.dbusmenu` at `/MenuBar/<n>`, **only if `com.canonical.AppMenu.Registrar` is on the session bus when the app starts**; the bar inside the window disappears then | On Wayland Qt does **not** call `RegisterWindow` (it has no window id to give). The object is found on the app's own bus connections, by the pid niri reports for the focused window. The tray icon's menu (the `Menu` of its `StatusNotifierItem`, `/MenuBar`) is told apart and never taken |
| GTK 3 with `appmenu-gtk-module` (`gtk-modules` in `settings.ini`) | Every `GtkMenuBar` as a `GMenuModel` (`org.gtk.Menus`) at `/org/appmenu/gtk/window/menus/menubar/<n>`, its actions (`org.gtk.Actions`, prefix `unity.`) on the same object; works on Wayland | The non-empty menubar of the pid. Its action group fills only after the menus are subscribed to (`Start`), so the actions are read after that. A submenu's `submenu-action` is set to true while it shows (the app may update it, as GTK does) |
| `GtkApplication` (GTK 3 and 4) | A menubar set with `gtk_application_set_menubar` at `<app path>/menus/menubar`; always its actions: `app.` at `<app path>`, `win.` at `<app path>/window/<n>` (about, preferences, quit, new-window, new-tab, undo…) | The app path is the one that has windows or a menubar under it, or the path GApplication makes of the app id (`org.gnome.Nautilus` → `/org/gnome/Nautilus`). No menubar (most GTK 4 apps): the shell makes standard menus out of the actions |
| X11 apps through XWayland, libdbusmenu | `RegisterWindow(xid, path)` with the registrar | By the registering connection's pid |
| Electron, Chromium (Helium), Firefox, kitty, Alacritty, Steam | Nothing on Wayland | Standard menus from the shell (below) |

What does not work, and why:

- **An app started before the registrar keeps its menu inside its window** — Qt checks for the
  registrar once, when it creates its menu bar. Turn the skin on, then restart such apps (or log
  in again). And the other way round: a Qt app started while the skin was on has no menu bar in
  its window any more, even after the skin is off, until it is restarted. That is why the helper is
  started again at once if it dies while the skin is on.
- **Several windows of one app, each with a menu:** which of them is focused is not known (Qt and
  `appmenu-gtk-module` say nothing about it on Wayland, `win.` actions are per window). The newest
  window's menu is shown, and only the items that have a shortcut — those go to the focused window
  as key presses; the rest are left out rather than risk acting on another window.
- **Flatpak apps** talk to the bus through `xdg-dbus-proxy`: the pid on the bus is the proxy's, not
  the window's. They get the standard menus.
- **GTK 3 apps need `appmenu-gtk-module` installed** (`extra/appmenu-gtk-module`); the installer
  installs it with the skin. Without it GTK 3 apps keep their menu bars in their windows, and the
  menu bar gets the standard menus or the app's actions.

## The helper and the menu bar

`scripts/appmenu.py serve` (run by `services/AppMenu.qml` while the skin is on) owns the
registrar, is told the focused window's pid and app id, and answers with the menus as JSON — item
labels without mnemonics, hidden items left out, toggles, shortcuts as key names, the app's own
"disabled" kept. Choosing an item goes back the same way: a dbusmenu `Event "clicked"`, a GTK
`Activate`. `appmenu.py dump` prints what it finds for every open window (the table below was made
with it). Tests: `tests/appmenu/test_appmenu.py` (stand-in apps on a private bus, every source,
activation, submenus, several windows, an app quitting).

The menu bar (`modules/mac`) shows the result as macOS would:

- the **app menu** (the app's name in bold): About, Settings…, Quit — the app's own items moved
  there, like Qt and GTK do on a Mac; without them the shell's About panel and Quit = closing every
  window of the app through niri (the app may still ask to save);
- the app's own menus, or for apps with none **standard menus** that work through the app's own
  shortcuts, pressed in its window by `wtype` once the menu has closed
  (`data/appmenu-profiles.json`: Firefox, Chromium browsers, kitty, Alacritty, foot, Nautilus,
  Obsidian, Discord, VS Code, any Electron app), its `.desktop` actions (New Window, New Private
  Window, Steam's Library and Store…) and its D-Bus actions;
- **Window** from niri: Fill, Center, Full Screen, floating, to another desktop or display, the
  app's windows;
- **Help** when there is something in it.

Nothing dead: what can't be done is not shown; an item the app itself greys out stays grey.

## Per app on this machine

| App | Toolkit | Where the menu comes from | What works |
|---|---|---|---|
| Nautilus 50 (files) | GTK 4 | the app's D-Bus actions + standard menus | About, Settings, Quit, New Window, New Tab, Sidebar — by D-Bus; Edit, View (list/icons, hidden files, zoom), Go (Back, Forward, Enclosing Folder, Documents, Desktop, Downloads, Home, Trash, Go to Folder) — by its shortcuts; Window by niri |
| Firefox 157 (browser) | GTK 3, own UI | standard menus (shortcuts) + `.desktop` actions | File, Edit, View, History, Bookmarks, Tools, tabs in Window, Settings (`about:preferences`), Help (opens support.mozilla.org); About = the shell's panel |
| Helium (browser) | Chromium | standard menus (shortcuts) | the same set for Chromium browsers; Settings (`chrome://settings`) |
| kitty 0.48 (terminal) | own (GLFW) | standard menus (shortcuts) | Shell (new window, tab, split, close), Edit (copy, paste, clear, scrollback), View (font size, reload settings), Settings (kitty.conf), tabs in Window |
| Alacritty 0.17 (terminal) | winit | standard menus (shortcuts) | new window, copy, paste, find, font size |
| Telegram 7.2 | Qt 6 | its own menu (dbusmenu): File, Edit, Tools, Help | everything Telegram enables; its Quit, About and Preferences go to the app menu |
| Steam | CEF | `.desktop` actions | File: Store, Community, Library, Servers, Screenshots, News, Settings, Big Picture, Friends (`steam://` links into the running Steam); Window by niri |
| qBittorrent 5.2 (Qt app) | Qt 6 | its own menu (dbusmenu) | everything: File, Edit, View, Tools, Help; About, Preferences and Exit in the app menu |
| Meld 3.24 (GTK 3 app) | GTK 3, `GtkApplication` | its D-Bus actions (its menubar is empty) | About, Preferences, Quit, New Tab, Fullscreen, Keyboard Shortcuts, Help |
| Audacity 3.7 (GTK 3 app with a menu bar) | wxWidgets on GTK 3 | its own menu via `appmenu-gtk-module` | the whole menu bar (File … Help, submenus), Undo greyed out until there is something to undo |
| Discord (Electron, Flatpak) | Electron | standard menus (shortcuts) | Edit, View (quick switcher, reload, zoom) |
