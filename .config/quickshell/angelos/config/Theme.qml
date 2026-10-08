pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Pixel pink palette in the spirit of NEEDY GIRL OVERDOSE.
// Light = "angel" (pastel win98), dark = "overdose" (night stream).
Singleton {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property bool autoDark: {
        const h = clock.hours;
        const a = Config.appearance;
        return a.darkFrom > a.lightFrom ? (h >= a.darkFrom || h < a.lightFrom) : (h >= a.darkFrom && h < a.lightFrom);
    }
    readonly property bool dark: Config.appearance.mode === "dark" || (Config.appearance.mode === "auto" && autoDark)

    function generated(isDark) {
        // the accent "from the wallpaper" is heaven's only: hell wears hell's own, one for every
        // circle (a new picture in hell used to recolour everything, 2026-10-08). Not the
        // circle's: a new Theme.accent re-binds the whole shell, and following the circle made
        // the switch in the dark between circles freeze it for 170–440 ms (the circles' own
        // colours come through Theme.hell*)
        const seed = Qt.color(root.hell ? HellLook.fallback.palette.accent : Config.appearance.customAccent || "#c77dff");
        const floor = Qt.color(isDark ? "#12141a" : "#fffdf8");
        const ink = Qt.color(isDark ? "#fafafa" : "#202126");
        const a = isDark ? mix(seed, Qt.color("#ffffff"), 0.25) : mix(seed, Qt.color("#161820"), 0.32);
        return {
            desk: hex(mix(floor, seed, 0.06)),
            face: hex(mix(floor, seed, 0.12)),
            faceAlt: hex(mix(floor, seed, 0.2)),
            text: hex(ink),
            textDim: hex(mix(ink, floor, 0.3)),
            accent: hex(a),
            accent2: hex(mix(a, ink, 0.35)),
            title1: hex(a),
            title2: hex(a)
        };
    }
    readonly property var flavors: ({
            wallpaper: {
                name: I18n.t("Из обоев", "From wallpaper"),
                dark: generated(true),
                light: generated(false)
            },
            gruvbox: {
                "name": "Gruvbox",
                "dark": {
                    "desk": "#282828",
                    "face": "#3c3836",
                    "faceAlt": "#504945",
                    "text": "#ebdbb2",
                    "textDim": "#a89984",
                    "accent": "#fabd2f",
                    "accent2": "#83a598",
                    "title1": "#fabd2f",
                    "title2": "#83a598"
                },
                "light": {
                    "desk": "#fbf1c7",
                    "face": "#f2e5bc",
                    "faceAlt": "#ebdbb2",
                    "text": "#3c3836",
                    "textDim": "#665c54",
                    "accent": "#9d0006",
                    "accent2": "#076678",
                    "title1": "#9d0006",
                    "title2": "#076678"
                }
            },
            rosepine: {
                "name": "Ros\u00e9 Pine",
                "dark": {
                    "desk": "#191724",
                    "face": "#1f1d2e",
                    "faceAlt": "#26233a",
                    "text": "#e0def4",
                    "textDim": "#908caa",
                    "accent": "#ebbcba",
                    "accent2": "#c4a7e7",
                    "title1": "#ebbcba",
                    "title2": "#c4a7e7"
                },
                "light": {
                    "desk": "#faf4ed",
                    "face": "#fffaf3",
                    "faceAlt": "#f2e9e1",
                    "text": "#575279",
                    "textDim": "#797593",
                    "accent": "#b4637a",
                    "accent2": "#286983",
                    "title1": "#b4637a",
                    "title2": "#286983"
                }
            },
            catppuccin: {
                "name": "Catppuccin",
                "dark": {
                    "desk": "#1e1e2e",
                    "face": "#313244",
                    "faceAlt": "#45475a",
                    "text": "#cdd6f4",
                    "textDim": "#a6adc8",
                    "accent": "#cba6f7",
                    "accent2": "#89b4fa",
                    "title1": "#cba6f7",
                    "title2": "#89b4fa"
                },
                "light": {
                    "desk": "#eff1f5",
                    "face": "#e6e9ef",
                    "faceAlt": "#ccd0da",
                    "text": "#4c4f69",
                    "textDim": "#6c6f85",
                    "accent": "#8839ef",
                    "accent2": "#1e66f5",
                    "title1": "#8839ef",
                    "title2": "#1e66f5"
                }
            },
            nord: {
                "name": "Nord",
                "dark": {
                    "desk": "#2e3440",
                    "face": "#3b4252",
                    "faceAlt": "#434c5e",
                    "text": "#eceff4",
                    "textDim": "#d8dee9",
                    "accent": "#88c0d0",
                    "accent2": "#b48ead",
                    "title1": "#88c0d0",
                    "title2": "#b48ead"
                },
                "light": {
                    "desk": "#eceff4",
                    "face": "#e5e9f0",
                    "faceAlt": "#d8dee9",
                    "text": "#2e3440",
                    "textDim": "#4c566a",
                    "accent": "#5e81ac",
                    "accent2": "#8f3f71",
                    "title1": "#5e81ac",
                    "title2": "#8f3f71"
                }
            },
            dracula: {
                "name": "Dracula",
                "dark": {
                    "desk": "#282a36",
                    "face": "#343746",
                    "faceAlt": "#44475a",
                    "text": "#f8f8f2",
                    "textDim": "#b8b8d2",
                    "accent": "#bd93f9",
                    "accent2": "#ff79c6",
                    "title1": "#bd93f9",
                    "title2": "#ff79c6"
                },
                "light": {
                    "desk": "#f8f8f2",
                    "face": "#efedf7",
                    "faceAlt": "#e4dff0",
                    "text": "#282a36",
                    "textDim": "#6272a4",
                    "accent": "#7045ad",
                    "accent2": "#a52d76",
                    "title1": "#7045ad",
                    "title2": "#a52d76"
                }
            },
            tokyonight: {
                "name": "Tokyo Night",
                "dark": {
                    "desk": "#1a1b26",
                    "face": "#24283b",
                    "faceAlt": "#414868",
                    "text": "#c0caf5",
                    "textDim": "#a9b1d6",
                    "accent": "#7aa2f7",
                    "accent2": "#bb9af7",
                    "title1": "#7aa2f7",
                    "title2": "#bb9af7"
                },
                "light": {
                    "desk": "#d5d6db",
                    "face": "#e1e2e7",
                    "faceAlt": "#c4c8da",
                    "text": "#343b58",
                    "textDim": "#565f89",
                    "accent": "#34548a",
                    "accent2": "#5a4a78",
                    "title1": "#34548a",
                    "title2": "#5a4a78"
                }
            },
            solarized: {
                "name": "Solarized",
                "dark": {
                    "desk": "#002b36",
                    "face": "#073642",
                    "faceAlt": "#164956",
                    "text": "#fdf6e3",
                    "textDim": "#93a1a1",
                    "accent": "#b58900",
                    "accent2": "#2aa198",
                    "title1": "#b58900",
                    "title2": "#2aa198"
                },
                "light": {
                    "desk": "#fdf6e3",
                    "face": "#eee8d5",
                    "faceAlt": "#e1dbc8",
                    "text": "#586e75",
                    "textDim": "#657b83",
                    "accent": "#9c7100",
                    "accent2": "#007e78",
                    "title1": "#9c7100",
                    "title2": "#007e78"
                }
            },
            everforest: {
                "name": "Everforest",
                "dark": {
                    "desk": "#2d353b",
                    "face": "#343f44",
                    "faceAlt": "#475258",
                    "text": "#d3c6aa",
                    "textDim": "#9da9a0",
                    "accent": "#a7c080",
                    "accent2": "#83c092",
                    "title1": "#a7c080",
                    "title2": "#83c092"
                },
                "light": {
                    "desk": "#fdf6e3",
                    "face": "#f3ead3",
                    "faceAlt": "#e5dfc5",
                    "text": "#5c6a72",
                    "textDim": "#708089",
                    "accent": "#557529",
                    "accent2": "#287b65",
                    "title1": "#557529",
                    "title2": "#287b65"
                }
            },
            bubblegum: {
                name: "Bubblegum",
                light: {
                    accent: "#ff4fa3",
                    accent2: "#57d5ff",
                    title1: "#ff7ec0",
                    title2: "#b895ff"
                },
                dark: {
                    accent: "#ff5cad",
                    accent2: "#4fe3ff",
                    title1: "#ff4fa3",
                    title2: "#7b4dff"
                }
            },
            overdose: {
                name: "Overdose",
                light: {
                    accent: "#e8307f",
                    accent2: "#9b5cff",
                    title1: "#ff3d8b",
                    title2: "#ff8ab8"
                },
                dark: {
                    accent: "#ff2e7e",
                    accent2: "#b36bff",
                    title1: "#d4145a",
                    title2: "#5b1a8f"
                }
            },
            cyberangel: {
                name: "Cyber Angel",
                light: {
                    accent: "#ff5cad",
                    accent2: "#1fb8e6",
                    title1: "#7fdcff",
                    title2: "#ff9ad0"
                },
                dark: {
                    accent: "#ff6ec2",
                    accent2: "#3ff0ff",
                    title1: "#1a9fd6",
                    title2: "#ff4fa3"
                }
            }
        })

    readonly property var legacyBase: legacyFor(dark)
    function legacyFor(isDark) {
        return isDark ? ({
                desk: "#1a0f24",
                face: "#241432",
                faceAlt: "#2f1a42",
                sunken: "#150b1e",
                text: "#ffe1f1",
                textDim: "#a987b8",
                titleText: "#ffffff",
                hi: "#4a2c63",
                lo: "#0e0716",
                edge: "#07030b",
                accent3: "#ffe066",
                accent4: "#a57cff",
                danger: "#ff4f6d",
                ok: "#57e3a2",
                selectText: "#1a0d24",
                shadow: "#000000",
                ansi: ["#2a1838", "#ff4f6d", "#57e3a2", "#ffe066", "#7b8cff", "#ff5cad", "#4fe3ff", "#e8cfe0", "#6b4f7d", "#ff7a93", "#8af0c0", "#fff0a0", "#a3b0ff", "#ff9fd0", "#9ff0ff", "#ffffff"]
            }) : ({
                desk: "#ffd1e8",
                face: "#fff3f9",
                faceAlt: "#ffe3f1",
                sunken: "#ffffff",
                text: "#3b1f4a",
                textDim: "#9a7aa8",
                titleText: "#ffffff",
                hi: "#ffffff",
                lo: "#e7a6cc",
                edge: "#5a2e6e",
                accent3: "#ffc93c",
                accent4: "#b895ff",
                danger: "#ff3d64",
                ok: "#2fbf7f",
                selectText: "#ffffff",
                shadow: "#5a2e6e",
                ansi: ["#3b1f4a", "#e0305a", "#1f9e6a", "#c98a00", "#4b5fd6", "#e0308a", "#1b9ec2", "#b89cb0", "#9a7aa8", "#ff5c80", "#34c28a", "#e0a82e", "#6f80f0", "#ff5cad", "#3cc0e0", "#fff3f9"]
            });
    }
    // the chosen flavour's colours in either mode, whichever is on now (the wizard's previews)
    function paletteFor(isDark) {
        const f = (flavors[Config.appearance.flavor] || flavors.overdose)[isDark ? "dark" : "light"];
        return f.desk ? f : Object.assign({}, legacyFor(isDark), f);
    }
    readonly property var flavor: (flavors[Config.appearance.flavor] || flavors.overdose)[dark ? "dark" : "light"]

    // ---- the Golden Gate skin (Config.settingsUi.skin "goldengate"): macOS 27's colours ----
    // While the skin is on and the demon doesn't rule, the palette is a Mac's — light or dark,
    // the accent picked in its Appearance — so everything that follows angelOS's colours (GTK,
    // Qt, the terminals, Telegram, Steam, the browsers, the shell's own pixel windows) looks like
    // a Mac too. services/GoldenGate takes its accent from here.
    readonly property bool macLook: Config.ready && Config.settingsUi.skin === "goldengate" && realm !== "hell"
    readonly property var macAccents: ({
            "blue": ["#0088ff", "#0091ff"],
            "purple": ["#a550a7", "#bf5af2"],
            "pink": ["#f74f9e", "#ff6aa8"],
            "red": ["#ff5257", "#ff6961"],
            "orange": ["#f7821b", "#ff9f0a"],
            "yellow": ["#ffc600", "#ffd60a"],
            "green": ["#62ba46", "#4cd964"],
            "graphite": ["#8c8c8c", "#98989d"]
        })
    readonly property color macAccent: (macAccents[Config.mac.accent] || macAccents.blue)[dark ? 1 : 0]
    readonly property var macBase: dark ? ({
            desk: "#1c1c1e",
            face: "#242426",
            faceAlt: "#2c2c2e",
            sunken: "#1a1a1c",
            text: "#f5f5f7",
            textDim: "#98989d",
            titleText: "#ffffff",
            hi: "#3a3a3c",
            lo: "#141416",
            edge: "#0a0a0b",
            accent: "#0091ff",
            accent2: "#5e5ce6",
            accent3: "#ff9f0a",
            accent4: "#bf5af2",
            title1: "#0091ff",
            title2: "#5e5ce6",
            danger: "#ff453a",
            ok: "#30d158",
            selectText: "#ffffff",
            shadow: "#000000",
            // Terminal.app's "Basic" colours, dark
            ansi: ["#000000", "#c23621", "#25bc24", "#adad27", "#492ee1", "#d338d3", "#33bbc8", "#cbcccd", "#818383", "#fc391f", "#31e722", "#eaec23", "#5833ff", "#f935f8", "#14f0f0", "#e9ebeb"]
        }) : ({
            desk: "#e8e8ea",
            face: "#f5f5f7",
            faceAlt: "#ececee",
            sunken: "#ffffff",
            text: "#1d1d1f",
            textDim: "#86868b",
            titleText: "#1d1d1f",
            hi: "#ffffff",
            lo: "#d2d2d7",
            edge: "#b8b8bd",
            accent: "#0088ff",
            accent2: "#5856d6",
            accent3: "#ff9500",
            accent4: "#af52de",
            title1: "#0088ff",
            title2: "#5856d6",
            danger: "#ff3b30",
            ok: "#28c840",
            selectText: "#ffffff",
            shadow: "#000000",
            // Terminal.app's "Basic" colours
            ansi: ["#000000", "#990000", "#00a600", "#999900", "#0000b2", "#b200b2", "#00a6b2", "#bfbfbf", "#666666", "#e50000", "#00d900", "#e5e500", "#0000ff", "#e500e5", "#00e5e5", "#e5e5e5"]
        })
    readonly property var base: {
        if (macLook)
            return macBase;
        if (!flavor.desk)
            return legacyBase;
        return Object.assign({}, legacyBase, flavor, {
            sunken: flavor.desk,
            hi: flavor.faceAlt,
            lo: flavor.desk,
            edge: flavor.desk,
            selectText: dark ? flavor.desk : "#ffffff",
            accent3: flavor.accent2,
            accent4: flavor.accent2,
            ansi: [flavor.desk, "#e36b78", "#8eaf73", "#d8b56b", flavor.accent2, flavor.accent, "#72b7b0", flavor.text, flavor.textDim, "#f58b98", "#aacf93", "#efd18b", flavor.accent2, flavor.accent, "#92d7d0", flavor.text]
        });
    }
    readonly property color menuSurface: mix(face, accent, dark ? 0.08 : 0.04)
    readonly property color menuHeader: mix(faceAlt, accent, dark ? 0.16 : 0.10)
    readonly property color menuBorder: mix(faceAlt, accent, 0.32)

    // ---- tokens ----
    readonly property color desk: base.desk
    readonly property color face: base.face
    readonly property color faceAlt: base.faceAlt
    readonly property color sunken: base.sunken
    // Accessibility → Contrast: text toward black or white, dim text nearly as strong, crisper edges
    readonly property bool highContrast: Config.ready && !!Config.appearance.highContrast
    readonly property color text: highContrast ? mix(base.text, dark ? "#ffffff" : "#000000", 0.6) : base.text
    readonly property color textDim: highContrast ? mix(base.textDim, text, 0.7) : base.textDim
    readonly property color titleText: base.text
    readonly property color hi: base.hi
    readonly property color lo: highContrast ? mix(base.lo, dark ? "#ffffff" : "#000000", 0.35) : base.lo
    readonly property color edge: highContrast ? mix(base.edge, dark ? "#ffffff" : "#000000", 0.35) : base.edge
    readonly property color accent: macLook ? macAccent : flavor.accent
    readonly property color accent2: macLook ? macBase.accent2 : flavor.accent2
    readonly property color accent3: base.accent3
    readonly property color accent4: base.accent4
    readonly property color title1: macLook ? macAccent : flavor.title1
    readonly property color title2: macLook ? macBase.title2 : flavor.title2
    readonly property color danger: base.danger
    readonly property color ok: base.ok
    readonly property color select: accent
    readonly property color selectText: base.selectText
    readonly property color shadow: base.shadow
    readonly property var ansi: base.ansi

    // translucent panel background (blur shows through)
    readonly property real panelAlpha: Config.appearance.blur ? Config.appearance.opacity : 1
    readonly property color panel: Qt.alpha(face, panelAlpha)
    readonly property color panelAlt: Qt.alpha(faceAlt, panelAlpha)

    // Settings skins take their colours from the active palette, including wallpaper colours.
    readonly property color ngoPink: accent
    readonly property color ngoLilac: accent2
    readonly property color ngoMint: mix(accent2, face, dark ? 0.38 : 0.2)
    readonly property color ngoInk: text
    readonly property color ngoPaper: face
    readonly property color ngoPaperText: text
    readonly property color ngoSticker: dark ? faceAlt : face
    // Windose uses the same palette with quieter surfaces and restrained accents.
    // Stream keeps the saturated ngo tokens above.
    readonly property color windoseRose: mix(accent, face, dark ? 0.5 : 0.36)
    readonly property color windoseLavender: mix(accent2, face, dark ? 0.55 : 0.42)
    readonly property color windosePaper: mix(face, accent2, dark ? 0.09 : 0.035)
    readonly property color windoseSticker: mix(faceAlt, face, dark ? 0.22 : 0.35)
    readonly property color windoseInk: mix(text, face, dark ? 0.22 : 0.28)
    readonly property color windoseLine: mix(accent2, face, dark ? 0.65 : 0.62)
    readonly property color windoseTitle: mix(accent, text, dark ? 0.38 : 0.52)
    readonly property color streamBg: desk
    readonly property color streamPanel: face
    readonly property color streamText: text
    readonly property color streamDim: textDim
    readonly property color streamLive: accent

    // Only controls inside SettingsView inherit its skin.
    function settingsSkinFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.settingsSkin !== undefined)
                return p.settingsSkin;
        return "classic";
    }
    // inside the Settings window in its Windows 11 look (SettingsView.fluent): cards
    function fluentFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.fluent !== undefined)
                return p.fluent === true;
        return false;
    }

    // ---- the two dimensions: heaven and hell ----
    // The desktop widgets live in one of them: heaven (the usual look) or hell while
    // the demon rules (Y2K → Angel or demon → Widgets in hell). DesktopWidgets sets
    // `realm` midway through the widgets' burn, so a widget can simply bind to it:
    //   color: Theme.hell ? Theme.hellEmber : Theme.accent
    // Plugins declare that they draw both in manifest.json: "realms": ["heaven", "hell"].
    property string realm: "heaven"
    readonly property bool hell: realm === "hell"
    // hell's palette: the circle's (config/HellLook.qml, story/circles.json), not the flavour's
    readonly property color hellBody: HellLook.palette.body
    readonly property color hellFace: HellLook.palette.face
    readonly property color hellFaceAlt: HellLook.palette.faceAlt
    readonly property color hellSunken: HellLook.palette.sunken
    readonly property color hellEdge: HellLook.palette.edge
    readonly property color hellHi: HellLook.palette.hi
    readonly property color hellLo: HellLook.palette.lo
    readonly property color hellBlood: HellLook.palette.blood
    readonly property color hellEmber: HellLook.palette.ember
    readonly property color hellFlame: HellLook.palette.flame
    readonly property color hellGold: HellLook.palette.gold
    readonly property color hellText: HellLook.palette.text
    readonly property color hellTextDim: HellLook.palette.textDim
    // calm ground under text and icons, the thin rim of hell's frames, the one accent
    readonly property color hellPlate: HellLook.palette.plate
    readonly property color hellRim: HellLook.palette.rim
    readonly property color hellAccent: HellLook.palette.accent
    readonly property color hellPanel: Qt.alpha(hellBody, Math.max(0.82, panelAlpha))
    // the hell bar's roles (HellLook.barRoles): icons, the hover and the active plate, a
    // sprite's body and its lighter parts — the accent only for a state
    readonly property color hellBarIcon: HellLook.barRole.barIcon
    readonly property color hellBarHover: HellLook.barRole.barHover
    readonly property color hellBarActive: HellLook.barRole.barActive
    readonly property color hellSprite: HellLook.barRole.sprite
    readonly property color hellSpriteHi: HellLook.barRole.spriteHi
    // Jacquard 12 Hell (OFL, data/fonts): Jacquard 12, a pixel blackletter, with the Cyrillic
    // drawn for angelOS on its own grid (sources and the build: data/fonts/src/jacquard12-hell).
    // Hell's headings, crisp at 21 px and its multiples (Theme.hellPx).
    readonly property string fontHell: hellFont.status === FontLoader.Ready ? hellFont.name : fontTitle
    function hellPx(n) {
        return 21 * Math.max(1, Math.round(n || 1));
    }
    // what the blackletter can write: Latin, Cyrillic and the usual punctuation (symbols
    // and emoji go in the hell text font). The old name stays for plugins: "latin" meant
    // "Jacquard can draw it" when it had no Cyrillic.
    function hellCovers(text) {
        return /^[\x20-\x7E\u00A0-\u00FF\u0401\u0410-\u044F\u0451\u2013\u2014\u2018\u2019\u201C\u201D\u2022\u2026\u2116]*$/.test(String(text));
    }
    function latin(text) {
        return hellCovers(text);
    }
    function roman(n) {
        n = Math.floor(n);
        if (n <= 0)
            return "N";                     // nulla, the medieval zero
        const r = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let s = "";
        for (const [v, c] of r)
            while (n >= v) {
                s += c;
                n -= v;
            }
        return s;
    }
    FontLoader {
        id: hellFont
        source: Qt.resolvedUrl("../data/fonts/Jacquard12Hell-Regular.ttf")
    }
    // Departure Mono (OFL, data/fonts): hell's text — labels, values, her lines. 11 px grid.
    readonly property string fontHellText: hellTextFont.status === FontLoader.Ready ? hellTextFont.name : fontBody
    function hellTextPx(n) {
        return 11 * Math.max(1, Math.round(n || 1));
    }
    FontLoader {
        id: hellTextFont
        source: Qt.resolvedUrl("../data/fonts/DepartureMono-Regular.otf")
    }
    // (hell's lyrics used to have a font of their own; now the headings' — kept for plugins)
    readonly property string fontLyricsHell: fontHell

    // ---- the grimoire's handwriting ----
    // Caveat (OFL, data/fonts; Latin and Cyrillic): while Settings are the demon's book
    // (SettingsView puts its window in scriptWindows), every PxText and field in that window
    // writes by hand, a size larger — a script's small letters need it to read. Elsewhere
    // nothing changes and nothing is looked up (PxText checks scriptWindows first).
    readonly property string fontScript: scriptFont.status === FontLoader.Ready ? scriptFont.name : fontBody
    // the open Settings windows (SettingsView: each adds itself, there can be several)
    property var settingsViews: []
    readonly property var scriptWindows: settingsViews.map(v => v.scriptHost).filter(w => !!w)
    // the windows whose content is re-inked on paper (the grimoire, a circle's dress): their
    // pictures come out as engravings the right way round (widgets/GrimoirePhoto)
    readonly property var inkWindows: settingsViews.map(v => v.inkHost).filter(w => !!w)
    // the window in the Golden Gate skin's System Settings look (SettingsView): every PxText in it
    // is set in the skin's font at macOS's sizes (widgets/PxText)
    property var macWindow: null
    // the skin's font: Inter (open, drawn close to SF Pro; the fonts catalog fetches it), or
    // Config.mac.font if installed, else a plain sans
    readonly property var macFamilies: Qt.fontFamilies()
    readonly property string macFont: Config.mac.font && macFamilies.includes(Config.mac.font) ? Config.mac.font : macFamilies.includes("Inter") ? "Inter" : macFamilies.includes("Inter Variable") ? "Inter Variable" : macFamilies.includes("Noto Sans") ? "Noto Sans" : "sans-serif"
    readonly property string macMono: macFamilies.includes("JetBrains Mono") ? "JetBrains Mono" : macFamilies.includes("Noto Sans Mono") ? "Noto Sans Mono" : "monospace"
    function scriptPx(px) {
        return Math.round(px * 1.38);
    }
    FontLoader {
        id: scriptFont
        source: Qt.resolvedUrl("../data/fonts/Caveat-Variable.ttf")
    }

    // ---- metrics ----
    readonly property int u: Math.max(1, Config.appearance.px)   // one art pixel
    // the font scale: ×1, ×1.25 … ×2 (fontPx keeps every size on its font's pixel grid)
    readonly property real fs: Math.max(1, Math.min(3, Config.appearance.fontScale || 1))
    readonly property int gap: u * 4
    readonly property int pad: u * 5
    // How much the text has outgrown the art pixel. Rows, bars and title strips were drawn for
    // body text of 6.5 art pixels (13 px at px 2); bigger fonts (×2) or a smaller pixel (px 1)
    // overflow them. fit(n) = n art pixels, grown with the text when it is bigger than that:
    // the size for anything that holds a line of text. (px 4 with ×1 text: 1, nothing grows.)
    readonly property real textGrowth: Math.max(1, sizeBody / (u * 6.5))
    function fit(n) {
        return Math.round(u * n * textGrowth);
    }
    // the bars (taskbar, top bar, island…): a two-line clock and the Start wordmark fit
    readonly property int barHeight: fit(20)

    // ---- fonts (sizes are native multiples so glyphs stay crisp) ----
    readonly property string defaultTitleFont: "Pixeloid Sans"
    readonly property string defaultBodyFont: "CozetteVector"
    readonly property string defaultMonoFont: "Pixeloid Mono"
    readonly property string fontTitle: Config.appearance.fontTitle || defaultTitleFont
    readonly property string fontBody: Config.appearance.fontBody || defaultBodyFont
    readonly property string fontMono: Config.appearance.fontMono || defaultMonoFont
    // glyph cell of known pixel fonts (scripts/fonts.py keeps the same numbers)
    readonly property var fontNative: ({
            "Pixeloid Sans": 9,
            "Pixeloid Mono": 9,
            "CozetteVector": 13,
            "CozetteVectorBold": 13,
            "Cozette": 13,
            "Pixelify Sans": 11,
            "Tiny5": 8,
            "Press Start 2P": 8,
            "Monocraft": 9,
            "Departure Mono": 11,
            "Silkscreen": 8
        })
    function crisp(base, family) {
        const n = fontNative[family] || 0;
        return n > 0 ? Math.max(n, Math.round(base / n) * n) : base;
    }
    // `base` at the font scale, on the font's pixel grid: a pixel font is only sharp at whole
    // multiples of its cell, so ×1.5 makes a 9 px cell font 27 px (×3 of the cell) where the
    // 13 px body font can only stay 13 or go 26 — each size moves at its own step, none blurs.
    // Fonts of no known grid (vector fonts) scale exactly.
    function fontPx(base, family) {
        const n = fontNative[family] || 0;
        if (n <= 0)
            return Math.max(1, Math.round(base * fs));
        return n * Math.max(1, Math.round(Math.max(1, Math.round(base / n)) * fs));
    }
    readonly property int sizeTiny: fontPx(9, fontTitle)
    readonly property int sizeBody: fontPx(13, fontBody)
    readonly property int sizeTitle: fontPx(18, fontTitle)
    readonly property int sizeBig: fontPx(27, fontTitle)
    readonly property int sizeHuge: fontPx(36, fontTitle)
    readonly property int sizeMono: fontPx(18, fontMono)
    readonly property int sizeMonoSmall: fontPx(13, fontMono)

    // ---- motion: stepped easing feels "pixel" ----
    readonly property int fast: 140
    readonly property int normal: 220
    readonly property int slow: 380

    function mix(a, b, t) {
        // accepts colors or "#rrggbb" strings
        a = typeof a === "string" ? Qt.color(a) : a;
        b = typeof b === "string" ? Qt.color(b) : b;
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    function hex(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    // flat palette for templates
    function exportPalette() {
        const p = {
            mode: dark ? "dark" : "light",
            flavor: macLook ? "goldengate" : Config.appearance.flavor
        };
        const keys = ["desk", "face", "faceAlt", "sunken", "text", "textDim", "titleText", "hi", "lo", "edge", "accent", "accent2", "accent3", "accent4", "title1", "title2", "danger", "ok", "select", "selectText", "shadow"];
        for (const k of keys)
            p[k] = hex(root[k]);
        for (let i = 0; i < 16; i++)
            p["color" + i] = ansi[i];
        p.bg = dark ? p.desk : p.face;
        p.fg = p.text;
        p.bgAlt = dark ? p.face : p.faceAlt;
        return p;
    }
}
