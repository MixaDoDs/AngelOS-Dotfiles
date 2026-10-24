pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Pixel pink palette in the spirit of NEEDY GIRL OVERDOSE.
// Night = "overdose" (night stream). By day the wallpaper and the programs are light and the
// interface wears a day look (dayLooks): mostly not a white one.
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
    // night: the mode itself (the wallpaper's night variant, the lock's sky, what the programs
    // are told). dark: the interface has light text on dark surfaces — at night, and by day
    // in a day look that is dark
    readonly property bool night: Config.appearance.mode === "dark" || (Config.appearance.mode === "auto" && autoDark)
    readonly property bool dark: night || (!!dayLook && dayLook.dark === true)

    // ---- the day looks (Config.appearance.dayLook): the interface by day ----
    // Each is a whole palette, the scheme's own accent aside. "scheme" = the colour scheme's
    // light half on the zine's paper. `apps: "light"`: the programs get the scheme's light
    // palette (a dark interface over light programs, as Windows' custom mode); the others
    // dress the programs in their own colours. `alpha`: panels no more opaque than this.
    readonly property var dayLooks: ({
            dusk: {
                name: I18n.t("Сумерки", "Dusk"),
                dark: true,
                apps: "light",
                desk: "#343a4a",
                face: "#3d4457",
                faceAlt: "#485068",
                sunken: "#323848",
                text: "#eef1f8",
                textDim: "#b4bac8",
                hi: "#59627a",
                lo: "#2c3140",
                edge: "#1c202b",
                shadow: "#1c202b",
                accent: "#8fb4ff",
                accent2: "#c9b3ff",
                title1: "#4d5670",
                title2: "#4d5670"
            },
            sage: {
                name: I18n.t("Шалфей", "Sage"),
                dark: false,
                desk: "#aab7a0",
                face: "#c5cfbd",
                faceAlt: "#b7c3ae",
                sunken: "#d6ddd0",
                text: "#1c2a22",
                textDim: "#46544b",
                hi: "#d6ddd0",
                lo: "#96a68b",
                edge: "#1c2a22",
                shadow: "#1c2a22",
                accent: "#2f6b4f",
                accent2: "#6b4f1c",
                title1: "#96a68b",
                title2: "#96a68b"
            },
            lavender: {
                name: I18n.t("Лаванда", "Lavender"),
                dark: true,
                desk: "#4a4466",
                face: "#5b5478",
                faceAlt: "#676089",
                sunken: "#4b4563",
                text: "#f4efff",
                textDim: "#cbc4e0",
                hi: "#7a7399",
                lo: "#3f3a57",
                edge: "#231f33",
                shadow: "#231f33",
                accent: "#ffb3e0",
                accent2: "#b3e0ff",
                title1: "#6f6791",
                title2: "#6f6791"
            },
            olive: {
                name: I18n.t("Олива", "Olive"),
                dark: true,
                desk: "#4a5132",
                face: "#5d6540",
                faceAlt: "#69724a",
                sunken: "#4c5334",
                text: "#f3f5e0",
                textDim: "#ced3b4",
                hi: "#7c8558",
                lo: "#3e442a",
                edge: "#22260f",
                shadow: "#22260f",
                accent: "#e8d86a",
                accent2: "#f0b078",
                title1: "#737c50",
                title2: "#737c50"
            },
            amber: {
                name: I18n.t("Янтарь", "Amber"),
                dark: true,
                desk: "#120c04",
                face: "#1a1206",
                faceAlt: "#2a1c08",
                sunken: "#0a0702",
                text: "#ffb000",
                textDim: "#c08400",
                hi: "#3a2606",
                lo: "#0a0702",
                edge: "#7a5200",
                shadow: "#000000",
                accent: "#ffb000",
                accent2: "#ff7a00",
                title1: "#3a2606",
                title2: "#3a2606",
                danger: "#ff5a1f",
                ok: "#ffd866"
            },
            glass: {
                name: I18n.t("Дымчатое стекло", "Smoked glass"),
                dark: true,
                apps: "light",
                alpha: 0.62,
                shadowAlpha: 0.4,
                desk: "#12121a",
                face: "#12121a",
                faceAlt: "#262630",
                sunken: "#08080c",
                text: "#ffffff",
                textDim: "#c8c8d2",
                hi: "#3a3a46",
                lo: "#08080c",
                edge: "#000000",
                shadow: "#000000",
                accent: "#4287fa",
                accent2: "#8fb4ff",
                title1: "#1c1c26",
                title2: "#1c1c26"
            },
            scheme: {
                name: I18n.t("Бумага (по цветовой схеме)", "Paper (the colour scheme's)")
            }
        })
    readonly property string dayLookId: Config.appearance.dayLook in dayLooks ? Config.appearance.dayLook : "dusk"
    // the look on now: null at night, in the Golden Gate skin and for "scheme"
    readonly property var dayLook: night || macLook || dayLookId === "scheme" ? null : dayLooks[dayLookId]

    function generated(isDark) {
        // the accent "from the wallpaper" is heaven's only: hell wears hell's own, one for every
        // circle (a new picture in hell used to recolour everything, 2026-10-08). Not the
        // circle's: a new Theme.accent re-binds the whole shell, and following the circle made
        // the switch in the dark between circles freeze it for 170–440 ms (the circles' own
        // colours come through Theme.hell*)
        const seed = Qt.color(root.hell ? HellLook.fallback.palette.accent : Config.appearance.customAccent || "#c77dff");
        if (!isDark) {
            // the paper and the ink stay; the wallpaper gives the spot colour (a grey one stays grey)
            const sat = seed.hslSaturation < 0.1 ? seed.hslSaturation : 0.95;
            const spot = hex(Qt.hsla(seed.hslHue, sat, 0.62, 1));
            return Object.assign({}, zinePaper, {
                accent: spot,
                accent2: hex(Qt.hsla(seed.hslHue, sat * 0.9, 0.4, 1)),
                title1: spot,
                title2: spot
            });
        }
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
                    accent: "#c92a7a",
                    accent2: "#1a72a0",
                    title1: "#c92a7a",
                    title2: "#7d5cc4"
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
                    accent: "#fb407f",
                    accent2: "#7b4fc9",
                    title1: "#fb407f",
                    title2: "#fb407f"
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
                    accent: "#c41f72",
                    accent2: "#126f9a",
                    title1: "#126f9a",
                    title2: "#c41f72"
                },
                dark: {
                    accent: "#ff6ec2",
                    accent2: "#3ff0ff",
                    title1: "#1a9fd6",
                    title2: "#ff4fa3"
                }
            }
        })

    // the light theme's paper (2026-10-12, "Зин"): kraft desk, cream paper, ink for the text, the
    // outline and the shadow. Boxes are flat (Theme.zine): no bevels, an outline and a solid shadow
    readonly property var zinePaper: ({
            desk: "#e6dabf",
            face: "#fbf5e6",
            faceAlt: "#efe5cc",
            sunken: "#fffdf6",
            text: "#17141f",
            textDim: "#5d5666"
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
            }) : Object.assign({}, zinePaper, {
                titleText: "#ffffff",
                // lines drawn by hand (separators, grooves): the kraft's own shades
                hi: "#fffdf6",
                lo: "#cfc2a0",
                edge: "#17141f",
                accent3: "#976000",
                accent4: "#7d5cc4",
                danger: "#c8264b",
                ok: "#137a52",
                selectText: "#ffffff",
                shadow: "#17141f",
                // on a light background: every colour readable as text (white is a mid grey, as GitHub Light's)
                ansi: ["#17141f", "#c8264b", "#137a52", "#976000", "#3d4fc0", "#b0207a", "#0f6f8a", "#6e6080", "#8f7ca0", "#e0305a", "#1f9468", "#b07a00", "#5a6be0", "#d0308a", "#178aa8", "#8f7ca0"]
            });
    }
    // the chosen flavour's colours in either mode, whichever is on now (the wizard's previews)
    function paletteFor(isDark) {
        const look = isDark || dayLookId === "scheme" ? null : dayLooks[dayLookId];
        if (look)
            return Object.assign({}, legacyFor(look.dark), look);
        const f = (flavors[Config.appearance.flavor] || flavors.overdose)[isDark ? "dark" : "light"];
        return f.desk ? f : Object.assign({}, legacyFor(isDark), f);
    }
    readonly property var schemeFlavor: (flavors[Config.appearance.flavor] || flavors.overdose)[night ? "dark" : "light"]
    readonly property var flavor: dayLook || schemeFlavor

    // ---- the Golden Gate skin (Config.settingsUi.skin "goldengate"): macOS 27's colours ----
    // While the skin is on and the demon doesn't rule, the palette is a Mac's — light or dark,
    // the accent picked in its Appearance — so everything that follows angelOS's colours (GTK,
    // Qt, the terminals, Telegram, Steam, the browsers, the shell's own pixel windows) looks like
    // a Mac too. services/GoldenGate takes its accent from here.
    readonly property bool macLook: Config.ready && Config.settingsUi.skin === "goldengate" && realm !== "hell"
    // a palette with its own paper (a named scheme, a day look) over the legacy roles: what it
    // doesn't say — the outline, the shadow, the 16 colours — comes from what it does
    function baseOf(fl, isDark, isNight) {
        const legacy = legacyFor(isDark);
        if (!fl.desk)
            return legacy;
        return Object.assign({}, legacy, {
            sunken: fl.desk,
            hi: fl.faceAlt,
            lo: fl.desk,
            edge: isNight ? fl.desk : fl.text,
            shadow: isNight ? legacy.shadow : fl.text,
            selectText: isDark ? fl.desk : "#ffffff",
            accent3: fl.accent2,
            accent4: fl.accent2,
            ansi: [fl.desk, "#e36b78", "#8eaf73", "#d8b56b", fl.accent2, fl.accent, "#72b7b0", fl.text, fl.textDim, "#f58b98", "#aacf93", "#efd18b", fl.accent2, fl.accent, "#92d7d0", fl.text]
        }, fl);
    }
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
    readonly property var base: macLook ? macBase : baseOf(flavor, dark, night)
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
    // on a window's title plate by day (PxWindow): the text colour if it reads there
    readonly property color titleText: zine ? inkOn(title1) : base.text
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
    // the zine's spot colour may be a light one: ink on it then, white on a deep one
    readonly property color selectText: zine ? (luminance(accent) > 0.3 ? "#17141f" : "#ffffff") : base.selectText
    readonly property color shadow: base.shadow
    // by day the interface is a zine: flat boxes (widgets/PxBox), an outline, a solid shadow
    readonly property bool zine: !night && !macLook
    readonly property real shadowAlpha: zine ? (dayLook && dayLook.shadowAlpha || 1) : dark ? 0.55 : 0.35
    readonly property var ansi: base.ansi

    // translucent panel background (blur shows through)
    readonly property real panelAlpha: Math.min(dayLook && dayLook.alpha || 1, Config.appearance.blur ? Config.appearance.opacity : 1)
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
    // under a frame scaled by a fraction (a zoomed desktop widget): native glyphs would be
    // resampled as a texture and smear, so PxText draws them with Qt instead (#83)
    function zoomedFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.zoomedFrame !== undefined)
                return p.zoomedFrame === true;
        return false;
    }
    // ---- the P5 settings window (modules/settings/p5): black, paper and the accent ----
    // The window puts settingsSkin "p5" on what it shows; the pixel widgets inside take these
    // colours (and their own P5 shapes), and a catalog's own parts ask tone() for theirs.
    // The dark theme turns the card over: "black" is the ink, "paper" what it is written on, so
    // there the paper is near-black and the ink light (a white card glared at night — the owner).
    readonly property color p5Black: dark ? mix("#ffffff", accent, 0.08) : mix("#000000", accent, 0.07)
    readonly property color p5Paper: dark ? mix("#000000", accent, 0.12) : mix("#ffffff", accent, 0.05)
    readonly property color p5White: dark ? mix("#000000", accent, 0.19) : mix("#ffffff", accent, 0.02)
    readonly property color p5Paper2: dark ? mix("#000000", accent, 0.27) : mix("#ffffff", accent, 0.16)
    readonly property color p5Paper3: dark ? mix("#000000", accent, 0.4) : mix("#ffffff", accent, 0.3)
    readonly property color p5Dim: mix(p5Black, dark ? "#000000" : "#ffffff", 0.38)
    // the accent as letters on the paper: darkened (lightened on the dark card) until it reads
    readonly property color p5AccentInk: dark ? mix(accent, "#ffffff", 0.2) : darkTo(accent, 0.18)
    // a colour darkened until its luminance is at most `l` (text on white)
    function darkTo(c, l) {
        let k = 0;
        let x = Qt.color(c);
        while (luminance(x) > l && k < 12) {
            x = mix(x, "#000000", 0.12);
            k++;
        }
        return x;
    }
    function p5For(item) {
        return settingsSkinFor(item) === "p5";
    }
    // one of the theme's colours, or its P5 counterpart inside the P5 window
    function tone(name, p5) {
        if (!p5)
            return root[name];
        switch (name) {
        case "face":
            return p5Paper2;
        case "faceAlt":
            return p5Paper3;
        case "sunken":
            return dark ? mix("#000000", accent, 0.06) : mix("#ffffff", accent, 0.08);
        case "text":
        case "edge":
        case "lo":
            return p5Black;
        case "textDim":
            return p5Dim;
        case "hi":
            return "#ffffff";
        case "ok":
        case "danger":
        case "accent2":
            return dark ? root[name] : darkTo(root[name], 0.2);
        }
        return root[name];
    }
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
    // ---- the P5 settings window's letters (OFL, data/fonts; Latin and Cyrillic) ----
    // its text: Handjet at its bold (a static cut, HandjetP5-Bold), narrow like P5's menus;
    // a size larger than the body's — a narrow face needs it (p5BodyPx)
    readonly property string fontP5Body: p5BodyFont.status === FontLoader.Ready ? p5BodyFont.name : fontBody
    function p5BodyPx(px) {
        return Math.round(px * 1.5);
    }
    // the P5 window's own words (a line's name, its value) a size more again (the owner, 23.10: «шрифт больше»)
    readonly property int p5LabelPx: Math.round(sizeTitle * 1.75)
    FontLoader {
        id: p5BodyFont
        source: Qt.resolvedUrl("../data/fonts/HandjetP5-Bold.ttf")
    }
    FontLoader {
        id: dotGothicFont
        source: Qt.resolvedUrl("../data/fonts/DotGothic16-Regular.ttf")
    }
    // the cut-out letters of its headings: a font per letter, each with Cyrillic (the last
    // four come with angelOS's fonts, ~/.local/share/fonts/angelos)
    readonly property var p5Ransom: [fontTitle, fontHell, fontP5Body, fontMono, dotGothicFont.status === FontLoader.Ready ? dotGothicFont.name : fontBody, fontHellText, "Press Start 2P", "Monocraft", "Tiny5", fontBody]
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
            "Silkscreen": 8,
            "Jacquard 12 Hell": 12,
            "DotGothic16": 16,
            "Handjet P5": 16
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

    function luminance(c) {
        const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    function inkOn(bg) {
        const l = luminance(bg), t = luminance(base.text);
        if ((Math.max(l, t) + 0.05) / (Math.min(l, t) + 0.05) >= 4.5)
            return base.text;
        return l > 0.3 ? "#17141f" : "#ffffff";
    }

    function hex(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    // flat palette for templates
    // What the programs get. By day in a look with `apps: "light"` it is the scheme's light
    // palette, not the interface's.
    function exportPalette() {
        const own = !!dayLook && dayLook.apps === "light";
        const src = own ? Object.assign({}, baseOf(schemeFlavor, false, false), {
            titleText: "#ffffff",
            accent: schemeFlavor.accent,
            accent2: schemeFlavor.accent2,
            title1: schemeFlavor.title1,
            title2: schemeFlavor.title2,
            select: schemeFlavor.accent,
            selectText: luminance(Qt.color(schemeFlavor.accent)) > 0.3 ? "#17141f" : "#ffffff"
        }) : root;
        const isDark = own ? false : dark;
        const p = {
            mode: isDark ? "dark" : "light",
            flavor: macLook ? "goldengate" : Config.appearance.flavor
        };
        const keys = ["desk", "face", "faceAlt", "sunken", "text", "textDim", "titleText", "hi", "lo", "edge", "accent", "accent2", "accent3", "accent4", "title1", "title2", "danger", "ok", "select", "selectText", "shadow"];
        for (const k of keys)
            p[k] = hex(Qt.color(src[k]));
        for (let i = 0; i < 16; i++)
            p["color" + i] = src.ansi[i];
        p.bg = isDark ? p.desk : p.face;
        p.fg = p.text;
        p.bgAlt = isDark ? p.face : p.faceAlt;
        return p;
    }
}
