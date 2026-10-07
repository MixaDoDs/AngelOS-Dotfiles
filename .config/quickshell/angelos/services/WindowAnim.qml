pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// niri's window open and close animations: its own, off, or an angelOS shader
// (shaders/open/*.glsl, shaders/close/*.glsl), each at its own speed —
// written into cfg/animation.kdl by scripts/window-anim.py (backed up, validated), in the
// theme's accents — templates.json's "window-anim" writes them again when the theme changes.
// cfg/animation.kdl is where the choice lives, like the workspace slide.
Singleton {
    id: root

    readonly property var openStyles: [
        {
            "id": "default",
            "label": I18n.t("Обычная", "Default"),
            "hint": I18n.t("как у niri: окно проявляется и чуть подрастает", "niri's own: the window fades in and grows a little")
        },
        {
            "id": "pop",
            "label": I18n.t("Пузырь", "Bubble"),
            "hint": I18n.t("выпрыгивает, как Y2K-пузырь: пружинит, блик в цветах темы", "pops up like a Y2K bubble: springs, a shine in the theme's colours")
        },
        {
            "id": "pixel",
            "label": I18n.t("Пиксели", "Pixels"),
            "hint": I18n.t("собирается из пиксельных блоков: сначала крупно, потом чётко", "assembles from pixel blocks: chunky first, then sharp")
        },
        {
            "id": "heart",
            "label": I18n.t("Сердечко", "Heart"),
            "hint": I18n.t("проявляется в растущем сердце цвета темы", "appears inside a growing heart in the theme's colour")
        },
        {
            "id": "star",
            "label": I18n.t("Звезда ✦", "Star ✦"),
            "hint": I18n.t("раскрывается растущей звездой-блёсткой с бликом по краю", "opens through a growing sparkle star with a glint on its rim")
        },
        {
            "id": "cd",
            "label": I18n.t("CD-диск", "CD"),
            "hint": I18n.t("вкручивается радужным диском, дырка посередине затягивается", "spins in as a rainbow disc, the hole in the middle closes up")
        },
        {
            "id": "crt",
            "label": I18n.t("Старый телевизор", "Old TV"),
            "hint": I18n.t("точка, яркая полоса, потом картинка со вспышкой и полосками", "a dot, a bright line, then the picture with a flash and scanlines")
        },
        {
            "id": "glitch",
            "label": I18n.t("Глитч", "Glitch"),
            "hint": I18n.t("строки мигают, полосы съезжаются, цвета сходятся", "rows flicker in, slices slide together, colours meet")
        },
        {
            "id": "drop",
            "label": I18n.t("Падение", "Drop"),
            "hint": I18n.t("падает сверху с наклоном и отскакивает на месте", "drops in from above with a tilt and bounces on its spot")
        },
        {
            "id": "rise",
            "label": I18n.t("Из панели", "Out of the bar"),
            "hint": I18n.t("разворачивается вверх из панели задач", "unfolds upwards out of the taskbar")
        },
        {
            "id": "off",
            "label": I18n.t("Без анимации", "Off"),
            "hint": I18n.t("окно появляется сразу", "the window appears at once")
        }
    ]
    readonly property var closeStyles: [
        {
            "id": "default",
            "label": I18n.t("Обычная", "Default"),
            "hint": I18n.t("как у niri: окно тает и чуть уменьшается", "niri's own: the window fades and shrinks a little")
        },
        {
            "id": "pixel",
            "label": I18n.t("Пиксели", "Pixels"),
            "hint": I18n.t("рассыпается на пиксельные блоки, они гаснут по одному", "crumbles into pixel blocks that blink out one by one")
        },
        {
            "id": "heart",
            "label": I18n.t("Сердечко", "Heart"),
            "hint": I18n.t("окно сжимается внутри сердца цвета темы", "the window shrinks away inside a heart in the theme's colour")
        },
        {
            "id": "crt",
            "label": I18n.t("Старый телевизор", "Old TV"),
            "hint": I18n.t("схлопывается в яркую полосу, потом в точку", "collapses into a bright line, then a dot")
        },
        {
            "id": "glitch",
            "label": I18n.t("Глитч", "Glitch"),
            "hint": I18n.t("полосы разъезжаются, цвета расслаиваются", "slices jump sideways, colours split")
        },
        {
            "id": "fall",
            "label": I18n.t("Падение", "Fall"),
            "hint": I18n.t("окно падает вниз с лёгким наклоном", "the window drops with a slight tilt")
        },
        {
            "id": "minimize",
            "label": I18n.t("В панель", "Into the bar"),
            "hint": I18n.t("складывается вниз, к панели задач", "folds down towards the taskbar")
        },
        {
            "id": "off",
            "label": I18n.t("Без анимации", "Off"),
            "hint": I18n.t("окно исчезает сразу", "the window disappears at once")
        }
    ]
    // what cfg/animation.kdl has ("custom" = a hand-written shader)
    property var anims: ({
            "open": {
                "preset": "",
                "speed": 1,
                "ms": 0
            },
            "close": {
                "preset": "",
                "speed": 1,
                "ms": 0
            }
        })
    readonly property string open: anims.open.preset
    readonly property string close: anims.close.preset
    readonly property real openSpeed: anims.open.speed || 1
    readonly property real closeSpeed: anims.close.speed || 1
    property string log: ""
    readonly property bool busy: writer.running || queue.length > 0
    property var queue: []

    function styles(kind) {
        return kind === "open" ? openStyles : closeStyles;
    }
    function styleOf(kind, id) {
        return styles(kind).find(s => s.id === id) || null;
    }
    function speedOf(kind) {
        return kind === "open" ? openSpeed : closeSpeed;
    }
    // pick(kind, id[, speed]): the speed stays as it is unless given
    function pick(kind, id, speed) {
        if (!styleOf(kind, id))
            return;
        const sp = Math.round(Math.max(0.25, Math.min(4, speed === undefined ? speedOf(kind) : speed)) * 100) / 100;
        if (id === anims[kind].preset && Math.abs(sp - speedOf(kind)) < 0.005)
            return;
        if (Shell.dev) {
            log = I18n.t("В dev-режиме конфиг niri не изменяется", "Dev mode does not modify niri");
            return;
        }
        // one write at a time: both kinds edit the same file
        queue = queue.filter(q => q[0] !== kind).concat([[kind, id, sp]]);
        next();
    }
    function setSpeed(kind, v) {
        const id = anims[kind].preset;
        if (id && id !== "custom" && id !== "off")
            pick(kind, id, v);
    }
    function next() {
        if (writer.running || !queue.length)
            return;
        const [kind, id, sp] = queue[0];
        queue = queue.slice(1);
        writer.command = ["python3", Quickshell.shellDir + "/scripts/window-anim.py", kind, id, String(sp)];
        writer.running = true;
    }
    // a throwaway window that opens and closes itself, to see both animations
    function preview() {
        Shell.exec(Shell.terminalArgv(["sh", "-c", "printf '\\n  ♡ angelOS: " + I18n.t("привет… и пока!", "hello… and bye!") + "\\n'; sleep 1.6"], "angelos.closepreview"));
    }
    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    Process {
        id: reader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/window-anim.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (r.open && r.close)
                        root.anims = {
                            "open": r.open,
                            "close": r.close
                        };
                } catch (e) {}
            }
        }
    }
    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.log = r.error ? r.error : r.ok || "";
                } catch (e) {
                    root.log = text.trim();
                }
            }
        }
        onExited: {
            root.refresh();
            root.next();
        }
    }
}
