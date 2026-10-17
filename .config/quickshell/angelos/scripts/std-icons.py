#!/usr/bin/env python3
"""widgets/StdIcons.js: pixel icons for the freedesktop icon names (camera-photo, edit-copy,
dialog-warning, audio-volume-high…) — what the shell draws when the user's icon theme has no
picture for a name a notification, a tray item or an app asks for (Qt drew a pink-and-black
checkerboard there, #47). services/StdIcon looks a name up: the theme first, these after.

  std-icons.py PIXELARTICONS_DIR HACKERNOON_DIR     (the unpacked npm packages:
      npm pack pixelarticons@2.4.2 @hackernoon/pixel-icon-library@1.1.0)

Rendered as scripts/icon-sets.py renders the icon styles (1:1 on the 24-unit grid, cut to the
ink, rows of '#'). Licences: pixelarticons — MIT, © 2019 Gerrit Halfmann; HackerNoon's Pixel
Icon Library — CC BY 4.0, © HackerNoon (changed: rendered to bitmaps, cropped, coloured by the
theme). See docs/ICON-CREDITS.md.
"""
import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("icon_sets", HERE / "icon-sets.py")
icon_sets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(icon_sets)

# the icon each name gets: a pixelarticons name, "hn:<name>" for HackerNoon's, "own:<name>" for
# angelOS's own (widgets/Icons.js: neither set has a Bluetooth sign)
NAMES = {
    # ---- actions
    "address-book-new": "contact", "application-exit": "logout", "appointment-new": "calendar",
    "call-start": "phone-call", "call-stop": "phone", "contact-new": "avatar-square-plus",
    "document-new": "file", "document-open": "open", "document-open-recent": "clock",
    "document-page-setup": "file-text", "document-print": "printer", "document-print-preview": "printer",
    "document-properties": "info-box", "document-revert": "undo", "document-save": "save",
    "document-save-as": "save", "document-send": "send", "document-edit": "pencil",
    "edit-clear": "eraser", "edit-copy": "copy", "edit-cut": "cut", "edit-delete": "delete",
    "edit-find": "search", "edit-find-replace": "search", "edit-paste": "clipboard", "edit-redo": "redo",
    "edit-select-all": "square-dashed-cursor", "edit-undo": "undo", "edit": "pencil",
    "folder-new": "folder-plus", "format-justify-center": "text-align-center",
    "format-justify-fill": "text-align-justify", "format-justify-left": "text-align-left",
    "format-justify-right": "text-align-right", "format-text-bold": "heading",
    "go-bottom": "arrow-bar-down", "go-down": "arrow-down", "go-first": "arrow-bar-left",
    "go-home": "home", "go-jump": "corner-up-right", "go-last": "arrow-bar-right", "go-next": "arrow-right",
    "go-previous": "arrow-left", "go-top": "arrow-bar-up", "go-up": "arrow-up", "help-about": "info-box",
    "help-contents": "circle-question", "help-faq": "circle-question", "insert-image": "image-2-plus",
    "insert-link": "link", "insert-object": "box", "insert-text": "text-cursor", "list-add": "plus",
    "list-remove": "minus", "mail-forward": "mail-right", "mail-mark-important": "flag",
    "mail-mark-read": "mail-open", "mail-mark-unread": "mail", "mail-message-new": "mail",
    "mail-reply-all": "message-reply", "mail-reply-sender": "message-reply", "mail-send": "send",
    "mail-send-receive": "mail", "media-eject": "arrow-bar-up", "media-playback-pause": "pause",
    "media-playback-start": "play", "media-playback-stop": "stop", "media-record": "circle",
    "media-seek-backward": "chevrons-horizontal", "media-seek-forward": "forward",
    "media-skip-backward": "chevron-left-2", "media-skip-forward": "chevron-right-2",
    "object-flip-horizontal": "flip-horizontal-2", "object-flip-vertical": "flip-vertical-2",
    "object-rotate-left": "undo", "object-rotate-right": "redo", "process-stop": "cancel",
    "system-lock-screen": "lock", "system-log-out": "logout", "system-reboot": "reload",
    "system-run": "play", "system-search": "search", "system-shutdown": "power",
    "tools-check-spelling": "check", "view-fullscreen": "expand", "view-refresh": "refresh",
    "view-restore": "collapse", "view-sort-ascending": "sort-vertical", "view-sort-descending": "sort-vertical",
    "window-close": "close", "window-new": "app-windows", "zoom-fit-best": "aspect-ratio",
    "zoom-in": "zoom-in", "zoom-original": "search", "zoom-out": "zoom-out", "share": "share",
    "send-to": "send", "crop": "crop", "image-crop": "crop", "color-select": "pipette",
    # ---- status
    "alarm": "alarm-clock", "appointment-missed": "calendar", "appointment-soon": "alarm-clock",
    "audio-volume-high": "volume-3", "audio-volume-medium": "volume-2", "audio-volume-low": "volume-1",
    "audio-volume-muted": "volume-x", "battery-caution": "battery-low", "battery-low": "battery-low",
    "battery-full": "battery-full", "battery-good": "battery-medium", "battery-empty": "battery",
    "battery-charging": "zap", "dialog-error": "square-alert", "dialog-information": "circle-info",
    "dialog-password": "key", "dialog-question": "circle-question", "dialog-warning": "warning-diamond",
    "folder-drag-accept": "folder", "folder-open": "folder", "folder-visiting": "folder",
    "image-loading": "loader", "image-missing": "image", "mail-attachment": "attachment",
    "mail-unread": "mail", "mail-read": "mail-open", "mail-replied": "message-reply", "mail-signed": "shield",
    "mail-signed-verified": "shield", "media-playlist-repeat": "repeat", "media-playlist-shuffle": "shuffle",
    "network-error": "cancel", "network-idle": "wifi", "network-offline": "cancel",
    "network-receive": "download", "network-transmit": "upload", "network-transmit-receive": "arrows-vertical",
    "network-wireless": "wifi", "network-wired": "modem", "network-cellular": "cellular-signal-3",
    "printer-error": "printer", "printer-printing": "printer", "security-high": "shield",
    "security-medium": "shield", "security-low": "shield", "software-update-available": "download",
    "software-update-urgent": "warning-diamond", "system-software-update": "download",
    "sync-error": "refresh", "sync-synchronizing": "refresh", "task-due": "clock", "task-past-due": "clock",
    "user-available": "user", "user-idle": "user", "user-away": "user", "user-busy": "user",
    "user-offline": "user", "user-trash-full": "trash", "weather-clear": "sun", "weather-clear-night": "moon",
    "weather-few-clouds": "cloud-sun", "weather-few-clouds-night": "cloud-moon", "weather-overcast": "cloud",
    "weather-showers": "cloud", "weather-snow": "snowflake", "weather-storm": "zap", "weather-fog": "cloud",
    "microphone-sensitivity-high": "mic", "microphone-sensitivity-medium": "mic",
    "microphone-sensitivity-low": "mic", "microphone-sensitivity-muted": "mic-off",
    "microphone-disabled": "mic-off", "notification": "bell", "notifications": "bell",
    "notifications-disabled": "bell-off", "bluetooth": "own:bluetooth", "bluetooth-active": "own:bluetooth",
    "bluetooth-disabled": "own:bluetoothOff", "airplane-mode": "hn:plane", "night-light": "moon",
    "changes-prevent": "lock", "changes-allow": "unlock", "checkbox-checked": "checkbox-on",
    "checkbox": "checkbox", "emblem-ok": "check", "object-select": "check", "starred": "star",
    "non-starred": "star", "view-reveal": "eye", "view-conceal": "eye-off", "content-loading": "loader",
    "screen-shared": "monitor", "media-playlist-consecutive": "bulletlist",
    # ---- devices
    "audio-card": "volume-3", "audio-speakers": "volume-3", "audio-input-microphone": "mic",
    "audio-headphones": "headphone", "audio-headset": "headphone", "battery": "battery-full",
    "camera-photo": "camera", "camera-video": "video", "camera-web": "webcam", "computer": "computer",
    "computer-laptop": "laptop", "drive-harddisk": "database", "drive-optical": "album",
    "drive-removable-media": "usb", "drive-multidisk": "database", "input-gaming": "gamepad",
    "input-keyboard": "keyboard", "input-mouse": "mouse", "input-tablet": "tablet", "input-touchpad": "hand",
    "media-flash": "memory-stick", "media-optical": "album", "media-removable": "usb",
    "multimedia-player": "music", "pda": "smartphone", "phone": "smartphone", "printer": "printer",
    "scanner": "scan-barcode", "video-display": "monitor", "display": "monitor", "tv": "tv",
    "modem": "modem", "network-vpn": "shield", "uninterruptible-power-supply": "battery-full",
    "cpu": "cpu", "memory": "memory-stick", "gpu": "gpu", "usb": "usb", "watch": "watch",
    # ---- places
    "folder": "folder", "folder-remote": "cloud", "network-server": "server", "network-workgroup": "users",
    "start-here": "home", "user-bookmarks": "bookmark", "user-desktop": "monitor", "user-home": "home",
    "user-trash": "trash", "folder-download": "download", "folder-downloads": "download",
    "folder-documents": "file-text", "folder-pictures": "image", "folder-music": "music",
    "folder-videos": "video", "folder-templates": "files", "folder-publicshare": "share",
    "folder-cloud": "cloud", "folder-games": "gamepad", "folder-code": "code", "user-trash-empty": "trash",
    # ---- files
    "application-x-executable": "app-windows", "application-x-addon": "blocks",
    "application-x-firmware": "cpu", "application-pdf": "file", "application-zip": "archive",
    "application-x-archive": "archive", "audio-x-generic": "music", "font-x-generic": "text-start-a",
    "image-x-generic": "image", "package-x-generic": "package", "text-html": "code", "text-x-generic": "file-text",
    "text-x-script": "script", "video-x-generic": "video", "x-office-document": "file-text",
    "x-office-spreadsheet": "chart", "x-office-presentation": "presentation", "x-office-calendar": "calendar",
    "x-office-address-book": "contact", "x-office-drawing": "brush", "inode-directory": "folder",
    "text-x-preview": "file-text", "x-package-repository": "package",
    # ---- emblems
    "emblem-default": "check", "emblem-important": "warning-diamond", "emblem-favorite": "heart",
    "emblem-photos": "images", "emblem-shared": "share", "emblem-system": "gear",
    "emblem-downloads": "download", "emblem-mail": "mail", "emblem-symbolic-link": "link",
    "emblem-readonly": "lock", "emblem-unreadable": "eye-off", "emblem-synchronizing": "refresh",
    # ---- generic apps and categories
    "accessories-calculator": "calculator", "accessories-text-editor": "notes",
    "accessories-character-map": "text-start-a", "accessories-dictionary": "book-open",
    "accessories-screenshot": "camera", "applets-screenshooter": "camera", "screenshot": "camera",
    "help-browser": "circle-question", "multimedia-volume-control": "sliders",
    "preferences-desktop": "settings-cog", "preferences-desktop-wallpaper": "image",
    "preferences-desktop-theme": "colors-swatch", "preferences-desktop-font": "text-start-a",
    "preferences-desktop-keyboard": "keyboard", "preferences-desktop-display": "monitor",
    "preferences-system": "gear", "preferences-system-notifications": "bell",
    "preferences-system-network": "wifi", "preferences-system-privacy": "shield",
    "preferences-system-time": "clock", "preferences-other": "sliders", "system-file-manager": "folder",
    "system-software-install": "package", "system-users": "users", "utilities-terminal": "terminal",
    "utilities-system-monitor": "analytics", "web-browser": "globe", "internet-mail": "mail",
    "mail-client": "mail", "internet-chat": "message", "internet-web-browser": "globe",
    "applications-utilities": "tools", "applications-system": "gear", "applications-games": "gamepad",
    "applications-graphics": "brush", "applications-internet": "globe", "applications-multimedia": "music",
    "applications-office": "file-text", "applications-science": "test-tube", "applications-development": "code",
    "applications-accessories": "tools", "applications-education": "university", "applications-other": "box",
    "media-tape": "album", "system-help": "circle-question", "camera": "camera", "image": "image",
    "video": "video", "music": "music", "calendar": "calendar", "clock": "clock", "mail": "mail",
    "chat": "message", "terminal": "terminal", "settings": "gear", "download": "download", "upload": "upload",
    "trash": "trash", "user": "user", "users": "users", "home": "home", "lock": "lock", "search": "search",
    "warning": "warning-diamond", "error": "square-alert", "info": "circle-info", "question": "circle-question",
    "heart": "heart", "star": "star", "bell": "bell", "gamepad": "gamepad", "game": "gamepad",
    "keyboard": "keyboard", "mouse": "mouse", "monitor": "monitor", "laptop": "laptop", "wifi": "wifi",
    "globe": "globe", "copy": "copy", "save": "save", "pencil": "pencil", "power": "power",
    "volume": "volume-3", "speaker": "volume-3", "mic": "mic", "microphone": "mic", "headphones": "headphone",
    "phone-call": "phone-call", "send": "send", "link": "link", "share-alt": "share", "package": "package",
    "update": "download", "refresh": "refresh", "sync": "refresh", "shield": "shield", "key": "key",
    "picture": "image", "photo": "image", "movie": "video", "film": "clapperboard", "book": "book-open",
    "note": "note", "notes": "notes", "code": "code", "bug": "bug", "robot": "robot", "bot": "robot",
    "cloud": "cloud", "server": "server", "database": "database", "chart": "chart", "map": "map",
    "location": "map-pin", "flag": "flag", "gift": "gift", "trophy": "trophy", "coffee": "coffee",
}
# a name with none of the above: the first of these words in it decides (screenshot-tool, org.x.Mail…)
WORDS = [["screenshot", "camera"], ["camera", "camera"], ["webcam", "webcam"], ["photo", "image"],
         ["picture", "image"], ["image", "image"], ["wallpaper", "image"], ["video", "video"],
         ["movie", "video"], ["music", "music"], ["audio", "music"], ["sound", "volume-3"],
         ["volume", "volume-3"], ["speaker", "volume-3"], ["microphone", "mic"], ["headphone", "headphone"],
         ["headset", "headphone"], ["mail", "mail"], ["message", "message"], ["chat", "message"],
         ["folder", "folder"], ["directory", "folder"], ["battery", "battery-full"], ["power", "power"],
         ["network", "wifi"], ["wifi", "wifi"], ["wireless", "wifi"], ["wired", "modem"],
         ["bluetooth", "own:bluetooth"], ["vpn", "shield"], ["download", "download"], ["upload", "upload"],
         ["update", "download"], ["install", "package"], ["package", "package"], ["trash", "trash"],
         ["delete", "delete"], ["warn", "warning-diamond"], ["error", "square-alert"],
         ["alert", "square-alert"], ["info", "circle-info"], ["question", "circle-question"],
         ["help", "circle-question"], ["password", "key"], ["keyboard", "keyboard"], ["key", "key"], ["lock", "lock"],
         ["secur", "shield"], ["user", "user"], ["avatar", "user"], ["contact", "contact"],
         ["phone", "smartphone"], ["call", "phone-call"], ["print", "printer"], ["scan", "scan-barcode"],
         ["calendar", "calendar"], ["alarm", "alarm-clock"], ["clock", "clock"], ["time", "clock"],
         ["game", "gamepad"], ["steam", "gamepad"], ["terminal", "terminal"], ["console", "terminal"],
         ["code", "code"], ["develop", "code"], ["setting", "gear"], ["prefer", "gear"],
         ["config", "gear"], ["system", "gear"], ["copy", "copy"], ["clipboard", "clipboard"],
         ["paste", "clipboard"], ["save", "save"], ["edit", "pencil"], ["write", "pencil"],
         ["text", "file-text"], ["document", "file-text"], ["file", "file"], ["search", "search"],
         ["find", "search"], ["zoom", "zoom-in"], ["web", "globe"], ["browser", "globe"],
         ["internet", "globe"], ["cloud", "cloud"], ["share", "share"], ["send", "send"],
         ["bell", "bell"], ["notif", "bell"], ["display", "monitor"], ["monitor", "monitor"],
         ["screen", "monitor"], ["keyboard", "keyboard"], ["mouse", "mouse"], ["usb", "usb"],
         ["disk", "database"], ["drive", "database"], ["weather", "cloud-sun"], ["night", "moon"],
         ["star", "star"], ["heart", "heart"], ["love", "heart"], ["home", "home"], ["play", "play"],
         ["pause", "pause"], ["stop", "stop"], ["record", "circle"], ["sync", "refresh"],
         ["refresh", "refresh"], ["reload", "reload"], ["link", "link"], ["map", "map"]]


def main():
    pa_dir = Path(sys.argv[1]) / "svg"
    hn_dir = Path(sys.argv[2]) / "icons/SVG/regular"
    want = sorted(i for i in set(NAMES.values()) | {w[1] for w in WORDS} if not i.startswith("own:"))
    pics = {}
    for icon in want:
        src = hn_dir / (icon[3:] + ".svg") if icon.startswith("hn:") else pa_dir / (icon + ".svg")
        if not src.exists():
            raise SystemExit("no such icon in the packs: %s (%s)" % (icon, src))
        pics[icon] = icon_sets.rows(icon_sets.raster(src))
    js = [".pragma library", "",
          "// Pixel icons for the freedesktop icon names, drawn when the user's icon theme has none for a",
          "// name (services/StdIcon). Generated by scripts/std-icons.py, don't edit by hand.",
          "// pixelarticons — MIT, (c) 2019 Gerrit Halfmann; HackerNoon's Pixel Icon Library — the icons",
          "// CC BY 4.0, (c) HackerNoon, changed: rendered to bitmaps, cropped, coloured by the theme.",
          "// docs/ICON-CREDITS.md has the licences and links.", "",
          "const pics = " + json.dumps(pics, indent=1, sort_keys=True) + ";", "",
          "const names = " + json.dumps(NAMES, sort_keys=True) + ";", "",
          "const words = " + json.dumps(WORDS) + ";", "",
          "// the rows for a name: itself (no -symbolic), then without its last parts (audio-volume-high-rtl →",
          "// audio-volume-high), then a word in it (org.gnome.Screenshot → camera); null: nothing fits;",
          "// a string: the name of angelOS's own icon (widgets/Icons.js)",
          "function pic(icon) {",
          "    return icon.indexOf(\"own:\") === 0 ? icon.slice(4) : pics[icon];",
          "}",
          "function find(name) {",
          "    let n = String(name || \"\").toLowerCase().replace(/\\.(svg|png|xpm)$/, \"\").replace(/-symbolic$/, \"\").replace(/-(rtl|ltr)$/, \"\");",
          "    if (!n)",
          "        return null;",
          "    for (let s = n; s; s = s.lastIndexOf(\"-\") > 0 ? s.slice(0, s.lastIndexOf(\"-\")) : \"\")",
          "        if (names[s])",
          "            return pic(names[s]);",
          "    for (const w of words)",
          "        if (n.indexOf(w[0]) >= 0)",
          "            return pic(w[1]);",
          "    return null;",
          "}", ""]
    target = HERE.parent / "widgets/StdIcons.js"
    target.write_text("\n".join(js))
    print("StdIcons.js: %d names, %d words, %d pictures" % (len(NAMES), len(WORDS), len(pics)))


if __name__ == "__main__":
    main()
