pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "AngelLines.js" as Lines
import "../widgets/Logos.js" as Logos

// Pushes the current palette to other apps through templates (kitty, foot, gtk, niri…).
// The last state always wins: whatever the palette depends on re-renders when it changes,
// one render runs at a time, and a change during a render is rendered right after it.
Singleton {
    id: root

    readonly property string paletteFile: Config.cacheDir + "/palette.json"
    // the palette itself, as it would be written: everything it depends on is in it, so any
    // change re-renders — also the ones that come late: Theme.realm turns midway through the
    // widgets' burn, after Angel.demon (a return "as in the game" used to render heaven's
    // file with hell's accent and stay so); hell's wallpaper accent lands a beat after the circle
    readonly property string paletteText: JSON.stringify(Object.assign(Theme.exportPalette(), decorPalette(), terminalPalette(), appsPalette(), hellPalette()), null, 2)
    readonly property string disabled: (Config.appearance.disabledTemplates || []).join(",")
    readonly property string signature: Config.appearance.themeApps + "|" + disabled + "|" + paletteText
    property string lastLog: ""
    property var entries: []
    // tests (test-ui) put a stand-in renderer here: the real one reloads kitty and gsettings
    readonly property string stub: Quickshell.env("ANGELOS_TEST") === "1" ? (Quickshell.env("ANGELOS_RENDER_STUB") || "") : ""
    readonly property bool live: !Shell.dev || stub !== ""
    property string rendered: ""                  // the signature the last finished render had
    property string _running: ""                  // the one of the render going on
    property bool _force: false                   // a render asked for by hand while one ran
    // nothing waiting, nothing running, the files are the current palette's (debug panel, checks)
    readonly property bool settled: !render.running && !debounce.running && (rendered === signature || !Config.appearance.themeApps)

    onSignatureChanged: if (Config.ready)
        debounce.restart()
    Component.onCompleted: listEntries.running = true

    // first render once settings are loaded
    Timer {
        running: Config.ready
        interval: 1200
        onTriggered: root.apply()
    }

    // render now, even when nothing changed (Settings → Appearance → apply)
    function apply() {
        sync(true);
    }
    function sync(force) {
        if (!Config.appearance.themeApps || !live)
            return;
        if (render.running) {
            // next after it (onExited). Quickshell would restart a running process asked to run
            // too, but then palette.json would change under the hooks of the render going on
            _force = _force || !!force;
            return;
        }
        if (!force && signature === rendered)
            return;
        _force = false;
        _running = signature;
        // the renderer writes the palette file itself before anything reads it: the hooks of
        // a render see its palette, never the next one half-way
        render.command = ["python3", stub || Quickshell.shellDir + "/scripts/render-templates.py", paletteFile, disabled, "--palette", paletteText];
        render.running = true;
    }

    // window decorations (templates gtk3-decor/gtk4-decor, scripts/gtk-live.py, Helium):
    // heaven's title bars like angelOS's own windows, hell's in obsidian and blood
    function decorPalette() {
        const hell = Angel.demon;
        const h = c => Theme.hex(c);
        return {
            "realm": hell ? "hell" : "heaven",
            "decorGtk": Config.decor.gtkButtons ? "1" : "",
            "decorButtons": /^[a-z,]*$/.test(Config.decor.gtkLayout || "") ? Config.decor.gtkLayout : "maximize,close",
            "decorHeader": h(hell ? Theme.mix(Theme.hellFaceAlt, Theme.hellBlood, 0.35) : Theme.menuHeader),
            "decorFace": h(hell ? Theme.hellFace : Theme.face),
            "decorFaceAlt": h(hell ? Theme.hellFace : Theme.faceAlt),
            "decorHover": h(hell ? Theme.hellFaceAlt : Theme.mix(Theme.face, Theme.accent, 0.25)),
            "decorHi": h(hell ? Theme.hellHi : Theme.hi),
            "decorLo": h(hell ? Theme.hellLo : Theme.lo),
            "decorEdge": h(hell ? Theme.hellEdge : Theme.edge),
            "decorText": h(hell ? Theme.hellText : (Theme.dark ? Theme.text : Theme.edge)),
            "decorTextDim": h(hell ? Theme.hellTextDim : Theme.textDim),
            "decorTitle": h(hell ? Theme.hellFlame : Theme.text),
            "decorDanger": h(hell ? Theme.hellBlood : Theme.danger)
        };
    }

    // the terminals (kitty, foot, Alacritty: templates with "terminal": true) while the demon
    // rules (Y2K → Terminal in hell): `term` overrides their colours with the circle's
    // (HellLook via Theme.hell*): its dark, its bone text, its one accent; the 16 colours keep
    // their hues (red still means an error) but dulled into the ash. `kittyExtra` lays a
    // scorched background behind kitty (scripts/terminal-hell.py paints it, writes the realm
    // for the fish greeting). No cursor trail and no blinking: in hell things keep still.
    readonly property bool terminalHell: Angel.demon && Config.y2k.hellTerminal
    function h(c) {
        return Theme.hex(c);
    }
    // a terminal colour in the circle: the hue kept, pulled `k` of the way into its dim ink
    function ash(c, k) {
        return h(Theme.mix(Qt.color(c), Theme.hellTextDim, k));
    }
    function terminalPalette() {
        const bgImage = Config.home + "/.local/share/angelos/terminal/hell.png";
        if (!terminalHell)
            return {
                "termRealm": "heaven",
                "term": ({}),
                "hellLines": [],
                "kittyExtra": "# heaven: kitty's own defaults\ncursor_trail 0\ncursor_blink_interval -1\nbackground_image none\nbackground_tint 0.0"
            };
        return {
            "termRealm": "hell",
            "term": {
                "mode": "dark",
                "bg": h(Theme.hellBody),
                "fg": h(Theme.hellText),
                "bgAlt": h(Theme.hellFace),
                "accent": h(Theme.hellAccent),
                "accent2": h(Theme.hellFlame),
                "selectText": h(Theme.hellBody),
                "textDim": h(Theme.hellTextDim),
                "lo": h(Theme.hellFaceAlt),
                "color0": h(Theme.hellSunken),
                "color1": ash("#c0392b", 0.3),
                "color2": ash("#6f8f3a", 0.35),
                "color3": ash("#c9963a", 0.3),
                "color4": ash("#4a6aa8", 0.35),
                "color5": ash("#8e3a6e", 0.35),
                "color6": ash("#3f8f88", 0.35),
                "color7": h(Theme.hellTextDim),
                "color8": h(Theme.hellRim),
                "color9": ash("#e0533f", 0.25),
                "color10": ash("#93b552", 0.3),
                "color11": ash("#e2b45a", 0.25),
                "color12": ash("#7390d6", 0.3),
                "color13": ash("#b8568f", 0.3),
                "color14": ash("#64b8ae", 0.3),
                "color15": h(Theme.hellText)
            },
            "hellLines": Lines.demonTerminal.map(l => I18n.english ? l[1] : l[0]),
            "fastfetch": fastfetchHell(),
            "kittyExtra": "# hell (Settings → The angel → Hell → Terminal in hell): a scorched background, nothing moving\ncursor_trail 0\ncursor_blink_interval -1\nbackground_image " + bgImage + "\nbackground_image_layout scaled\nbackground_tint 0.7"
        };
    }

    // fastfetch in hell (scripts/terminal-hell.py writes its config from the user's own): the
    // circle — its number and name, its one line, the words for the readings ("CPU · жар") —
    // its colours, and the emblem with horns in them (unless the logo is left to the user)
    function fastfetchHell() {
        const n = HellLook.number;
        const lab = id => HellLook.look.labels && HellLook.look.labels[id] ? I18n.label(HellLook.look.labels[id]) : "";
        const ink = Theme.mix(Theme.hellAccent, Theme.hellEdge, 0.55);
        return {
            "number": n,
            "roman": n > 0 ? Theme.roman(n) : "",
            "name": I18n.label(HellLook.title),
            "where": I18n.label(HellLook.where),
            "circleWord": I18n.t("Круг", "Circle"),
            "labels": {
                "cpu": lab("cpu"),
                "gpu": lab("gpu"),
                "ram": lab("ram"),
                "vram": lab("vram")
            },
            "keys": h(Theme.hellAccent),
            "title": h(Theme.hellText),
            "dim": h(Theme.hellTextDim),
            "logo": Config.bar.logoFastfetch === false ? null : {
                "rows": Logos.emblem(["heart", "pill", "star", "cd", "kitty"].includes(Config.bar.logoEmblem) ? Config.bar.logoEmblem : "heart", true),
                "palette": {
                    "#": h(ink),
                    "o": h(Theme.hellAccent),
                    "x": h(Theme.hellBlood),
                    "y": h(Theme.hellFlame),
                    "w": h(Theme.hellText),
                    "f": h(Theme.hellTextDim),
                    "r": h(Theme.hellAccent),
                    "p": h(Theme.mix(Theme.hellAccent, Theme.hellText, 0.45))
                }
            }
        };
    }

    // GTK and Qt apps (templates with "apps": true, scripts/qt-theme.py) while the demon
    // rules (Y2K → Apps in hell): the whole app in the circle's colours, not only its title bar
    readonly property bool appsHell: Angel.demon && Config.y2k.hellApps
    function appsPalette() {
        return {
            "appsRealm": appsHell ? "hell" : "heaven",
            "qtStyle": Config.appearance.qtStyle ? "1" : "",
            "apps": !appsHell ? ({}) : {
                "mode": "dark",
                "bg": h(Theme.hellFace),
                "bgAlt": h(Theme.hellFaceAlt),
                "fg": h(Theme.hellText),
                "textDim": h(Theme.hellTextDim),
                "accent": h(Theme.hellAccent),
                "accent2": h(Theme.hellFlame),
                "accent3": h(Theme.hellGold),
                "selectText": h(Theme.hellText),
                "danger": h(Theme.hellAccent),
                "ok": ash("#6f8f3a", 0.35),
                "face": h(Theme.hellFace),
                "faceAlt": h(Theme.hellFaceAlt),
                "sunken": h(Theme.hellSunken),
                "hi": h(Theme.hellHi),
                "lo": h(Theme.hellLo),
                "edge": h(Theme.hellEdge),
                "select": h(Theme.mix(Theme.hellRim, Theme.hellBlood, 0.5))
            }
        };
    }

    // the circle's whole palette while the demon rules (scripts/steam-theme.py): the apps that
    // follow the realm on their own, whatever Y2K → Apps in hell says
    function hellPalette() {
        if (!Angel.demon)
            return {
                "hell": ({})
            };
        return {
            "hell": {
                "circle": HellLook.circle,
                "body": h(Theme.hellBody),
                "face": h(Theme.hellFace),
                "faceAlt": h(Theme.hellFaceAlt),
                "sunken": h(Theme.hellSunken),
                "hi": h(Theme.hellHi),
                "lo": h(Theme.hellLo),
                "edge": h(Theme.hellEdge),
                "rim": h(Theme.hellRim),
                "text": h(Theme.hellText),
                "textDim": h(Theme.hellTextDim),
                "accent": h(Theme.hellAccent),
                "blood": h(Theme.hellBlood),
                "flame": h(Theme.hellFlame),
                "ember": h(Theme.hellEmber),
                "gold": h(Theme.hellGold),
                "ok": ash("#6f8f3a", 0.35)
            }
        };
    }

    Timer {
        id: debounce
        interval: 500
        onTriggered: root.sync(false)
    }

    Process {
        id: render
        stdout: StdioCollector {
            onStreamFinished: root.lastLog = text
        }
        stderr: StdioCollector {
            onStreamFinished: if (text)
                console.warn("angelOS templates:", text)
        }
        // what changed while it ran goes next: the last state is the one on disk
        onExited: {
            root.rendered = root._running;
            if (root._force || root.signature !== root.rendered)
                Qt.callLater(() => root.sync(root._force));
        }
    }

    // list of templates for the settings page
    Process {
        id: listEntries
        command: ["sh", "-c", 'cat "$1"; for f in "$2"/*.json; do [ -f "$f" ] && { printf "\\n"; cat "$f"; }; done', "sh", Quickshell.shellDir + "/templates/templates.json", Config.templatesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                // naive split on top-level arrays/objects is enough for our own files
                for (const chunk of text.split(/\n(?=[\[{])/)) {
                    try {
                        const d = JSON.parse(chunk);
                        for (const e of (Array.isArray(d) ? d : [d]))
                            if (!out.find(o => o.id === e.id))
                                out.push(e);
                    } catch (e) {}
                }
                root.entries = out;
            }
        }
    }
}
